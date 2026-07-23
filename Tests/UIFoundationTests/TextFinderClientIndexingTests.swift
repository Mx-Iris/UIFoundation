#if canImport(AppKit) && !targetEnvironment(macCatalyst)

import Testing
import AppKit
@testable import UIFoundationAppKit

// MARK: - Recording Data Sources

/// Table data source that serves deterministic per-cell strings and records
/// whether any text-finder string callback arrived off the main thread.
///
/// The regression guarded by these tests: index building used to run on a
/// background queue and call `stringForRow` there, racing with main-thread
/// access to the same consumer state (torn reads/writes of cached display
/// strings over-released their String storage, crashing later in
/// `TextIndexStore.removeAll()`). The fix gathers strings in main-actor
/// chunks, so every callback must observe `Thread.isMainThread == true`.
private final class RecordingTableTextFinderDataSource: NSObject, NSTableViewDataSource, TableViewTextFinderDataSource {
    let rowCount: Int
    let columnCount: Int
    var cellStringPrefix: String

    private(set) var offMainThreadCallbackCount = 0
    private(set) var stringCallbackCount = 0

    init(rowCount: Int, columnCount: Int, cellStringPrefix: String = "cell") {
        self.rowCount = rowCount
        self.columnCount = columnCount
        self.cellStringPrefix = cellStringPrefix
    }

    func numberOfRows(in tableView: NSTableView) -> Int {
        rowCount
    }

    func numberOfSearchableColumns(in client: TableViewTextFinderClient) -> Int {
        columnCount
    }

    func textFinderClient(_ client: TableViewTextFinderClient, stringForRow row: Int, column: Int) -> String? {
        if !Thread.isMainThread {
            offMainThreadCallbackCount += 1
        }
        stringCallbackCount += 1
        return "\(cellStringPrefix)-row\(row)-column\(column)"
    }
}

/// Table data source implementing the search-string-lengths fast path.
/// Cell strings have deliberately varying widths ("r0c0" vs "r999c1") so the
/// run-length store must handle multiple runs, and rows listed in
/// `lengthsUnavailableRows` return `nil` lengths to exercise the
/// fall-back-to-materialized contract.
private final class GridLengthsTableTextFinderDataSource: NSObject, NSTableViewDataSource, TableViewTextFinderDataSource {
    let rowCount: Int
    let columnCount: Int
    var lengthsUnavailableRows: Set<Int> = []

    private(set) var stringCallbackCount = 0
    private(set) var lengthsCallbackCount = 0

    init(rowCount: Int, columnCount: Int) {
        self.rowCount = rowCount
        self.columnCount = columnCount
    }

    func cellString(row: Int, column: Int) -> String {
        "r\(row)c\(column)"
    }

    func numberOfRows(in tableView: NSTableView) -> Int {
        rowCount
    }

    func numberOfSearchableColumns(in client: TableViewTextFinderClient) -> Int {
        columnCount
    }

    func textFinderClient(_ client: TableViewTextFinderClient, stringForRow row: Int, column: Int) -> String? {
        stringCallbackCount += 1
        return cellString(row: row, column: column)
    }

    func textFinderClient(_ client: TableViewTextFinderClient, searchStringLengthsForRow row: Int) -> [Int]? {
        guard !lengthsUnavailableRows.contains(row) else { return nil }
        lengthsCallbackCount += 1
        return (0 ..< columnCount).map { columnIndex in
            cellString(row: row, column: columnIndex).utf16.count
        }
    }
}

/// Outline flavor of the recording data source — flat list of string items.
private final class RecordingOutlineTextFinderDataSource: NSObject, NSOutlineViewDataSource, OutlineViewTextFinderDataSource {
    let rootItems: [String]

    private(set) var offMainThreadCallbackCount = 0
    private(set) var stringCallbackCount = 0

    init(rootItems: [String]) {
        self.rootItems = rootItems
    }

    func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
        item == nil ? rootItems.count : 0
    }

    func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
        rootItems[index]
    }

    func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
        false
    }

    func numberOfSearchableColumns(in client: OutlineViewTextFinderClient) -> Int {
        1
    }

    func textFinderClient(_ client: OutlineViewTextFinderClient, stringForItem item: Any, column: Int) -> String? {
        if !Thread.isMainThread {
            offMainThreadCallbackCount += 1
        }
        stringCallbackCount += 1
        return item as? String
    }

    func textFinderClient(_ client: OutlineViewTextFinderClient, childItemsOfItem item: Any?) -> [Any]? {
        nil
    }
}

// MARK: - Chunked Main-Actor Indexing Tests

