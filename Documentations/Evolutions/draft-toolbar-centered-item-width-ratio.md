# Draft - 工具栏居中项的宽度比例：`NSToolbar.box.preferredCenteredItemWidthRatio`

- **状态**: In Progress
- **创建日期**: 2026-11-03
- **最后更新**: 2026-11-03
- **实现分支 / PR**: `feature/toolbar-principal-item-width-ratio`（从 `main` `7811fe5` 切出）
- **配套文档**: 指南 [`ToolbarCenteredItemWidth.md`](../ToolbarCenteredItemWidth.md)；逆向报告
  [`Researchs/AppKit-NSToolbar-CenteredItemWidthRatio-Internals.md`](../../Researchs/AppKit-NSToolbar-CenteredItemWidthRatio-Internals.md)

## 摘要

RuntimeViewer 要照 Xcode 26 在工具栏正中放一个活动胶囊（RuntimeViewer 提案 `draft-xcode-activity-progress`），
那个胶囊占工具栏宽的 40%、随窗口缩放。公开 API 做不到：工具栏项的宽度只来自它视图的约束，约束够不到工具栏视图。
Xcode 用的是 `NSToolbar` 的私有属性 `preferredPrincipalItemWidthRatio`。本提案在 `AppleInternal` trait 下给它一个
`.box` 封装，与 scroll pocket 等私有 API 的封装同一形态。

## 方案

- `UIFoundationAppleInternalObjC/include/NSToolbar_Private.h` 用 `@interface NSToolbar ()` 声明
  `@property CGFloat preferredPrincipalItemWidthRatio;`。
- `UIFoundationAppleInternal/Toolbar/NSToolbar+CenteredItemWidth.swift`：
  `NSToolbar.box.preferredCenteredItemWidthRatio: CGFloat?`。AppKit 缺这个属性时读回 `nil`、赋值什么都不做，
  先用 `instancesRespond(to:)` 判断，与 scroll pocket 的封装一致。
- 名字用公开 API 的说法 centered item（`centeredItemIdentifiers`），不用 AppKit 内部的 principal item；文档里注明
  对应的私有名字。
- 行为在 macOS 27.2 上实测，写进指南的契约：宽度是 `ceil(比例 × 工具栏宽)`；0 或负数表示没有偏好（新工具栏是
  −1）；算出的宽度小于项的最小宽度时比例作废、项取最大宽度——与 26.6 反汇编读出的「取最小宽度」相反；赋值不重排，
  下一次布局才用上。
- 测试 `ToolbarCenteredItemWidthTests`：读写、比例生效、没有比例时更宽、低于最小宽度作废、事后赋值在下一次布局生效。
- `AgentPlugins/uifoundation` 的两个 skill 都不列 `AppleInternal` 的封装，不用改，也不用升插件版本。

## 源码兼容性

纯新增：一个私有头文件和一个 `.box` 属性，都在 `AppleInternal` trait 下，不改已有 API，不改 `Package.swift`。

## 下游影响

- **RuntimeViewer**：开着 `AppleInternal`，用它让活动胶囊占工具栏宽的 40%；需要抬 UIFoundation 的 pin。
- **MachOKitUI、PrivateSymbols、XCOrganizer、StarLight、LyricsX**：不受影响，没有调用方。

## 决策日志

| 日期 | 决定 | 理由 |
|------|------|------|
| 2026-11-03 | Created，直接 In Progress | 用户批准 RuntimeViewer 的活动进度提案时，一并同意了在本库加这个封装并发版 |
| 2026-11-03 | 低于最小宽度时比例作废，写进契约 | macOS 27.2 实测如此（0.13 × 1200 = 156 < 160 时项取 928 点，0.14 时取 169 点），与 26.6 反汇编的读法不同；以实测为准，26.6 未实测 |
