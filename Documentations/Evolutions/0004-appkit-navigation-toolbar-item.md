# 0004 - NSToolbar.Navigation：AppKit 的后退 / 前进工具栏项

- **状态**: Draft
- **作者**: JH
- **创建日期**: 2026-08-12
- **最后更新**: 2026-08-12
- **所属愿景**: 无
- **关联提案**: [0003](0003-settings-navigation-history.md)（SwiftUI 侧的同类控件）
- **实现分支 / PR**: 待定
- **配套文档**: 待定 —— 落地时判断是否需要使用指南

## 摘要

AppKit 没有任何内建的「后退 / 前进」工具栏项，只能手搓；RuntimeViewer 已经搓了一个。本提案把它抽成
本库既有 toolbar DSL 里的一个类 `NSToolbar.Navigation`，并把它踩出来的两条 AppKit 行为契约**用 API
形状固化住**，而不是留成注释里的口头约定。不带历史模型、不带 RxSwift，纯新增。

## 动机

### 一、AppKit 这一格是空的

SwiftUI 侧有现成答案：`ControlGroup` + `.controlGroupStyle(.navigation)`，一行拿到 Xcode 设置窗口那个
控件（[0003](0003-settings-navigation-history.md) 刚验证过，逐属性吻合）。**AppKit 侧没有对应物** ——
`NSToolbarItem` 及其子类里没有任何 back/forward 形态，`NSToolbarItemGroup` 也只是分组，不带方向语义。
想在 AppKit 工具栏里放一对 Safari 式导航按钮，只能自己拿 `NSSegmentedControl` 拼。

RuntimeViewer 正是这么做的 —— `RuntimeViewerUsingAppKit/Main/MainToolbarController.swift:9` 的
`NavigationToolbarItem`。

### 二、手搓过程中踩出来的两条契约，才是真正值得封装的东西

那个类本身只有三十来行，照抄不难。难的是它注释里记下的两件事 —— 都是**从 API 签名完全看不出来、
不踩一遍不会知道**的 AppKit 行为：

1. **分段菜单和 `action` 是耦合的。** 给某一段 `setMenu(_:forSegment:)` 之后，只有当控件**同时**还有
   非 `nil` 的 `action`，那个菜单才走「长按弹出」；若有菜单而没有 action，AppKit 会在**普通单击**时
   就把菜单弹出来，单步导航直接没了。RuntimeViewer 因此在 `init` 里装了一个空实现的占位 action。
2. **空菜单照样会弹。** 一段挂着行数为 0 的 `NSMenu`，长按仍然会弹出一个空盒子。所以「历史为空」必须
   表达成把菜单**摘下来**（`setMenu(nil, forSegment:)`），而不是留一个空菜单。

第三条虽然写在代码里但没写进注释：`setShowsMenuIndicator(false, forSegment:)` —— 不关掉的话两段会
带下拉箭头，读起来像弹出按钮，而 Safari 式的前进后退没有这种装饰。

每个下一次要在 AppKit 里做导航项的人，都得把这三条重踩一遍。这就是封装的理由。

### 三、现有调用方式还留了一个顺序陷阱

RuntimeViewer 把「填菜单内容」和「决定菜单挂不挂」拆成了两步，于是调用点必须注意顺序 ——
`MainWindowController.swift:172` 那行注释原文：

> Row content first, reachability second: `attachHistoryMenus` must see menus that already match the
> snapshot it is judging.

顺序反了不会报错，只会得到一个「有历史却没菜单」或「没历史却弹空盒子」的界面。封装时应该把这两步
并成一次调用，让这个陷阱在 API 层面消失。

### 四、本库已经有落点

`Sources/UIFoundationAppKit/Toolbar/` 下是一套成熟的 toolbar DSL：`ToolbarItem` 基类 + 链式 modifier +
`ToolbarActionTrampoline` 闭包动作，已有 `NSToolbar.Button` / `.Item` / `.Group` / `.Menu` /
`.PopUpButton` / `.Search` / `.SegmentedControl` / `.View` / `.TrackingSeparator` 九个子类。加一个
`.Navigation` 是顺着现有结构长出来的，不是新开一套。

## 前期调研

### ① RuntimeViewer 的实现做了什么

