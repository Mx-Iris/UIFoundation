# Draft - 开 AppKitPlus trait 时把 LayerBackedView 的外观交给 AppKitPlus

- **状态**: In Progress
- **作者**: JH
- **创建日期**: 2026-11-26
- **最后更新**: 2026-11-26
- **所属愿景**: 无
- **关联提案**: [0017-appkitplus-layer-backed-view](0017-appkitplus-layer-backed-view.md)（`LayerBackedView` 改继承 `NSLayerBackedView` 的来历）；上游 AppKitPlus 的 `0122-layer-backed-view-appearance`（给 `NSLayerBackedView` 加外观成员，其「后续」一节点名要本库配合）
- **实现分支 / PR**: `feature/appkitplus-layer-appearance`，从 `main` 切出，worktree `.worktrees/UIFoundation-AppKitPlusLayerAppearance`
- **配套文档**: 无单独文档——改现有指南 [`LayerBackground.md`](../LayerBackground.md)、[`AppKitPlus.md`](../AppKitPlus.md)、[`WelcomePanel.md`](../WelcomePanel.md)
- **网页版**: 同目录同名的 `.html`

## 摘要

AppKitPlus 0.24.0 给 `NSLayerBackedView` 加了 `cornerRadius`、`cornerCurve`、`backgroundColor`、`borderColor`、
`borderWidth`、`borderPositions`、`borderLocation`、`borderInsets` 与 `shadowProperties`。开着 `AppKitPlus` trait 时
`LayerBackedView` 继承 `NSLayerBackedView`，这些 Objective-C 类成员在名字查找上压过 `LayerBackgroundProviding`
协议扩展里的同名属性：调用方设的值进了 AppKitPlus，本库的 `LayerBackgroundRenderer` 什么也收不到，却仍在每次
`updateLayer()` 里用自己的默认值（圆角 0、背景 `nil`）把 layer 改回去。结果是所有经 `LayerBackedView` 设的圆角和背景色
都没了——RuntimeViewer 的欢迎窗口变成直角就是这样来的。本提案按 AppKitPlus 0122 当初定好的分工收尾：trait 打开时，
`LayerBackedView` 不再遵循 `LayerBackgroundProviding`、不再挂 renderer，外观全部交给 AppKitPlus 自己的成员；
`AppKitPlus-Release` 的下限从 0.6.0 提到 0.24.0；为保持源码兼容，trait 下补上 `shadowColor` 等五个阴影属性，
转写到 `shadowProperties`；`borderPositions` 在 trait 下仍默认空集合，与 trait 关闭时一致。trait 关闭时一行不变。
随 0.51.0 发布。

## 动机

**现状是坏的，而且已经传到下游。** RuntimeViewer 在 2026-11-26 把 AppKitPlus 抬到 0.24.0（为了 `NSResponderDebugPanel`），
同时依赖本库 0.50.1 并开着 `AppKitPlus` 与 `WelcomePanel` trait。之后它的欢迎窗口（`WelcomePanelController`，
`.xcode26` 样式）从 20 点圆角变成直角，窗口阴影也变成方的。

**复现过，能变红。** 把本库 0.50.1 导出到一个干净目录，只把 `AppKitPlus-Release` 解析到 0.24.0，跑现成的哨兵测试：

```bash
swift package --disable-keychain --traits AppKitPlus update AppKitPlus-Release
swift test --traits AppKitPlus,WelcomePanel --filter LayerBackedViewBaseClassTests
```

`backgroundRoutesThroughRenderer` 的两条断言都失败（`layer?.backgroundColor == NSColor.red.cgColor`、
`layer?.cornerRadius == CGFloat(8)`），退出码 1，其余三条通过。这条哨兵本来就是为「AppKitPlus 加了同名成员、静默接管」
而设的（AppKitPlus 0.1.6 的 `backgroundColor` 分类出过一次同样的事），但本库自己的 `Package.resolved` 一直钉着
AppKitPlus 0.6.0，它从没在 0.24.0 上跑过，所以没拦住。

