# 0017 - AppKitPlus：把 LayerBackedView 的基类换成 NSLayerBackedView

- **状态**: Implemented
- **作者**: JH
- **创建日期**: 2026-09-04
- **最后更新**: 2026-09-04
- **所属愿景**: 无
- **关联提案**: 无
- **实现分支 / PR**: `main`（直接落地）
- **配套文档**: 无独立指南 —— 契约写在 `CLAUDE.md` 的「AppKitPlus」一节

## 摘要

引入 [AppKitPlus](https://github.com/AppKitSupportProgram/AppKitPlus-Release) 作为新的可选依赖，
落在新 SPM trait `AppKitPlus`（默认关闭）下。trait 开启时，`LayerBackedView` 的基类由 `NSView`
换成 AppKitPlus 的 `NSLayerBackedView`（UXKit `UXView` 的移植），两边「一出生就 layer-backed」的
默认值合一，本库视图同时获得 AppKitPlus 导航转场所需的 safe-area 冻结等设施。

代价是**包级 macOS 部署下限从 10.15 抬到 12**。AppKitPlus 以 `binaryTarget` 分发且要求 macOS 12，
SPM 的平台检查发生在包依赖图层面，`@available` 与条件编译都绕不过去（实测见「前期调研」第 1 条）。
这是本提案唯一的破坏性改动，但对三个已知下游实际影响为零 —— 它们的下限都已是 macOS 15。

## 动机

`LayerBackedView`（`Sources/UIFoundationAppKit/Base/LayerBackedView.swift:7`）是本库所有代码构建
视图的根：`XiblessView` / `XibView` / `GradientView` / `SupplementaryView` 都从它派生，
`LayerBackgroundProviding` 的整套 `cornerRadius` / `backgroundColor` / `border*` / `shadow*`
渲染管线也挂在它身上。它做的事只有一件 —— 让视图从构造那一刻起就走
`wantsLayer` + `wantsUpdateLayer` + `updateLayer()` 的路径，而不是 `drawRect:`。

AppKitPlus 的 `NSLayerBackedView` 做的是同一件事，而且做得更完整：它是 UXKit `UXView` 的移植，
除了同样的三条 layer-backing 默认值之外，还带 `userInteractionEnabled`（真 ivar + `hitTest:`
覆写，而不是给普通视图用的关联对象 + 动态子类）、`wantsSafeAreaInsetsFrozen`（转场期间冻结
safe area，避免整棵子树在动画中途重新布局）、`sizeThatFits:`，以及 `layerClass` 这个类级钩子。

两个类职责重叠，却是两套独立的默认值。让前者继承后者有三处实际收益：

1. **默认值只有一份。** 目前 `LayerBackedView` 的 layer-backing 由 `attachToSelfIfNeeded()`
   里的 `LayerBackgroundRenderer.attach(to:)` 顺带打开；换基类后这三条默认值由基类在
   `-initWithFrame:` / `-initWithCoder:` 里保证，renderer 只管背景渲染，职责边界更干净。
2. **本库视图可以直接进 AppKitPlus 的容器。** AppKitPlus 的 `NSNavigationController` 在转场期间
   要求页面视图支持 `wantsSafeAreaInsetsFrozen` —— 那是 `NSLayerBackedView` 的 ivar，普通
   `NSView` 拿不到。换基类后，本库所有派生视图天然满足。
3. **同一作者的两套基础库不该在同一层各造一个轮子。** 两边都会继续演进，重叠部分迟早漂移。

## 前期调研

以下每一条都在本机实测过（macOS 26 / Swift 6.2 工具链），探针代码在 `/tmp/akp-probe`、
`/tmp/akp-probe2`，非仓库产物。

### 1. 平台下限是硬阻塞，`@available` 救不了

AppKitPlus 以 `binaryTarget` 分发（`AppKitPlus.xcframework.zip`，dynamic framework），其包 manifest
声明 `platforms: [.macOS(.v12)]`。造一个 `platforms: [.macOS(.v10_15)]` 的探针包依赖它，trait 打开
即报错：

```
error: the library 'Probe' requires macos 10.15, but depends on the product 'AppKitPlus'
which requires macos 12.0; consider changing the library 'Probe' to require macos 12.0 or later
```

这是包依赖图层面的检查，与源码里写不写 `@available(macOS 12, *)` 无关，也与 `#if AppKitPlus`
无关。`UIFoundationSettings`（macOS 14）与 `UIFoundationRunningApplication`（macOS 11）用的
「包 floor 不动、逐声明标 `@available`」那套办法只适用于源码 target，对二进制依赖无效。

### 2. trait 关闭时，SPM 完全不下载这个依赖

同一个探针包，trait 关闭时构建：不产生 `Package.resolved`、不 clone 仓库、不下载
2.6 MB 的 xcframework，构建正常通过。**默认消费者为这个依赖付出的成本是零**（除去 macOS
floor 抬升本身）。

### 3. 0.1.6 会静默劫持 `backgroundColor`（第一条排除理由）

调研最初拿到的是 0.1.6，那个版本有两处会破坏本库现有行为，实测确认：

- 它有一个 `NSView (Appearance)` category 声明 `@property NSColor *backgroundColor`。ObjC 类成员
  在名字查找上赢过 Swift 协议扩展，于是 `LayerBackgroundProviding.backgroundColor` 被整个盖住：
  探针里 `LayerBackedView().backgroundColor = .red` 走的是 AppKitPlus 的实现，renderer 的 setter
  一次都没被调用。`NSLayerBackedView` 自己的 `borderColor` 同样盖住协议的 `borderColor`。
- 泄漏范围是整个下游：同一 target 内**没有** `import AppKitPlus` 的文件看得到这个属性，只
  `import UIFoundation` 的下游模块也看得到。因此中招的不止 `LayerBackedView` —— 探针里
  `NSTableCellView` 的 conformer（对应本库的 `LayerBackedTableCellView`）同样被劫持，而它根本
  不继承新基类。
- 0.1.6 还把两轴的 content compression resistance 从 AppKit 默认的 750 降到 500，会改变现有四个
  子类的布局优先级。

0.2.0 把 `NSView (Appearance)` 整个删掉了，`NSLayerBackedView` 也不再有 `borderColor`，并在头
文件里显式记录「不跟随 UXView 降到 500」。同一组探针在 0.2.0 下重跑：

```
PROTOCOL backgroundColor set     ← 协议扩展重新拿回控制权
PROTOCOL borderColor set
PROTOCOL cornerRadius set
defaults: wantsLayer true  wantsUpdateLayer true  redrawPolicy 1(onSetNeedsDisplay)
compression h: 750.0
```

三条默认值与本库现有实现逐条一致，compression 保持 AppKit 默认。**所以 0.1.x 必须排除。**
（0.2.0 后来也被排除，理由见第 5 条。）

### 4. `NSView` 一层的名字冲突面是干净的

> **这一条当时被误当成了「冲突面已复查干净」，第 5 条是它的更正。** 只查 `NSView` 是不够的。

0.2.0 在 `NSView` 上加的 category 成员全集：`accessories`、`contentMode`、`center`、`transform`、
`focused`、`interactions`、`setNeedsUpdateProperties` / `updateProperties` /
`updatePropertiesIfNeeded`、`bringSubviewToFront:` / `sendSubviewToBack:` / `insertSubview:*:`，
以及 `NSView (Animation)` 的一组类方法。与本库的交集：

- 与 `LayerBackgroundProviding` 的 12 个属性名**无交集**。
- `bringSubviewToFront` / `insertSubview(_:belowSubview:)` 等在本库里位于 `.box` 命名空间
  （`Sources/UIFoundationToolbox/Shared/NSUIView+.swift:133-176`），不在 `NSView` 本身上，
  因此不产生歧义，只是多了一条等价路径。

### 5. 真正的冲突面不是属性遮蔽，而是「非法 override」，而且会传染

调研阶段只查了 `NSView` / `NSViewController` 两个宿主类的 category，**这是不够的**，落地时被编译器
补上了：AppKitPlus 还在 `NSCollectionViewItem` / `NSTableCellView` / `NSControl` / `NSButton` /
`NSMenuItem` / `NSToolbarItem` / `NSWindow` / `NSTableView` / `NSOutlineView` / `NSCollectionView` /
`NSEvent` / `NSCell` 上都加了成员。

更关键的是冲突的**性质**与 0.1.6 那种「静默遮蔽」不同：当子类声明一个与 AppKitPlus 加在其父类上的
extension 成员同名的属性时，Swift 判定为非法 override 而非遮蔽，直接编译失败：

```
error: overriding non-open property outside of its defining module
error: property 'contentView' with type 'View' cannot override a property with type 'NSView'
```

三条实测结论：

- **`@nonobjc` 救不了。** 造了一个纯 Swift 探针（模块 A 声明 `@nonobjc` 的 extension 属性，模块 B
  在子类里声明同名存储属性），报错一字不差。这是 Swift 对「类的 extension 成员」的通用规则，不是
  ObjC 桥接的副作用 —— 因此上游加 `@nonobjc` 不是解法，改名才是。
- **它随模块传播。** 一个只 `import` 本库、从不 `import AppKitPlus` 的下游模块，写一个带
  `contentView` 的 `NSCollectionViewItem` 子类，照样编译失败。所以「把依赖关进一个小 target」
  这条路是堵死的 —— 拆 target 不改变传播。
- **`MemberImportVisibility`（SE-0444）理论上能挡住，实际不可行**：给 `UIFoundationAppKit` 启用后
  产生 **763 个错误**（该 target 几十个文件都依赖隐式的传递可见性）。那是一笔独立的技术债，不能
  混进本提案。

落地实际踩到三处，处理方式各不相同，见「落地步骤」与决策日志。

### 6. 已知下游的 macOS 下限都已高于 12

| 下游 | 依赖 UIFoundation 的包 | macOS 下限 |
|------|----------------------|-----------|
| RuntimeViewer | `RuntimeViewerPackages` | 15 |
| MachOKitUI | 包根 | 15 |
| PrivateSymbols | app target | 15 |

（`RuntimeViewerCore` 是 macOS 10.15，但它不依赖 UIFoundation。）示例 app 的部署目标是 14.0。
因此 floor 从 10.15 抬到 12 对现有下游**实际影响为零**；破坏性是名义上的，针对的是尚未出现的
10.15–11 消费者。

## 提议方案

1. **新增 SPM trait `AppKitPlus`**，默认关闭，与现有 12 个 trait 并列。
2. **新增依赖** `https://github.com/AppKitSupportProgram/AppKitPlus-Release`，约束 `from: "0.2.1"`。
   0.2.1 是下限而非上限，两个更早的版本都必须排除：0.1.x 会静默劫持 `backgroundColor`
   （前期调研第 3 条），0.2.0 的 `NSCollectionViewItem` / `NSTableCellView` 带一个名为
   `contentView` 的 extension 属性（前期调研第 5 条），0.2.1 已将其改名 `configurationContentView`。
   上游 README 声明「无 API/ABI 稳定性保证，任何版本都可能删类、改布局、改协议要求」并建议 pin
   精确版本，本库不采纳这条建议 —— 两个仓库同一作者，上游破坏性变更会在本库这边同步处理，比起
   把每次 patch 升级都变成一次改 manifest 的动作，`from:` 更实用。需要知道的语义：SPM 的 `from:`
   即使对 0.x 版本也是 up-to-next-major，即 `0.2.0 ..< 1.0.0`，因此 0.3.0 这类可能带破坏性变更的
   版本会被自动接受；升级时仍需按前期调研第 5 条复查名字冲突面。`UIFoundationAppKit` 通过
   `condition: .when(traits: ["AppKitPlus"])` 条件依赖它。
3. **包级 `platforms` 的 macOS 项由 `.v10_15` 改为 `.v12`**，其余平台不动。
4. **`LayerBackedView` 的基类条件化**：trait 开启时是 `NSLayerBackedView`，关闭时仍是 `NSView`，
   通过一个 `LayerBackedViewBase` typealias 表达（见「详细设计」）。类体本身不变。
5. **示例 app 启用该 trait**，让 `LayerBackgroundDemoViewController` 这类现有 demo 成为 trait
   开启路径的常驻验证。示例部署目标已是 14.0，无需调整。
6. **新增测试** 固定基类归属与协议属性归属，两条路径各有断言。

### 非目标

- **不改 `LayerBackedTableCellView` / `TableCellView` / `XiblessViewController` 的基类。**
  前者的基类 `NSTableCellView` 由 AppKit 定死；后两者 AppKitPlus 虽有 `NSLayerBackedViewController`
  对应物，但本次只做用户点名的那一个类，避免范围蔓延。
- **不清理现有 133 处 `@available(macOS 10.x/11, *)` / `#available` 判断。** 抬 floor 后它们在逻辑上
  变成冗余，但**实测编译器一条警告都不产生**（落地后 `swift build` 警告总数为 0）—— 提案初稿里
  「会产生 always-true 警告」是未经验证的推测，此处更正。因此清理它们纯属可读性收益，属独立技术债，
  混进来只会让本次 diff 无法审查。
- **不把 `UIFoundationRunningApplication` 并入 umbrella。** 抬 floor 到 12 之后，它「macOS 11 高于
  包的 10.15」这条隔离理由确实失效了，但那是另一个决定，需要单独评估。`UIFoundationSettings`
  的 macOS 14 理由仍然成立。
- **不 `@_exported import AppKitPlus`。** 下游想用 AppKitPlus 的 API 自己 import。基类成员通过
  继承可见，这是正常的 SPM 行为。
- **不用 AppKitPlus 的 `NSNavigationController` 替换本库 `Navigation` trait 那套。** 两套实现来源
  不同（本库那套是从 macOS App Store 逆向的，见提案 0001），是否合并是独立议题。
- **不配置 local/remote 本地依赖切换。** 本机 `/Volumes/Code/Personal/AppKitPlus` 是 Xcode 工程
  而非 SPM 包，`AppKitPlus-Release` 本地那份也只是同一个 `binaryTarget` manifest，挂上去没有收益。

## 详细设计

### `Package.swift`

```swift
platforms: [
    // AppKit — macOS 12 是 AppKitPlus 的下限，见 Evolution 0017
    .macOS(.v12),
    // UIKit
    .iOS(.v13), .macCatalyst(.v13), .tvOS(.v13), .visionOS(.v1), .watchOS(.v6),
],

traits: [
    .trait(name: "AppKitPlus"),
    .trait(name: "AppleInternal"),
    // …既有 trait 按字母序排列
],

dependencies: [
    // 0.2.1 is a floor, not a pin. Two earlier releases are excluded for reasons
    // that both fail silently or confusingly -- see 前期调研 3 and 5.
    .package(
        url: "https://github.com/AppKitSupportProgram/AppKitPlus-Release",
        from: "0.2.1",
    ),
],

.target(
    name: "UIFoundationAppKit",
    dependencies: [
        // …既有依赖
        .product(name: "AppKitPlus", package: "AppKitPlus-Release", condition: .when(platforms: appkitPlatforms, traits: ["AppKitPlus"])),
    ],
    // …
),
```

### `LayerBackedView.swift`

```swift
#if canImport(AppKit) && !targetEnvironment(macCatalyst)

import AppKit
import UIFoundationToolbox
#if AppKitPlus && canImport(AppKitPlus)
import AppKitPlus
#endif

#if AppKitPlus && canImport(AppKitPlus)
/// The class `LayerBackedView` inherits from.
///
/// With the `AppKitPlus` trait on this is `NSLayerBackedView`, whose initializers
/// already apply the layer-backing defaults this class used to apply itself, and
/// which carries `userInteractionEnabled` / `wantsSafeAreaInsetsFrozen` as real
/// ivars rather than associated objects.
public typealias LayerBackedViewBase = NSLayerBackedView
#else
public typealias LayerBackedViewBase = NSView
#endif

@IBDesignable
open class LayerBackedView: LayerBackedViewBase, LayerBackgroundProviding {
    // 类体不变
}
```

类体一行不改：`isLayerBackingEnabled`、两个 init、`setup()` / `firstLayout()`、
`layout()` / `updateLayer()` 的覆写、`wantsUpdateLayer` 全部照旧。`NSLayerBackedView` 的
`-wantsUpdateLayer` 返回 `YES`，本类覆写成 `isLayerBackingEnabled`，语义与现在一致
（默认 `true`，被显式关掉时回到 `drawRect:` 路径 —— 这正是 AppKitPlus 头文件推荐的做法）。

### 测试

新增 `Tests/UIFoundationTests/LayerBackedViewBaseClassTests.swift`：

```swift
@Test func inheritsFromAppKitPlusBaseWhenTraitEnabled() {
    #if AppKitPlus && canImport(AppKitPlus)
    #expect(LayerBackedView.superclass() == NSLayerBackedView.self)
    #else
    #expect(LayerBackedView.superclass() == NSView.self)
    #endif
}

/// Canary: 0.1.6 的 `NSView (Appearance)` category 会把这个 setter 整个盖掉。
@Test func backgroundColorStillRoutesThroughTheRenderer() { … }

/// Canary: 0.1.6 把两轴压缩阻力降到 500。
@Test func compressionResistanceStaysAtAppKitDefault() { … }
```

后两个测试在 trait 两侧都要通过 —— 它们断言的是「换基类没有改变既有语义」，而不是
AppKitPlus 的行为。

## 替代方案考量

- **manifest 里用环境变量条件化 `platforms`**（只在设了变量时才抬到 12）。能让默认消费者留在
  10.15。否决：远程消费者与 Xcode 集成路径都无法可靠地设置这个变量，属于 hack，且会让
  `Package.resolved` 的行为随环境漂移。
- **把依赖 AppKitPlus 的代码拆到独立 target / 独立包。** 这是本库对付高 floor 组件的既有手法
  （`UIFoundationSettings` / `UIFoundationRunningApplication`）。此处不适用：要换基类的
  `LayerBackedView` 就在 `UIFoundationAppKit` 里，是全库视图的根，无法搬走；而 SPM 的
  `platforms` 是包级声明，拆 target 也不改变包 floor 的检查结果。
- **停留在 0.1.6，靠在两个 conformer 上显式 `override var backgroundColor / borderColor` 转发回
  renderer。** 实测编译与运行都成立。否决：这只护住了本库自己的两个类，下游任何自定义
  `LayerBackgroundProviding` conformer 都会静默中招，且 compression 750→500 仍需另行补偿。
  0.2.0 让这两个问题同时消失，没有理由退回去。
- **不加这个依赖，把 `NSLayerBackedView` 的能力抄进本库。** 否决：`userInteractionEnabled` 的
  hitTest 语义、safe-area 冻结与 AppKitPlus 导航容器是配套的，抄一半等于制造第二次漂移。

## 影响

### 源码兼容性（source compatibility）

**有破坏，两处：**

1. **包级 macOS 下限 10.15 → 12。** 部署目标低于 12 的消费者无法再依赖本库任何 product，
   与是否开启 `AppKitPlus` trait 无关。已知下游全部为 macOS 15，实际影响为零（前期调研第 5 条）。
   无法用 `@available(*, deprecated)` 提供过渡 —— 平台下限没有软着陆机制。
2. **trait 开启时 `LayerBackedView` 的公开 API 表面变大**：继承而来的
   `userInteractionEnabled` / `wantsSafeAreaInsetsFrozen` / `contentMode` / `center` /
   `transform` / `sizeThatFits(_:)` / `layerClass` 等成员出现在所有派生类上。这是纯新增，不破坏
   现有调用点，但意味着 trait 开与关的 API 表面不同 —— 这是 trait 机制本身的既定含义。

3. **trait 开启时，下游多出一条命名约束**：`NSView` / `NSViewController` / `NSTableCellView` /
   `NSCollectionViewItem` 等类的子类，不能再声明与 AppKitPlus 加在这些类上的 extension 成员同名的
   属性 —— Swift 判为非法 override，直接编译失败，且**这个约束随模块传播**，下游即使从不
   `import AppKitPlus` 也逃不掉（前期调研第 5 条）。已知会撞的名字见 `CLAUDE.md`「AppKitPlus」一节
   的表格。trait 关闭时完全不存在这条约束。

现有的 `cornerRadius` / `backgroundColor` / `border*` / `shadow*` 调用点行为**完全不变**，
由「详细设计」里两个 canary 测试固定。

本库内部有两处标识符被改名，均为**内部符号**，不影响公开 API：
`QuickActionBar.ResultsTableView.parent` → `resultsView`，示例 app 的
`NavigationDemoViewController.navigationController` → `navigationStackController`。

### ABI 兼容性

不适用 —— 本库以 SPM 源码分发，使用方每次重新编译。

（AppKitPlus 自身是二进制分发且开启了 library evolution，但那是它的 ABI，不是本库的。上游
不保证 ABI 稳定，正是本提案 pin 精确版本的理由。）

### 下游影响

- 本仓库内：`UIFoundationAppKit`（新增条件依赖 + 换基类）、`UIFoundation`（umbrella 传递）、
  示例 app（启用 trait）。其余 target 不受影响。
- 跨仓库：**RuntimeViewer**、**MachOKitUI**、**PrivateSymbols** 三个已知下游都消费
  `LayerBackedView` 的派生类。它们的 macOS 下限已是 15，升级本库时无需任何改动，也不必开启新
  trait —— 默认关闭意味着它们拿到的仍是 `NSView` 基类。

### 文档与示例

- `CLAUDE.md`：External Dependencies 表加一行；Module Dependency Graph 标注条件依赖；
  「View Base Class Hierarchy」段落说明条件基类；新增一节介绍 `AppKitPlus` trait（含 0.1.6 的
  遮蔽陷阱与版本下限理由）；Example App 一节的 trait 列表补上 `AppKitPlus`；
  Build & Test 一节补 `swift build --traits AppKitPlus`。
- `Documentations/Evolutions/README.md` 与 `Documentations/README.md`：登记本提案。
- 是否需要独立使用指南在落地时判断 —— 倾向不需要，`CLAUDE.md` 一节足以覆盖。

## API 演进与废弃策略

- 无 API 被替代，无需废弃标注。
- **需要 semver major 跃迁**：macOS 部署下限抬升是破坏性变更。本库目前未打 tag 版本号，若将来
  开始打，此改动应落在一次 major 上。
- 上游 AppKitPlus 处于 pre-1.0 测试期且自述无 API/ABI 稳定性，但本库仍用 `from: "0.2.1"` 而非
  `.exact(_:)`：两个仓库同一作者，破坏性变更在本库这边同步处理。注意 SPM 的 `from:` 对 0.x 也是
  up-to-next-major（`0.2.0 ..< 1.0.0`），0.3.0 会被自动取用 —— **上游发布新的 minor 时，仍要按
  前期调研第 4 条重新复查 `NSView` category 的名字冲突面**，这是一次独立动作，不因为约束是
  `from:` 就自动安全。

## 落地步骤

已全部执行，逐条记录实际结果：

1. `Package.swift`：加 trait、加依赖（`from: "0.2.1"`）、加条件 product 依赖、抬 macOS floor 到 12。
2. `LayerBackedView.swift`：引入 `LayerBackedViewBase` typealias 并换基类，类体一行未动。
3. **处理三处名字冲突**（前期调研第 5 条），三处的处理方式不同，这正是原则所在：
   - `XiblessCollectionViewItem.contentView` —— **在上游修**。`contentView` 是任何
     `NSCollectionViewItem` / `NSTableCellView` 子类都想要的名字，本库改名只护住自己，
     护不住下游。AppKitPlus 0.2.1 将其改名 `configurationContentView`，本库版本下限随之提到 0.2.1，
     该文件最终**零改动**。
   - `QuickActionBar.ResultsTableView.parent` → `resultsView` —— 撞 `NSFocusItem.parent`
     （经 `NSView (Focus)`）。内部类型的内部属性，改名无破坏性。
   - 示例 app `NavigationDemoViewController.navigationController` → `navigationStackController`
     —— 撞 `NSViewController.navigationController`。这一处最有代表性：本库 `Navigation` trait 的
     宿主天然会用这个名字，它演示了 trait 开启后下游要遵守的命名约束。
4. 新增 `LayerBackedViewBaseClassTests.swift`（4 个测试），trait 两侧各跑一次，均通过。
5. 示例 app 的 traits 列表加 `AppKitPlus`，`xcodebuild … build` 通过。
6. 文档同批次更新：`CLAUDE.md` 新增「AppKitPlus」一节（含命名冲突契约表与升级复查清单），
   并更新平台行、依赖表、模块依赖图、View Base Class Hierarchy、构建命令、示例 trait 列表。

### 验证矩阵

| 命令 | 结果 |
|------|------|
| `swift build` / `swift test`（trait 全关） | 通过，112 tests |
| `swift build --traits AppKitPlus` / `swift test …` | 通过，112 tests |
| `swift build --traits <13 个全开>` | 通过 |
| `swift test --traits <13 个全开>` | 379 tests，4 个失败**全部为既有失败**（见下） |
| `xcodebuild` 构建示例 app | BUILD SUCCEEDED |

**单开一个 trait 构建是不够的**：`parent` 那处冲突在 `QuickActionBar` 的源码里，只有两个 trait
同时开才编译得到；`navigationController` 那处只有构建示例 app 才会暴露。

全 trait 测试的 4 个失败**都不是本次引入的**，已逐个对基线（`git stash` 后同命令）验证：

- `FilterResourcesTests` 三个 —— 命令行 `swift test` 不跑 `actool`，资源查找返回 `nil`。
  这是 `CLAUDE.md` 早已记录的已知限制，须用 `xcodebuild` 才能跑。
- `QuickActionBarPresentationTests` 的「Resuming a dismissal keeps the existing presentation alive」
  —— 基线同样失败。

顺带修掉一处**范围外的既有破损**：`Tests/UIFoundationTests/Settings/AppSettingsTests.swift` 仍
`@testable import UIFoundationSettings`，而 `AppSettings` 已在 commit `25cb784` 移到
`UIFoundationSettingsUI`。它只在 `Settings` trait 开启时才编译，所以此前一直没被发现，而它挡住了
全 trait 验证这条路径，故补一个 import 修复。

## 决策日志

| 日期 | 变更 | 说明 |
|------|------|------|
| 2026-09-04 | Created as Draft | 用户要求：加 AppKitPlus 依赖，用 trait 开启、默认不开启，有这个库时 `LayerBackedView` 继承自 `NSLayerBackedView`。 |
| 2026-09-04 | 平台方案定为「包级抬到 macOS 12」 | 实测确认 SPM 的平台检查在包图层面，`@available` 与条件编译都绕不过（前期调研第 1 条）。用户在三个选项（抬 floor / 环境变量 hack / 放弃）中选择抬 floor。 |
| 2026-09-04 | 版本下限定为 0.2.0 | 用户指出 0.2.0 已移除 `backgroundColor` / `borderColor` 与 500 的压缩阻力默认值，实测复核属实。0.1.6 的遮蔽问题因此消失，原计划的「在两个 conformer 上显式 override」方案作废。 |
| 2026-09-04 | Accepted → In Progress | 用户批准（「开工」），开始实现。 |
| 2026-09-04 | 发现调研遗漏：冲突面不止 `NSView` / `NSViewController` | 换基类后首次构建即失败于 `XiblessCollectionViewItem.contentView`。性质也与预想不同 —— 是「非法 override」而非「静默遮蔽」，且随模块传播到下游。原以为可以拆 target 隔离，实测证否。 |
| 2026-09-04 | `contentView` 冲突选择在上游修，而非本库改名 | 用户决定。四个选项（上游改名 / 本库改名 / `#if` 排除该类 / 暂停）中选上游改名：它是唯一能同时护住本库与所有下游的做法。实测 `@nonobjc` 不构成替代解法。AppKitPlus 0.2.1 已改名 `configurationContentView`，本库版本下限随之从 0.2.0 提到 0.2.1，`XiblessCollectionViewItem` 最终零改动。 |
| 2026-09-04 | 另两处冲突就地改名 | `QuickActionBar.ResultsTableView.parent` → `resultsView`、示例 app 的 `navigationController` → `navigationStackController`。两者都是内部符号，且名字并非下游普遍需要，不值得再推一次上游改动。 |
| 2026-09-04 | 放弃 `MemberImportVisibility` 作为隔离手段 | 给 `UIFoundationAppKit` 启用后产生 763 个错误。它本身是值得做的 import 卫生改造，但属独立技术债，混进来会让本次 diff 无法审查。 |
| 2026-09-04 | 修复一处范围外的既有破损 | `AppSettingsTests.swift` 的 import 在 `25cb784` 之后就失效了，只在 `Settings` trait 开启时暴露，挡住了全 trait 验证路径。补一个 `@testable import UIFoundationSettingsUI`。 |
| 2026-09-04 | 版本约束由 `.exact("0.2.0")` 改为 `from: "0.2.0"` | 用户决定。放弃上游 README「pin 精确版本」的建议：两个仓库同一作者，破坏性变更同步处理，逐次改 manifest 不划算。代价是 SPM 的 `from:` 对 0.x 同样是 up-to-next-major，0.3.0 会被自动取用，因此上游发新 minor 时必须重新复查名字冲突面。 |
| 2026-09-04 | In Progress → Implemented | 代码、测试、示例、文档同批次落地；验证矩阵见「落地步骤」。收尾判断：**不需要**独立使用指南 —— 唯一的宿主契约是命名约束，写在 `CLAUDE.md` 的「AppKitPlus」一节即可，单独开一篇会让它更难被读到。**未引入新术语**，术语表不动。 |
| 2026-09-04 | 示例 app 启用该 trait；不配置 local 依赖切换 | 未经询问的假设：示例部署目标已是 14.0，启用无成本且能常驻验证 trait 开启路径；本机 AppKitPlus 源码仓库不是 SPM 包，local 切换无收益。 |
| 2026-09-06 | 补平台条件：`.when(traits:)` → `.when(platforms: appkitPlatforms, traits:)` | 原写法只按 trait 门控，漏了平台。AppKitPlus 只发 macOS 切片的 xcframework，因此**任何开启该 trait 的下游，其 iOS / tvOS / visionOS 构建必然链接失败**（`no library for this platform was found`），报错点同时出现在 `UIFoundationAppKit` 和下游自己的 target 上。本库自测发现不了：trait 默认关闭，且本库的验证矩阵未覆盖「trait 开启 + 非 macOS 平台」这一格。由 RuntimeViewer 的发布构建暴露 —— 它启用该 trait 后，CI 跑满一小时挂在 iOS Simulator 那一步。修复后实测：下游 iOS Simulator 构建从 exit 65 变 exit 0，macOS 构建仍以 `-DAppKitPlus` 编译 `UIFoundationAppKit` 并链接框架。trait 的编译标志在非 macOS 上仍会传入，无害 —— `LayerBackedView.swift` 的守卫是 `#if AppKitPlus && canImport(AppKitPlus)`，第二个条件在那里为假，这也正是当初写两重条件的意义。 |
