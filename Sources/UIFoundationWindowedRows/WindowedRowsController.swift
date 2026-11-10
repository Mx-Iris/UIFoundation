import Combine
import Foundation
import OSToolbox

/// The rows a table displays, captured so a background task can walk them: the
/// source, and the matching source rows while a search is active.
public struct WindowedDisplayedRows<Row: Sendable>: Sendable {
    public let source: WindowedRowSource<Row>

    /// The source rows the table displays, in order, or `nil` when it displays
    /// every source row.
    public let filteredSourceRowIndices: [Int]?

    public init(source: WindowedRowSource<Row>, filteredSourceRowIndices: [Int]?) {
        self.source = source
        self.filteredSourceRowIndices = filteredSourceRowIndices
    }

    /// The number of displayed rows.
    public var count: Int {
        filteredSourceRowIndices?.count ?? source.totalCount
    }

    /// The displayed rows in `displayedRange`, fetched straight from the source.
    /// Consecutive source rows are fetched in one call. Meant for a background
    /// task that walks every displayed row, such as a find index scan; it never
    /// touches a ``ViewportCache``.
    public func rows(in displayedRange: Range<Int>) -> [Row] {
        guard let filteredSourceRowIndices else {
            return source.fetch(displayedRange)
        }
        var fetchedRows: [Row] = []
        fetchedRows.reserveCapacity(displayedRange.count)
        var stretchStart = displayedRange.lowerBound
        while stretchStart < displayedRange.upperBound {
            var stretchEnd = stretchStart + 1
            while stretchEnd < displayedRange.upperBound,
                  filteredSourceRowIndices[stretchEnd] == filteredSourceRowIndices[stretchEnd - 1] + 1 {
                stretchEnd += 1
            }
            let sourceLowerBound = filteredSourceRowIndices[stretchStart]
            let sourceUpperBound = filteredSourceRowIndices[stretchEnd - 1] + 1
            fetchedRows.append(contentsOf: source.fetch(sourceLowerBound ..< sourceUpperBound))
            stretchStart = stretchEnd
        }
        return fetchedRows
    }
}

/// Runs a ``WindowedRowSource`` for one table: resolves its row count in the
/// background, installs a ``ViewportCache``, paces visible-range reports, runs
/// the row search, and tells the table what to reload.
///
/// A table binding feeds it the visible range and the start and end of scroll
/// bar drags, asks it for rows by displayed index, and performs the ``Event``s
/// it sends: reloads, and the visible-range forwards and settles that load
/// rows into the cache. The controller never touches a view.
///
/// Rules it keeps so the table stays responsive with millions of rows:
/// - The row count is resolved on a detached task: a source's count may walk a
///   whole binary.
/// - While the user drags a scroll bar's knob, no fetch is started; when the
///   drag ends, the latest range is forwarded and the rows around it are
///   fetched before the next frame (``Event/settle(centerRow:radius:)``).
/// - A loaded window reloads only its own rows, mapped through the search.
/// - Search progress reloads the table at most every 100 ms, and always once
///   the scan completes.
@Loggable(subsystem: "UIFoundationWindowedRows", category: "WindowedRowsController")
@Signpostable(subsystem: "UIFoundationWindowedRows", category: "WindowedRowsController")
@MainActor
public final class WindowedRowsController<Row: Sendable> {
    /// What the controller asks the table to do, in the order it must happen.
    public enum Event {
        /// The previous source's cache was dropped.
        case cacheDidClear
        /// Reload every row: the row count changed.
        case reloadAllRows
        /// The source's row count is resolved and its cache installed; the row
        /// count is now ``totalRowCount``. Carries how long the count took to
        /// resolve, in seconds. A ``reloadAllRows`` follows.
        case cacheDidInstall(ViewportCache<Row>, countResolveDuration: TimeInterval)
        /// A window of source rows has arrived. A ``reloadRows(_:)`` for the
        /// displayed rows it covers follows.
        case windowDidLoad(Range<Int>)
        /// Reload these displayed rows: their window has arrived.
        case reloadRows(IndexSet)
        /// Pass this range to the cache's
        /// ``ViewportCache/reportVisibleRange(_:)``: a drag has ended.
        case forwardVisibleRange(Range<Int>)
        /// Call the cache's ``ViewportCache/prewarmSynchronous(centerRow:radius:)``
        /// now, before the next frame, so the rows in view after a drag are real.
        case settle(centerRow: Int, radius: Int)
        /// Call the cache's ``ViewportCache/prewarmSynchronous(centerRow:radius:)``
        /// for a row the table is about to scroll to.
        case prewarm(centerRow: Int, radius: Int)
        /// Scroll this displayed row into view.
        case scrollToRow(Int)
        /// The search keyword was applied: ``isSearchActive`` and
        /// ``numberOfDisplayedRows`` may have changed. A ``reloadAllRows`` follows.
        case searchDidChange
        /// The search scanned another batch; ``numberOfDisplayedRows`` may have
        /// grown. A ``reloadAllRows`` follows when the table should show the new
        /// matches.
        case searchProgressDidUpdate(WindowedSearchProgress)
        /// Show or hide a loading indicator: resolving the row count is taking
        /// longer than half a second.
        case loadingIndicatorVisibilityDidChange(Bool)
        /// The user started dragging a scroll bar's knob.
        case dragDidBegin
        /// The user stopped dragging, or a fling stopped.
        case dragDidEnd
    }

