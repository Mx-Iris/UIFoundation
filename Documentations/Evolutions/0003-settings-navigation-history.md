# 0003 - SettingsNavigator：设置窗口的页面历史导航

- **状态**: Implemented
- **作者**: JH
- **创建日期**: 2026-08-12
- **最后更新**: 2026-08-12
- **所属愿景**: 无
- **关联提案**: [0002](0002-reusable-settings-window.md)（本提案改动它落地的 UI 层）
- **实现分支 / PR**: 待定
- **配套文档**: [`SettingsWindow.md`](../SettingsWindow.md) 第 5 节「Page navigation」

## 摘要

给设置窗口加一对 Xcode 式的前进 / 后退按钮，并把「当前在哪一页」从 `SettingsRootView` 的私有
`@State` 中取出来，做成宿主可以在代码里直接读写的对象 `SettingsNavigator`。历史是唯一事实来源，
侧栏选中项由它派生。仅改动 `UIFoundationSettingsUI` 一个 target，模型层一行不动，纯新增。

## 动机

### 一、宿主现在无法从代码里控制设置窗口停在哪一页

选中页存在 `SettingsRootView` 的私有状态里（`Sources/UIFoundationSettingsUI/SettingsRootView.swift:21`）：

```swift
@State private var selectedPageID: SettingsPage.ID?
```

`private` + `@State`，既读不到也写不进。这挡住了几个真实场景：

1. **从别处跳进某一页。** App 里点「检查更新」要打开设置并停在 Updates 页；点某个报错气泡里的
   「去设置」要落在对应页。今天只能打开设置窗口，然后让用户自己在侧栏里找。
2. **宿主把导航挂到自己的菜单上。** Xcode 的设置导航是能从菜单走的；宿主想做同样的事，没有可
   调用的东西。
3. **恢复上次停留的页。** 关掉再打开设置，Xcode 记得你上次在哪一页。今天每次都回到第一页。

### 二、页一多，来回比对只能靠侧栏

`SettingsWindowController` 没有页数上限，示例里已经有 7 页起、且带 `if` / `for` 动态生成的页。
在两页之间来回切换是设置窗口的高频动作（改一个值 → 去另一页看效果 → 回来再改），Xcode 和系统设置
都给了前进 / 后退，本库没有。

用户诉求原话：「设置页面加一个导航要怎么加」+「要代码层可控制，做成 Xcode 那样」。

## 前期调研

以下每条都是在 macOS 26.5.2 上实测出来的，探针源码在会话 scratchpad
（`SettingsToolbarProbe.swift` / `SettingsNavigationProbe.swift` / `SettingsDrillDownProbe.swift`）。

### ① 工具栏是存在的，`.navigation` 放置的落点也正确

在与 `SettingsWindowController` 同构的窗口里（`.fullSizeContentView`、`NSHostingController` 作
`contentViewController`），SwiftUI 确实建了 `NSToolbar`。加两个 `ToolbarItem(placement: .navigation)`
之后：

```
• com.apple.SwiftUI.navigationSplitView.toggleSidebar   windowFrame={{146, 348}, {38.5, 28.5}}
• E780D58A-…                                            windowFrame={{197, 348}, {36, 36}}
• AF86C2CC-…                                            windowFrame={{238, 348}, {36, 36}}
```

侧栏宽 185 → 两个按钮落在 x=197 / 238，**紧贴详情区左边缘**，正是截图里 Xcode 那对 chevron 的位置。
被隐藏的 toggleSidebar 占的槽位在 x=146，落在侧栏区域内，不会把 chevron 挤开。

### ② 子页面下钻是白送的，本提案不必做

把 `NavigationStack` 直接写在某一页的 content 里（不是包在 detail 列外面），push 之后 SwiftUI 自动
往窗口工具栏塞一个返回箭头：

```
at root: [… navigationSplitView.toggleSidebar, splitViewSeparator-0]
pushed : [… navigationSplitView.toggleSidebar, splitViewSeparator-0, com.apple.SwiftUI.navigationStack.back]
BACK BUTTON APPEARS: true
```

结论：宿主今天就能写下钻，`SettingsPage` 一个字都不用改。所以本提案的「导航」**只指页间历史**，
不含下钻（见非目标）。

### ③ 一条既有结论被证伪：`SettingsWindowSupport.swift` 的注释是错的

`Sources/UIFoundationSettingsUI/SettingsWindowSupport.swift:139` 现在写着：

