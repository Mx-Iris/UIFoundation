#if canImport(AppKit) && !targetEnvironment(macCatalyst)

import AppKit
import Testing
import WindowedRowsToolbox
@testable import UIFoundationAppKit

/// A row that says which source row it is.
private struct NumberedRow: Sendable, Equatable {
    let index: Int
    let text: String

    static let placeholder = NumberedRow(index: -1, text: "")
}

/// A table in a scroll view, 20 pt rows, with a data source over a controller
/// of `rowCount` rows.
@MainActor
private final class WindowedTableFixture {
    let scrollView = NSScrollView(frame: CGRect(x: 0, y: 0, width: 400, height: 200))
    let tableView = NSTableView()
    let controller: WindowedRowsController<NumberedRow>
    let dataSource: WindowedTableViewDataSource<NumberedRow>
    var eventNames: [String] = []

    init(rowCount: Int, text: @escaping @Sendable (Int) -> String = { "row \($0)" }) {
        tableView.addTableColumn(NSTableColumn(identifier: NSUserInterfaceItemIdentifier("text")))
        tableView.rowHeight = 20
        tableView.intercellSpacing = .zero
        tableView.headerView = nil
        scrollView.documentView = tableView
        scrollView.hasVerticalScroller = true

        controller = WindowedRowsController(
            policy: ViewportWindowingPolicy(windowSize: 100, maxResidentWindows: 4, prefetchNeighbors: false, scrollCoalesceMillis: 0, searchDebounceMillis: 0),
            placeholder: .placeholder
        ) { source, keyword in
            .keywordMatching(source: source, keyword: keyword) { row, matcher in matcher.matches(row.text) }
        }
        dataSource = WindowedTableViewDataSource(tableView: tableView, controller: controller)
        dataSource.searchableColumns = {
            WindowedFindIndexColumns(count: 1) { row, columnStrings in columnStrings[0] = row.text }
        }
        controller.onEvent = { [weak self] event in
            guard let self else { return }
            self.eventNames.append(Self.name(of: event))
            self.dataSource.handle(event)
        }
        controller.setSource(WindowedRowSource(
            totalCount: rowCount,
            fetch: { range in range.map { NumberedRow(index: $0, text: text($0)) } }
        ))
    }

    private static func name(of event: WindowedRowsController<NumberedRow>.Event) -> String {
        switch event {
        case .dragDidBegin: "dragDidBegin"
        case .dragDidEnd: "dragDidEnd"
        case .forwardVisibleRange: "forwardVisibleRange"
        case .settle: "settle"
        default: "other"
        }
    }

    /// Scrolls so that `row` is the first visible row.
    func scroll(toRow row: Int) {
        scrollView.contentView.scroll(to: CGPoint(x: 0, y: CGFloat(row) * 20))
        scrollView.reflectScrolledClipView(scrollView.contentView)
    }

    func waitUntil(timeoutSeconds: TimeInterval = 5, _ condition: () -> Bool) async -> Bool {
        let deadline = ProcessInfo.processInfo.systemUptime + timeoutSeconds
        while !condition() {
            if ProcessInfo.processInfo.systemUptime >= deadline { return false }
            try? await Task.sleep(nanoseconds: 1_000_000)
        }
        return true
    }

    func waitForInstall() async -> Bool {
        await waitUntil { controller.installedCache != nil && tableView.numberOfRows == controller.numberOfDisplayedRows }
    }
}

@Suite("A table of windowed rows")
@MainActor
struct WindowedTableViewDataSourceTests {
    @Test("the table shows no rows until the row count is resolved, then all of them")
    func rowCountFollowsTheController() async throws {
        let fixture = WindowedTableFixture(rowCount: 10_000)
        #expect(fixture.tableView.dataSource === fixture.dataSource)
        #expect(fixture.dataSource.numberOfRows(in: fixture.tableView) == 0)
        try #require(await fixture.waitForInstall())
        #expect(fixture.tableView.numberOfRows == 10_000)
    }

    @Test("without a controller the table shows no rows")
    func noControllerNoRows() async throws {
        let fixture = WindowedTableFixture(rowCount: 100)
        try #require(await fixture.waitForInstall())
        fixture.dataSource.controller = nil
        fixture.tableView.reloadData()
        #expect(fixture.tableView.numberOfRows == 0)
    }