| 做的事 | 位置 |
|---|---|
| `NSToolbarItem` 子类，`isNavigational = true`，`view = segmentedControl` | `MainToolbarController.swift:9` |
| 2 段、`.automatic` 样式、`.momentary` 跟踪、chevron.backward / forward | 同上 |
| 两个长期存活的 `NSMenu`，由外部填行、`attachHistoryMenus` 决定挂不挂 | 同上 `:57` |
| 占位 action 保持 `action` 非 nil | 同上 `:69` |
| 关掉两段的菜单指示箭头 | 同上 |
| 启用态、可见性、菜单内容全部由 RxSwift 从 view model 绑过来 | `MainWindowController.swift:168-195` |
| 历史行（标题 + 图标 + 索引）与「最近的在最前」的 Safari 序 | `NavigationHistorySnapshot.swift` |

### ② 两条 AppKit 行为契约的证据强度

**来自用户的实测经验，本提案未独立复验。** 这两条都依赖真实的鼠标按下 - 保持 - 松开跟踪，
`performClick(_:)` 走不到那条路径，无头环境里合成不出来。

这不影响方案 —— 设计上让两条都**结构性成立**（永远保持 action 非 nil；空历史时自动摘菜单），
即使某条其实比实际更保守，代价也只是多做了一次无害的事。落地时在示例 App 里手工长按确认一次，
结论写回本提案。

### ③ 相关 API 的版本下限

| API | 可用版本 | 本库下限 macOS 10.15 |
|---|---|---|
| `setMenu(_:forSegment:)` / `menuForSegment(_:)` | 无标注（10.0 起） | 可用 |
| `setShowsMenuIndicator(_:forSegment:)` | macOS 10.13 | 可用 |
| `NSToolbarItem.isNavigational` | **macOS 11** | 需 `@available` 门 |
| SF Symbol `chevron.backward` / `chevron.forward` | macOS 11 | 需回退到 `NSImage.goBackTemplateName` / `goForwardTemplateName` |

顺带发现一个既有小瑕疵：本库 `NSToolbar.Item.isNavigational`
（`ToolbarItem+Item.swift:65`）标的是 `@available(macOS 12.0, *)`，而 SDK 头文件写的是
`macos(11.0)` —— 比实际严了一个大版本，等于在 macOS 11 上白白挡掉一个能用的属性。**本提案不顺手改
它**（不属于本次范围，且改动会影响既有调用方的 `@available` 推导），只登记在此，值得单开一个 bug 修复。

### ④ SF Symbol 的方向感知

`chevron.backward` / `chevron.forward` 是**方向感知**的（RTL 布局下自动镜像），`chevron.left` /
`chevron.right` 不是。RuntimeViewer 用的是前者，正确；本提案沿用。

## 提议方案

在既有 toolbar DSL 里加一个类，**数据走 data source 拉取，事件走 delegate 通知**：

```swift
let navigationItem = NSToolbar.Navigation()
navigationItem.dataSource = self
navigationItem.delegate = self
```

它负责三件事，宿主一件都不用管：

1. **把控件搭对** —— 2 段、momentary、方向感知的 chevron、无菜单指示箭头、`isNavigational`。
2. **把两条契约锁死** —— action 永远非 nil（`target` / `action` 由内部 trampoline 持有，公开 API 里
   没有置空它们的入口）；历史为空时自动摘菜单。
3. **把顺序陷阱消掉** —— 宿主不再需要在正确的时机推送更新，见下。

### 为什么是 data source 拉取，而不是宿主推送

这是本提案最关键的一处形状选择。推送式（宿主调 `setHistoryItems(_:for:)`）**没有消灭本提案要消灭的
那类 bug，只是把它换了个位置** —— 顺序陷阱没了，但「历史变了却忘了推」这类失同步依然存在，而且同样
不报错、只表现为界面不对。

拉取式把这件事整个删掉：`NSToolbarItem` 本来就有 `validate()`，**AppKit 在验证周期里自动调它**
（本库的 `ToolbarItem` 已经把这个钩子暴露成 `open func validate()`，`ToolbarItem.swift:206`）。导航项
在这里向 data source 问「这个方向还能走吗」「这个方向有几条历史」，据此更新分段启用态、以及菜单挂
不挂。宿主没有任何需要按时调用的东西，也就无从忘记。