**上游已经写明要本库配合。** AppKitPlus 0122「后续」一节原文要求：本库在 AppKitPlus 新版发布后把下限提到那一版，
trait 打开时 `LayerBackedView` 不再走 `LayerBackgroundRenderer`，并且「两边要一起发」——否则就是现在这样，
本库依赖范围内的旧版本解析到 AppKitPlus 新版，renderer 用默认值盖掉 layer。0.24.0 发了，本库这一侧没做。

**影响面不止欢迎窗口。** 本库 `Sources/` 里有 76 处给视图设 `cornerRadius` / `backgroundColor` / `cornerCurve`，其中经
`LayerBackedView` 及其子类（`XiblessView`、各组件的私有视图）设的，在「trait 打开 + AppKitPlus 0.24.0」下全部失效。
RuntimeViewer 自己还有 Load Frameworks 的横幅、编辑区窗格的分隔短线、起始页 Open Quickly 输入框的胶囊与描边环，
用的都是 `LayerBackedView`。

## 前期调研

- **冲突怎么发生的**：`LayerBackedView`（`Sources/UIFoundationAppKit/Base/LayerBackedView.swift:33`）在
  `#if AppKitPlus && canImport(AppKitPlus)` 下继承 `NSLayerBackedView`，并遵循 `LayerBackgroundProviding`。外观属性
  全是协议扩展成员（`Sources/UIFoundationAppKit/Base/LayerBackgroundProviding.swift:39` 起），转发到挂在关联对象上的
  `LayerBackgroundRenderer`。具体类型上调用 `view.cornerRadius = 20` 时，Swift 先找类成员，找到
  `NSLayerBackedView.cornerRadius` 就不再看协议扩展。
- **renderer 为什么会把值改回去**：`LayerBackedView.updateLayer()` 调 `updateLayerBackgroundIfNeeded()` →
  `LayerBackgroundRenderer.updateLayer()`（`LayerBackgroundRenderer.swift:133`），无条件写
  `layer.cornerRadius = cornerRadius`、`layer.backgroundColor = backgroundColor?.cgColor`、阴影四项和
  `layer.masksToBounds = owner.clipsToBounds`。renderer 收不到值，写下去的就是默认值。
- **AppKitPlus 0.24.0 的成员**（`AppKitPlus/View/NSLayerBackedView.h`，声明在 `NSLayerBackedView` 协议上，三个类
  `NSLayerBackedView` / `NSLayerBackedControl` / `NSLayerBackedTableCellView` 共用一份实现）：
  - `cornerRadius`、`backgroundColor` 转发到 AppKit 自己的同名私有成员（AppKit 每次刷新 layer 都会写回），系统没有时自存；
  - `cornerCurve`、`borderColor`、`borderWidth`、`borderPositions`（`NSLayerBackedView.BorderPositions`，默认 `.all`）、
    `borderLocation`（`NSLayerBackedView.BorderLocation`，`inside` / `center` / `outside`）、`borderInsets` 由视图自己写，
    颜色按有效外观解析、外观或强调色变化时重新解析；
  - 阴影是一个 `shadowProperties: NSShadowProperties`（Swift 值类型：`color: NSColor`、`opacity: CGFloat`、
    `radius: CGFloat`、`offset: CGSize`、`path: NSBezierPath?`），与 `NSView.shadow` 是同一个阴影；默认黑色、不透明度 0、
    半径 0、偏移零；
  - 「没人设过的成员从不写」：子类自己写 layer 的照常有效；
  - 裁剪用 AppKit 自己的 `clipsToBounds`；有阴影时 AppKit 关掉裁剪。
- **与本库 renderer 的默认值差异**（AppKitPlus 0122 自己列过，此处逐项核对过）：
  | 成员 | 本库 renderer | AppKitPlus 0.24.0 |
  |---|---|---|
  | `borderPositions` | 空集合（只设颜色和宽度不出边框） | `.all` |
  | `shadowColor` | `nil` | 黑色（`shadowProperties.color`） |
  | `shadowOffset` / `shadowRadius` | `(0, -3)` / `3` | 零 / `0` |
  | 分边边框的内缩 | 上下内缩之差当成左右边的 x 偏移（AppKitPlus 视为笔误） | 四边各按各的 |