> On macOS 26 SwiftUI builds no toolbar at all for a plain `NavigationSplitView` in an AppKit-hosted
> window, so this finds nothing and does nothing; it stays for the systems that do install one.

实测**独立窗口下这段代码是在干活的**：

```
[chrome ran] toolbar exists: true, toggle item found: true
TOGGLE ACTUALLY HIDDEN: true
```

「没有工具栏」只在**嵌入宿主窗口**时成立 —— 设置 UI 不是 `contentViewController` 时，SwiftUI 拿不到
窗口工具栏（实测 `window.toolbar == nil`，items 为空）。当前注释会让下次维护的人以为那段是死代码而
删掉，本提案同批次改正。

### ④ 现状代码路径

| 位置 | 现状 |
|---|---|
| `SettingsRootView.swift:21` | `@State private var selectedPageID` —— 唯一的选中状态，外部不可达 |
| `SettingsRootView.swift:35` | `List(pages, selection: $selectedPageID)` |
| `SettingsRootView.swift:53` | `selectedPage` —— 找不到就回落第一页 |
| `SettingsWindowController.swift:67` | 构造 `SettingsRootView`，不透传任何状态 |

### ⑤ 前人怎么做的

- **Xcode 设置窗口**：详情区左上一对 chevron，走的是「访问过的面板」历史，无历史时两个都是灰的
  （截图即此状态）。
- **系统设置（Ventura+）**：同一对 chevron 同时承担面板历史与子页下钻两件事。
- **~~macOS 26 的 Liquid Glass 工具栏会把相邻的工具栏项渲染进同一个玻璃胶囊~~** —— 这条推测**已被
  推翻**。用户先逆向出 Xcode 的设置导航是**一个** `NSToolbarItem` 装**一个** `NSSegmentedControl`、
  `trackingMode = .momentary`；随后提供的视图层级捕获进一步给出了它的来历：那个分段控件是
  **SwiftUI `ControlGroup` + `.controlGroupStyle(.navigation)`** 产出的，不是手搓的。截图里那个带
  分隔线的圆角胶囊就是它自己画的，与工具栏项的自动分组无关。落地按此实现，详见「详细设计 ·
  落地时修正」与决策日志。

## 提议方案

新增 `SettingsNavigator`，一个 `@MainActor` + `@Observable` 的类，同时承担两件事：

1. **唯一的选中页事实来源** —— 宿主读写 `currentPageID` 即可跳页。
2. **访问历史** —— `goBack()` / `goForward()` / `canGoBack` / `canGoForward`。

`SettingsRootView` 与 `SettingsWindowController` 各加一个可选的 `navigator` 参数；不传就自己建一个
并公开出来，所以「代码层可控」是默认能力，不需要宿主额外配置。工具栏在 `.navigation` 位置放一对
chevron，可用 `showsNavigationControls: false` 关掉——**关掉的只是按钮，不是导航能力**。

### 关键设计：历史是唯一事实来源，侧栏 selection 由它派生

不采用「选中项 + `isNavigatingThroughHistory` 标志位」这种常见写法（理由见替代方案 ②）。侧栏的
`selection` 绑定直接读写导航器：

```swift
Binding(
    get: { navigator.currentPageID },
    set: { if let newValue = $0 { navigator.currentPageID = newValue } }
)
```

点侧栏 = 写 `currentPageID` = 自动记一次访问；按后退 = 只动历史索引 = 侧栏高亮自动跟着走。两条路径
写的是同一个变量，结构上就不存在「谁覆盖谁」的问题。

这与本库既有的 `SettingsStore` 是同一套机制：`@Observable` 的属性在 SwiftUI 的 `body` 里被读到就
自动建立依赖，不需要 `DynamicProperty`（见 0002 决策日志）。

### 非目标

- **不做子页面下钻。** 调研 ② 证明它已经白送，再包一层只会和 SwiftUI 自己的返回按钮打架。
- **不做统一历史**（把「页 + 该页栈内位置」当成一条历史，即系统设置那种）。需要把每页的
  `NavigationStack` path 提到根视图，`SettingsPage` API 要大改；等有真实需求再单独提案。
- **不做搜索**。设置窗口的搜索是另一件事，与导航无关。
- **不把历史持久化到磁盘。** Xcode 也不。「记住上次停留的页」由宿主自己存 `currentPageID` 即可，
  一行的事，不值得进框架。