### 两级拉取：条数是热的，内容是冷的

data source 分成两个层次，不是为了对称，是有实际成本差别：

- **条数**（`numberOfHistoryEntries(in:)`）必须**提前**知道 —— 「挂不挂菜单」的决定必须在长按发生
  *之前*做完（挂了 `nil` 就等于没有菜单，来不及在按下时补）。所以它跟着验证周期走，要求实现得廉价。
- **每一行的内容**（`historyEntry(at:in:)`）只在菜单**真的要弹出来**时才拉（组件作为两个 `NSMenu`
  的 `NSMenuDelegate`，在 `menuNeedsUpdate(_:)` 里填）。RuntimeViewer 每行要解析一个图标
  （`NavigationHistorySnapshot` 的 `iconSize` 那段），这种开销一年也不该在验证周期里跑一次。

### 行是数据，不是 `NSMenuItem`

data source 返回的是值类型 `HistoryEntry`（标题 + 图标），**不是 `NSMenuItem`**。这样点击路由归组件
所有：它自己建菜单项、自己接管 target / action，delegate 收到的是一个**索引**。宿主不必知道
`representedObject` 这类细节，组件也不必去改宿主递进来的对象的 target（那种「你给我 view，我偷偷改
你的 action」的接口最容易出事）。

### 非目标

- **不带历史模型。** 历史行的内容（标题、图标、点击后跳到哪）是宿主的领域数据；本组件只接收
  「后退方向有哪些行、前进方向有哪些行」。理由见替代方案 ③。
- **不带 RxSwift**，也不提供任何响应式绑定。本库零响应式依赖，宿主自己接。
- **不做键盘快捷键。** `NSToolbarItem` 没有 key equivalent；⌘[ / ⌘] 属于主菜单的事，宿主自己绑。
- **不动 `SettingsNavigator`**（0003 落地的 SwiftUI 侧导航）。两者一个是 AppKit 控件、一个是 SwiftUI
  状态模型，没有共享面。
- **不做「长按菜单」以外的历史 UI**（比如下拉列表、悬浮预览）。

## 详细设计

新文件 `Sources/UIFoundationAppKit/Toolbar/ToolbarItem+Navigation.swift`：

```swift
extension NSToolbar {
    /// A Safari-style back / forward pair, as one toolbar item.
    open class Navigation: ToolbarItem {

        /// Which half of the control a message is about.
        public enum Direction: Hashable, Sendable {
            case backward
            case forward
        }

        /// One row of a long-press history menu. Data, not a view — the item
        /// builds the `NSMenuItem` and owns what a click on it does.
        public struct HistoryEntry {
            public var title: String
            public var image: NSImage?
            public var isEnabled: Bool

            public init(title: String, image: NSImage? = nil, isEnabled: Bool = true)
        }

        /// Supplies availability and history. Pulled, never pushed — see
        /// ``validate()``.
        public weak var dataSource: (any DataSource)?

        /// Receives clicks.
        public weak var delegate: (any Delegate)?

        /// The hosted control. Exposed for styling only; the segment wiring,
        /// target and action belong to this class.
        public let segmentedControl: NSSegmentedControl

        /// What the segments are called, for tooltips and VoiceOver.
        /// Defaults to `"Back"` / `"Forward"`; localize per app.
        public var backwardTitle: String
        public var forwardTitle: String

        /// Re-asks the data source whether each direction is available and how
        /// deep its history is, then updates the segments and attaches or
        /// detaches each history menu.
        ///
        /// AppKit calls this on the toolbar's validation cycle, so a host that
        /// only changes its own history has nothing to call.
        open override func validate()

        public init(_ identifier: NSToolbarItem.Identifier? = nil)
    }
}
```

协议嵌套在类型里，遵循本库既有的命名空间约定（同 `TabBar.DataSource` / `TabBar.Delegate`）：

