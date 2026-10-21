# Draft - QuickActionBar 与 SpotlightPanel：Esc 先清空查询再关闭，收起动画对齐 Spotlight

- **状态**: Accepted
- **作者**: JH
- **创建日期**: 2026-10-21
- **最后更新**: 2026-10-21
- **实现分支 / PR**: `feature/escape-clears-query-before-dismissing`

## 摘要

两个仿 Spotlight 的面板现在按 Esc 都是直接关闭，哪怕搜索框里还有字、结果列表正展开着。macOS 27.2 的 Spotlight 不是这样：搜索框有内容时，第一下 Esc 只清空查询文字，结果列表随着查询变空而收起；搜索框已经空了，Esc 才关闭面板。`QuickActionBar` 和 `SpotlightPanel` 都改成这个两步行为。不加 API，不加开关。

第一下 Esc 之后看到的主要就是结果列表收起的那段动画，所以两个组件的展开 / 收起曲线一并换成 Spotlight 自己的：`Spring(duration: 0.3, bounce: 0.2)`。QuickActionBar 现在的弹簧是对这条曲线的近似，常数偏软，整体慢约两成；SpotlightPanel 现在用的是本库自定的 0.2 秒 ease-in-ease-out，之前的逆向没有找到这条曲线。

## 方案

- **Spotlight 的做法**（逆向自 macOS 27.2 build 26B118。27.2 起界面代码已不在 Spotlight.app 主程序里，而在同一工程产出的私有框架 `SpotlightUIInternal.framework`；地址、vtable 槽位与汇编核对写进 `Researchs/Spotlight-Panel-Internals.md` 新增的一节）。Esc 分两层处理：
  - 搜索框的 `control(_:textView:doCommandBy:)` 收到 `cancelOperation:` 时，查询非空就清空它（`stringValue = ""`，再发出文字变化，空查询让结果收起）并吞掉这次 Esc；查询为空就沿响应链交给下一个 responder。
  - `SearchViewController.cancelOperation(_:)` 依次判断：导航栈里压着子页就返回上一页；查询非空或开着顶层浏览筛选，就清掉它们、重置结果，并把焦点放回搜索框；都没有才关闭面板。
  - 两个组件都没有导航栈和浏览筛选，只复刻「查询非空就清空」这一层。
- **AppKit 怎么派发这次 Esc**（逆向自同一构建的 AppKit，地址同样写进研究报告）：
  - 搜索框的 field editor 链上只有 `NSWindow` 实现了 `cancelOperation:`（`NSTextView`、`NSTextField`、`NSControl`、`NSView`、`NSResponder` 都没有），命令表不接的话，Esc 一路传到窗口为止。
  - `NSTableView` 自己实现了 `cancelOperation:`。没有单元格在编辑时，它沿 `nextResponder` 链**逐个**调用每一个实现了 `cancelOperation:` 的 responder，调完一个不停。所以焦点在结果列表时，窗口照样收到 Esc；但谁要是在 view controller 上接了它，之后窗口自己的实现也会被调用。
  - `-[NSWindow cancelOperation:]` 在窗口可见时调私有的 `_cancelKey:`：先找 Esc 快捷键的按钮，找不到就把 `cancel:` 发给 first responder。面板里没有这样的按钮，也没人接 `cancel:`。
- **QuickActionBar**：改窗口已有的 `cancelOperation(_:)` 覆写（它不调 super）。上面两条路径都只到这里一次，一处判断就够。
  - 搜索框有文字：取消尚未触发的防抖搜索（`QuickActionBar.Debounce` 补一个 `cancel()`），清空文字，立刻按空字符串搜索一次，不等 0.2 秒防抖；焦点不在搜索框时放回搜索框。面板留着。
  - 搜索框为空：照旧关闭。
- **SpotlightPanel**：两层，与 Spotlight 对应。
  - 命令表（`ContentViewController` 的 `control(_:textView:doCommandBy:)`）里 `cancelOperation(_:)` 一项：查询非空时改为 `searchTerm = ""`（这个 setter 本就跳过防抖、立刻发出 `searchTermDidChange`），为空时才调 `cancelRequested`。
  - 焦点不在搜索框时（Tab 移到结果列表——`Panel` 开着 `autorecalculatesKeyViewLoop`；或在 macOS 26 及更早点过某一行），Esc 经 `NSTableView` 那条链走到 `Panel`，现在落进 `-[NSWindow cancelOperation:]`，面板不关。改为在 `SpotlightPanel.Panel` 上覆写 `cancelOperation(_:)`、不调 super，交给命令表的同一个判断，清空时把焦点放回搜索框。放在 `Panel` 而不放在 `ContentViewController`，正是因为 `NSTableView` 调完一个不停：放在 view controller 上，之后还会走到 `NSWindow` 的默认实现。