- **阴影五项没有同名类成员**：在 AppKitPlus 0.24.0 公开头文件里搜 `shadowColor` / `shadowOpacity` / `shadowOffset` /
  `shadowRadius` / `shadowPath`，只有 `NSLabel.h`（`NSLabel` 的文字阴影，与 `LayerBackedView` 不在一条继承链上）和
  `NSLayerBackedView.h` 的一处注释。所以在 `LayerBackedView` 上声明这五个属性不会撞上「不能覆写模块外的非 open 属性」。
- **没有下游泛型地使用这条管线**：在所有本地仓库里搜 `LayerBackgroundProviding`、`attachToSelfIfNeeded`、
  `updateLayerBackgroundIfNeeded`、`LayerBackgroundRenderer`（排除本库与构建产物），只有 LyricsX 的
  `LyricsPanelViewController.InteractionToggleButton`，它是 `NSView` 子类、自己遵循协议，不经 `LayerBackedView`，不受影响。
  RuntimeViewer 没有用阴影五项，设边框的地方都显式写了 `borderPositions = .all`。本库自身设阴影五项的地方为零，
  设边框的 `CustomToolTipManager` 与示例 App 也都显式写了 `.all`。
- **`LayerBackedTableCellView` 不受影响**：它继承本库的 `TableCellView: NSTableCellView`，不是
  `NSLayerBackedTableCellView`（`Sources/UIFoundationAppKit/Base/TableCellView.swift:8`、`:40`），类上没有这些成员。
- **各下游的 AppKitPlus 版本**（2026-11-26 读各自的锁文件）：RuntimeViewer 0.24.0（已中招）；PrivateSymbols 0.19.0 / 0.21.0、
  LaunchpadAwakener 0.21.0、MacKedUpdater 0.20.0、XCOrganizer 0.18.0 / 0.22.0、MachOKitUI 0.21.0 都还在 0.23.0 以下，
  现在没事，升到本库 0.51.0 时会被下限一起带到 AppKitPlus 0.24.0。
- **锁文件的解析坑**：`AGENTS.md` 记着 `swift package --traits … update` 会失败。实测带上包名
  `swift package --traits AppKitPlus update AppKitPlus-Release` 能成功把 pin 写成 0.24.0（在导出副本上，2026-11-26）。
  落地时照这条命令做，并把这条实测补进 `AGENTS.md`。

## 提议方案

1. **trait 打开时 `LayerBackedView` 的外观归 AppKitPlus**：不遵循 `LayerBackgroundProviding`，构造时不挂 renderer，
   `updateLayer()` 和 `layout()` 不再调 renderer。`cornerRadius`、`cornerCurve`、`backgroundColor`、`border*` 直接是
   `NSLayerBackedView` 的成员。trait 关闭时保持原样：继承 `NSView`、遵循协议、走 renderer。
2. **`AppKitPlus-Release` 下限提到 0.24.0**：trait 下的代码要用 `shadowProperties` 和 AppKitPlus 的外观成员，旧版本没有；
   而且只要范围里还允许 0.24.0 以下，「trait 打开 + 新版 AppKitPlus + 本库旧行为」这种组合就会再出现。
3. **trait 下补阴影五项，保住源码兼容**：在 `LayerBackedView` 上声明 `shadowColor`、`shadowOpacity`、`shadowOffset`、
   `shadowRadius`、`shadowPath`，读写 `shadowProperties` 对应字段。`shadowColor = nil` 写成 `.clear`（不画阴影）。
4. **trait 下 `borderPositions` 仍默认空集合**：`LayerBackedView` 构造时设 `borderPositions = []`。理由：同一个类型的默认值
   不该随 trait 变；只设颜色和宽度就冒出四边边框，比现在多画东西，是看得见的行为变化。
5. **哨兵测试改成与归属无关的断言，并让它真正跑在新版上**：断言「设在 `LayerBackedView` 上的值最终落在它的 layer 上、
   刷新一次也不被改回」，trait 开关两种都要过；本库自己的 `Package.resolved` 把 AppKitPlus 抬到 0.24.0。
