import Foundation
import Testing
@testable import UIFoundationWindowedRows

@Suite("Running a windowed source for a table")
@MainActor
struct WindowedRowsControllerTests {
    /// The events a controller sent, in order, without their payloads.
    private final class EventLog {
        var names: [String] = []
        var reloadedRows: [IndexSet] = []
        var progress: [WindowedSearchProgress] = []

        func record(_ event: WindowedRowsController<NumberedRow>.Event) {
            switch event {
            case .cacheDidClear: names.append("cacheDidClear")
            case .reloadAllRows: names.append("reloadAllRows")
            case .cacheDidInstall: names.append("cacheDidInstall")
            case .windowDidLoad: names.append("windowDidLoad")
            case .reloadRows(let rows):
                names.append("reloadRows")
                reloadedRows.append(rows)
            case .forwardVisibleRange(let range): names.append("forwardVisibleRange(\(range))")
            case .settle(let centerRow, let radius): names.append("settle(\(centerRow), \(radius))")
            case .prewarm(let centerRow, let radius): names.append("prewarm(\(centerRow), \(radius))")
            case .scrollToRow(let row): names.append("scrollToRow(\(row))")
            case .searchDidChange: names.append("searchDidChange")
            case .searchProgressDidUpdate(let snapshot):
                names.append("searchProgressDidUpdate")
                progress.append(snapshot)
            case .loadingIndicatorVisibilityDidChange(let isVisible): names.append("loadingIndicator(\(isVisible))")
            case .dragDidBegin: names.append("dragDidBegin")
            case .dragDidEnd: names.append("dragDidEnd")
            }
        }
    }

    private func makeController(
        scheduler: ManualTestScheduler = ManualTestScheduler(),
        searchDebounceMillis: Int = 0,
        completionDispatch: WindowedRowSearch<NumberedRow>.CompletionDispatch = .mainQueueAsync
    ) -> (WindowedRowsController<NumberedRow>, EventLog) {
        let log = EventLog()
        let controller = WindowedRowsController(
            policy: ViewportWindowingPolicy(windowSize: 10, scrollCoalesceMillis: 0, searchDebounceMillis: searchDebounceMillis),
            placeholder: NumberedRow.placeholder,
            scheduler: scheduler
        ) { source, keyword in
            .keywordMatching(source: source, keyword: keyword, completionDispatch: completionDispatch) { row, matcher in
                matcher.matches(row.text)
            }
        }
        controller.onEvent = { log.record($0) }
        return (controller, log)
    }

    private func installedController(
        rowCount: Int,
        scheduler: ManualTestScheduler = ManualTestScheduler(),
        searchDebounceMillis: Int = 0,
        completionDispatch: WindowedRowSearch<NumberedRow>.CompletionDispatch = .mainQueueAsync,
        text: @escaping @Sendable (Int) -> String = { "row \($0)" }
    ) async throws -> (WindowedRowsController<NumberedRow>, EventLog) {
        let (controller, log) = makeController(
            scheduler: scheduler,
            searchDebounceMillis: searchDebounceMillis,
            completionDispatch: completionDispatch
        )
        controller.setSource(makeNumberedSource(rowCount: rowCount, text: text))
        try #require(await waitUntil { controller.installedCache != nil })
        log.names.removeAll()
        return (controller, log)
    }

    @Test("a new source shows no rows at first, then all of them once its count is resolved in the background")
    func newSourceInstallsAfterTheCountResolves() async throws {
        let (controller, log) = makeController()
        controller.setSource(makeNumberedSource(rowCount: 100))
        #expect(log.names == ["cacheDidClear", "reloadAllRows"])
        #expect(controller.numberOfDisplayedRows == 0)

        try #require(await waitUntil { controller.installedCache != nil })
        // The windows prefetched on install may already have reported after these.
        #expect(Array(log.names.prefix(4)) == ["cacheDidClear", "reloadAllRows", "cacheDidInstall", "reloadAllRows"])
        #expect(controller.totalRowCount == 100)
        #expect(controller.numberOfDisplayedRows == 100)
    }