- **收起动画（展开用同一条）**：
  - Spotlight 的取值（`SpotlightUIShared.framework`，同一构建）：结果平台的尺寸动画按横、纵两个轴各有一条「展开」和一条「收起」曲线（`WindowSizingAnimation.AxisAnimation`）。默认值四条都是 `Animation.spring(Spring(duration: 0.3, bounce: 0.2))`，普通查询用的 `ResultPlatterBehavior.standard` 用的就是这份默认值；没设动画的平台退回 `linear(duration: 0)`，即不做动画。面板是一整块圆角裁剪的玻璃，顶边不动，高度变化由底边承担。
  - 换算成弹簧常数（质量 1）：stiffness = (2π / 0.3)² ≈ 438.65，damping = 4π × (1 − 0.2) / 0.3 ≈ 33.51，阻尼比 0.8。
  - QuickActionBar：`SpringState` 的常数由 300 / 28 改为上面两个数，在代码里由 duration 与 bounce 算出来并注明出处。展开与收起本来就共用这一个弹簧，结构不动：窗口照旧按 120 Hz 计时器逐帧改 frame，结果视图照旧在收起落定后才隐藏，收起过程中被圆角裁掉。
  - SpotlightPanel：`WindowFrameAnimator` 的 ease-in-ease-out 换成同一个弹簧。`Configuration.resizeAnimationDuration` 保留，含义改为弹簧的 duration，默认值由 0.2 改为 Spotlight 的 0.3；bounce 固定为 Spotlight 的 0.2，不新增配置项。示例 App 里调这个值的滑块继续有效。
  - 顺带补上之前没找到的两个常数：标准宽度 640（`SUIUtilities.isCampoEnabled` 为真时 520，用户默认值 `spotlightWidth` 大于 0 时以它为准）；标准平台的 preferred 高度 410，最大高度 5000。SpotlightPanel 的 `standardWidth` 本来就选了 680，是否改成 640 不在本提案内，只在研究报告和指南里记下实测值。
  - **没有核实的部分**：收起时结果内容是保持原样被平台裁掉，还是先清空再缩；清空查询后多久开始收起。这两点要么继续逆向 SwiftUI 那一层，要么实际观察 Spotlight 才能定。在定下来之前，两个组件各保留现在的做法（QuickActionBar 内容留到收起结束，SpotlightPanel 结果一变空就隐藏、再按 `sizingDebounceDelay` 防抖后开始收起），不凭猜测改。
- **没有问就采用的假设**：
  - 「有内容」就是字符串非空，空白也算内容。
  - 清空后列表收不收起由宿主对空查询的返回决定，组件不替宿主清结果。StarLight、RuntimeViewer 对空查询返回空，列表收起；XCOrganizer 返回最近项、示例 App 的 SpotlightPanel 演示返回全部命令，列表换成那份内容，第二下 Esc 才关闭。组件若先清空列表再等宿主返回，对空查询有结果的宿主就会看到列表先收起再展开。
  - 没设 `contentSource`、只靠 `provideResultIdentifiers(_:)` 推结果的 QuickActionBar，清空文字后结果不变，由推结果的宿主自己处理。
  - `quickActionBarDidCancel(_:)` / `spotlightPanelDidCancel(_:)` 只在真正关闭时调用，清空查询不算取消。SpotlightPanel 的宿主会照常收到一次 `searchTermDidChange("")`。
  - 不加「Esc 直接关闭」的开关：Spotlight 没有，三个下游也没有这个需求。
- **测试**：Esc 和 Tab 都用真实的 keyDown 事件送进窗口（`NSWindow.sendEvent(_:)`），让 AppKit 自己翻译成命令、沿响应链派发；焦点移到结果列表也用 Tab 键完成，不伸手进私有的表格。结果从公开状态读：`currentSearchText` / `searchTerm`、宿主收到的搜索词、`resumePresentation()`（只有正在关闭时返回 `true`）、窗口的 `firstResponder`、`cancelRequested`。每条先在改动前跑一遍，确认会失败（「搜索框为空时 Esc 关闭」那条守的是旧行为，改动前后都应通过）。
  - QuickActionBar（`QuickActionBarEscapeTests.swift`，经公开的 `present` 打开，窗口从 `@testable` 可见的 `quickActionBarWindow` 取）：有字时 Esc 清空文字、宿主收到空字符串的搜索、面板不进入关闭；为空时 Esc 开始关闭；Tab 到结果列表后 Esc 同样先清空，焦点回到搜索框。
  - SpotlightPanel（`SpotlightPanel/SpotlightPanelEscapeTests.swift`，沿用现有测试单独构造 `ContentViewController` 与 `Panel` 的做法，两者按 `wireUpEvents` 的方式接起来）：有字时 Esc 清空并发出 `searchTermDidChange("")`、不调 `cancelRequested`；为空时调 `cancelRequested`；Tab 到结果列表后 Esc 同样先清空，焦点回到搜索框。
  - 弹簧（两个组件各一条，期望值来自阻尼振动的解析解，不照抄实现）：阻尼比 0.8 的弹簧最大超调为 e^(−0.8π/0.6) ≈ 1.52%，数值积分的结果应落在这附近；SpotlightPanel 的 `WindowFrameAnimator` 改用弹簧后，中途的 frame 应出现这次超调，落定时等于目标 frame。
  - `QuickActionBarPresentationTests` 第 35 行在 `main` 上本来就失败，与本改动无关，照旧对照 `main` 判断。