6. **随 0.51.0 发布**，之后 RuntimeViewer 把本库下限抬到 0.51.0。

### 非目标

- 不改 trait 关闭时的任何行为，也不改 `LayerBackgroundRenderer` 本身（包括它分边边框内缩的写法）。
- 不让 trait 下的 `LayerBackedView` 拿回 renderer 的阴影默认值（`(0, -3)` / `3`）：没有调用方依赖，硬塞会让
  「没设过阴影」变成「设过阴影」，AppKitPlus 会因此关掉裁剪。只在指南里写明差异。
- 不废弃阴影五项、不改名：trait 关闭时它们仍是正式 API。
- 不处理 `NSLayerBackedControl` / `NSLayerBackedTableCellView`：本库没有类继承它们。
- 不修 AppKitPlus 自己的实现；对照测试若发现它画得和 renderer 不同，记录并报给上游，不在本库打补丁。
- RuntimeViewer 一侧的升级只列在下游影响里，属于 RuntimeViewer 自己的提交，不在本提案的分支上。

## 改动地图

| 文件 / 类型 | 动作 | 改什么 | 为什么 | 步骤 |
|---|---|---|---|---|
| `Package.swift` | 修改 | `AppKitPlus-Release` 的 `from:` 从 `"0.6.0"` 改成 `"0.24.0"`，更新旁边说明下限的注释 | trait 下的代码要用 0.24.0 的成员；不再允许会被静默接管的旧版本 | 1 |
| `Package.resolved` | 修改 | AppKitPlus pin 抬到 0.24.0；`originHash` 设为新 `Package.swift` 的 `shasum -a 256` | 让哨兵测试和全部 trait-on 测试跑在下限版本上 | 1 |
| `Sources/UIFoundationAppKit/Base/LayerBackedView.swift` · `LayerBackedView` | 修改 | 协议遵循挪到只在 trait 关闭时编译的扩展里；`commonInit()` 按 trait 分支（关：`attachToSelfIfNeeded()`；开：`borderPositions = []`）；`updateLayer()` / `layout()` 里的 renderer 调用只在 trait 关闭时编译；重写类型注释 | 方案 1、4 | 2 |
| `Sources/UIFoundationAppKit/Base/LayerBackedView+Shadow.swift` · `extension LayerBackedView` | 新增 | trait 下的五个阴影属性，转写 `shadowProperties` | 方案 3，源码兼容 | 2 |
| `Tests/UIFoundationTests/LayerBackedViewBaseClassTests.swift` | 修改 | `backgroundRoutesThroughRenderer` 改成 `appearanceReachesTheLayer`（与归属无关）；新增 `bordersStayOffUntilEdgesAreNamed`、`shadowMembersForwardToShadowProperties`（trait 下）；更新类型注释里的历史 | 方案 4、5；修复前先变红 | 1、2 |
| `Tests/UIFoundationTests/WelcomePanelTests.swift` | 修改 | 新增 `xcode26WindowContentIsRounded`：`.xcode26` 窗口内容视图的 layer 圆角 20、裁剪打开 | 用户看到的症状本身的回归测试 | 1、2 |
| `Tests/UIFoundationTests/LayerBackgroundCornerCurveTests.swift` | 不改（跑） | 在 trait 开关两种下各跑一次像素测试 | 对照 AppKitPlus 与 renderer 的画法 | 3 |
| `Documentations/LayerBackground.md` | 修改 | 新增一节「AppKitPlus trait 下」：谁负责外观、默认值差异表、阴影五项的转写；更新第 123 行一带的「依赖遮蔽」段 | 指南与行为同批 | 4 |
| `Documentations/AppKitPlus.md` | 修改 | §6.1 下限改为 0.24.0 及理由；新增「0.7.0–0.24.0 新增了什么」的碰撞清点结果；§2.1 与哨兵说明改写 | 同上；bump 前必做的碰撞清点要留档 | 3、4 |
| `Documentations/WelcomePanel.md` | 修改 | 圆角一条补上 trait 下靠 AppKitPlus 的 `cornerRadius` | 同上 | 4 |
| `AGENTS.md` | 修改 | 平台一行与 AppKitPlus 下限；外观一块（「`LayerBackedView` gets … from `LayerBackgroundProviding`」）按 trait 分开写；`swift package update` 一块补上带包名能成功的实测 | 索引与实际一致 | 4 |
| `README.md` | 修改 | 「The trait requires AppKitPlus 0.6.0 or later」改为 0.24.0，补一句 trait 下外观由 AppKitPlus 负责 | 对外文档 | 4 |
| `AgentPlugins/uifoundation/skills/uifoundation-widgets/SKILL.md` | 修改 | 「With the `AppKitPlus` trait」一节补一句外观成员归属与阴影写法 | skill 描述的公开 API 变了 | 4 |
| `AgentPlugins/uifoundation/.claude-plugin/plugin.json`、`.codex-plugin/plugin.json` | 修改 | `version` 1.4.0 → 1.5.0 | 已安装的插件只在版本变时更新 | 4 |
| `Documentations/Evolutions/README.md`、`Documentations/README.md` | 修改 | 登记本提案；落地时改编号 | 索引 | 4 |

