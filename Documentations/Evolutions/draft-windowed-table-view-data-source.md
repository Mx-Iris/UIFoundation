# Draft - WindowedTable：上百万行的 `NSTableView`

- **状态**: In Progress
- **创建日期**: 2026-11-09
- **最后更新**: 2026-11-09
- **配套文档**: [WindowedTable](../WindowedTable.md)
- **关联提案**: MachOKitUI 的 `extract-windowed-rows`（把 windowed 机制抽成可复用组件），本提案是它的第 2 步；
  第 1 步是 FrameworkToolbox 的 `windowed-rows-toolbox`

## 摘要

FrameworkToolbox 新增的 `WindowedRowsToolbox` 提供了上百万行表格的数据层：按需取行、窗口缓存、过滤搜索，以及串起
它们的控制器 `WindowedRowsController`。这些都不碰界面。

本提案在 `UIFoundationAppKit` 里加上 AppKit 那一半，从 MachOKitUI 的详情表里搬来、按行的类型泛型：

- 把控制器接到 `NSTableView` 上：当数据源、汇报滚动、拖动滚动条时不取行；
- ⌘F 的外部索引扫描：在后台遍历全部显示的行，查找栏底边带一条细进度条。

MachOKitUI 随后改用它们。

## 方案

**新增三个公开类型**，放在 `UIFoundationAppKit/WindowedTable/`：

| 类型 | 作用 | 在 MachOKitUI 里原来是 |
|------|------|------------------------|
| `WindowedTableViewDataSource<Row>` | 用表格构造，成为它的数据源；监听表格所在的滚动视图，把可见行和拖动的开始、结束交给控制器；`handle(_:)` 执行控制器的事件；持有表格的 `TableViewTextFinderClient`，需要索引时用扫描器建 | `FlatDetailTableBridge` 的数据源部分，以及详情表控制器里的滚动监听和事件处理 |
| `WindowedFindIndexScanner` | 后台按 512 行一批取全部显示的行，把每行的字符串写进 `TextFinderExternalIndex`；一次只跑一个，新的开始或取消时丢掉旧的；进度条贴在查找栏底边 | 详情表控制器里的 `startWindowedFindIndexScan` 和 `FindBarScanProgressView` |
| `WindowedFindIndexColumns<Row>` | 查找栏要搜的列数，以及每行往这些列里写什么字符串（复用同一个缓冲区） | 扫描循环里按列拼字符串的那段 |

**调用点**：见 [WindowedTable](../WindowedTable.md) 的「最小用法」。

**没问就采用的决定**：

- **只当数据源，不接管代理**：形状参照 `NSTableViewDiffableDataSource(tableView:cellProvider:)`，用表格构造、接管数据源；但不收 `cellProvider`，单元格仍由使用方的代理来做。原因是 MachOKitUI 详情表的单元格、行视图和选中联动都写在代理里。
- **事件由使用方转给 `handle(_:)`，组件不自己订阅控制器**：控制器只有一个 `onEvent`。MachOKitUI 由视图模型订阅它，再把事件翻成自己的，所以组件不能把这个位置占掉。
- **关掉组件，是把 `controller` 设成 `nil`**：同一张表要轮流显示别的内容时（MachOKitUI 两张表轮流显示）就这样关，不必换数据源。
- **扫描器单独公开**：MachOKitUI 行能展开的那张表用 `NSOutlineView`，也要同样的扫描，所以扫描器能脱离数据源，交给 `OutlineViewTextFinderClient` 用。
- **`import UIFoundation` 一并导出 `WindowedRowsToolbox`**：使用方不必再单独 import 它。
- **开发时用本地的 FrameworkToolbox**：`Package.swift` 里 FrameworkToolbox 这一项加了本地路径，由环境变量 `USING_LOCAL_DEPENDENCIES=1` 打开。FrameworkToolbox 发新版后，要求的版本随之上调。

**下游影响**：

- MachOKitUI：改用这三个类型，见它的提案；
- RuntimeViewer、PrivateSymbols：零影响，纯新增。

## 决策日志

| 日期 | 决定 | 理由 |
|------|------|------|
| 2026-11-09 | Created as In Progress | MachOKitUI 的提案 `extract-windowed-rows` 已获用户批准，本提案是它的第 2 步，随实现一起写 |
| 2026-11-09 | 查找数据源用 `@MainActor TableViewTextFinderDataSource` 隔离遵循 | 数据源是 `@MainActor`，而该协议没有隔离；普通遵循会报跨隔离警告，Swift 6 下是错误 |
| 2026-11-09 | `WindowedFindIndexColumns` 要求至少一列 | `TextFinderExternalIndex` 在零列时触发 precondition；没有可搜的列时，组件改装一个一列的空索引 |
| 2026-11-09 | `WindowedFindIndexScanner.runningScan` 公开；扫描器释放后扫描在下一批停下 | MachOKitUI 改用它时发现：它的测试要等 ⌘F 扫描结束才能读索引，宿主也可能要等；扫描原先在宿主的 `deinit` 里取消，扫描器跟着宿主释放后理应自己停 |