```swift
extension NSToolbar.Navigation {

    public protocol DataSource: AnyObject {

        /// Whether that half of the control is live.
        ///
        /// Pulled on every validation cycle — keep it cheap.
        func navigationToolbarItem(
            _ item: NSToolbar.Navigation,
            canNavigateIn direction: NSToolbar.Navigation.Direction
        ) -> Bool

        /// How many history rows that direction has — **not** the rows.
        ///
        /// Also pulled on every validation cycle, because it decides whether the
        /// segment gets a menu at all, and that has to be settled before the
        /// press rather than during it. Defaults to `0`: no history menu.
        func navigationToolbarItem(
            _ item: NSToolbar.Navigation,
            numberOfHistoryEntriesIn direction: NSToolbar.Navigation.Direction
        ) -> Int

        /// One row, asked for only while the menu is opening — the right place
        /// for per-row icon resolution.
        ///
        /// Index 0 is the **nearest** entry in that direction: the one a single
        /// click of that segment would land on (Safari's ordering).
        func navigationToolbarItem(
            _ item: NSToolbar.Navigation,
            historyEntryAt index: Int,
            in direction: NSToolbar.Navigation.Direction
        ) -> NSToolbar.Navigation.HistoryEntry
    }

    public protocol Delegate: AnyObject {

        /// A segment was clicked: move one step in that direction.
        func navigationToolbarItem(
            _ item: NSToolbar.Navigation,
            didNavigateIn direction: NSToolbar.Navigation.Direction
        )

        /// A history row was chosen. `index` uses the same nearest-first
        /// numbering the data source was asked with.
        func navigationToolbarItem(
            _ item: NSToolbar.Navigation,
            didSelectHistoryEntryAt index: Int,
            in direction: NSToolbar.Navigation.Direction
        )
    }
}
```

`numberOfHistoryEntriesIn` 与 `didSelectHistoryEntryAt` 由协议扩展给默认实现（分别返回 `0` 和空操作），
所以「只要前进后退、不要历史菜单」的宿主只实现两个方法：`canNavigateIn` 和 `didNavigateIn`。

### 两条契约怎么被结构性锁住

**契约一（action 必须非 nil）。** `segmentedControl.target` / `.action` 在 `init` 里指向内部
trampoline，**公开 API 里没有改动它们的入口** —— 宿主能做的只是不设 delegate，那样 trampoline 收到点击
后无人可通知，但 AppKit 看到的 action 依旧非 nil，长按行为不受影响。对比 RuntimeViewer 的版本：那里
`segmentedControl` 是公开的 `let`，外部随时能把 `action` 置空而不自知，只能靠注释提醒自己。

**契约二（空菜单要摘掉）。** 只在 `validate()` 一处判定：

```swift
open override func validate() {
    super.validate()
    for direction in [Direction.backward, .forward] {
        let isAvailable = dataSource?.navigationToolbarItem(self, canNavigateIn: direction) ?? false
        segmentedControl.setEnabled(isAvailable, forSegment: segmentIndex(for: direction))

        let entryCount = dataSource?.navigationToolbarItem(self, numberOfHistoryEntriesIn: direction) ?? 0
        // Empty means detached, not an empty menu: a segment wired to a menu
        // with no rows still pops an empty box on a long press.
        segmentedControl.setMenu(entryCount > 0 ? historyMenu(for: direction) : nil,
                                 forSegment: segmentIndex(for: direction))
    }
}
```

菜单内容则由组件作为 `NSMenuDelegate` 在 `menuNeedsUpdate(_:)` 里现填，所以「行内容」和「挂不挂」
不可能不一致 —— 两者读的是同一次数据源问答的两个层次，而不是两次分别推送的状态。

### 版本回退

```swift
private static func chevronImage(for direction: Direction) -> NSImage? {
    if #available(macOS 11.0, *) {
        let symbolName = direction == .backward ? "chevron.backward" : "chevron.forward"
        return NSImage(systemSymbolName: symbolName, accessibilityDescription: …)
    }
    // 10.15：方向感知的 chevron 还不存在，退回工具栏模板图
    return NSImage(named: direction == .backward ? NSImage.goBackTemplateName : NSImage.goForwardTemplateName)
}
```

`isNavigational` 同样用 `if #available(macOS 11.0, *)` 包住（按 SDK 的真实下限，不是本库
`NSToolbar.Item` 上那个偏严的 12.0）。

### 无障碍

两段各自设 `accessibilityDescription`（随图片传入）与 `setToolTip(_:forSegment:)`，字符串由
`backwardTitle` / `forwardTitle` 属性给出，默认 `"Back"` / `"Forward"`，宿主可本地化。RuntimeViewer
的版本没有这一层。