## 架构图

改了什么（trait 打开时）：

```text
NSView
 └── NSLayerBackedView            (AppKitPlus 0.24.0: cornerRadius, cornerCurve, backgroundColor,
      │                            border*, shadowProperties — owns the layer appearance)
      └── LayerBackedView
-           : LayerBackgroundProviding          // conformance only without the trait
-           commonInit() → attachToSelfIfNeeded()
+           commonInit() → borderPositions = []  // keep UIFoundation's default
-           updateLayer() → renderer.updateLayer()   // wrote 0 / nil back over AppKitPlus's values
-           layout()      → renderer.layout()
+           shadowColor / shadowOpacity / shadowOffset / shadowRadius / shadowPath
+               → shadowProperties.{color, opacity, offset, radius, path}
```

trait 关闭时（不变）：

```text
NSView
 └── LayerBackedView : LayerBackgroundProviding
       cornerRadius, backgroundColor, border*, shadow*  → LayerBackgroundRenderer → CALayer
```

一次 `view.cornerRadius = 20` 的走向：

```text
before (trait on, AppKitPlus 0.24.0)
  view.cornerRadius = 20 ──► NSLayerBackedView.cornerRadius ──► NSView (AppKit) ──► layer.cornerRadius = 20
  updateLayer() ──► LayerBackgroundRenderer.updateLayer() ──► layer.cornerRadius = 0   ✗ (renderer never saw 20)

after (trait on)
  view.cornerRadius = 20 ──► NSLayerBackedView.cornerRadius ──► NSView (AppKit) ──► layer.cornerRadius = 20
  updateLayer() ──► NSLayerBackedView.updateLayer()                                    ✓ nothing writes it back
```

## 详细设计

`LayerBackedView.swift`（只列变化的部分）：

```swift
@IBDesignable
open class LayerBackedView: LayerBackedViewBase {
    open var isLayerBackingEnabled: Bool { true }

    private func commonInit() {
        #if AppKitPlus && canImport(AppKitPlus)
        // AppKitPlus draws a border along every edge by default; this class has always drawn none
        // until the edges are named, with the trait on or off.
        borderPositions = []
        #else
        attachToSelfIfNeeded()
        #endif
        setup()
    }

    open override func layout() {
        super.layout()
        _firstLayout()
        #if !(AppKitPlus && canImport(AppKitPlus))
        layoutLayerBackgroundIfNeeded()
        #endif
    }

    open override func updateLayer() {
        super.updateLayer()
        #if !(AppKitPlus && canImport(AppKitPlus))
        updateLayerBackgroundIfNeeded()
        #endif
    }

    open override var wantsUpdateLayer: Bool { isLayerBackingEnabled }
}

#if !(AppKitPlus && canImport(AppKitPlus))
extension LayerBackedView: LayerBackgroundProviding {}
#endif
```

