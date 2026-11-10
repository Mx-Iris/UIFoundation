# UIFoundationWindowedRows —— 上百万行表格的数据层

> 面向使用方。为什么放在本库，见提案
> [UIFoundationWindowedRows：把上百万行表格的数据层从 FrameworkToolbox 搬进来](Evolutions/draft-windowed-rows-module.md)；
> 最初的设计见 FrameworkToolbox 的提案 0017（那时模块叫 `WindowedRowsToolbox`）。AppKit 的表格组件见
> [WindowedTable](WindowedTable.md)。

## 什么时候用

适合两种表格：

- 行数上百万；
- 每行建起来很贵，比如要 demangle、要解析二进制。

这时不能事先把所有行建好。`UIFoundationWindowedRows` 让表格只持有看得见的几个窗口：常驻的行数最多是「窗口大小 × 常驻窗口数」，与总行数无关，默认是 256 × 4。

几千行以内、建行又便宜的表，直接用数组即可，用不着它。

## 怎么依赖

- **与界面无关的模块**：依赖 product `UIFoundationWindowedRows`，写 `import UIFoundationWindowedRows`。这个 target 只依赖 FrameworkToolbox 的 `OSToolbox`（日志与 signpost 宏），不依赖本库别的 target，所以不会把 AppKit 或 UIKit 编进来。
- **macOS 上已经 `import UIFoundation` 的**：`UIFoundationAppKit` 会一并导出它，不必另外依赖。

## 最小用法

```swift
let source = WindowedRowSource.rowByRow(totalCount: entries.count) { index in
    LogRow(entry: entries[index])
}
let controller = WindowedRowsController(placeholder: LogRow.loading) { source, keyword in
    .keywordMatching(source: source, keyword: keyword) { row, matcher in
        matcher.matches(row.message)
    }
}
controller.onEvent = { event in handle(event) }
controller.setSource(source)
```

表格那边要做这几件事：

- **行数**：数据源的行数取 `controller.numberOfDisplayedRows`。
- **单元格**：用 `controller.row(atDisplayedRow:)` 取行。窗口还没取回时它返回构造时给的占位行，取回后会有 `reloadRows` 事件，那时再取一次。
- **滚动**：滚动时报告可见的行号区间 `reportVisibleRange(_:)`；拖动滚动条开始和结束时，分别调 `userDidBeginDragging()` 和 `userDidEndDragging()`。
- **搜索**：搜索框的内容交给 `setSearchKeyword(_:)`。

## 契约（签名上看不出来的）

1. **`fetch` 必须是纯函数**：它会在后台线程上被并发调用，调用方有三个——缓存取窗口、搜索扫描、⌘F 建索引。闭包只能读捕获进来的不可变数据，必须恰好返回 `range.count` 行。
2. **别在主线程上读 `totalCount`**：行数是第一次读时才算的，可能要扫描整个文件，控制器会在后台把它算好。为了不在建表时就把元素数组建出来，可以把数组放进 `WindowedLazyBox`，让行数和取行两个闭包共用这一个盒子。
3. **事件要按顺序执行，有两个要转交给缓存**：
   - `forwardVisibleRange` 交给缓存的 `reportVisibleRange(_:)`；
   - `settle` 和 `prewarm` 交给缓存的 `prewarmSynchronous(centerRow:radius:)`。

   不执行它们，松手后看到的就一直是占位行。本库的 [WindowedTable](WindowedTable.md) 会替你执行。
4. **行数只在 `reloadAllRows` 时变**：`numberOfDisplayedRows` 与表格上一次全量重载时的行数保持一致；搜索进度到达时，只有伴随着 `reloadAllRows` 的那一次才会改它。
5. **搜索结果只增不减**：`filteredRowIndices` 按升序排列、只往后追加，所以已显示的行位置不会变。显示的第 n 行对应来源的第 `filteredRowIndices[n]` 行；要拿来源行号，用 `sourceRowIndex(forDisplayedRow:)`，不要直接把显示行号当成来源行号。
6. **扫描全部行时绕开缓存**：导出、建 ⌘F 索引这类需要遍历所有行的任务，用 `makeDisplayedRows()` 拿到 `WindowedDisplayedRows`，在后台直接从来源分批取。经过缓存逐行取的话，每行都会未命中，把可见区域附近的窗口挤掉。
7. **昂贵的来源不要标成预热候选**：`isPrewarmCandidate` 为 `true` 的来源，松手后会在主线程上同步取行，只给建行便宜的来源标。

## 表格那边的约定

- **用固定行高**：自动行高会让 `reloadData` 在主线程上逐行量一遍，十万行以上就卡住。
- **行不能展开的大表用 `NSTableView`**：`NSOutlineView` 每个顶层行要占约 90 字节，换走以后也不还，400 万行就是 370 MB。
- **AppKit 的拖动**：拖动滚动条用的是 `NSScrollView` 的 live scroll 通知，`willStartLiveScroll` 对应 `userDidBeginDragging()`，`didEndLiveScroll` 对应 `userDidEndDragging()`。

## 日志

日志与 signpost 的 subsystem 是 `UIFoundationWindowedRows`，category 是类型名：`ViewportCache`、`WindowedRowsController`、`WindowedRowSearch`。2026-11-10 之前它在 FrameworkToolbox 里，subsystem 是 `WindowedRowsToolbox`，按旧名写的 `log stream` 条件要跟着改。

## 测试

- **控制时间**：给控制器注入一个自己实现的 `WindowedRowsScheduler`，测试推进它的时钟时才执行到期的工作。这样防抖、合并上报、加载指示都能逐毫秒验证，不用真的等。
- **同步搜索**：用 `.synchronous` 派发的 `WindowedRowSearch`，配合 `waitForCompletion()`，在没有主运行循环的测试里也能等搜索跑完。