- **不动 `UIFoundationSettings` 模型层。** 导航是 UI 状态，不是设置数据。
- **不做多窗口共享导航。** 一个窗口一个导航器。

## 详细设计

### `SettingsNavigator`

新文件 `Sources/UIFoundationSettingsUI/SettingsNavigator.swift`：

```swift
@available(macOS 14.0, *)
@MainActor
@Observable
public final class SettingsNavigator {

    /// - Parameter initialPageID: 初始页。传 `nil` 表示由 ``SettingsRootView`` 落到第一页。
    public init(initialPageID: SettingsPage.ID? = nil)

    /// 当前显示的页。
    ///
    /// 写入即记一次访问：会丢弃「前进」方向上的条目，正如浏览器后退后再点新链接。
    /// 写入与当前值相同的 ID 不产生新条目。
    public var currentPageID: SettingsPage.ID? { get set }

    /// 访问过的页，从最早到最新。
    public private(set) var visitedPageIDs: [SettingsPage.ID]

    /// ``visitedPageIDs`` 中当前所处的位置；历史为空时为 `-1`。
    public private(set) var currentHistoryIndex: Int

    public var canGoBack: Bool { get }
    public var canGoForward: Bool { get }

    /// - Returns: 后退到的页；已在最早一条时返回 `nil` 且不改变任何状态。
    @discardableResult public func goBack() -> SettingsPage.ID?

    /// - Returns: 前进到的页；已在最新一条时返回 `nil` 且不改变任何状态。
    @discardableResult public func goForward() -> SettingsPage.ID?

    /// 清空历史，只保留当前页。
    public func clearHistory()

    /// 丢弃不在 `availablePageIDs` 里的历史条目。
    ///
    /// 页列表是可变的（`@SettingsPageBuilder` 支持 `if` 与 `for`），一页消失后历史里的旧 ID
    /// 会指向不存在的页。``SettingsRootView`` 在页列表变化时调用此方法。
    public func pruneHistory(keeping availablePageIDs: Set<SettingsPage.ID>)
}
```

### 行为契约（对齐 Xcode / 系统设置）

| 动作 | 结果 |
|---|---|
| 侧栏点一个新页 | 入栈；「前进」方向的条目被截断 |
| 侧栏点当前已选中的页 | 不入栈，历史不变 |
| 后退 / 前进 | 只移动索引，侧栏高亮跟随；**不**产生新条目 |
| 已到最早 / 最新一条 | 对应按钮 `.disabled(true)` |
| 当前页从页列表中消失 | 落到第一页，并 prune 掉失效条目 |
| `currentPageID = nil` | 视为「无选中」，不入栈 |

### `SettingsRootView`

```swift
public init(
    navigator: SettingsNavigator? = nil,
    showsNavigationControls: Bool = true,
    sidebarWidth: CGFloat = 185,
    @SettingsPageBuilder pages: () -> [SettingsPage]
)
```

现有的 `init(sidebarWidth:pages:)` 保留不动（新参数都有默认值，旧调用点原样编译）。

工具栏：

```swift
.toolbar {
    if showsNavigationControls {
        ToolbarItem(placement: .navigation) {
            Button { navigator.goBack() } label: { Image(systemName: "chevron.backward") }
                .disabled(!navigator.canGoBack)
                .help("Back")
                .keyboardShortcut("[", modifiers: .command)
        }
        ToolbarItem(placement: .navigation) {
            Button { navigator.goForward() } label: { Image(systemName: "chevron.forward") }
                .disabled(!navigator.canGoForward)
                .help("Forward")
                .keyboardShortcut("]", modifiers: .command)
        }
    }
}
```

⌘[ / ⌘] 是 macOS 的通用后退 / 前进约定（Safari、访达、系统设置）。Xcode 的设置窗口本身没有绑快捷键，
这里选择**加上**：一个没有快捷键的导航按钮对键盘用户等于不存在。

### 落地时修正：`ControlGroup` + `.controlGroupStyle(.navigation)`

上面那段「两个 `ToolbarItem` 各放一个 `Button`」是**提案期的写法，未按此落地**（原文保留，作为「当时
是怎么想的」的记录）。实际落地的是：

```swift
ToolbarItem(placement: .navigation) {
    ControlGroup {
        Button { navigator.goBack() } label: { Label("Back", systemImage: "chevron.backward") }
            .disabled(!navigator.canGoBack)
            .keyboardShortcut("[", modifiers: .command)
        Button { navigator.goForward() } label: { Label("Forward", systemImage: "chevron.forward") }
            .disabled(!navigator.canGoForward)
            .keyboardShortcut("]", modifiers: .command)
    }
    .controlGroupStyle(.navigation)
}
```