`updateLayer()` 的覆写保留：子类按惯例写 `super.updateLayer()`，删掉覆写虽然也能编过，但留着让两种 trait 下的
继承链形状一样，文档也好写。`isLayerBackingEnabled` 继续是类自己的 `open` 成员，两种 trait 下都满足协议要求或独立存在。

`LayerBackedView+Shadow.swift`：

```swift
#if canImport(AppKit) && !targetEnvironment(macCatalyst) && AppKitPlus && canImport(AppKitPlus)

import AppKit
import AppKitPlus

/// The shadow members `LayerBackgroundProviding` gives `LayerBackedView` without the `AppKitPlus` trait,
/// kept with the trait on by writing through to AppKitPlus's `shadowProperties`.
extension LayerBackedView {
    /// The shadow's colour. `nil` draws no shadow. Unset, this reads AppKitPlus's default, black.
    public var shadowColor: NSColor? {
        get { shadowProperties.color }
        set { shadowProperties.color = newValue ?? .clear }
    }

    public var shadowOpacity: Float {
        get { Float(shadowProperties.opacity) }
        set { shadowProperties.opacity = CGFloat(newValue) }
    }

    public var shadowOffset: CGSize {
        get { shadowProperties.offset }
        set { shadowProperties.offset = newValue }
    }

    public var shadowRadius: CGFloat {
        get { shadowProperties.radius }
        set { shadowProperties.radius = newValue }
    }

    public var shadowPath: NSBezierPath? {
        get { shadowProperties.path }
        set { shadowProperties.path = newValue }
    }
}

#endif
```

类型上的两处差异（trait 下，今天已经如此，本提案只是写明）：`borderPositions` 的类型是
`NSLayerBackedView.BorderPositions`、`borderLocation` 是 `NSLayerBackedView.BorderLocation`，写 `.all`、`[.top, .bottom]`、
`.center` 的调用点两种 trait 下都能编；显式写出 `LayerBackgroundRenderer.BorderPositions` 的会在 trait 下编不过（已查无此类调用点）。

测试（`Tests/UIFoundationTests/`）：

- `LayerBackedViewBaseClassTests.appearanceReachesTheLayer`：`backgroundColor = .red`、`cornerRadius = 8` 后走一次刷新，
  断言 layer 的背景是红色、圆角是 8。怎么在无窗口的测试里触发 AppKit 写回 layer（`updateLayer()`、
  `displayIfNeeded()`、放进一个不显示的窗口）在第 1 步实测后定，写进测试注释。
- `LayerBackedViewBaseClassTests.bordersStayOffUntilEdgesAreNamed`：只设 `borderColor` 与 `borderWidth`，
  断言 `borderPositions` 为空、layer 与子 layer 都没有画出边框。
- `LayerBackedViewBaseClassTests.shadowMembersForwardToShadowProperties`（仅 trait 下编译）：五项逐一写入后读
  `shadowProperties`；`shadowColor = nil` 后颜色是 `.clear`。
- `WelcomePanelTests.xcode26WindowContentIsRounded`：经 `(panel as NSWindowController).window` 取窗口（子类把 `window`
  标成了 unavailable，经基类类型调用走的是同一个覆写），断言内容视图 layer 圆角 20、`masksToBounds` 为真。

## 替代方案考量

- **反过来让 renderer 继续独占外观：`LayerBackedView` 覆写 AppKitPlus 的九个成员，转给 renderer。** 否：`borderPositions`、
  `borderLocation` 的类型是 AppKitPlus 的，覆写必须用它们的类型，trait 关闭时又是本库的类型，两套声明得分别维护；
  AppKitPlus 的颜色随外观和强调色重新解析等能力会被绕开；也违背上游 0122 已经和本库约好的分工。
- **保留协议遵循，只在 trait 下让 renderer 不写 layer。** 否：协议扩展里的阴影五项、`attachToSelfIfNeeded()` 仍然可见，
  调用后静默无效，正是这次事故的形状；一个不再由协议负责外观的类型继续声称遵循它，语义不成立。
