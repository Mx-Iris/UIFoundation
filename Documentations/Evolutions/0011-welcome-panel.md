# 0011 - WelcomePanel：把 WelcomeKit 的 Xcode 式欢迎窗口移植进本库

- **状态**: Implemented
- **作者**: JH
- **创建日期**: 2026-08-23
- **最后更新**: 2026-08-23
- **所属愿景**: 无
- **关联提案**: 无
- **实现分支 / PR**: main（与本提案同批次提交）
- **配套文档**: 使用指南 [`Documentations/WelcomePanel.md`](../WelcomePanel.md)

## 摘要

把独立仓库 [`Mx-Iris/WelcomeKit`](https://github.com/Mx-Iris/WelcomeKit)（作者本人的库，
本地位于 `/Volumes/Repositories/Private/Personal/Library/macOS/WelcomeKit`）整体搬进
UIFoundation，落在新的默认关闭 trait `WelcomePanel` 下，仅 macOS。它是 Xcode 那种欢迎窗口：
左半边应用图标 + 名称 + 版本号 + 最多三个操作项，右半边最近项目列表，共三种样式
（`xcode14` / `xcode15` / `xcode26`）。

搬迁遵循本库已有的移植先例（TabBar / QuickActionBar / StatusItemController / SystemHUD）：
公开 API 收进 `WelcomePanelController` 一个顶层符号（其余全部嵌套），内部重复件换成本库已有的
基类与 `.box` 扩展，**运行时行为一律保持原样**。目标写法：

```swift
let panel = WelcomePanelController(configuration: .init(style: .xcode26))
panel.dataSource = self
panel.delegate = self
panel.showWindow(nil)
```

## 动机

- **它 100% 是 AppKit 基础组件，正是本库的定位。** WelcomeKit 没有任何外部依赖、没有业务逻辑，
  全部内容就是一个窗口控制器加几个视图。把它单独放一个仓库，等于让每个要用它的 App 多背一条
  SPM 依赖，而这条依赖提供的东西和 UIFoundation 是同一类。
- **它自带的一整套内部件与本库重复，其中四个类名与本库顶层符号直接冲突。** 也就是说：这套代码
  只要进本库就**必须**做去重，不存在「先原封搬进来、以后再整理」这个选项。去重之后它净增的
  代码只有欢迎窗口本身（约 900 行），其余 500 行是本库已经有的东西。
- **作者要求搬。** 这是本次的直接触发原因，不再另找论证。

## 前期调研

### 原库现状（HEAD `48adfd4`，2025-11-26）

- `Package.swift`：swift-tools 5.7，平台 `macOS 12`，**零外部依赖**，资源一条 `.process("Resources")`。
- `Sources/WelcomeKit/` 共 17 个 Swift 文件、1444 行；测试只有一个空壳 `testExample`。
- 资源：`Resources/Assets.xcassets` 下两个 imageset —— `close` / `close_hover`，各 13×13 与
  26×26 两档（灰色圆圈，hover 态圈内带叉），只被 `xcode14` 样式的关闭按钮使用。
- 公开符号 6 个：`WelcomePanelController`、`WelcomePanelDataSource`、`WelcomePanelDelegate`、
  `WelcomeConfiguration`、`WelcomeStyle`、`WelcomeAction`。

### 与本库重复的部分（去重清单，已逐条核对过双方实现）

| 原库内部件 | 本库已有的等价物 | 备注 |
|---|---|---|
| `View`（图层背衬 + `backgroundColor` / `cornerRadius`） | `LayerBackedView`（`Base/LayerBackedView.swift`） | **顶层名冲突** |
| `TableCellView`（同上，`NSTableCellView` 版） | `LayerBackedTableCellView`（`Base/TableCellView.swift:40`） | **顶层名冲突** |
| `ViewController`（`loadView` 装 `contentView`） | `XiblessViewController<View>`（`UIFoundationShared/Controller/Shared/XiblessViewController.swift:11`） | |
| `ScrollView`（清背景 + 剔除 `NSVisualEffectView`） | `ScrollView`（`Base/ScrollView.swift`） | **顶层名冲突**，行为有差异，见下 |
| `Then` | `Sources/UIFoundationAppKit/Then.swift` | 原库那份带 MIT 头，本库自有 |
| `ArrayBuilder` | FrameworkToolbox 的 `@ArrayBuilder` | |
| `ConstraintMaker.makeConstraints` | `UIFoundationUtilities/ConstraintMaker.swift:18` | 本库版 `@discardableResult` 返回约束数组 |
| `NSView.addSubview(_:fill:)` | `.box.addSubview(_:fill:)`（`UIFoundationToolbox/AppKit/NSView+.swift:47`） | 用了 2 处 |
| `NSAppearance.isDark` | `.box.isDark`（`UIFoundationToolbox/AppKit/NSAppearance+.swift:53`） | 语义更稳（走 `bestMatch`，原库是枚举名硬比） |
| `NSTableView.makeView(ofClass:owner:)` | `.box.makeView(ofClass:identifier:owner:viewBuilder:)`（`UIFoundationToolbox/AppKit/NSTableView+.swift:8`） | 原库定义了但**没用**，两处复用都是手写的 |
| `TrackView` | 无（原库定义了但没用） | 死代码 |

**原库中的死代码（定义了、业务代码零引用，本次直接不搬）**：`TrackView`、`NSLayoutEdgesAnchor`
与 `NSView.edgesAnchor`、`[NSLayoutConstraint].active()`、`NSEdgeInsets.zero`、
`NSTableView.makeView(ofClass:owner:)`。核实方式：在 `Sources/WelcomeKit` 内 grep 各符号并排除
其自身定义文件，命中数为 0。

**本库没有的**：`Bundle.appName` / `Bundle.appVersion`（读 `CFBundleName` /
`CFBundleShortVersionString`）。全仓 grep 无等价物。

### 三处行为差异，替换基类时必须处理

1. **圆角裁剪的条件不同。** 原库 `View.updateLayer()` 写死
   `layer.masksToBounds = cornerRadius != 0`；本库 `LayerBackgroundRenderer.swift:155` 写的是
   `layer.masksToBounds = owner.clipsToBounds`。而 `NSView.clipsToBounds` 虽然从 macOS 10.9
   就有，**默认值取决于链接的 SDK**：链接 macOS 14 及以后为 `false`。因此换成
   `LayerBackedView` 后必须在圆角容器上显式 `clipsToBounds = true`，否则 `xcode15` / `xcode26`
   的无边框圆角窗口会漏出直角内容。
2. **`ScrollView` 对 `NSVisualEffectView` 的处置不同。** 原库在 `didAddSubview` 里
   `removeFromSuperview()`（且在 `super` 之前）；本库是 `isHidden = true`（`Base/ScrollView.swift:29-35`），
   且要显式打开 `isHiddenVisualEffectView`。视觉结果相同，采用本库版本。
3. **`ScrollView.drawsBackground` 在本库是恒 `false` 的只读实现**（`Base/ScrollView.swift:24-27`，
   setter 空实现）。原库两处 `drawsBackground = false` 赋值将变成无操作，结果一致。
   但最近项目列表那侧要靠图层画 `projectViewBackgroundColor`，需要一个会画背景的
   `ScrollView` 子类；`LayerBackedTableCellView` 的 `isLayerBackingEnabled` 默认是
   **`false`**（`Base/TableCellView.swift:40`），两个 cell 子类必须覆写为 `true`，这一点容易漏。

   > **落地修正（2026-08-23）**：本条原写「需要一个开了 `LayerBackgroundProviding` 的
   > `ScrollView` 子类」，**这条路走不通** —— `NSScrollView` 自己就有 `backgroundColor`
   > 属性，协议扩展的同名属性会在每个调用点被类成员遮蔽（根 `CLAUDE.md` 的
   > `LayerBackgroundProviding` 一节点名警告过这个坑，当时没对上号）。最终按原库的做法覆写
   > **类属性** `backgroundColor` 并在 `updateLayer()` 里画进图层，即
   > `WelcomePanelController.BackgroundScrollView`。两个 cell 走 `LayerBackgroundProviding`
   > 没问题 —— `NSTableCellView` 没有同名属性。

### `.xcode26` 是半成品（两处漏判，本次**不修**）

`.xcode26` 由提交 `52c0f59`（2025-10-09）加入，做法是在所有 `case .xcode15:` 上追加
`, .xcode26`。有两处判等**没跟上**，因此 `.xcode26` 下：

- **关闭按钮没有图标** —— `HoverButton.swift:22` 只在 `style == .xcode15` 时设置
  `xmark.circle.fill`。
- **操作项点按没有高亮反馈** —— `WelcomeActionCellView.swift:88` / `:94`
  （`mouseDown` / `mouseUp`）同样只判 `.xcode15`。

作者已决定**原样搬，一行不改**，两处记为已知问题写进指南（见「非目标」）。

### 其他保真照搬、但值得记录的写法

均为原库现状，不在本次修改，落地时写进指南的「已知问题」一节：
`windowNibName` 返回空字符串 `""`；窗口先以 `styleMask: []` 构造再于 `windowDidLoad` 改写；
`xcode15` 分支里 `contentWindow.backgroundColor = .clear` 重复设置一次；
`WelcomeActionCellView` 的 `mouseDown` / `mouseUp` 不调 `super`；
两处 `NSTrackingArea(rect: .zero, …)` 配 `.inVisibleRect`（AppKit 会忽略该 rect，写法有效但迷惑）。

### 平台可用性下限

原库声明 `macOS 12`，但代码中未见 12 专属 API。实际用到的最高门槛是 macOS 11：
`NSTableView.style` 与 `.sourceList`、`NSImage(systemSymbolName:accessibilityDescription:)`、
`NSButton.symbolConfiguration`、`NSAppearance.currentDrawing()`。本库 umbrella 下限是
macOS 10.15，故公开类型标 `@available(macOS 11.0, *)`。

> **落地实测（2026-08-23）**：标 `@available(macOS 11.0, *)` 全量编译通过，**macOS 11 下限成立** ——
> 原库声明的 macOS 12 确实没有对应的 API 依据。

### 资源打包的已知代价

`Sources/UIFoundationAppKit` 已有 `.process("Resources")` 指向一个当前为空的
`Resources/Assets.xcassets`，两个 imageset 直接放进去即可，不需要新增 `.process` 条目。
代价是本库既有的那条 xcassets 坑同样适用（根 `CLAUDE.md` 的 Filter 一节已记录）：
命令行 `swift build` / `swift test` **不跑 `actool`**，`Bundle.module.image(forResource:)`
在纯 CLI 环境返回 `nil`；Xcode 构建的 App 正常。这是作者在选项里已知情接受的代价。
另外 xcassets 是 **target 级**资源，无法按 trait 条件化，因此这两张图会进入所有链接
`UIFoundationAppKit` 的产物（哪怕 `WelcomePanel` trait 关闭）—— 与 Filter 的资源同样处理，
体积为两张 PNG 共约 4 KB。

## 提议方案

新增 trait `WelcomePanel`（默认关闭），代码落在
`Sources/UIFoundationAppKit/WelcomePanel/`，每个文件包 `#if WelcomePanel && os(macOS)`。

1. **命名空间**：`WelcomePanelController` 是唯一的顶层符号，其余全部嵌套在它下面 ——
   公开的 `Configuration` / `Style` / `Action` / `DataSource` / `Delegate`，以及全部内部件
   （`Window`、`WelcomeViewController`、`ProjectsViewController`、`ActionCellView`、
   `ProjectCellView`、`HoverButton`、`BackgroundScrollView`）。协议嵌套在类里依赖 Swift 6.3
   的能力，本库 TabBar 已在用。
2. **内部件按上表逐条替换**为本库已有的基类与 `.box` 扩展；三处行为差异按「前期调研」处理。
   `Bundle.appName` / `appVersion` 作为**内部** helper 留在本 feature 目录内，不新增公开 API。
3. **资源**：两个 imageset 移入 `Sources/UIFoundationAppKit/Resources/Assets.xcassets`，
   并改名为 `WelcomePanelCloseButton` / `WelcomePanelCloseButtonHovered` —— `close` / `close_hover`
   这种名字放进一个多组件共用的资源目录太容易撞车。
4. **行为保真**：几何常量、配色、动画、事件处理逐字照搬，包括上面点名的两处 `.xcode26` 漏判。
5. **示例 App** 新增一个 demo（自开窗口，理由同 Toolbar Navigation demo：浏览器详情面板装不下
   一个独立窗口），并把 `WelcomePanel` 加进示例工程的 `XCLocalSwiftPackageReference` traits 列表。
6. **文档**：使用指南 `Documentations/WelcomePanel.md`（宿主契约 + 已知问题 + 与原库的差异），
   更新 `Documentations/README.md` 索引与根 `CLAUDE.md` 的组件章节。
7. **测试**：`Tests/UIFoundationTests/WelcomePanel/`，同样 trait 门控。

### 非目标

- **不修 `.xcode26` 的两处漏判**（关闭按钮无图、点按无反馈）。作者明确选择原样搬；修它属于行为
  变更，应另立提案或由作者随手改。本次只负责把它们记录下来，不让它们变成「搬迁引入的 bug」。
- **不做 Liquid Glass**。`.xcode26` 目前只是 `.xcode15` 的几何去掉 `NSVisualEffectView`，
  不引入 `NSGlassEffectView`。
- **不重新设计 API**。`window` 与 `contentViewController` 上那两个
  `@available(*, unavailable)` 覆写原样保留（宿主因此拿不到窗口对象），这是原库的既有契约，
  写进指南而不在本次推翻。
- **不动原仓库**。不归档、不改 README、不加废弃说明。
- **不做 UIKit / Catalyst 版本**。macOS 独占。
- **不新增公开的 `Bundle.appName` / `.box` API**。

## 详细设计

### 公开 API（形状不变，只改命名空间）

```swift
@available(macOS 11.0, *)
public final class WelcomePanelController: NSWindowController {
    public weak var dataSource: (any DataSource)?      // didSet -> reloadData()
    public weak var delegate: (any Delegate)?
    public let configuration: Configuration

    public init(configuration: Configuration = .init())
    public func reloadData()
    public override func showWindow(_ sender: Any?)    // 内部先 reloadData()

    @available(*, unavailable) public override var window: NSWindow? { get set }
    @available(*, unavailable) public override var contentViewController: NSViewController? { get set }
}

extension WelcomePanelController {
    public enum Style { case xcode14, xcode15, xcode26 }

    public struct Configuration {
        public var style: Style
        public var welcomeLabelText: String?
        public var welcomeLabelFont: NSFont?
        public var welcomeLabelColor: NSColor?
        public var versionLabelText: String?
        public var versionLabelFont: NSFont?
        public var versionLabelColor: NSColor?
        public var appIconImage: NSImage?
        public var appIconImageShadow: NSShadow?
        public var primaryAction: Action?
        public var secondaryAction: Action?
        public var tertiaryAction: Action?
        public var checkShowOnLaunch: Bool
        public var allActions: [Action] { get }
    }

    public struct Action {
        public var image: NSImage?
        public var imageTintColor: NSColor?
        public var title: String?
        public var titleColor: NSColor?
        public var titleFont: NSFont?
        public var subtitle: String?
        public var subtitleColor: NSColor?
        public var subtitleFont: NSFont?
        public var action: ((Self) -> Void)?
    }

    public protocol DataSource: AnyObject {
        func welcomePanelUsesRecentDocumentURLs(_ welcomePanel: WelcomePanelController) -> Bool
        func numberOfProjects(in welcomePanel: WelcomePanelController) -> Int
        func welcomePanel(_ welcomePanel: WelcomePanelController, urlForProjectAtIndex index: Int) -> URL
    }

    public protocol Delegate: AnyObject {
        func welcomePanel(_ welcomePanel: WelcomePanelController, didCheckShowPanelWhenLaunch isCheck: Bool)
        func welcomePanel(_ welcomePanel: WelcomePanelController, didSelectProjectAtIndex index: Int)
        func welcomePanel(_ welcomePanel: WelcomePanelController, didDoubleClickProjectAtIndex index: Int)
    }
}
```

改名映射（旧 → 新）：`WelcomeConfiguration` → `WelcomePanelController.Configuration`，
`WelcomeStyle` → `.Style`，`WelcomeAction` → `.Action`，
`WelcomePanelDataSource` → `.DataSource`，`WelcomePanelDelegate` → `.Delegate`。
`Style` 上的那些几何 / 字体 / 配色属性维持 `internal`，与原库一致。

### 文件清单（每个基名全库唯一，符合本库的唯一基名规则）

```
Sources/UIFoundationAppKit/WelcomePanel/
├── WelcomePanelController.swift              控制器 + 内嵌 Window
├── WelcomePanel+Configuration.swift
├── WelcomePanel+Style.swift
├── WelcomePanel+Action.swift
├── WelcomePanel+Protocols.swift              DataSource / Delegate
├── WelcomePanel+WelcomeViewController.swift  左半边
├── WelcomePanel+ProjectsViewController.swift 右半边
├── WelcomePanel+ActionCellView.swift
├── WelcomePanel+ProjectCellView.swift
├── WelcomePanel+HoverButton.swift
├── WelcomePanel+ScrollView.swift             带图层背景的 ScrollView 子类
└── WelcomePanel+Bundle.swift                 internal appName / appVersion
```

### Package.swift 改动

```swift
traits: [
    …,
    .trait(name: "TabBar"),
    .trait(name: "WelcomePanel"),   // 新增，默认关闭
],
```

`UIFoundationAppKit` 的 `resources:` 列表**不变** —— 两个 imageset 放进已有的
`Resources/Assets.xcassets`，被现成的 `.process("Resources")` 覆盖。

### 宿主契约（写进指南的部分）

1. **数据是被拉取的，不是被推送的。** `showWindow(_:)` 与窗口
   `windowDidChangeOcclusionState`（变为可见时）都会自动 `reloadData()`；`dataSource` 赋值本身
   也触发一次。宿主自己改了最近项目列表可以调 `reloadData()`，但多数情况不需要。
2. **最多三个操作项**，且顺序固定为 primary / secondary / tertiary，nil 的被跳过。
3. **`numberOfProjects` 返回负数按 0 处理**（原库行为，保留）。
4. **`welcomePanelUsesRecentDocumentURLs` 返回 `true` 时，另外两个 data source 方法不被调用**，
   列表直接取 `NSDocumentController.shared.recentDocumentURLs`。
5. **「启动时显示此窗口」复选框只有 `xcode14` 样式有**；另外两种样式下
   `didCheckShowPanelWhenLaunch` 永远不会触发。
6. **拿不到窗口**：`window` / `contentViewController` 被标记为不可用，宿主只能通过
   `showWindow(_:)` / `close()` 操作。

## 替代方案考量

- **做成独立 target（如 `UIFoundationWelcomePanel`），而不是 `UIFoundationAppKit` 的子目录。**
  否。本库拆独立 target 只有一个成立过的理由 —— `UIFoundationSettings` / `SettingsUI` 要把平台
  下限抬到 macOS 14，不能拖累 umbrella。欢迎窗口不需要抬下限，而它要用
  `LayerBackedView` / `LayerBackedTableCellView` / `ScrollView` 这些 `UIFoundationAppKit` 里的
  基类，独立 target 反而要反向依赖。trait 已经能做到「关闭时一行代码都不编译」。
- **保留原库的内部件，只做重命名避冲突。** 否。那等于在同一个 target 里放两套图层背衬视图基类，
  与本库既有风格背离，且以后改 `LayerBackgroundRenderer` 时这一套不会跟着受益。
- **顺手把 `.xcode26` 的两处漏判修掉。** 否 —— 作者明确选择原样搬。留档理由：搬迁与修 bug 混在
  一批里，会让「搬迁是否忠实」变得无法验证；这两处也确实可能是有意为之（虽然看起来不像）。
- **关闭按钮改用 SF Symbol、彻底不带资源。** 否 —— 作者选择照搬 PNG 保真，已知情接受 CLI 构建
  下取图为 `nil` 的代价。
- **公开 API 照搬原名（`WelcomeConfiguration` / `WelcomeStyle` / `WelcomeAction` 等 6 个顶层名）。**
  否 —— 作者选择嵌套形状。`Style` / `Action` 这类通用名不应出现在 umbrella 的顶层。

## 影响

### 源码兼容性（source compatibility）

**纯新增。** 本库现有 API 一个都不动，trait 默认关闭时编译产物与今天完全一致。

唯一需要点名的场景是**原 WelcomeKit 的使用方迁移**：若某个 App 同时 `import WelcomeKit` 与
开启了 `WelcomePanel` trait 的 `UIFoundation`，两边都有 `WelcomePanelController`，
调用点需要用模块名限定。迁移对照：

```swift
// 迁移前
let panel = WelcomePanelController(configuration: WelcomeConfiguration(style: .xcode15))

// 迁移后
let panel = WelcomePanelController(configuration: .init(style: .xcode15))
// WelcomeStyle → WelcomePanelController.Style（多数场合可用隐式成员简写，无需写全名）
// WelcomeAction → WelcomePanelController.Action
// WelcomePanelDataSource / Delegate → WelcomePanelController.DataSource / .Delegate
```

本库不为原库的旧名提供 `typealias` —— 那些名字从未在本库中存在过，没有可弃用的对象。

### ABI 兼容性

不适用 —— 本库以 SPM 源码分发，使用方每次重新编译。

### 下游影响

- **本仓库**：只动 `UIFoundationAppKit` 一个 target（外加 `Package.swift` 的 traits 列表、
  测试 target、示例工程）。
- **RuntimeViewer**（用 `TabsControl`）、**MachOKitUI**（用 `TextFinder`）、
  **PrivateSymbols**（全面改用本库基类）：**零影响**，trait 默认关闭，且不触碰任何既有类型。
- 唯一的非零成本是那两张 PNG 会进 `UIFoundationAppKit` 的资源包（xcassets 无法按 trait
  条件化），约 4 KB。

### 文档与示例

- 新增使用指南 `Documentations/WelcomePanel.md`：宿主契约六条、三种样式的差异表、
  已知问题（`.xcode26` 两处漏判等）、与原库 WelcomeKit 的差异清单。
- 更新 `Documentations/README.md` 的使用指南索引。
- 更新根 `CLAUDE.md`：新增「Welcome Panel」组件章节（体例与 TabBar / SystemHUD 一致），
  并在示例 App 一节的 traits 列表里补上 `WelcomePanel`。
- 示例 App 新增 `WelcomePanelDemoViewController` 与 `DemoCatalog.all` 一条。
- `THIRD_PARTY_LICENSES.md` **不需要改** —— 移植来源是作者本人的库；原库里唯一的第三方文件
  （`Then.swift`，MIT / Suyeol Jeon）本次不搬，用本库自己那份。

## API 演进与废弃策略

- 无被替代的旧 API，本次不产生任何 `@available(*, deprecated)` 标注。
- 新增 trait 属于纯新增能力，**不需要 semver major 跃迁**。
- 后续若要修 `.xcode26` 的两处漏判、或放开 `window` 的可访问性，都属于行为 / 契约变更，
  另立提案。

## 落地步骤

每一步都应能单独构建通过。

1. `Package.swift` 加 `.trait(name: "WelcomePanel")`；建空目录 `Sources/UIFoundationAppKit/WelcomePanel/`。
2. 搬入并去重：`Style` / `Configuration` / `Action` / 两个协议（纯数据与协议，无 UI 依赖），
   全部嵌套并加 trait 门控。`swift build --traits WelcomePanel` 通过。
3. 搬入视图层：`HoverButton` / `ActionCellView` / `ProjectCellView` / `ScrollView` 子类，
   基类换成本库的 `LayerBackedView` / `LayerBackedTableCellView` / `ScrollView`，
   处理圆角裁剪（`clipsToBounds = true`）与 `isLayerBackingEnabled` 覆写。
4. 搬入两个子控制器与 `WelcomePanelController` + 内嵌 `Window`；`.box` 与 `makeConstraints` 替换到位。
5. 资源：两个 imageset 移入 `Resources/Assets.xcassets` 并改名，更新取图代码。
6. 测试：`Tests/UIFoundationTests/WelcomePanel/`，覆盖 —— 三种样式的几何 / 样式表取值、
   `allActions` 的 nil 压缩与顺序、`numberOfProjects` 负数钳制、
   `usesRecentDocumentURLs` 两条取数路径、cell 复用 identifier。
   **判定成败只认 `swift test` 的退出码**（`${pipestatus[1]}`），不认 xcsift 摘要。
7. 示例 App：加 demo + 在 `XCLocalSwiftPackageReference` 的 traits 里加 `WelcomePanel`，
   `xcodebuild` 构建通过。人工验收三种样式的观感（这一步只能由作者做）。
8. 文档三处 + 提案状态改 `Implemented`。

**收尾时必须判断两件事**（结果写进决策日志）：

- **配套专题文章**：本组件有「从 API 签名看不出来的宿主契约」（上面列了六条），
  **判定需要使用指南** `Documentations/WelcomePanel.md`。实现说明暂不判定，落地时再看是否有
  「下次维护会踩、代码看不出来」的决策留下。
- **新术语**：预计无 —— `WelcomePanel` / `Style` 等都是自解释的。落地时复核。

## 决策日志

| 日期 | 变更 | 说明 |
|------|------|------|
| 2026-08-23 | Created as Draft | 作者要求把自己的 `Mx-Iris/WelcomeKit` 搬进本库。 |
| 2026-08-23 | 定命名空间形状 | 作者选定：`WelcomePanelController` 顶层，`Configuration` / `Style` / `Action` / `DataSource` / `Delegate` 全部嵌套；trait 名 `WelcomePanel`。备选的「`WelcomePanel` 作命名空间 + `.Controller`」与「照搬 6 个顶层原名」均否。 |
| 2026-08-23 | 定 `.xcode26` 处置 | 作者选定**原样搬、一行不改**，两处漏判（关闭按钮无图、点按无高亮）记为已知问题，不在本批次修。 |
| 2026-08-23 | 定关闭按钮资源 | 作者选定照搬两张 PNG 进现有 `Assets.xcassets`，知情接受命令行构建不跑 `actool` 导致取图为 `nil` 的已知代价。备选的 SF Symbol 与代码绘制均否。 |
| 2026-08-23 | Draft → Accepted → In Progress | 作者审阅后批准（「开工」），直接进入实现。 |
| 2026-08-23 | 定原仓库处置 | 暂不处理 —— 不归档、不改 README。搬完后由作者自行决定。 |
| 2026-08-23 | 落地修正：`BackgroundScrollView` 不走 `LayerBackgroundProviding` | 提案原方案在 `NSScrollView` 上撞了同名 `backgroundColor` 属性（协议扩展会被类成员遮蔽），改为按原库做法覆写类属性并在 `updateLayer()` 里画。已在「前期调研」第 3 条原地标注修正。 |
| 2026-08-23 | 落地实测：macOS 11 下限成立 | `@available(macOS 11.0, *)` 全量编译通过，原库声明的 macOS 12 无 API 依据。 |
| 2026-08-23 | 两个子控制器由 `private` 改为 `internal` | 测试需要断言 `projectsViewController` 的取数结果；两个类型本就是 module-internal，对宿主零可见性变化。同 TabBar 里 `NSSegmentedControl` 的先例。 |
| 2026-08-23 | 两处 `.xcode26` 缺口加 canary 测试 | 决定原样搬之后，用两个显式命名 `KNOWN GAP: …` 的测试把现状钉住 —— 将来修复时这两个测试会失败，强制同批次更新指南的「已知问题」。 |
| 2026-08-23 | In Progress → Implemented | 8 步全部完成：trait + 12 个源文件 + 2 个 imageset + 13 个测试（`swift test` 退出码 0，全库 110 测试通过）+ 示例 demo（`xcodebuild` 通过）+ 文档四处。**收尾判断**：① 需要使用指南 —— 已写 `Documentations/WelcomePanel.md`（七条宿主契约 + 已知问题 + 与原库差异）；实现说明不写，该记的决策（圆角裁剪、ScrollView 背景、两处缺口）都已进指南与本提案，另起一篇只会重复。② 无新术语，术语表不动。**人工验收未做** —— 三种样式的观感需作者本人在示例 App 里过目。 |