    /// Receives every event, synchronously, in order.
    public var onEvent: ((Event) -> Void)?

    /// The policy for the next source. Changing it also updates the installed
    /// cache's neighbour prefetching and the merge window of visible-range
    /// reports at once.
    public var policy: ViewportWindowingPolicy {
        didSet {
            installedCache?.prefetchNeighborsEnabled = policy.prefetchNeighbors
            scrollCoordinator?.scrollCoalesceMillis = policy.scrollCoalesceMillis
        }
    }

    /// The row returned for a row that is not loaded yet.
    public let placeholder: Row

    private let scheduler: any WindowedRowsScheduler
    private let makeSearch: @MainActor (_ source: WindowedRowSource<Row>, _ keyword: String) -> WindowedRowSearch<Row>

    /// The source the table shows, or `nil`.
    public private(set) var source: WindowedRowSource<Row>?

    /// The cache, once the source's row count is resolved.
    public private(set) var installedCache: ViewportCache<Row>?

    /// The search running or finished for the current keyword, or `nil`.
    public private(set) var activeSearch: WindowedRowSearch<Row>?

    /// The applied keyword, trimmed; empty when no search is active.
    public private(set) var searchKeyword: String = ""

    /// The source's row count; `0` until the cache is installed.
    public private(set) var totalRowCount: Int = 0

    /// The rows the table shows: the matches while a search is active, every row
    /// otherwise. It changes only together with a ``Event/reloadAllRows``.
    public private(set) var numberOfDisplayedRows: Int = 0

    /// The latest search progress, or `nil`.
    public private(set) var searchProgress: WindowedSearchProgress?

    /// Whether resolving the row count has taken longer than half a second.
    public private(set) var isLoadingIndicatorVisible: Bool = false

    /// Whether a search with a non-empty keyword is filtering the rows.
    public var isSearchActive: Bool {
        activeSearch != nil && !searchKeyword.isEmpty
    }

    private var sourceGeneration: UInt64 = 0
    private var scrollCoordinator: ViewportScrollCoordinator?
    private var loadingIndicatorWork: (any Cancellable)?
    private var searchDebounceWork: (any Cancellable)?
    /// System uptime, in seconds, of the latest reload a search progress caused.
    private var lastSearchProgressReloadUptime: TimeInterval?

    private static var searchProgressReloadThrottleInterval: TimeInterval { 0.1 }
    private static var loadingIndicatorDelayMilliseconds: Int { 500 }

    /// Creates a controller.
    ///
    /// `makeSearch` builds the search for a keyword, typically
    /// `{ source, keyword in .keywordMatching(source: source, keyword: keyword) { row, matcher in matcher.matches(row.name) } }`.
    public init(
        policy: ViewportWindowingPolicy = .default,
        placeholder: Row,
        scheduler: any WindowedRowsScheduler = MainActorTaskScheduler(),
        makeSearch: @escaping @MainActor (_ source: WindowedRowSource<Row>, _ keyword: String) -> WindowedRowSearch<Row>
    ) {
        self.policy = policy
        self.placeholder = placeholder
        self.scheduler = scheduler
        self.makeSearch = makeSearch
    }