**`.controlGroupStyle(.navigation)` 是 load-bearing 的**，不能"简化"掉。三条实测：

| 写法 | 结果 |
|---|---|
| 两个相邻 `ToolbarItem` | 两个 `NSToolbarItem`，画成两个分开的按钮 |
| `ToolbarItemGroup` | **仍是**两个 `NSToolbarItem`，同上 |
| `ControlGroup`（不带 `.navigation`） | 1 个 item，但 `view == nil` —— 走原生 item 路径，根本没有分段控件 |
| `ControlGroup` + `.controlGroupStyle(.navigation)` | 1 个 item，内含 `SwiftUISegmentedControl` ✓ |

最后一行与 Xcode 的视图层级捕获**逐项吻合**：

```
NSToolbarItemViewer
 < SwiftUI.ToolbarItemHostingView<_ViewList_View>
  < SwiftUI.AppKitPlatformViewHost<PlatformViewRepresentableAdaptor<AppKitSegmentedControlAdaptor>>
   < SwiftUI.SwiftUISegmentedControl
```

| 属性 | Xcode 实测 | 本实现 |
|---|---|---|
| `segmentCount` | 2 | 2 |
| `trackingMode` | 2 = `.momentary` | 同 |
| `segmentStyle` | 8 = `.separated` | 同 |
| `controlSize` | 4 = `.extraLarge`（macOS 26 新增） | 同 |
| fitting size | 73 × 36 | 73 × 36 |
| `selectedSegment` | −1（瞬态，无常驻选中） | 同 |

`.disabled()` 会映射到 `isEnabled(forSegment:)`，`.keyboardShortcut` 直接生效 —— 两者都有测试守着。

### `SettingsWindowController`

```swift
public init(
    title: String = "Settings",
    contentWidth: CGFloat = 715,
    minimumContentHeight: CGFloat = 400,
    navigator: SettingsNavigator? = nil,
    showsNavigationControls: Bool = true,
    @SettingsPageBuilder pages: () -> [SettingsPage]
)

/// 这个窗口的导航器。宿主用它从代码里跳页。
public let navigator: SettingsNavigator
```

宿主的用法就是一行：

```swift
settingsWindowController.navigator.currentPageID = "updates"
settingsWindowController.showWindow(nil)
```

## 替代方案考量

### ① 只把 `selectedPageID` 暴露成 `@Binding`

**是什么**：`SettingsRootView(selection: $pageID, pages:)`，宿主自己养一个 `@State`。

**为什么否**：解决了跳页，没解决历史 —— 前进 / 后退还得宿主自己实现一遍，而这正是最容易写错的部分
（截断语义、去重、边界）。而且把状态推给宿主，等于每个用这个库的 App 都要写一遍同样的样板。

### ② 选中项 + `isNavigatingThroughHistory` 标志位

**是什么**：保留 `selectedPageID`，另加一个布尔量，在 `onChange` 里判断这次变化是不是自己触发的，
是就不记历史。这是这类需求最常见的写法。

**为什么否**：标志位的复位时机依赖 SwiftUI 何时把 selection 写回来，而这不是有保证的时序 —— 复位早了
会漏记一次访问，晚了会把用户的下一次点击误判成程序触发。派生 binding 的方案里根本没有「两个变量需要
同步」这回事，从结构上排除了这类 bug。

### ③ 把历史放进 `SettingsWindowController`（AppKit 层）

**是什么**：导航状态由窗口控制器持有，`SettingsRootView` 保持纯 SwiftUI。

**为什么否**：`SettingsRootView` 是公开 API，文档明确说了可以脱离窗口控制器单独使用（用于把设置 UI
嵌进别处）。历史放在 AppKit 层，就等于「单独用 `SettingsRootView` 时没有导航」。

### ④ 用 `NavigationStack` 承载页间跳转（把每次选页当成 push）

**是什么**：详情区包一个 `NavigationStack`，选页就 push，返回按钮由 SwiftUI 画。

**为什么否**：两个问题。侧栏 selection 与栈是两份状态，来回切页时会互相打架（选 A→B→A 之后栈里有三层，
侧栏却只有一个高亮）；且返回按钮是 SwiftUI 自己的，宿主既控制不了它的启用状态，也没法从代码触发。