- **trait 下改用 AppKitPlus 的默认值（`borderPositions = .all`）。** 否：同一个类型的默认值会随 trait 变，
  只设颜色和宽度的调用点会多出四边边框；现有调用点虽然都显式写了 `.all`，下游未知代码不一定。
- **不抬下限，用版本判断兼容 0.6.0–0.23.0。** 否：AppKitPlus 是二进制包，`canImport(_:_version:)` 读的模块版本不可靠；
  而且 0.24.0 以下没有 `shadowProperties`，trait 下的阴影转写写不出来。
- **只在 RuntimeViewer 一侧绕开（退回 AppKitPlus 0.23.0，或只给欢迎窗口补一行 `layer.cornerRadius`）。** 否：问题在本库，
  76 处调用点都会坏；退回 0.23.0 还会让 RuntimeViewer 失去 Debug ▸ Responder Debugger。

## 影响

### 源码兼容性（source compatibility）

trait 关闭：纯不变。

trait 打开：

- **有破坏，范围很小**：`LayerBackedView` 不再遵循 `LayerBackgroundProviding`。把 `LayerBackedView` 当作
  `any LayerBackgroundProviding` / `some LayerBackgroundProviding` 用、或在它身上调 `attachToSelfIfNeeded()`、
  `updateLayerBackgroundIfNeeded()`、`layoutLayerBackgroundIfNeeded()` 的代码编不过。已查所有本地仓库，无此类调用点。
  不提供过渡：保留遵循就是保留静默失效。
  ```swift
  // before (trait on): compiled, did nothing
  func style(_ view: some LayerBackgroundProviding) { view.cornerRadius = 8 }
  style(layerBackedView)
  // after: set the member on the concrete type
  layerBackedView.cornerRadius = 8
  ```
- 阴影五项、`cornerRadius` 等名字和类型照旧可用（阴影五项由新扩展提供，其余由 `NSLayerBackedView` 提供）。
- **行为差异**（写进指南）：阴影偏移与半径的默认值变成零和 0；`shadowColor` 未设时读到黑色而不是 `nil`；
  分边边框的内缩按四边各自算；有阴影时 AppKit 不裁剪子视图。
- **依赖要求**：trait 打开的使用方，AppKitPlus 必须能解析到 0.24.0 及以上。

### ABI 兼容性（条件项）

不适用 —— 本库以 SPM 源码分发，使用方每次重新编译。

### 下游影响

本仓库内：`UIFoundationAppKit` 里所有经 `LayerBackedView` 设外观的组件（WelcomePanel、QuickActionBar、TabBar、
SystemHUD、Navigation、Tooltip 等）在 trait 下改由 AppKitPlus 画。示例 App 开着 `AppKitPlus` trait，要重新构建并看一眼
LayerBackground 演示页。

下游仓库：

- **RuntimeViewer**（AppKitPlus 0.24.0 + 本库 0.50.1，已中招）：本库 0.51.0 发布后，`RuntimeViewerPackages/Package.swift`
  的 UIFoundation 下限改为 `from: "0.51.0"`，三个工作区的锁文件只抬这一个 pin，根 `AGENTS.md` 的 *Dependency floors*
  补一句「0.51.0 是第一个在 AppKitPlus 0.24.0 下保住 `LayerBackedView` 外观的版本」。之后目视欢迎窗口、Load Frameworks
  横幅、起始页 Open Quickly 输入框、编辑区分隔短线。
- **PrivateSymbols、LaunchpadAwakener、MacKedUpdater、XCOrganizer、MachOKitUI**（都开着 trait，AppKitPlus 在 0.18.0–0.22.0）：
  现在没事；升到 0.51.0 会被带到 AppKitPlus 0.24.0，要各自按自己的规矩做 AppKitPlus 的碰撞清点。
- **LyricsX**：trait 关闭，自己的 `InteractionToggleButton` 遵循协议，不受影响。

### 文档与示例

`LayerBackground.md`、`AppKitPlus.md`、`WelcomePanel.md`、`AGENTS.md`、`README.md`、`uifoundation-widgets` skill 与两份
插件清单的版本号，见改动地图。示例 App 不改代码。

