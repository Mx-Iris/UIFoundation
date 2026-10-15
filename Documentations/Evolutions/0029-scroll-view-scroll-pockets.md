# 0029 - Scroll pocket 封装：让浮在列表上的栏也有滚动边缘效果

- **状态**: Implemented
- **创建日期**: 2026-10-14
- **最后更新**: 2026-10-15
- **实现分支 / PR**: `feature/scroll-pocket`（从 `main` `17cdd81` 切出），快进合入 `main`，随 `0.39.0` 发布
- **配套文档**: 指南 [`ScrollPockets.md`](../ScrollPockets.md)；逆向报告
  [`Researchs/AppKit-NSScrollView-ScrollPocket-Internals.md`](../../Researchs/AppKit-NSScrollView-ScrollPocket-Internals.md)

## 摘要

macOS 26 起，内容滚到栏底下时 AppKit 会在那条边上画滚动边缘效果，画它的是滚动视图自己加的 `NSScrollPocket`
视图（AppKit 内部叫 scroll pocket）。AppKit 只替窗口标题栏和 split view item 的 accessory 安排 pocket，公开 API
也只有这两个 accessory 类上的 `preferredScrollEdgeEffectStyle`。Xcode 的导航区是另一种搭法：列表全高，分段控件栏
和过滤栏浮在列表上，再用私有的 `-[NSScrollView registerPocketContainer:onEdge:]` 把两个栏登记成 pocket 的容器。
本提案在 `AppleInternal` trait 下把这组私有接口声明出来，并在 `NSScrollView.box` 上加一层检查过可用性的封装。
直接动机是 RuntimeViewer 要照 Xcode 重做侧栏。

## 方案

- `UIFoundationAppleInternalObjC/include/NSScrollView_Private.h` 声明 `registerPocketContainer:onEdge:`、
  `unregisterPocketContainer:onEdge:`、`scrollPocketStyleOnEdge:`、`setScrollPocketStyle:onEdge:`、
  `_pocketForEdge:makeIfNeeded:`，都标 `API_AVAILABLE(macos(26.0))`。`alwaysShownPocketEdges` /
  `allowedPocketEdges` 原来就声明了。`NSView_Private.h` 声明只读的 `_scrollPocketElementStyle`，让 Swift 子类能覆写。
- `UIFoundationAppleInternal/ScrollView/NSScrollView+ScrollPocket.swift`：
  - `NSScrollView.ScrollPocketEdge`（`.top` = 0、`.bottom` = 1）与 `NSScrollView.ScrollPocketEdges`（OptionSet，每条边一位）。
  - `scrollView.box.registerScrollPocketContainer(_:on:)` / `unregisterScrollPocketContainer(_:on:)`。
  - `scrollView.box.alwaysShownScrollPocketEdges: NSScrollView.ScrollPocketEdges?`。
  - `scrollView.box.scrollPocketStyle(on:) -> Int?` / `setScrollPocketStyle(_:on:)`，值保持裸 `Int`：各个值画出什么样还没弄清。
  - `scrollView.box.scrollPocket(on:) -> NSView?`，只读，不会创建 pocket。
  - `NSView.barScrollPocketElementStyle`（= 2）：栏覆写 `_scrollPocketElementStyle` 时回答的值。名字取自
    DVTUserInterfaceKit 自己的叫法（`NSViewWithScrollPocketElementStyleBar`）。
  - 每个方法先查 `instancesRespond(to:)`，缺方法时什么都不做或读回 `nil`，与 `estimatesRowHeights`、
    `NSGlassEffectView.isEffectInteractive` 的处理一致。
- 测试 `ScrollPocketTests`（`AppleInternal` trait，10 条）钉住指南里写的行为：底部 pocket 只在登记或常显时存在；
  它的高度跟滚动视图自己的 `contentInsets.bottom` 走、与登记的容器取并集，只有 clip view 的 inset 时高度为 0；
  顶部 pocket 跟顶部安全区走、不跟 inset；撤销登记后高度退回；样式默认 0、可读回；外加一条预警测试，盯 AppKit
  自带视图的 `_scrollPocketElementStyle` 取值。