- **文档**：`README.md` 的 Quick Action Bar 一节写明两步 Esc；`AGENTS.md` 的 QuickActionBar 一节（与上游 DSFQuickActionBar 的差异、弹簧常数的出处）和 SpotlightPanel 一节各加一条；`Documentations/SpotlightPanel.md` 第 7 节键盘表的 Escape 一行、第 5 节的尺寸动画，以及第 8 节已知偏离里「展开 / 收起曲线是本库自定的」那一条（改为已对齐，并写明内容可见性仍是本库的做法）；`resizeAnimationDuration` 的文档注释；示例 App SpotlightPanel 演示里人工检查第 4 条（现在要在空查询上按 Esc 才会关闭）；`Researchs/Spotlight-Panel-Internals.md` 新增 27.2 一节（代码位置变化、Esc 判定链、尺寸动画的取值），并更新第 9 节「没有恢复的内容」里已经找到的两项。`uifoundation-widgets` skill 没写到这两个组件，插件版本不动。
- **下游影响**：用 QuickActionBar 的是 XCOrganizer、StarLight 和 RuntimeViewer（Open Quickly）：搜索框有字时第一下 Esc 由关闭变为清空；展开 / 收起动画变快约两成、回弹略有变化。API 不变，源码兼容。SpotlightPanel 只有示例 App 在用，`resizeAnimationDuration` 的含义与默认值随之改变。MachOKitUI、PrivateSymbols 不用这两个组件。
- **逆向材料**（不进仓库）：`/Volumes/RE/Spotlight/27.2/`（Spotlight.app 副本、主程序的接口导出、`Spotlight.i64`）；`/Volumes/DyldSharedCaches/macOS/27.2/` 下三个框架的接口导出、合并数据库 `SpotlightUIInternal+SpotlightUIShared+SpotlightUIServices.i64`、`AppKit.i64`，以及这次归档的 27.2 dyld shared cache（cache UUID `b39b8e818b0e3d1491b55ed0494535d6`）。
- **落地步骤**（每步自己能构建通过、相关测试通过，各提交一次）：
  1. QuickActionBar 的 Esc：窗口 `cancelOperation(_:)` 先清空查询、`Debounce.cancel()`，`QuickActionBarEscapeTests`。
  2. SpotlightPanel 的 Esc：命令表那一项、`Panel.cancelOperation(_:)` 与它在 `wireUpEvents` 里的接线，`SpotlightPanelEscapeTests`。
  3. 尺寸弹簧：QuickActionBar 的 `SpringState` 常数；SpotlightPanel 的 `WindowFrameAnimator` 改用弹簧、`resizeAnimationDuration` 的含义与默认值；两组弹簧测试，现有 `SpotlightPanelWindowFrameAnimatorTests` 随曲线更新。
  4. 文档：上面「文档」一条列的全部内容。
  5. 验证：全 trait 构建、整套测试、示例 App 构建，结果记进决策日志。

## 决策日志

| 日期 | 决定 | 理由 |
|------|------|------|
| 2026-10-21 | Created as Draft | 用户希望 QuickActionBar 像 Spotlight 一样，第一下 Esc 收起结果列表、第二下才关闭；逆向 macOS 27.2 的 Spotlight 后确认，它收起列表的方式是清空查询 |
| 2026-10-21 | 第一下 Esc 清空查询文字，不做「保留文字、只收起列表」 | 用户选择与 Spotlight 一致的做法。另一种不是 Spotlight 的行为，还要额外维护「列表被用户收起」的状态（再输入时重新展开） |
| 2026-10-21 | SpotlightPanel 同一批次改 | 用户选择。两者是同一处与 Spotlight 的偏离，用同一份逆向依据 |
| 2026-10-21 | QuickActionBar 只改窗口一处；SpotlightPanel 的第二层放在 `Panel` 上 | 27.2 AppKit 逆向：搜索框里的 Esc 一路传到窗口才有人接；`NSTableView` 把 Esc 交给链上每一个实现者、调完不停，放在 view controller 上会再落进 `NSWindow` 的默认实现 |
| 2026-10-21 | 展开 / 收起动画并入本提案，两个组件都换成 `Spring(duration: 0.3, bounce: 0.2)` | 用户要求把收起动画也复刻下来，并认为这是最重要的部分。曲线取自 `SpotlightUIShared` 里标准结果平台的默认尺寸动画；它与第一下 Esc 是同一次改动的两半 |
| 2026-10-21 | SpotlightPanel 保留 `resizeAnimationDuration`，改作弹簧 duration，默认 0.3 | 不新增 API，示例 App 的滑块仍有意义；bounce 固定用 Spotlight 的 0.2 |
| 2026-10-21 | 收起时内容是否保留、何时开始收起，暂不改 | 这两点还没核实，按猜测改会把一处已知偏离换成一处未知偏离 |
| 2026-10-21 | 用户批准，开始实现 | 经 `/accept-proposal`；实现放在 `feature/escape-clears-query-before-dismissing`，worktree 为 `.worktrees/UIFoundation-EscapeClearsQuery`。原来的「一步完成」拆成五步，每步单独构建、测试、提交 |