### ⑤ 统一历史（页 + 页内栈位置）

**是什么**：系统设置那种，一对 chevron 同时走页间历史和页内下钻。

**为什么否**：要把每一页的 `NavigationStack` path 提到根视图统一管理，`SettingsPage` 得从「一个视图」
变成「一个带路由的视图」，API 面积翻倍。本轮页间历史已经覆盖了动机里的全部场景，不为一个尚无人提出的
需求先付这笔成本。有需求时另开提案。

## 影响

### 源码兼容性（source compatibility）

**纯新增。** 不破坏任何现有调用点：

- `SettingsRootView.init(sidebarWidth:pages:)` —— 参数原样保留，新增的 `navigator` /
  `showsNavigationControls` 都带默认值，位置在前，旧的**带标签**调用照常匹配。
- `SettingsWindowController.init(title:contentWidth:minimumContentHeight:pages:)` —— 同上。
- `SettingsPage` / `SettingsPageBuilder` / `SettingsForm` / `SettingsPageIcon` —— 不动。
- `UIFoundationSettings`（模型层）—— 不动。

新增的公开符号只有一个：`SettingsNavigator`。导航控件本身是 `SettingsRootView` 内部的
`ControlGroup`，不引入任何新类型。

### ABI 兼容性

不适用 —— 本库以 SPM 源码分发，使用方每次重新编译。

### 下游影响

| 目标 | 影响 |
|---|---|
| `UIFoundationSettingsUI` | 唯一改动的 target |
| `UIFoundationSettings` | 无 |
| 示例 App（`SettingsDemoViewController`） | 加一个「从代码跳页」按钮演示可控性 |
| **RuntimeViewer** | 回接尚未开始（见 0002「下游影响 ⓪」）。本提案先落地意味着回接时直接拿到导航，**不增加**额外迁移成本；反之若先回接再加导航，就要动两次。 |
| **MachOKitUI** / **PrivateSymbols** | 无 —— 均未启用 `Settings` trait |

### 文档与示例

- `Documentations/SettingsWindow.md` 增加「页面导航」一节：`SettingsNavigator` 的行为契约、
  从代码跳页的写法、以及「下钻请直接写 `NavigationStack`」这条指路。
- 同批次改正 `SettingsWindowSupport.swift:139` 那段被证伪的注释（调研 ③）。

## API 演进与废弃策略

无旧 API 被替代，无需废弃标注，无需 semver major 跃迁。

`SettingsNavigator` 的 `visitedPageIDs` / `currentHistoryIndex` 设为 `private(set)`，把「怎么改历史」
收在方法里；将来若要开放（比如允许宿主整体替换历史），从 `private(set)` 放开是兼容的，反过来不是。

## 落地步骤

1. **`SettingsNavigator.swift` + 单元测试。** 测历史语义本身：截断、去重、边界返回 `nil`、
   `pruneHistory` 后索引仍然有效。不依赖 UI，可独立验证。
2. **`SettingsRootView` 接入。** 换成派生 binding，页列表变化时 prune。此步之后行为应与现在完全一致
   （只是状态换了个家），可单独构建 + 跑现有测试确认无回归。
3. **工具栏控件 + 快捷键。** 一个 `ToolbarItem` 装一个瞬态 `NSSegmentedControl`（见「详细设计 · 落地时修正」），⌘[ / ⌘] 由零尺寸 SwiftUI 按钮承载。
4. **`SettingsWindowController` 暴露 `navigator`。**
5. **改正 `SettingsWindowSupport.swift` 的错注释**（调研 ③）。
6. **示例 App**：`SettingsDemoViewController` 加「跳到 Updates 页」按钮，并让动态生成的页参与历史，
   顺带验证 `pruneHistory`。
7. **文档**：更新 `SettingsWindow.md`。
   - **要不要配套专题文章**：不需要单独成篇。契约（谁记历史、什么时候截断、页消失怎么办）写进已有的
     `SettingsWindow.md` 即可 —— 它已经是这个组件的使用指南，另起一篇只会让调用方不知道该看哪份。
   - **有没有引入新术语**：无。「历史」「后退 / 前进」都是通用词，不需要进术语表。

## 决策日志

