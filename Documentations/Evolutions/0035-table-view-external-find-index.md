# 0035 - TableViewTextFinderClient 接收宿主建好的查找索引

- **状态**: Implemented
- **创建日期**: 2026-11-08
- **最后更新**: 2026-11-08
- **实现分支 / PR**: `feature/table-view-external-find-index`
- **关联提案**: MachOKitUI 的 `draft-flat-tables-in-table-view`（行不展开的大表改用 `NSTableView`）
- **配套文档**: [TextFinder.md](../TextFinder.md)

## 摘要

`OutlineViewTextFinderClient` 能接收宿主在后台建好的查找索引（`installExternalIndex(_:)`），`TableViewTextFinderClient` 不能。table 版只能自己在主线程上逐格取字符串，或者靠数据源给出每行的 O(1) 长度。MachOKitUI 要把上百万行的详情表从 `NSOutlineView` 换成 `NSTableView`，因为前者每行要占约 90 字节内存，换走也不还。这些行要在后台取，长度也只有渲染出来才知道，所以 ⌘F 需要 outline 版那套外部索引。本提案把这套接口原样给 table 版。

## 方案

- **索引类型改用中性的名字**：`OutlineViewExternalTextIndex` 改名 `TextFinderExternalIndex`，旧名留作 typealias，现有调用不用改。
- **table 版数据源加两个方法**：与 outline 版同名同义，都有默认实现。`textFinderClientBuildsIndexExternally(_:)` 默认返回 `false`；`textFinderClientNeedsExternalIndexRebuild(_:)` 默认什么都不做。
- **table 版 client**：加 `installExternalIndex(_:)`。`rebuildIndex()` 在外部模式下不再自己取字符串，只请宿主重建；装上的索引走现有的 `finishRebuild(installing:)`，查找栏开着时会重新触发搜索。装索引时作废还在跑的主线程分块任务，防止旧结果盖住新索引。
- **源码兼容**：只加接口，不改语义；旧类型名照常可用。
- **下游**：MachOKitUI（`TextFinder`）会在大表上用它；RuntimeViewer、PrivateSymbols 不用外部索引，不受影响。
- **测试**：`TextFinderClientRunLengthPathTests.tableExternalIndexFlow`，照 outline 版的 `externalIndexFlow` 写。覆盖的点：外部模式下不取字符串、只请求一次重建，查找时用装上的索引，作废后重新请求。
- **指南**：`TextFinder.md` 的类型表改用新名字，「外部索引」一节改成两种 client 都适用。

## 决策日志

| 日期 | 决定 | 理由 |
|------|------|------|
| 2026-11-08 | Created；状态直接 In Progress | MachOKitUI 的提案 `draft-flat-tables-in-table-view` 把这一步列为第 1 步，用户已批准那份提案 |
| 2026-11-08 | 索引类型改用中性名 `TextFinderExternalIndex`，旧名留作 typealias | table 版 client 收一个以 `OutlineView` 开头的类型读着别扭；typealias 保住源码兼容，不加废弃标注，免得下游突然冒警告 |
| 2026-11-08 | 实现完成，待用户看过后收尾 | MachOKitUI 的 `feature/flat-tables-in-table-view` 已用上：行不能展开的大表在 `NSTableView` 里，⌘F 经 `TableViewTextFinderClient.installExternalIndex` 装后台建好的索引。发版要用户另行批准 |
| 2026-11-08 | Implemented，编号 0035，随 `0.44.0` 发布 | 用户批准发版，供 MachOKitUI 升依赖。指南 `TextFinder.md` 随实现一起改好；没有新的项目术语要登记——`TextFinderExternalIndex` 是接口类型，不是术语 |
