# 0037 - UIFoundationWindowedRows：把上百万行表格的数据层从 FrameworkToolbox 搬进来

- **状态**: Implemented
- **创建日期**: 2026-11-10
- **最后更新**: 2026-11-10
- **实现分支 / PR**: 本库、FrameworkToolbox、MachOKitUI 都是 `feature/windowed-rows-module`
- **配套文档**: [UIFoundationWindowedRows —— 上百万行表格的数据层](../WindowedRows.md)
- **关联提案**: [`0036`](0036-windowed-table-view-data-source.md)（WindowedTable，建在这个数据层上）；
  FrameworkToolbox 的 `0017`（数据层原先的家）；MachOKitUI 的 `0009`（把 windowed 机制抽成可复用组件，
  当时定了数据层进 FrameworkToolbox）

## 摘要

上百万行表格的数据层——按需取行的 `WindowedRowSource`、只留可见行附近几个窗口的 `ViewportCache`、后台搜索
`WindowedRowSearch`、把它们串起来的 `WindowedRowsController`——2026-11-09 作为 `WindowedRowsToolbox` 放进了
FrameworkToolbox。那个包里的模块都是某个 Apple 框架的工具箱（Foundation、os、dyld、Objective-C runtime），
这一块不是，放在那里格格不入；它真正的搭档是本库的 AppKit 表格组件 WindowedTable。

本提案把它原样搬进本库，成为独立的 target 与 product `UIFoundationWindowedRows`。它只依赖 FrameworkToolbox 的
`OSToolbox`（日志与 signpost 宏），不依赖本库任何别的 target，所以与界面无关的模块（MachOKitUICore）依赖它，
不会因此带进 AppKit。FrameworkToolbox 随后删掉这个模块。

## 方案

**本库**

- 新 target 与 product `UIFoundationWindowedRows`，8 个源文件从 FrameworkToolbox 的
  `Sources/WindowedRowsToolbox/` 原样搬来；依赖只有 `OSToolbox`。它不进 `UIFoundation` 伞形 target 的依赖列表，
  但 `UIFoundationAppKit` 依赖它并重新导出，macOS 上 `import UIFoundation` 照旧看得到这些类型。
- 测试单独成一个 target `UIFoundationWindowedRowsTests`，6 个文件原样搬来：跑这些测试不必编 AppKit 那几层。
- 日志与 signpost 的 subsystem 跟着模块改名，从 `WindowedRowsToolbox` 改成 `UIFoundationWindowedRows`；
  category 不变。
- `UIFoundationAppKit` 改依赖本地 target，WindowedTable 的源码与测试改 import。
- 使用指南从 FrameworkToolbox 的 `Documentations/WindowedRowsToolbox.md` 搬成 `Documentations/WindowedRows.md`；
  `WindowedTable.md`、`TextFinder.md`、文档索引、`AGENTS.md` 的项目地图，以及插件 skill `uifoundation-widgets`
  同步（插件版本号随之升）。
- 发 0.46.0。

**FrameworkToolbox**：删掉 target、product、测试与使用指南，`CLAUDE.md` 删去对应的两处；删 product 是破坏性
变更，发下一个 minor（现在是 0.20.0）。

**MachOKitUI**：MachOKitUICore 改依赖本库的 `UIFoundationWindowedRows`，UIFoundation 的要求升到 0.46.0；
8 处 `import` 改名；`CLAUDE.md`、Internal 文档与未发布的发布说明里的模块名、`log stream` 的 subsystem 同步。

**发版顺序**：本库先发（之后它不再引用 FrameworkToolbox 的这个模块），再改 MachOKitUI，最后 FrameworkToolbox
删除并发版。模块换了名字，FrameworkToolbox 0.19.0 的旧模块与新模块同在一张依赖图里也不冲突，三个库不必卡着
同一时刻发。

**源码兼容性**：类型名与 API 都不变，变的只有 import 的模块名和日志的 subsystem。

**下游影响**：查过本机全部仓库，只有 MachOKitUI 用到这个模块；RuntimeViewer、PrivateSymbols 不受影响。

**没问就采用的假设**

- FrameworkToolbox 不留过渡期的副本：它依赖不了本库（本库依赖它），留副本就是两份要同步的代码，而用户只有
  MachOKitUI 一个。
- 已落地的 `0036`、FrameworkToolbox 的 `0017`、MachOKitUI 的 `0009` 正文不改；后两份在决策日志里追加一行，
  指向本提案。

**落地步骤**

1. 本库：加 `UIFoundationWindowedRows` 与它的测试 target，WindowedTable 改用它，文档与插件 skill 同步。（已完成）
2. FrameworkToolbox：删模块、测试与使用指南，构建并跑全量测试。（已完成）
3. MachOKitUI：改依赖与 import，用本地依赖对着第 1、2 步的检出构建，跑全量测试。（已完成）
4. 发版：本库 0.46.0（编号、合并、推送、打 tag）→ FrameworkToolbox 0.20.0 → MachOKitUI 改用两个发布版、重新解析
   `Package.resolved`、再跑全量测试，合进本地 `main`，不推送。（本库这一段随本次落地完成）

## 决策日志

| 日期 | 决定 | 理由 |
|------|------|------|
| 2026-11-10 | Created as Draft | 用户认为数据层放在 FrameworkToolbox 不合适：那里是 Apple 框架的工具箱，而它不是；它也不依赖本库别的 target，搬进来不会给与界面无关的使用方带进 AppKit。模块名暂定 `UIFoundationWindowedRows`，待用户确认 |
| 2026-11-10 | Accepted；模块名定为 `UIFoundationWindowedRows`；做完先发版，再把 MachOKitUI 合进本地 | 用户批准。名字与本库其他模块同一个前缀，也避开 FrameworkToolbox 旧版里的同名模块，三个库不必卡着同一时刻发版 |
| 2026-11-10 | 第 1 步完成：插件版本升到 1.3.0；「不依赖本库别的 target」写进 `Package.swift` 注释与 `AGENTS.md`，不另加守护测试 | `uifoundation-widgets` 新加了一行讲数据层，按以往教新组件升 minor 的惯例。FrameworkToolbox 守依赖边界的办法是在子进程里跑 `swift package dump-package`，算新的测试设施，超出本提案范围 |
| 2026-11-10 | 第 2、3 步完成 | FrameworkToolbox 删掉模块后全量测试通过。MachOKitUI 用本地依赖跑全量测试：默认配置 598 个、trait 全开 601 个，失败的都是它 main 上本来就有的；另有一条时有时无的预热用例，单独跑三次都通过。本库全量测试三次里有一次在 NSSplitView 的测试里崩溃（一个视图被过度释放），与本次改动无关，另两次全过，main 上的对照也全过 |
| 2026-11-10 | Implemented，编号 0037，发布 0.46.0；FrameworkToolbox 随后发 0.20.0 | 用户批准发版。使用指南是 `WindowedRows.md`；代码原样搬来，没有要另写的实现说明；窗口、占位行这些说法在指南里解释过，没有新术语要进术语表 |