| 日期 | 变更 | 说明 |
|------|------|------|
| 2026-08-12 | In Progress → Implemented | 七步全部落地。`swift test --traits Settings` 退出码 0，85 项测试 / 15 个套件通过（新增 21 项：`SettingsNavigatorTests` 14 + `SettingsNavigationControlsTests` 7）；不带 trait 构建、带 trait 构建、示例 App `xcodebuild` 均退出码 0。 |
| 2026-08-12 | 实现期新增：历史长度上限 | 提案没写上限。落地时补了 `SettingsNavigator.maximumHistoryLength = 100`：指南要求宿主持有一个长驻的窗口控制器，不封顶的话历史会随着 App 生命周期里的每一次点击一直涨。丢最旧的条目对用户不可见（没人往回退一百页），代价只是多一条测试。 |
| 2026-08-12 | 实现期修正：`init` 不能是 `nonisolated` | 提案的详细设计里 `SettingsNavigator.init` 原打算写成 `nonisolated`，好让 `SettingsRootView.init` 保持非隔离。编译不过 —— `@Observable` 把存储属性变成走访问器的计算属性，赋值即是对 main-actor 隔离状态的调用。改为普通（隔离）`init`，并把 `SettingsRootView.init` 标成 `@MainActor`。对调用方无实际影响：构造一个要显示的 View 本来就在主 actor 上。 |
| 2026-08-12 | 调研 ⑤ 的推测被用户的逆向结论推翻，改用瞬态分段控件 | 我原以为那个胶囊是 macOS 26 自动把相邻工具栏项合成的，且承认在无头环境里证实不了。用户逆向 Xcode 给出了答案：**一个** `NSToolbarItem` + **一个** `NSSegmentedControl`，`trackingMode = .momentary`。据此重写为 `SettingsNavigationControl`（`NSViewRepresentable`）。连带三条新实测：一个 ToolbarItem 裹 NSViewRepresentable 只产出 1 个 toolbar item；`NSSegmentedControl` 无分段级 key equivalent API（查 SDK 头文件）；给它重写 `performKeyEquivalent` 也不触发（窗口沿 contentView 派发，工具栏在 titlebar 分支）。⌘[ / ⌘] 因此改由 detail `.background` 里的零尺寸 SwiftUI 按钮承载 —— 实测这条能触发，并加了测试守它。 |
| 2026-08-12 | 手搓的 `NSViewRepresentable` 整个删掉，改用 `ControlGroup` + `.controlGroupStyle(.navigation)` | 用户提供了 Xcode 设置窗口的视图层级捕获（`.viewhierarchy`）。里面那条链是 `ToolbarItemHostingView` < `AppKitPlatformViewHost<PlatformViewRepresentableAdaptor<AppKitSegmentedControlAdaptor>>` < `SwiftUISegmentedControl` —— `AppKitSegmentedControlAdaptor` 是 **SwiftUI 自己的内部适配器**（模块名带私有 discriminator），说明 Xcode 那个控件不是手搓的，是某个标准 SwiftUI 构件产出的。逐个试：`ControlGroup` 不带 style → `view == nil`（走原生 item）；带 `.controlGroupStyle(.navigation)` → 类链、`segmentCount`/`trackingMode`/`segmentStyle`/`controlSize`、乃至 fitting size 73×36 全部与 Xcode 一致。用户随后给的 [Thaw `SettingsView.swift`](https://github.com/thaw-app/Thaw/blob/development/Thaw/Settings/SettingsView.swift) 用的正是同一个写法，交叉印证。于是删掉 `SettingsNavigationControl.swift`（含 `SettingsNavigationShortcuts`）整个文件：`.disabled()` 直接映射到 `isEnabled(forSegment:)`，`.keyboardShortcut` 直接生效，**上一轮那个「零尺寸隐藏按钮承载 ⌘[ / ⌘]」的丑陋 workaround 随之作废**。 |
| 2026-08-12 | `AppSettings.projectedValue` 也换成 key-path binding，并补上该类型的首个测试 | 顺着上一条的同一条规则复查 `AppSettings`：它的 `projectedValue` 用的是 `Binding(get:set:)`，而 `$something` 在每次 body 求值时都会被重新读取 —— 每次都新分配一对闭包，并交出一个 location 全新的 binding，这正是让持有 `@Binding` 的子视图「每轮都像变了」的原因。改成 `@Bindable var store = Root.store` + `$store.value[dynamicMember: keyPath]`。**动手前先发现这个类型此前零测试覆盖**，于是先写了 `AppSettingsTests`（6 项，含最关键的一条：经 binding 的写入必须落成对 `store.value` 的赋值，否则 `didSet` 不触发、自动保存静默失效），对着**原闭包实现**跑通作为基线，再做转换、确认 6 项仍全绿。全套 91 项测试通过。 |
| 2026-08-12 | 按 Apple 官方 SwiftUI 指南复查并优化 | 对照 `swiftui-specialist` skill 的 references 过了一遍本轮写的 SwiftUI 代码，改了四处。**① `SettingsNavigator` 踩了 observation 的 granularity trap**：`currentPageID` / `canGoBack` / `canGoForward` 原本都是计算属性，而 observation 只在**存储属性**这一级记录依赖、计算属性会把依赖传递上去 —— 于是读 `canGoBack` 实际等于依赖整个 `visitedPageIDs` 数组，任何一次历史变动（哪怕答案没变）都会让读它的视图失效。改成缓存的存储属性，由 `refreshDerivedState()` 统一刷新；因为都是 `Equatable`，重算出同一个值时 `@Observable` 生成的 setter 会直接跳过通知。**② 视图切分**：`SettingsRootView` 原来把侧栏、详情、工具栏都写在同一个 body 里，共享一个失效边界 —— 导航一下，整个 split view 连同当前设置页一起重算。拆成 `SettingsSidebar` / `SettingsDetailPane` / `SettingsNavigationControls` 三个独立 `View` 后，根视图 body 不再读任何被观察的属性，各区各自失效。**③ 闭包 binding 换成 key-path binding**：`Binding(get:set:)` 每次 body 都新分配一个闭包且无法比较，改用 `@Bindable var boundNavigator = navigator` + `$boundNavigator.currentPageID`。**④ 本地化**：包内的 `Text("Back")` 会去 `Bundle.main` 查、查不到静默显示 key，必须带 `bundle: #bundle`；而 `#bundle` 要求目标有资源包，所以给 `UIFoundationSettingsUI` 加了 `Resources/Localizable.xcstrings` 与 `.process("Resources")`。另外顺手去掉了 `List(_:selection:)` 里冗余的 `.tag(page.id)`（该初始化器本来就用元素的 `id` 打标），并把 `.onChange(of: pages.map(\.id))` 的数组提到 `init` 里预先算好（原写法每次 body 都分配一个新数组）。示例 App 里 `EditorPreview` 的 `ForEach(..., id: \.offset)` 是文档点名的「拿位置当身份」反模式，改成按行的角色（signature / statement / closing）给稳定 id。85 项测试仍全通过 —— 其中工具栏那几条正好证明了拆分子视图没有破坏 `ControlGroup` 的解析。 |
| 2026-08-12 | 破坏性验证（第三轮，ControlGroup） | 删掉 `.controlGroupStyle(.navigation)` → 分段控件整个消失，3 个测试失败（找不到 `NSSegmentedControl`、拿不到布局帧、分段启用态无从检查）。这正是需要守住的那条：少了这个 modifier 不会报错，只会静默退化成另一个控件。 |
| 2026-08-12 | 破坏性验证（第二轮，手搓分段控件；该实现已被上一行取代） | `trackingMode` 改 `.selectOne` → momentary 断言失败；删掉 `setEnabled(_:forSegment:)` → 分段启用态测试失败（4 条断言全红）；移除隐藏快捷键按钮 → 「⌘[ and ⌘] move through the history」失败。 |
| 2026-08-12 | 破坏性验证 | 每条关键断言都先把实现改坏确认变红再改回：去掉 `record()` 的截断 → 「picking a new page after going back drops what was ahead」失败；去掉 prune 的相邻去重 → 「pruning collapses the repeats it creates」失败；把 `selectedPage` 写死成第一页 → 「selecting a page in code drives the view」失败（窗口标题停在 General）。 |
| 2026-08-12 | Accepted → In Progress | 用户批准（「开工」），按落地步骤实施。 |
| 2026-08-12 | Created as Draft | 起因是「设置页面加一个导航要怎么加」+「要代码层可控制，做成 Xcode 那样」。写之前先实测了三件事：`.navigation` 放置的落点（x=197，紧贴详情区左边缘，与 Xcode 截图一致）、页内 `NavigationStack` 已自带返回按钮（所以下钻列入非目标）、以及 `SettingsWindowSupport.swift:139` 那条「macOS 26 不建工具栏」的注释被证伪（它只在嵌入宿主窗口时成立）。 |