    deinit {
        MainActor.assumeIsolated {
            installedCache?.cancel()
            scrollCoordinator?.tearDown()
            activeSearch?.cancel()
            searchDebounceWork?.cancel()
            loadingIndicatorWork?.cancel()
        }
    }

    // MARK: - Source

    /// Shows a source, or nothing.
    ///
    /// Drops the previous source's cache, search, pending keyword and loading
    /// timer, and sends ``Event/cacheDidClear``. For a new source it then sends
    /// ``Event/reloadAllRows`` with no rows, resolves the row count on a
    /// detached task, and on its return installs the cache and sends
    /// ``Event/cacheDidInstall(_:countResolveDuration:)`` and another
    /// ``Event/reloadAllRows``. A result for a source that was replaced in the
    /// meantime is dropped.
    public func setSource(_ newSource: WindowedRowSource<Row>?) {
        loadingIndicatorWork?.cancel()
        loadingIndicatorWork = nil
        searchDebounceWork?.cancel()
        searchDebounceWork = nil
        installedCache?.cancel()
        installedCache = nil
        scrollCoordinator?.tearDown()
        scrollCoordinator = nil
        sourceGeneration &+= 1
        emit(.cacheDidClear)
        cancelSearch()

        source = newSource
        totalRowCount = 0
        numberOfDisplayedRows = 0
        searchProgress = nil
        lastSearchProgressReloadUptime = nil
        isLoadingIndicatorVisible = false

        guard let newSource else { return }
        emit(.reloadAllRows)

        loadingIndicatorWork = scheduler.schedule(afterMilliseconds: Self.loadingIndicatorDelayMilliseconds) { [weak self] in
            guard let self else { return }
            self.loadingIndicatorWork = nil
            self.isLoadingIndicatorVisible = true
            self.emit(.loadingIndicatorVisibilityDidChange(true))
        }

        let generation = sourceGeneration
        let cachePolicy = self.policy
        let cachePlaceholder = self.placeholder
        let resolveStart = ProcessInfo.processInfo.systemUptime
        let resolveInterval = #signpost(.begin, "windowed_totalcount_resolve", "generation=\(generation)")
        // Detached, not a plain `Task`: a plain one would inherit the main actor
        // and resolve the count on the main thread, which for some sources
        // takes seconds.
        Task.detached(priority: .userInitiated) { [weak self] in
            let cache = ViewportCache(source: newSource, policy: cachePolicy, placeholder: cachePlaceholder)
            _ = cache.totalCount
            await MainActor.run { [weak self] in
                #signpost(.end, resolveInterval)
                guard let self, self.sourceGeneration == generation else { return }
                self.loadingIndicatorWork?.cancel()
                self.loadingIndicatorWork = nil
                self.install(cache, countResolveDuration: ProcessInfo.processInfo.systemUptime - resolveStart)
            }
        }
    }

    private func install(_ cache: ViewportCache<Row>, countResolveDuration: TimeInterval) {
        cache.onWindowLoaded = { [weak self, weak cache] loadedRange in
            guard let self, let cache, self.installedCache === cache else { return }
            self.emit(.windowDidLoad(loadedRange))
            self.reloadDisplayedRows(coveringSourceRows: loadedRange, in: cache)
        }
        installedCache = cache
        scrollCoordinator = ViewportScrollCoordinator(
            scrollCoalesceMillis: policy.scrollCoalesceMillis,
            scheduler: scheduler,
            forwardToCache: { [weak cache] range in cache?.reportVisibleRange(range) }
        )
        totalRowCount = cache.totalCount
        numberOfDisplayedRows = cache.totalCount
        isLoadingIndicatorVisible = false
        emit(.cacheDidInstall(cache, countResolveDuration: countResolveDuration))
        emit(.reloadAllRows)
        cache.requestPrefetch(around: 0)
    }

