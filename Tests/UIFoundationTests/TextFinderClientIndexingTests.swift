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
    func tableIndexBuildStaysOnMainThread() async {
        let columnCount = 2
        let dataSource = RecordingTableTextFinderDataSource(rowCount: Self.multiChunkRowCount, columnCount: columnCount)
        let tableView = NSTableView()
        tableView.dataSource = dataSource
        let client = TableViewTextFinderClient(tableView: tableView)
        client.dataSource = dataSource

        await client.indexingTaskForTesting?.value

        #expect(dataSource.offMainThreadCallbackCount == 0)
        #expect(dataSource.stringCallbackCount == Self.multiChunkRowCount * columnCount)
        #expect(client.indexStore.tokens.count == Self.multiChunkRowCount * columnCount)
        #expect(client.indexStore.token(at: 0).string == "cell-row0-column0")
    }

    @Test("Re-invalidating during an in-flight table build discards the stale pass")
    func tableStaleRebuildIsDiscarded() async {
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
        dataSource.cellStringPrefix = "second"
        client.invalidateIndex()

        await client.indexingTaskForTesting?.value

        #expect(client.indexStore.tokens.count == Self.multiChunkRowCount)
        #expect(client.indexStore.token(at: 0).string == "second-row0-column0")
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

        await client.indexingTaskForTesting?.value

        #expect(dataSource.offMainThreadCallbackCount == 0)
        #expect(dataSource.stringCallbackCount == rootItems.count)
        #expect(client.indexStore.tokens.count == rootItems.count)
        #expect(client.indexStore.token(at: 0).string == "node0")
        #expect(client.indexStore.token(at: 0).item as? String == "node0")
    }
}

#endif
