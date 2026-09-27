# 0026 - 行高估算开关：让带分组的 source list 不再叠行

- **状态**: Implemented
- **创建日期**: 2026-09-27
- **最后更新**: 2026-09-27
- **实现分支 / PR**: `main`（直接落地，随 `0.37.0` 发布）
- **配套文档**: 指南 [`TableViewRowHeightEstimation.md`](../TableViewRowHeightEstimation.md)；逆向报告
  [`Researchs/AppKit-NSTableView-RowHeightEstimation-Internals.md`](../../Researchs/AppKit-NSTableView-RowHeightEstimation-Internals.md)

## 摘要

行高不一致的 `NSTableView` / `NSOutlineView` 会进入 AppKit 的私有「行高估算」模式：没测量过的行按估算高度排布，
之后边测边修正。带分组行的 source list 大纲（例如按种类分组的侧边栏）在列表滚到靠后位置时重载或展开条目，
会把一部分行留在旧的估算位置上，再一滚动就两行叠画在一起。15.5、26.6.2、27.0 实测一致。AppKit 没有公开开关，
而且每次设置 delegate 都会自己把估算重新打开。本提案在 `AppleInternal` trait 下加一个读写这个私有开关的
`tableView.box.estimatesRowHeights`，并在指南里写明「设置 delegate 后要重新关掉」这条签名上看不出来的契约。

## 方案

- `UIFoundationAppleInternalObjC/include/NSTableView_Private.h` 声明私有属性 `_estimatesRowHeights`
  （getter `-_estimatesRowHeights`，setter `-_setEstimatesRowHeights:`）。
- `UIFoundationAppleInternal/TableView/NSTableView+RowHeightEstimation.swift`：
  `FrameworkToolbox where Base: NSTableView` 上的 `estimatesRowHeights: Bool?`。两个 selector 都存在才读写，
  否则读回 `nil`、赋值忽略 —— 与 `NSGlassEffectView.isEffectInteractive` 同一种处理，AppKit 去掉私有方法时
  只是失去这个开关，不会崩溃。按本库「框架类型的扩展走 `.box`」的约定放在 `box` 命名空间下。
- **库只提供开关，不替宿主在 delegate 变化时重新关掉。** 那需要子类化表格或 swizzle `setDelegate:`，前者该由
  宿主的子类来做（指南给了写法），后者对所有表格生效，范围过大。
- 测试 `TableViewRowHeightEstimationTests`（`AppleInternal` trait）：设 delegate 会打开估算；关掉后保持到
  delegate 变化为止；关掉后在一串靠后位置重载都不叠行；估算摆好的行已在屏幕上时关掉再 `reloadData()`，每行都
  回到表格给出的位置（指南契约 2 的依据，去掉那次 reload 它会失败）；以及一条 `withKnownIssue` 预警 —— 开着
  估算时 AppKit 仍会叠行，哪天不叠了就失败，提示重新评估。夹具里必须有可展开条目，否则估算开着也不出错
  （逆向报告 4.2 节）。
- 未经询问自行决定的：API 名 `estimatesRowHeights` 沿用私有方法的名字；不提供应用级默认值
  `NSTableViewCanEstimateRowHeights` 的封装。

## 源码兼容性

纯新增，只在 `AppleInternal` trait 打开时可见。`box` 命名空间下新增一个成员，不与现有成员重名；全 trait 构建通过。
ABI 兼容性不适用 —— 本库以 SPM 源码分发，使用方每次重新编译。

## 下游影响

- **RuntimeViewer**：`StatefulOutlineView` 在每次 delegate 变化后调用 `box.estimatesRowHeights = false`，修复
  runtime object 侧边栏的叠行。这是本提案的直接动机，需要抬到包含本改动的 UIFoundation 版本。
- **MachOKitUI**（`TextFinder`）：不受影响 —— 不调用就没有任何行为变化。
- **PrivateSymbols**：同上，不受影响。

## 决策日志

| 日期 | 决定 | 理由 |
|------|------|------|
| 2026-09-27 | Created as Draft | 来自 RuntimeViewer 侧边栏叠行的排查；用户：「按方案动手，动画先保留」 |
| 2026-09-27 | 用私有开关逐表格关闭，而不是应用级默认值 `NSTableViewCanEstimateRowHeights` | 默认值对进程里所有表格生效，并在首次读取后缓存到进程结束（逆向报告 3.1 节） |
| 2026-09-27 | 不把「关掉分组行吸顶」「重载后测量全部行」「`noteHeightOfRows`」作为方案 | 实测只能挡住部分触发路径；测量全部行在键盘选中末行后重载的路径上反而制造错位（逆向报告 4.4 节） |
| 2026-09-27 | 不提供关闭展开 / 收起动画的封装 | 用户决定保留动画；关掉估算后带动画收起的错位只在有负载的一段时间内出现过，50 余次重跑未复现，记为存疑（逆向报告 4.3 节） |
| 2026-09-27 | 更正契约：切换开关不会 `reloadData`，也不挪动屏幕上已有的行；宿主要在表格显示行之前切换，或切换后自己 `reloadData()` | 初稿按静态分析写成「有数据时切换会 reload」，漏看了判断前的 `-invalidate` 已清掉那两个标志位，reload 永远走不到；运行时计数为零、在已显示估算行时切换 27 行错位（逆向报告 1 节第 3 步、4.5 节）。补了对应测试 |
| 2026-09-27 | Implemented，落地为 0026 | 用户确认按「UIFoundation 先提交、发 `0.37.0`，RuntimeViewer 再抬 pin」的顺序落地。`swift test --traits AppleInternal --filter TableViewRowHeightEstimation` 5 个测试全部通过（预警测试按设计记录一条已知问题），原始退出码 0；打开全部 trait 的 `swift build` 通过。配套文档：指南与逆向报告已登记在头部，不需要另写实现说明。术语：行高估算是 AppKit 自己的机制，指南里已解释，不进术语表 |