    @Test("a count that resolves after its source was replaced is dropped")
    func staleCountIsDropped() async throws {
        let (controller, _) = makeController()
        controller.setSource(makeNumberedSource(rowCount: 100))
        controller.setSource(nil)
        try await Task.sleep(nanoseconds: 50_000_000)
        #expect(controller.installedCache == nil)
        #expect(controller.numberOfDisplayedRows == 0)
    }

    @Test("a loading indicator shows when resolving the count takes longer than half a second")
    func loadingIndicatorAfterHalfASecond() {
        let scheduler = ManualTestScheduler()
        let (controller, log) = makeController(scheduler: scheduler)
        let slowSource = WindowedRowSource<NumberedRow>(
            totalCount: { Thread.sleep(forTimeInterval: 0.2); return 10 }(),
            fetch: { range in range.map { NumberedRow(index: $0) } }
        )
        controller.setSource(slowSource)
        scheduler.advance(byMilliseconds: 499)
        #expect(controller.isLoadingIndicatorVisible == false)
        scheduler.advance(byMilliseconds: 1)
        #expect(controller.isLoadingIndicatorVisible)
        #expect(log.names.last == "loadingIndicator(true)")
    }

    @Test("rows arrive as placeholders, then a loaded window reloads exactly its rows")
    func loadedWindowReloadsItsRows() async throws {
        let (controller, log) = try await installedController(rowCount: 100)
        #expect(await waitUntil { log.reloadedRows.contains(IndexSet(integersIn: 0 ..< 10)) }, "the first window is prefetched on install")

        #expect(controller.row(atDisplayedRow: 55) == .placeholder)
        #expect(await waitUntil { log.reloadedRows.contains(IndexSet(integersIn: 50 ..< 60)) })
        #expect(controller.row(atDisplayedRow: 55) == NumberedRow(index: 55))
        #expect(controller.isRowLoaded(atDisplayedRow: 55))
    }

    @Test("ending a drag forwards the latest range and then settles around its centre")
    func dragEndForwardsThenSettles() async throws {
        let (controller, log) = try await installedController(rowCount: 1_000)
        controller.userDidBeginDragging()
        controller.reportVisibleRange(50 ..< 114)
        controller.userDidEndDragging()
        #expect(log.names == ["dragDidBegin", "dragDidEnd", "forwardVisibleRange(50..<114)", "settle(82, 1)"])
    }

    @Test("scrolling to a row prewarms it before scrolling")
    func scrollPrewarmsFirst() {
        let (controller, log) = makeController()
        controller.scrollToRow(300)
        #expect(log.names == ["prewarm(300, 1)", "scrollToRow(300)"])
    }

    @Test("a keyword applies only once it stays unchanged for the debounce interval")
    func keywordIsDebounced() async throws {
        let scheduler = ManualTestScheduler()
        let (controller, log) = try await installedController(rowCount: 100, scheduler: scheduler, searchDebounceMillis: 200)
        controller.setSearchKeyword("row 1")
        controller.setSearchKeyword("row 12")
        scheduler.advance(byMilliseconds: 199)
        #expect(controller.isSearchActive == false)
        scheduler.advance(byMilliseconds: 1)
        #expect(controller.isSearchActive)
        #expect(controller.searchKeyword == "row 12")
        #expect(log.names.prefix(2) == ["searchDidChange", "reloadAllRows"])
    }

    @Test("clearing the keyword applies at once")
    func clearingAppliesAtOnce() async throws {
        let scheduler = ManualTestScheduler()
        let (controller, _) = try await installedController(rowCount: 100, scheduler: scheduler, searchDebounceMillis: 200)
        controller.setSearchKeyword("row 1")
        scheduler.advance(byMilliseconds: 200)
        #expect(controller.isSearchActive)
        controller.clearSearch()
        #expect(controller.isSearchActive == false)
        #expect(controller.numberOfDisplayedRows == 100)
    }