    @Test("scrolling reports the rows in view, so their window is fetched")
    func scrollingFetchesTheVisibleRows() async throws {
        let fixture = WindowedTableFixture(rowCount: 10_000)
        try #require(await fixture.waitForInstall())
        #expect(fixture.controller.isRowLoaded(atDisplayedRow: 5_000) == false)
        fixture.scroll(toRow: 5_000)
        #expect(await fixture.waitUntil { fixture.controller.isRowLoaded(atDisplayedRow: 5_000) })
    }

    @Test("while the scroll bar's knob is dragged nothing is fetched; releasing it fetches the rows in view")
    func dragHoldsFetchesUntilRelease() async throws {
        let fixture = WindowedTableFixture(rowCount: 10_000)
        try #require(await fixture.waitForInstall())
        NotificationCenter.default.post(name: NSScrollView.willStartLiveScrollNotification, object: fixture.scrollView)
        fixture.scroll(toRow: 7_000)
        try await Task.sleep(nanoseconds: 50_000_000)
        #expect(fixture.controller.isRowLoaded(atDisplayedRow: 7_000) == false, "a drag must not fetch")

        NotificationCenter.default.post(name: NSScrollView.didEndLiveScrollNotification, object: fixture.scrollView)
        // Windows prefetched on install may report in between; only the drag's events count here.
        let dragEvents = fixture.eventNames.filter { $0 != "other" }
        #expect(Array(dragEvents.suffix(4)) == ["dragDidBegin", "dragDidEnd", "forwardVisibleRange", "settle"])
        #expect(await fixture.waitUntil { fixture.controller.isRowLoaded(atDisplayedRow: 7_000) })
    }

    @Test("the find index holds every displayed row, read from the source")
    func findIndexCoversEveryRow() async throws {
        let fixture = WindowedTableFixture(rowCount: 1_000)
        try #require(await fixture.waitForInstall())
        fixture.dataSource.textFinderClient.prepareIndexIfNeeded()
        try #require(await fixture.waitUntil { !fixture.dataSource.findIndexScanner.isScanning })
        let expectedLength = (0 ..< 1_000).reduce(0) { $0 + "row \($1)".utf16.count }
        #expect(fixture.dataSource.textFinderClient.stringLength() == expectedLength)
    }

    @Test("while a search is active, the find index holds only the matching rows")
    func findIndexFollowsTheSearch() async throws {
        let fixture = WindowedTableFixture(rowCount: 1_000) { $0 % 100 == 7 ? "match \($0)" : "row \($0)" }
        try #require(await fixture.waitForInstall())
        fixture.controller.setSearchKeyword("match")
        try #require(await fixture.waitUntil { fixture.controller.searchProgress?.isComplete == true })
        try #require(await fixture.waitUntil { fixture.tableView.numberOfRows == 10 })

        fixture.dataSource.textFinderClient.prepareIndexIfNeeded()
        try #require(await fixture.waitUntil { !fixture.dataSource.findIndexScanner.isScanning })
        let expectedLength = stride(from: 7, to: 1_000, by: 100).reduce(0) { $0 + "match \($1)".utf16.count }
        #expect(fixture.dataSource.textFinderClient.stringLength() == expectedLength)
    }

    @Test("a cancelled scan never delivers its index")
    func cancelledScanDeliversNothing() async throws {
        let scanner = WindowedFindIndexScanner()
        let rows = WindowedDisplayedRows(
            source: WindowedRowSource<NumberedRow>(
                totalCount: 200_000,
                fetch: { range in range.map { NumberedRow(index: $0, text: "row \($0)") } }
            ),
            filteredSourceRowIndices: nil
        )
        var deliveredCount = 0
        scanner.start(
            rows: rows,
            columns: WindowedFindIndexColumns(count: 1) { row, columnStrings in columnStrings[0] = row.text },
            showingProgressOver: nil
        ) { _ in deliveredCount += 1 }
        let runningScan = try #require(scanner.runningScan)
        scanner.cancel()
        await runningScan.value
        try await Task.sleep(nanoseconds: 20_000_000)
        #expect(deliveredCount == 0)
        #expect(scanner.isScanning == false)
    }

    @Test("the progress bar's fill follows the progress")
    func progressBarFillFollowsProgress() {
        let progressView = WindowedFindIndexProgressView(fillColor: .controlAccentColor)
        progressView.frame = CGRect(x: 0, y: 0, width: 200, height: 2)
        progressView.progress = 0.25
        progressView.layoutSubtreeIfNeeded()
        #expect(progressView.fillWidth == 50)
        progressView.progress = 3
        progressView.layoutSubtreeIfNeeded()
        #expect(progressView.fillWidth == 200, "progress is clamped to 1")
    }
}

#endif