@Suite("TextFinderClient chunked main-actor indexing")
@MainActor
struct TextFinderClientIndexingTests {

    /// Row count above `indexingChunkRowCount` (2048) so the build crosses at
    /// least one chunk boundary and exercises the `Task.yield()` path.
    private static let multiChunkRowCount = 5000

    @Test("Table index build calls the data source on the main thread only")
    func tableIndexBuildStaysOnMainThread() async throws {
        let columnCount = 2
        let dataSource = RecordingTableTextFinderDataSource(rowCount: Self.multiChunkRowCount, columnCount: columnCount)
        let tableView = NSTableView()
        tableView.dataSource = dataSource
        let client = TableViewTextFinderClient(tableView: tableView)
        client.dataSource = dataSource

        client.prepareIndexIfNeeded()
        await client.indexingTaskForTesting?.value

        let materializedStore = try #require(client.indexStorage as? TextIndexStore)
        #expect(dataSource.offMainThreadCallbackCount == 0)
        #expect(dataSource.stringCallbackCount == Self.multiChunkRowCount * columnCount)
        #expect(materializedStore.tokens.count == Self.multiChunkRowCount * columnCount)
        #expect(materializedStore.token(at: 0).string == "cell-row0-column0")
    }

    @Test("Re-invalidating during an in-flight table build discards the stale pass")
    func tableStaleRebuildIsDiscarded() async throws {
        let dataSource = RecordingTableTextFinderDataSource(
            rowCount: Self.multiChunkRowCount,
            columnCount: 1,
            cellStringPrefix: "first"
        )
        let tableView = NSTableView()
        tableView.dataSource = dataSource
        let client = TableViewTextFinderClient(tableView: tableView)
        client.dataSource = dataSource

        // The first build is scheduled but cannot have run yet — this test is
        // main-actor-isolated and has not suspended since it was created.
        // Re-invalidating bumps the generation and cancel-replaces the task,
        // so the first pass must exit without ever applying tokens.
        client.prepareIndexIfNeeded()
        dataSource.cellStringPrefix = "second"
        client.invalidateIndex()
        client.prepareIndexIfNeeded()

        await client.indexingTaskForTesting?.value

        let materializedStore = try #require(client.indexStorage as? TextIndexStore)
        #expect(materializedStore.tokens.count == Self.multiChunkRowCount)
        #expect(materializedStore.token(at: 0).string == "second-row0-column0")
    }

    @Test("Outline index build calls the data source on the main thread only")
    func outlineIndexBuildStaysOnMainThread() async {
        let rootItems = (0 ..< Self.multiChunkRowCount).map { itemIndex in "node\(itemIndex)" }
        let dataSource = RecordingOutlineTextFinderDataSource(rootItems: rootItems)
        let outlineView = NSOutlineView()
        outlineView.dataSource = dataSource
        outlineView.reloadData()
        let client = OutlineViewTextFinderClient(outlineView: outlineView)
        client.dataSource = dataSource

        client.prepareIndexIfNeeded()
        await client.indexingTaskForTesting?.value

        #expect(dataSource.offMainThreadCallbackCount == 0)
        #expect(dataSource.stringCallbackCount == rootItems.count)
        #expect(client.indexStore.tokens.count == rootItems.count)
        #expect(client.indexStore.token(at: 0).string == "node0")
        #expect(client.indexStore.token(at: 0).item as? String == "node0")
    }
}

// MARK: - Lazy Invalidation Tests

@Suite("TextFinderClient lazy index invalidation")
@MainActor
struct TextFinderClientLazyInvalidationTests {

    @Test("Table invalidation defers the build until the next find interaction")
    func tableInvalidationDefersBuild() async {
        let dataSource = RecordingTableTextFinderDataSource(rowCount: 100, columnCount: 2)
        let tableView = NSTableView()
        tableView.dataSource = dataSource
        let client = TableViewTextFinderClient(tableView: tableView)
        client.dataSource = dataSource

        // Setting the data source invalidates but must not build: the find
        // bar has never been used, so no data-source callback may fire.
        #expect(client.indexIsDirty)
        #expect(client.indexingTaskForTesting == nil)
        #expect(dataSource.stringCallbackCount == 0)

        client.prepareIndexIfNeeded()
        #expect(!client.indexIsDirty)
        await client.indexingTaskForTesting?.value
        #expect(dataSource.stringCallbackCount == 100 * 2)

        // A fresh prepare on a clean index must not rebuild.
        client.prepareIndexIfNeeded()
        await client.indexingTaskForTesting?.value
        #expect(dataSource.stringCallbackCount == 100 * 2)

        // Invalidating with a hidden find bar defers again.
        client.invalidateIndex()
        #expect(client.indexIsDirty)
        #expect(client.indexingTaskForTesting == nil)
        #expect(dataSource.stringCallbackCount == 100 * 2)
    }