## 替代方案考量

### ① 把 RuntimeViewer 的类原样搬过来

**是什么**：连同 `attachHistoryMenus(hasBackwardItems:hasForwardItems:)` 一起照抄，公开 `segmentedControl`。

**为什么否**：那样连它的两个弱点一起搬 —— 「填内容 / 挂菜单」的顺序陷阱，以及外部可以把 `action`
置空从而静默破坏长按行为。搬进公共库意味着把这两个陷阱复制给所有使用方，而它们恰恰是这次最该被
API 吃掉的部分。

### ② 复用既有的 `NSToolbar.SegmentedControl`，加参数支持

**是什么**：给 `NSToolbar.SegmentedControl` 加 `historyMenus` 之类的选项，不新增类型。

**为什么否**：导航项的语义是**固定的两段 + 方向**，而 `SegmentedControl` 是通用容器（任意段数、
三种选择模式、标签或图片）。塞进去等于让每个调用方重新配置一遍段数、跟踪模式、图片、指示箭头 ——
封装的意义就没了。而且 `Direction` 这种只对导航成立的概念会污染通用类型。

### ③ 把 `SettingsNavigator` 泛化成 `NavigationHistory<Element>` 给两边共用

**是什么**：抽一个平台无关的历史值类型（访问列表 + 游标 + 前进后退 + 剪枝），0003 的
`SettingsNavigator` 内部改用它，本组件也用它。

**为什么否**：**只有一个真实消费者。** RuntimeViewer 的历史不是一个独立模型，而是
`DocumentState.selectionStack` —— 文档状态的一部分，和它的其它状态一起演进，不会改用外来类型。
于是抽出来的泛型只服务 `SettingsNavigator` 一家，等于为一个使用方付一层抽象。等出现第二个真实
消费者再说。

### ④ 闭包 + 推送式历史（`onNavigate` / `setHistoryItems(_:for:)`）

**是什么**：本提案的初稿。动作走闭包（与 DSL 其余部分的 `onAction` 一致），历史由宿主在变化时推给
组件，`setHistoryItems(_:for:)` 一次做完「填内容 + 决定挂不挂」。

**为什么否**：它只消灭了顺序陷阱，**没有消灭失同步这一类 bug** —— 「历史变了但忘了推」照样发生，
照样不报错、照样只表现为界面不对（该有的菜单没有，或空历史弹出空盒子）。而这个组件存在的理由就是
消灭这一类问题。拉取式借 `NSToolbarItem` 本来就有的 `validate()` 把它整个删掉：宿主没有需要按时调用
的东西，也就无从忘记。

代价是宿主必须有一个对象来实现协议，而不是写两个闭包。考虑到用得上导航项的场景一定有个窗口控制器
或协调器，这个代价接近于零。**这一条否决了与 DSL 其余部分的风格一致性** —— 那些 item 是无状态的
按钮，导航项不是；一致性不值得用一整类 bug 去换。

### ⑤ 让组件自带历史模型（存 `[NSMenuItem]` 或存领域对象）

**是什么**：组件内部维护历史栈，宿主只调 `push` / `goBack`。

**为什么否**：历史行要显示什么（标题、图标、层级）、点击后跳到哪，全是宿主的领域知识。组件一旦
持有历史，就得替宿主定义「一条历史是什么」，而这件事每个 App 的答案都不一样。保持「组件画控件、
宿主给行」的分工，边界最干净。

## 影响

### 源码兼容性（source compatibility）

**纯新增。** 不改动任何既有类型：`ToolbarItem` 基类、`NSToolbar.SegmentedControl`、
`NSToolbar+Builder` 全部不动。新增的公开符号是 `NSToolbar.Navigation` 及其嵌套的 `Direction`。

### ABI 兼容性

不适用 —— 本库以 SPM 源码分发，使用方每次重新编译。

### 下游影响

