# Draft - 跨多个滚动视图的滚动边缘效果：`ScrollPocketView` 与 `NSView.box.titlebarBackdropGroupName`

- **状态**: In Progress
- **创建日期**: 2026-11-13
- **最后更新**: 2026-11-13
- **实现分支 / PR**: `feature/scroll-pocket-titlebar-backdrop-group`（从 `main` `8152d37` 切出）
- **配套文档**: 指南 [`ScrollPockets.md`](../ScrollPockets.md)；逆向报告
  [`Researchs/AppKit-NSScrollView-ScrollPocket-Internals.md`](../../Researchs/AppKit-NSScrollView-ScrollPocket-Internals.md)
  第 5 节

## 摘要

RuntimeViewer 的编辑区分成左右两栏，两栏的滚动视图都伸到工具栏底下，各自的 scroll pocket 让工具栏透出模糊的内容。
实际效果只有左栏的正文那段是模糊的：从左栏的 Minimap 往右，连同整个右栏，工具栏下面都是一块平的窗口底色。
原因在 AppKit：一个窗口里所有伸到标题栏底下的 pocket 共用一个 backdrop 分组，这个分组只截一次图，在第一个 pocket
绘制时截，之后才绘制的东西都不在截图里。

本提案在 `AppleInternal` trait 下加两样东西，对应两种解法：

- **`ScrollPocketView`**：一块不属于任何滚动视图的独立 pocket（AppKit 的 `NSScrollPocket`），放在几个滚动视图之后、
  盖住它们，一次截全。这是 Xcode 27.2 编辑区的做法（`DVTEdgeOcclusionView`），RuntimeViewer 采用它。
- **`NSView.box.titlebarBackdropGroupName`**：给一个视图子树里贴着标题栏的 pocket 另起一个分组名（私有属性
  `_titlebarGroupName`），并排的滚动视图各起一个，就各自截图。RuntimeViewer 用它让压在独立 pocket 下面的那层也完整。

## 方案

- `UIFoundationAppleInternalObjC/include/NSScrollPocket.h`：完整的私有类声明（AppKit 的 `.tbd` 把它列在
  `objc-classes` 里），只声明独立使用要用到的成员：`edge`、`style`、`allowsSeparator`、`backdropGroupName`、
  `captureView`。
- `UIFoundationAppleInternal/ScrollView/ScrollPocketView.swift`：`open class ScrollPocketView: NSView`。
  - `init(edge:)` 建一块 `NSScrollPocket` 铺满自己；默认 `style = ScrollPocketView.hardStyle`（2）、不画分隔线，
    与 Xcode 27 一致。
  - `style`、`allowsSeparator`、`backdropGroupName` 转发给那块 pocket；`style` 拒收 3 及以上（27.2 上会 trap）。
  - `captureView`：pocket 用来重放底色的 capture-only backdrop。滚动视图会把自己 pocket 的这块放到 clip view 后面；
    独立 pocket 由宿主放到它所盖内容的后面、同一位置，Xcode 的编辑区容器就是把两块 capture view 放在最底层。
  - 不接点击（`hitTest` 返回 `nil`）。macOS 26 以前、或 AppKit 缺这个类时是一个空视图，`captureView` 为 `nil`。
- `UIFoundationAppleInternalObjC/include/NSView_Private.h` 在 `@interface NSView ()` 里声明
  `@property (copy, nullable, setter=_setTitlebarGroupName:) NSString *_titlebarGroupName`（macOS 26+）；
  `NSScrollView+ScrollPocket.swift` 加 `extension FrameworkToolbox where Base: NSView` 的
  `titlebarBackdropGroupName: String?`：AppKit 用空串表示「没起名」，封装把空串读成 `nil`、把 `nil` 写成空串。
- 实测（macOS 27.2，`ScrollPocketTests` 的 `TitlebarFixture`：两个滚动视图并排在工具栏底下）：
  - 不起名时，两个 pocket 模糊内容的 `CABackdropLayer`（`ThinFilmContentBlurFill`）分组相同。
  - 在包着各个滚动视图的视图上各起一个名字，分组就是各自的名字；之后换进来的滚动视图新建的 pocket 也继承；
    在已经上屏的层级上起名，现有的 pocket 跟着换组。
  - 一块 `ScrollPocketView` 盖在两个滚动视图前面：它走 Hard 配方（`HardPocketContentBlur` 加不透明度 0.85 的
    `HardPocketBackgroundReplay`，非 key 窗口），用自己的分组，与两个滚动视图自带 pocket 的分组不同。
  - 独立 pocket 的 style 为 0 或 1 时什么都不画（没有元素可供选配方）；在 RuntimeViewer 的进程里给它
    `addElementContainer:` 标题栏容器后会走软模糊配方，这条没有做成 API。
- 为什么分组名设在外层视图上，而不封装 pocket 自己的 `backdropGroupName`（优先级更高）：滚动视图的 pocket 是 AppKit
  按需建的，后来建的不带它；外层视图上的名字对子树里任何时候建出来的 pocket 都有效。`ScrollPocketView` 的 pocket 由
  它自己持有，所以直接转发 `backdropGroupName`。

## 源码兼容性

纯新增，不改 `Package.swift`，现有调用方不受影响。

## 下游影响

- **RuntimeViewer**：开着 `AppleInternal`。编辑区最前面一块 `ScrollPocketView` 盖住工具栏那一条，每个标签栏背后
  各一块；每栏的内容容器各起一个 `titlebarBackdropGroupName`。需要把 UIFoundation 的 pin 抬到 0.47.0。
- **MachOKitUI、PrivateSymbols、XCOrganizer、StarLight、LyricsX**：不受影响，没有调用方。

## 决策日志

| 日期 | 决定 | 理由 |
|------|------|------|
| 2026-11-13 | 建为草案，直接开工 | RuntimeViewer 两栏编辑区的工具栏只有左栏一段有模糊；在 RuntimeViewer 的进程里查到两栏 pocket 共用 `TitlebarGroup-…` 分组，逆向确认分组名的来源与优先级。用户确认把私有 API 封装进本库并发版 |
| 2026-11-13 | 封装 `NSView` 的 `_titlebarGroupName`，不封装滚动视图 pocket 的 `backdropGroupName` | 后者只对已经存在的那个 pocket 有效；换内容时 AppKit 新建的 pocket 不带它，调用方得找准时机反复设。前者设在外层视图上一次，子树里以后建的 pocket 都继承，实测成立 |
| 2026-11-13 | `nil` 与空串对外统一成 `nil` | AppKit 的默认值和设 `nil` 后的读回值都是空串，它也只认非空的名字 |
| 2026-11-13 | 加 `ScrollPocketView`，与分组名同发一个版本 | RuntimeViewer 的用户比较两种解法后选了 Xcode 的做法：一块独立 pocket 盖住所有分栏，一次截全，也盖住画在工具栏上的 Minimap。两样 API 进同一个版本，下游只抬一次 pin |
| 2026-11-13 | 默认 style 2、不画分隔线；`captureView` 交给宿主摆放 | 与 Xcode 27 的 `DVTEdgeOcclusionView` 一致；style 0 / 1 的独立 pocket 没有元素，什么都不画。capture view 必须在所盖内容的后面，只有宿主知道那是哪里 |
| 2026-11-13 | 不接点击 | 盖在工具栏那一条的 pocket 被标题栏挡在后面，盖在栏后的 pocket 不该吞掉栏背景上的点击；Xcode 另放一块吞事件的视图，这里不需要 |