## API 演进与废弃策略

- 不废弃任何 API。trait 下的阴影五项是为兼容保留的转写，不标废弃：trait 关闭时它们仍是正式 API，只在一侧废弃会让同一行
  代码随 trait 出不出警告。指南里写明 trait 下也可以直接用 `shadowProperties`。
- 版本号：抬了依赖下限、trait 下去掉一个协议遵循，在 0.x 里按次版本发，**0.51.0**。

## 落地步骤

1. **让问题在本库自己的测试里变红**（已完成） —— `Package.swift`、`Package.resolved`、`LayerBackedViewBaseClassTests`、`WelcomePanelTests`
   - 行为：`appearanceReachesTheLayer` 在 trait 打开、AppKitPlus 0.24.0 下失败，trait 关闭下通过
   - 行为：`xcode26WindowContentIsRounded` 在 trait 打开下失败（圆角读到 0）
   - 行为：确定无窗口测试里触发 AppKit 写回 layer 的办法，写进测试注释
2. **把外观交给 AppKitPlus** —— `LayerBackedView.swift`、`LayerBackedView+Shadow.swift`、两份测试
   - 行为：`appearanceReachesTheLayer` 在两种 trait 下都通过
   - 行为：`xcode26WindowContentIsRounded` 通过
   - 行为：`bordersStayOffUntilEdgesAreNamed` 在两种 trait 下都通过
   - 行为：`shadowMembersForwardToShadowProperties` 通过
3. **全量验证与碰撞清点** —— `LayerBackgroundCornerCurveTests`（只跑）、`AppKitPlus.md` 的清点结果
   - 行为：全 trait 构建（`AGENTS.md` 的完整 trait 列表）无错误
   - 行为：trait 关闭与打开的全量测试都通过（开窗口的测试放到不是用户正在用的那台机器上跑），输出以 `Test run with … tests` 结尾
   - 行为：`LayerBackgroundCornerCurveTests` 在两种 trait 下都通过；不过的项记下 AppKitPlus 与 renderer 的差异，报给上游
   - 行为：AppKitPlus 0.7.0–0.24.0 公开头文件新增的分类成员与本库声明无静默遮蔽（按 `AppKitPlus.md` §6.3 的 grep）
   - 行为：示例 App 从导出副本构建通过
4. **文档、skill 与索引** —— 改动地图里的文档各行
   - 行为：指南写明 trait 下外观归属、默认值差异与阴影转写
   - 行为：插件版本 1.5.0
5. **落地与发版** —— 合进 `main`，提案改编号为 Implemented，打 tag `0.51.0`
   - 行为：RuntimeViewer 抬到 0.51.0 后欢迎窗口恢复圆角（RuntimeViewer 一侧的提交）

**收尾时必须判断两件事**：是否需要单独的使用指南或实现说明（预计不需要，契约写进现有三份指南）；是否引入新术语（预计没有）。

## 决策日志

| 日期 | 变更 | 说明 |
|------|------|------|
| 2026-11-26 | Created as Draft | RuntimeViewer 的欢迎窗口在升 AppKitPlus 0.24.0 后失去圆角；查明是 AppKitPlus 0122 留给本库的配合项没做，renderer 被 `NSLayerBackedView` 的同名成员绕开后仍按默认值覆盖 layer。用户选定在本库修，而不是让 RuntimeViewer 退回 AppKitPlus 0.23.0 |
| 2026-11-26 | 方向：外观归 AppKitPlus | 照上游 0122 的分工；反向（renderer 覆写 AppKitPlus 成员）因类型不一致、绕开外观重解析而否决 |
| 2026-11-26 | trait 下去掉协议遵循 | 保留遵循会让协议扩展的成员静默无效，正是这次事故的形状；已查无下游泛型用法 |
| 2026-11-26 | `borderPositions` 两种 trait 下都默认空集合 | 同一类型的默认值不随 trait 变 |
| 2026-11-26 | Accepted | 用户批准，开始实现。约定实现做完只在本地合进 `main`，不推送、不打 tag，等用户验收 |