    private func reloadDisplayedRows(coveringSourceRows loadedRange: Range<Int>, in cache: ViewportCache<Row>) {
        if isSearchActive, let activeSearch {
            // The matches ascend, so the displayed rows a window covers are one
            // contiguous run; find its ends by binary search instead of walking
            // every match — searches often have 100,000 matches or more.
            let indices = activeSearch.filteredRowIndices
            let firstDisplayedRow = Self.lowestIndex(in: indices, withValueAtLeast: loadedRange.lowerBound)
            let endDisplayedRow = Self.lowestIndex(in: indices, withValueAtLeast: loadedRange.upperBound)
            guard firstDisplayedRow < endDisplayedRow else { return }
            emit(.reloadRows(IndexSet(integersIn: firstDisplayedRow ..< endDisplayedRow)))
            return
        }

        let rowCount = cache.totalCount
        guard rowCount > 0, loadedRange.lowerBound < rowCount else { return }
        emit(.reloadRows(IndexSet(integersIn: loadedRange.lowerBound ..< min(loadedRange.upperBound, rowCount))))
    }

    /// The smallest index whose value is at least `threshold` in an ascending
    /// array, or the array's count when every value is smaller.
    private static func lowestIndex(in sortedValues: [Int], withValueAtLeast threshold: Int) -> Int {
        var lowerSearchBound = 0
        var upperSearchBound = sortedValues.count
        while lowerSearchBound < upperSearchBound {
            let middleIndex = (lowerSearchBound + upperSearchBound) / 2
            if sortedValues[middleIndex] < threshold {
                lowerSearchBound = middleIndex + 1
            } else {
                upperSearchBound = middleIndex
            }
        }
        return lowerSearchBound
    }

    // MARK: - Rows

    /// The source row that displayed row `displayedRow` shows while a search is
    /// active, or `nil` when no search is active or the row is past the matches.
    public func filteredSourceRowIndex(forDisplayedRow displayedRow: Int) -> Int? {
        guard isSearchActive, let activeSearch else { return nil }
        let indices = activeSearch.filteredRowIndices
        guard displayedRow >= 0, displayedRow < indices.count else { return nil }
        return indices[displayedRow]
    }

    /// The source row that displayed row `displayedRow` shows, or `nil` when it
    /// is out of range.
    public func sourceRowIndex(forDisplayedRow displayedRow: Int) -> Int? {
        if isSearchActive {
            return filteredSourceRowIndex(forDisplayedRow: displayedRow)
        }
        guard let installedCache, displayedRow >= 0, displayedRow < installedCache.totalCount else { return nil }
        return displayedRow
    }

    /// The row at a displayed index: the real row once its window is loaded,
    /// otherwise ``placeholder``, in which case the window is fetched and a
    /// ``Event/reloadRows(_:)`` follows when it arrives.
    public func row(atDisplayedRow displayedRow: Int) -> Row {
        guard let installedCache, let sourceRow = sourceRowIndex(forDisplayedRow: displayedRow) else {
            return placeholder
        }
        return installedCache.row(at: sourceRow)
    }

    /// Whether the row at a displayed index is loaded, without fetching
    /// anything.
    public func isRowLoaded(atDisplayedRow displayedRow: Int) -> Bool {
        guard let installedCache, let sourceRow = sourceRowIndex(forDisplayedRow: displayedRow) else {
            return false
        }
        return installedCache.isRowResident(at: sourceRow)
    }

    /// The displayed rows, for a background task that walks every one of them;
    /// `nil` without a source.
    public func makeDisplayedRows() -> WindowedDisplayedRows<Row>? {
        guard let source else { return nil }
        return WindowedDisplayedRows(
            source: source,
            filteredSourceRowIndices: isSearchActive ? activeSearch?.filteredRowIndices : nil
        )
    }

    // MARK: - Viewport

    /// Reports the visible displayed rows. Ignored until the cache is installed.
    public func reportVisibleRange(_ range: Range<Int>) {
        scrollCoordinator?.reportVisibleRange(range)
    }

    /// The user started dragging a scroll bar's knob: hold every fetch until the
    /// drag ends.
    public func userDidBeginDragging() {
        emit(.dragDidBegin)
        scrollCoordinator?.userDidBeginDragging()
    }

    /// The user stopped dragging: forward the latest range and settle around it.
    public func userDidEndDragging() {
        emit(.dragDidEnd)
        flushDraggedRange()
    }