- 未经询问自行决定的：
  - 不封装 27.0 才有的 `_registeredPocketContainersOnEdge:`。最初的草案有一个基于它的
    `registeredScrollPocketContainers(on:)`，但 27.2 上这个方法已经没有了，直接调用会抛 `unrecognized selector`。
  - 只给值 2 起名字。其余取值（−1、0、1、3）只有读数，没有可靠的含义，写在头文件注释和逆向报告里。
  - 不提供 pocket 颜色、外观这类私有接口（`_setPocketColor:forEdge:` 等），目前没有用处。

## 源码兼容性

纯新增，只在 `AppleInternal` trait 打开时可见。`box` 命名空间与 `NSView` 上各新增几个成员，都不与现有成员重名。
`AppleInternal` 与全部 trait 打开时的 `swift build` 都通过。ABI 兼容性不适用：本库以 SPM 源码分发，使用方每次重新编译。

## 下游影响

- **RuntimeViewer**：侧栏改成照 Xcode 的浮层布局（RuntimeViewer 的提案「侧栏照 Xcode 导航区布局：浮在列表上的栏
  与滚动边缘效果」，RuntimeViewer 的 `0052-xcode-navigator-overlay-bars.md`）。它的第一期只用已发布的 0.38.0 就能做：把栏变成滚动
  视图的安全区，再用已声明的 `alwaysShownPocketEdges` 让两条边常显。第二期要用本提案的登记与 `_scrollPocketElementStyle`。
  本库 `main` 自 `45e493d` 起要求 FrameworkToolbox ≥ 0.15.0，而 RuntimeViewerCore 原先钉的是 `exact: "0.12.0"`，
  维护者选择放开 RuntimeViewerCore 的这个钉，所以本改动从 `main` 正常发版（`0.39.0`），没有出 0.38.x 补丁版。
- **MachOKitUI**（`TextFinder`）：不受影响，不调用就没有任何行为变化。
- **PrivateSymbols**：同上，不受影响。

## 决策日志

| 日期 | 决定 | 理由 |
|------|------|------|
| 2026-10-14 | Created as Draft，直接进入 In Progress | 来自 RuntimeViewer 照 Xcode 重做侧栏：两个会话分工，私有 API 的封装按用户的规矩放进 `UIFoundationAppleInternal`。用户说「你们协商好了直接改就行，不用等我回复」，所以没有走审批；文档与代码同批落地 |
| 2026-10-14 | 去掉 `registeredScrollPocketContainers(on:)` 与 `_registeredPocketContainersOnEdge:` 的声明 | 27.0 的导出里有这个方法，27.2 的运行时里没有，探针直接调用时进程因 `unrecognized selector` 终止 |
| 2026-10-14 | 不给 `_scrollPocketElementStyle` 定义完整的枚举，只给 2 起名 `barScrollPocketElementStyle` | 27.2 实测：按钮、文本框、弹出按钮、搜索框都答 3，`NSControl` 本身和滑块答 0。逆向笔记原先写的「控件 0、分段控件 3」只对一部分成立，其余值的含义都靠不住。2 有 Xcode 自己的名字（DVTUserInterfaceKit 的 `NSViewWithScrollPocketElementStyleBar` 等，经 RuntimeViewer 那边的会话读过汇编） |
| 2026-10-14 | 指南写明「底部 pocket 跟滚动视图自己的 `contentInsets.bottom` 走」这条契约 | 27.2 实测：只设 clip view 的 inset 时，常显的底部 pocket 高度为 0，列表却照样让开了栏，看不出哪里错了 |
| 2026-10-15 | 从 `main` 发版，不出 0.38.x 补丁版 | 维护者：「FrameworkToolbox 可以升级，不用写死」——RuntimeViewerCore 放开 FrameworkToolbox 的 `exact` 钉，与本库 `main` 的下限 0.15.0 不再冲突 |
| 2026-10-15 | 状态改为 Implemented，编号 0029，快进合入 `main`，随 `0.39.0` 发布 | 维护者要求提交推送。配套文档（指南 `ScrollPockets.md`、逆向报告 `AppKit-NSScrollView-ScrollPocket-Internals.md`）已登记在文首。术语表不新增：scroll pocket 是 AppKit 自己的名字，指南开头已解释。agent 插件的两个 skill 不涉及 `AppleInternal` 的接口，不改 |
