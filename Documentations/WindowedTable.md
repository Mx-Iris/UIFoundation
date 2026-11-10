# WindowedTable —— 上百万行的 `NSTableView`

`UIFoundationAppKit/WindowedTable/` 把 FrameworkToolbox 的 `WindowedRowsController` 接到一张基于视图的
`NSTableView` 上，有三样东西：

- **`WindowedTableViewDataSource<Row>`**：表格的数据源，同时汇报滚动，并负责表格的查找栏。
- **`WindowedFindIndexScanner`**：在后台把所有显示的行写进查找索引，查找栏底边显示一条细进度条。也可以单独给
  `OutlineViewTextFinderClient` 用。
- **`WindowedFindIndexColumns<Row>`**：查找栏要搜的列数，以及每行往这些列里写什么字符串。

按需取行的数据层（行的来源、窗口缓存、过滤搜索、控制器）在 FrameworkToolbox 的 `WindowedRowsToolbox` 里，契约见那边的
`Documentations/WindowedRowsToolbox.md`。`import UIFoundation` 会一并导出它。决策记录见
[`Evolutions/0036-windowed-table-view-data-source.md`](Evolutions/0036-windowed-table-view-data-source.md)。

## 最小用法

```swift
let (scrollView, tableView) = NSTableView.scrollableTableView()
let controller = WindowedRowsController(placeholder: LogRow.loading) { source, keyword in
    .keywordMatching(source: source, keyword: keyword) { row, matcher in matcher.matches(row.message) }
}
let dataSource = WindowedTableViewDataSource(tableView: tableView, controller: controller)
dataSource.searchableColumns = {
    WindowedFindIndexColumns(count: 2) { row, columnStrings in
        columnStrings[0] = row.time
        columnStrings[1] = row.message
    }
}
controller.onEvent = { [weak dataSource] event in dataSource?.handle(event) }
controller.setSource(WindowedRowSource.rowByRow(totalCount: entries.count) { index in LogRow(entry: entries[index]) })

// The delegate makes the cells:
func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
    let logRow = controller.row(atDisplayedRow: row)   // the placeholder until its window arrives
    ...
}
```

⌘F 一律经 `dataSource.textFinderClient.performTextFinderAction(_:)` 发出，原因见 [TextFinder](TextFinder.md)。

## 契约

1. **表格要先放进滚动视图，再创建数据源**：滚动汇报和查找栏都在创建时挂到 `enclosingScrollView` 上。先建数据源、
   后放进滚动视图的话，滚动不会取行，查找栏也没有容器，而且都不报错。
2. **控制器的事件要交给 `handle(_:)`**：它负责重载行、把可见区间转给缓存、松手后同步取看得见的行。不交给它，松手以后
   看到的就一直是占位行。宿主在某个事件上还有自己的事（比如重画分隔线、让选中跟着变），就自己处理事件，只把需要的那几个
   转给 `handle(_:)`。
3. **单元格由代理来做，行要从控制器取**：用 `controller.row(atDisplayedRow:)` 取，行号是显示行号；搜索开着时，显示的第
   n 行不是来源的第 n 行。
4. **`fill` 写进去的字符串要和单元格显示的一模一样**：查找栏是在单元格里高亮匹配位置的，字符串一不同，高亮就落错地方。
   `fill` 在后台线程上跑，只能读它捕获进来的东西；缓冲区会一行行复用，每一列都要写。
5. **显示的字符串变了，要调 `invalidateFindIndex()`**：比如换了地址格式。`handle(.reloadAllRows)` 已经替你调过了。
   查找栏开着时会立即重新扫描；关着时等下次查找再扫。要等索引建好（比如测试里），等 `findIndexScanner.runningScan`
   的 `value`；被取消或被新扫描顶掉的扫描结束时不交付索引，读之前先看 `textFinderClient.stringLength()`。
6. **把 `controller` 设成 `nil` 就是关掉**：表格不再有行，也不再汇报滚动。同一张表要轮流显示别的内容时用它，
   不要靠换数据源。
7. **只给行不能展开的表用**：它把行当成一层的表格。行能展开的表要用 `NSOutlineView`，不过 `NSOutlineView`
   每个顶层行要占约 90 字节、换走也不还，不能交给它上百万行。

## 实现说明

- **扫描不经过缓存**：`WindowedFindIndexScanner` 从 `WindowedDisplayedRows` 直接按 512 行一批取行，相邻的来源行
  合成一次取。经缓存逐行取的话每行都会未命中，还会把可见区域附近的窗口挤掉。
- **进度条按帧摆放**：查找栏视图在第一次显示后才存在，所以进度条在每次进度汇报时（最多每 100 ms 一次）尝试挂上去。
  `NSScrollView` 按 frame 排布查找栏，进度条跟着它变宽靠的是 autoresizing mask，不能加约束。
- **填充色只在 `updateLayer` 里设**：设色时用 `performAsCurrentDrawingAppearance` 解析动态色。`updateLayer` 可能在
  显示周期之外运行，那时没有当前外观，动态色会按错误的外观解析。
- **查找数据源用隔离遵循**：`TableViewTextFinderDataSource` 没有隔离，数据源是 `@MainActor`，所以用
  `@MainActor TableViewTextFinderDataSource` 遵循（Swift 6.2 起），没有跨隔离警告。