    @Test("changing the source drops a keyword still waiting for its debounce")
    func sourceChangeDropsAPendingKeyword() async throws {
        let scheduler = ManualTestScheduler()
        let (controller, _) = try await installedController(rowCount: 100, scheduler: scheduler, searchDebounceMillis: 200)
        controller.setSearchKeyword("row 1")
        controller.setSource(makeNumberedSource(rowCount: 10))
        scheduler.advance(byMilliseconds: 200)
        #expect(controller.searchKeyword.isEmpty)
        #expect(controller.activeSearch == nil)
    }

    @Test("a search shows only the matching rows, mapped to their source rows")
    func searchFiltersTheDisplayedRows() async throws {
        let (controller, _) = try await installedController(rowCount: 100) { $0 % 10 == 3 ? "match \($0)" : "row \($0)" }
        controller.setSearchKeyword("match")
        #expect(await waitUntil { controller.searchProgress?.isComplete == true })
        #expect(controller.numberOfDisplayedRows == 10)
        #expect(controller.filteredSourceRowIndex(forDisplayedRow: 2) == 23)
        #expect(controller.sourceRowIndex(forDisplayedRow: 9) == 93)
        #expect(controller.sourceRowIndex(forDisplayedRow: 10) == nil)
        #expect(controller.makeDisplayedRows()?.count == 10)
    }

    @Test("while a search is active, a loaded window reloads only the matches it covers")
    func loadedWindowReloadsItsMatches() async throws {
        let (controller, log) = try await installedController(rowCount: 100) { $0 % 10 == 3 ? "match \($0)" : "row \($0)" }
        controller.setSearchKeyword("match")
        #expect(await waitUntil { controller.searchProgress?.isComplete == true })
        log.reloadedRows.removeAll()
        // Displayed row 5 is source row 53, in the window 50..<60.
        #expect(controller.row(atDisplayedRow: 5) == .placeholder)
        #expect(await waitUntil { !log.reloadedRows.isEmpty })
        #expect(log.reloadedRows.last == IndexSet(integer: 5))
        #expect(controller.row(atDisplayedRow: 5) == NumberedRow(index: 53, text: "match 53"))
    }

    @Test("search progress reloads the table at most every 100 ms, and always when the scan completes")
    func searchProgressReloadsAreThrottled() async throws {
        let rowCount = 20 * WindowedRowSearch<NumberedRow>.batchSize
        let (controller, log) = try await installedController(rowCount: rowCount) { $0 % 7 == 0 ? "match \($0)" : "row \($0)" }
        controller.setSearchKeyword("match")
        #expect(await waitUntil(timeoutMilliseconds: 20_000) { controller.searchProgress?.isComplete == true })
        let progressCount = log.names.filter { $0 == "searchProgressDidUpdate" }.count
        let reloadCount = log.names.filter { $0 == "reloadAllRows" }.count
        #expect(progressCount >= 20)
        #expect(reloadCount < progressCount, "batches inside the throttle window must not reload")
        let lastProgressPosition = try #require(log.names.lastIndex(of: "searchProgressDidUpdate"))
        #expect(log.names[(lastProgressPosition + 1)...].contains("reloadAllRows"), "the completed scan always reloads")
        #expect(controller.numberOfDisplayedRows == controller.filteredRowCount)
    }

    @Test("a keyword without a source changes nothing but still reports the change")
    func keywordWithoutASourceChangesNothing() {
        let (controller, log) = makeController()
        controller.setSearchKeyword("row")
        #expect(controller.activeSearch == nil)
        #expect(controller.isSearchActive == false)
        #expect(log.names == ["searchDidChange", "reloadAllRows"])
    }
}