| 目标 | 影响 |
|---|---|
| `UIFoundationAppKit` | 唯一改动的 target，新增一个文件 |
| **RuntimeViewer** | 本提案的来源。落地后可以删掉自己的 `NavigationToolbarItem`，改用本类型 —— 但**那是它自己的一次改动，不在本提案范围内**。它现在用 RxSwift 绑 `enabledForSegment(at:)` 和菜单内容，迁移时要改成 `canGoBackward` / `setHistoryItems(_:for:)`，或继续用 `segmentedControl` / `historyMenu(for:)` 走原路。 |
| MachOKitUI / PrivateSymbols / StarLight | 无 —— 不使用 toolbar DSL 的导航项（这是新增能力，没有既有调用方） |

### 文档与示例

- 示例 App 加一个演示项（或并入既有 demo）：一个带工具栏的窗口，导航项驱动一个假的浏览历史，
  长按能看到历史菜单 —— 顺便就是契约 ② 的手工验证场。
- 是否需要单独的使用指南在落地步骤里判断。预判：**需要**，因为「长按菜单为空必须摘掉」「action 不能
  为 nil」这两条正是「从 API 签名看不出来、违反了就出错」的契约，符合本项目写指南的判据。但也可能
  短到适合并进 DocC 注释 —— 落地时按实际长度定。

## API 演进与废弃策略

无旧 API 被替代。`Direction` 声明为 `public enum`，将来若要支持「向上一级」之类的第三方向，加 case
是源码破坏性的 —— 但调用方几乎都在 `switch` 里用它，故意不做成 frozen 也没有额外成本（本库不开
library evolution）。

## 落地步骤

1. **`ToolbarItem+Navigation.swift`** —— 类本体、两条契约的结构性实现、版本回退、无障碍。
2. **单元测试** —— 可测的部分：段数 / 跟踪模式 / 指示箭头状态；data source 报 `false` 时
   `isEnabled(forSegment:)` 随之为 `false`；data source 报 0 条历史时 `menuForSegment(_:)` 是 `nil`
   **而不是空菜单**（契约二的回归测试）；没有 delegate 时 `segmentedControl.action` 仍非 nil
   （契约一的回归测试）；`menuNeedsUpdate(_:)` 后菜单行数与 `numberOfHistoryEntriesIn` 一致，且
   行内容按 nearest-first 取自 `historyEntryAt:in:`；点击历史行时 delegate 收到的索引正确。
   **长按这个交互本身测不了**，见调研 ②。
3. **示例 App 演示项** —— 同时作为契约 ② 的手工验证场；验证结论写回本提案决策日志。
4. **文档** —— 判断是否单独成篇（预判需要）；判断有无新术语（预判无）。

## 决策日志

| 日期 | 变更 | 说明 |
|------|------|------|
| 2026-08-12 | 数据源 / 回调改为 delegate，且改推送为拉取 | 用户提出「数据源和回调用 Delegate 获取和通知」。评估后采纳，并且比单纯换接口形状更进一步：初稿的推送式（`setHistoryItems(_:for:)`）只消灭了顺序陷阱，没消灭「历史变了忘了推」这一类失同步 —— 而这正是本组件存在的理由。改成 data source 拉取后，借 `NSToolbarItem` 自带的 `validate()`（本库 `ToolbarItem.swift:206` 已暴露为 `open`），宿主没有任何需要按时调用的东西。附带两处自己的设计决定：**条数与行内容分两级拉取**（条数跟验证周期，因为「挂不挂菜单」必须在长按前定下；行内容只在 `menuNeedsUpdate` 时拉，避免 RuntimeViewer 那种逐行图标解析跑在验证周期里），以及 **data source 返回值类型 `HistoryEntry` 而非 `NSMenuItem`**（点击路由归组件，delegate 收到索引，避免「你给我 view、我偷改你的 action」那种接口）。 |
| 2026-08-12 | Created as Draft | 起因：用户提供 RuntimeViewer 手搓的 `NavigationToolbarItem`，问能否封装复用。调研确认 AppKit 确实没有内建导航项（SwiftUI 侧有，见 0003），本库已有 toolbar DSL 可直接挂载。方案的重点不是搬那三十行代码，而是把它注释里记下的两条 AppKit 行为契约变成 API 形状 —— 并顺手消掉现有调用方式里「先填内容后判可达性」的顺序陷阱。两条契约来自用户实测，**本提案未独立复验**（长按需要真实鼠标跟踪，无头环境合成不出来），落地时在示例 App 里手工确认。 |