    /// A fling stopped decelerating: forward the latest range and settle around
    /// it, as at the end of a drag.
    public func userDidFinishDeceleration() {
        emit(.dragDidEnd)
        flushDraggedRange()
    }

    private func flushDraggedRange() {
        guard let scrollCoordinator, let pending = scrollCoordinator.userDidEndDragging() else { return }
        emit(.forwardVisibleRange(pending))
        emit(.settle(centerRow: ViewportScrollCoordinator.centerRow(of: pending), radius: 1))
    }

    /// Fetches the rows around a displayed row and scrolls to it.
    public func scrollToRow(_ displayedRow: Int) {
        emit(.prewarm(centerRow: displayedRow, radius: 1))
        emit(.scrollToRow(displayedRow))
    }

    // MARK: - Search

    /// Applies a search keyword once it has stayed unchanged for the policy's
    /// `searchDebounceMillis`. An empty keyword, or a debounce of `0`, applies at
    /// once. Changing the source drops a keyword still waiting.
    public func setSearchKeyword(_ keyword: String) {
        searchDebounceWork?.cancel()
        searchDebounceWork = nil
        let debounceMilliseconds = policy.searchDebounceMillis
        let trimmedKeyword = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedKeyword.isEmpty || debounceMilliseconds <= 0 {
            applySearchKeyword(keyword)
            return
        }
        searchDebounceWork = scheduler.schedule(afterMilliseconds: debounceMilliseconds) { [weak self] in
            guard let self else { return }
            self.searchDebounceWork = nil
            self.applySearchKeyword(keyword)
        }
    }

    /// Clears the search keyword at once.
    public func clearSearch() {
        setSearchKeyword("")
    }

    private func applySearchKeyword(_ keyword: String) {
        lastSearchProgressReloadUptime = nil
        let trimmedKeyword = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedKeyword.isEmpty {
            cancelSearch()
        } else if let source {
            activeSearch?.cancel()
            searchKeyword = trimmedKeyword
            let search = makeSearch(source, trimmedKeyword)
            observe(search)
            activeSearch = search
            search.start()
        }
        // Without a source a non-empty keyword changes nothing.
        numberOfDisplayedRows = isSearchActive ? filteredRowCount : totalRowCount
        emit(.searchDidChange)
        emit(.reloadAllRows)
    }

    /// Adopts a search built and run by the caller — for a test that runs a
    /// search synchronously — without starting it or sending any event.
    public func installSearch(_ search: WindowedRowSearch<Row>, keyword: String) {
        activeSearch?.cancel()
        searchKeyword = keyword
        observe(search)
        activeSearch = search
    }

    /// Stops and drops the search without sending any event.
    public func cancelSearch() {
        activeSearch?.cancel()
        activeSearch = nil
        searchKeyword = ""
    }

    /// The number of matches so far, or `0` without a search.
    public var filteredRowCount: Int {
        activeSearch?.filteredRowIndices.count ?? 0
    }

    private func observe(_ search: WindowedRowSearch<Row>) {
        search.onProgress = { [weak self] progress in
            self?.handleSearchProgress(progress)
        }
        search.onComplete = { [weak self] progress in
            self?.handleSearchProgress(progress)
        }
    }

    private func handleSearchProgress(_ progress: WindowedSearchProgress) {
        // A million-row source reports about a thousand batches per scan, and a
        // full reload for each starves the main thread. Batches in between
        // still update the progress, so a "matched / scanned" label stays live;
        // the completed scan always reloads.
        let now = ProcessInfo.processInfo.systemUptime
        let throttleIntervalElapsed = lastSearchProgressReloadUptime.map {
            now - $0 >= Self.searchProgressReloadThrottleInterval
        } ?? true
        let shouldReload = progress.isComplete || throttleIntervalElapsed
        if shouldReload {
            lastSearchProgressReloadUptime = now
            numberOfDisplayedRows = filteredRowCount
        }
        searchProgress = progress
        emit(.searchProgressDidUpdate(progress))
        if shouldReload {
            emit(.reloadAllRows)
        }
    }

    // MARK: - Events

    private func emit(_ event: Event) {
        onEvent?(event)
    }
}