    @Test("Outline expand/collapse notifications only mark the index dirty")
    func outlineExpandCollapseMarksDirtyWithoutBuilding() async {
        let rootItems = ["alpha", "beta", "gamma"]
        let dataSource = RecordingOutlineTextFinderDataSource(rootItems: rootItems)
        let outlineView = NSOutlineView()
        outlineView.dataSource = dataSource
        outlineView.reloadData()
        let client = OutlineViewTextFinderClient(outlineView: outlineView)
        client.dataSource = dataSource

        client.prepareIndexIfNeeded()
        await client.indexingTaskForTesting?.value
        #expect(dataSource.stringCallbackCount == rootItems.count)

        // Expand/collapse used to trigger a full rebuild each; with lazy
        // invalidation (find bar hidden) they only mark the index dirty.
        NotificationCenter.default.post(name: NSOutlineView.itemDidExpandNotification, object: outlineView)
        NotificationCenter.default.post(name: NSOutlineView.itemDidCollapseNotification, object: outlineView)
        #expect(client.indexIsDirty)
        #expect(client.indexingTaskForTesting == nil)
        #expect(dataSource.stringCallbackCount == rootItems.count)
    }
}

// MARK: - Run-Length Fast Path Tests

@Suite("TextFinderClient run-length lengths fast path")
@MainActor
struct TextFinderClientRunLengthPathTests {

    @Test("Lengths-providing data source builds a run-length index without materializing strings")
    func lengthsPathSkipsStringMaterialization() async throws {
        let rowCount = 5000
        let columnCount = 2
        let dataSource = GridLengthsTableTextFinderDataSource(rowCount: rowCount, columnCount: columnCount)
        let tableView = NSTableView()
        tableView.dataSource = dataSource
        let client = TableViewTextFinderClient(tableView: tableView)
        client.dataSource = dataSource

        client.prepareIndexIfNeeded()
        await client.indexingTaskForTesting?.value

        #expect(client.indexStorage is RunLengthTextIndexStore)
        #expect(dataSource.lengthsCallbackCount == rowCount)
        // Index building must not have materialized a single cell string.
        #expect(dataSource.stringCallbackCount == 0)

        // Cross-validate layout and on-demand strings against the reference
        // enumeration order (row-major, column within row).
        var expectedTotalLength = 0
        var sampledCellStarts: [(row: Int, column: Int, start: Int)] = []
        for rowIndex in 0 ..< rowCount {
            for columnIndex in 0 ..< columnCount {
                if rowIndex == 0 || rowIndex == 999 || rowIndex == rowCount - 1 {
                    sampledCellStarts.append((rowIndex, columnIndex, expectedTotalLength))
                }
                expectedTotalLength += dataSource.cellString(row: rowIndex, column: columnIndex).utf16.count
            }
        }
        #expect(client.stringLength() == expectedTotalLength)

        for sample in sampledCellStarts {
            let expectedString = dataSource.cellString(row: sample.row, column: sample.column)
            for probeOffset in [0, expectedString.utf16.count - 1] {
                let token = client.indexStorage.token(at: sample.start + probeOffset)
                #expect(token.row == sample.row)
                #expect(token.column == sample.column)
                #expect(token.globalIndex == sample.start)
                #expect(token.string == expectedString)
            }
        }
        // Each sampled token materialized its cell string on demand.
        #expect(dataSource.stringCallbackCount > 0)
    }

    @Test("A nil lengths row falls the whole build back to the materialized index")
    func lengthsPathFallsBackOnNilRow() async throws {
        let rowCount = 3000
        let columnCount = 2
        let dataSource = GridLengthsTableTextFinderDataSource(rowCount: rowCount, columnCount: columnCount)
        dataSource.lengthsUnavailableRows = [1500]
        let tableView = NSTableView()
        tableView.dataSource = dataSource
        let client = TableViewTextFinderClient(tableView: tableView)
        client.dataSource = dataSource

        client.prepareIndexIfNeeded()
        await client.indexingTaskForTesting?.value

        let materializedStore = try #require(client.indexStorage as? TextIndexStore)
        #expect(materializedStore.tokens.count == rowCount * columnCount)
        #expect(dataSource.stringCallbackCount == rowCount * columnCount)
        #expect(materializedStore.token(at: 0).string == "r0c0")
    }
}

#endif
