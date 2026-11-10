import Foundation
import OSToolbox

/// A snapshot of a ``ViewportCache``'s counters, for diagnostics and tests.
public struct ViewportCacheDiagnostics: Sendable {
    public let hitCount: Int
    public let missCount: Int
    public let evictionCount: Int
    public let residentWindowCount: Int
    public let lastFetchDurationMillis: Double

    /// How many fetches ran on the main thread over the cache's lifetime. The
    /// only legitimate source is ``ViewportCache/prewarmSynchronous(centerRow:radius:)``;
    /// visible-range reports and prefetches fetch in the background and must
    /// never add to it.
    public let mainThreadFetchCount: Int

    #if DEBUG
    /// Whether the most recent synchronous fetch ran on the main thread.
    public let lastFetchOriginMainThread: Bool
    #endif

    public var hitRate: Double {
        let total = hitCount + missCount
        return total == 0 ? 0.0 : Double(hitCount) / Double(total)
    }
}

/// Keeps the rows around a table's visible range, a few fixed-size windows at a
/// time, and fetches the rest from a ``WindowedRowSource`` on demand.
///
/// The number of rows that exist at any time is bounded by
/// `windowSize × maxResidentWindows`, whatever the source's row count. A table
/// asks for rows with ``row(at:)``; a row whose window is not resident comes
/// back as the placeholder while the window is fetched in the background, and
/// ``onWindowLoaded`` reports the window's rows once it arrives, so the table
/// can reload them.
///
/// Threading: everything except the initializer runs on the main thread.
/// Fetches run on detached tasks and their results are applied back on the main
/// actor. The initializer may run anywhere, which lets a host build the cache
/// and resolve the source's row count off the main thread.
@Loggable(subsystem: "UIFoundationWindowedRows", category: "ViewportCache")
@Signpostable(subsystem: "UIFoundationWindowedRows", category: "ViewportCache")
public final class ViewportCache<Row: Sendable> {
    private let source: WindowedRowSource<Row>
    private var policy: ViewportWindowingPolicy

    /// The row ``row(at:)`` returns while a row's window is still being fetched.
    public let placeholder: Row

    /// Whether to fetch the windows next to the visible range in the background.
    /// Starts as the policy's `prefetchNeighbors` and can be changed at any time.
    public var prefetchNeighborsEnabled: Bool {
        get { policy.prefetchNeighbors }
        set { policy.prefetchNeighbors = newValue }
    }

    /// Window index → the window's rows.
    private var windows: [Int: [Row]] = [:]

    /// Resident window indices, most recently used first.
    private var leastRecentlyUsedOrder: [Int] = []

    /// Windows with a fetch in flight, so duplicate requests are merged.
    private var pendingWindows: Set<Int> = []

    /// Set by ``cancel()``. A fetch that finishes afterwards changes nothing and
    /// reports nothing.
    private var isCancelled: Bool = false

    private var hitCount: Int = 0
    private var missCount: Int = 0
    private var evictionCount: Int = 0
    private var lastFetchDurationMillis: Double = 0.0
    private var mainThreadFetchCount: Int = 0

    #if DEBUG
    private var lastFetchOriginMainThread: Bool = false
    #endif

    /// Called on the main thread when a background fetch has inserted a window,
    /// with the window's rows in source coordinates.
    public var onWindowLoaded: ((Range<Int>) -> Void)?

    /// The source's row count.
    public var totalCount: Int { source.totalCount }

    /// The current counters.
    public var diagnosticInfo: ViewportCacheDiagnostics {
        #if DEBUG
        return ViewportCacheDiagnostics(
            hitCount: hitCount,
            missCount: missCount,
            evictionCount: evictionCount,
            residentWindowCount: windows.count,
            lastFetchDurationMillis: lastFetchDurationMillis,
            mainThreadFetchCount: mainThreadFetchCount,
            lastFetchOriginMainThread: lastFetchOriginMainThread
        )
        #else
        return ViewportCacheDiagnostics(
            hitCount: hitCount,
            missCount: missCount,
            evictionCount: evictionCount,
            residentWindowCount: windows.count,
            lastFetchDurationMillis: lastFetchDurationMillis,
            mainThreadFetchCount: mainThreadFetchCount
        )
        #endif
    }

    #if DEBUG
    /// Logs the current counters at debug level.
    public func dumpDiagnosticInfo() {
        let info = diagnosticInfo
        #log(.debug, "diagnosticInfo hitRate=\(info.hitRate) residentWindows=\(info.residentWindowCount) evictions=\(info.evictionCount)")
    }
    #endif

    /// Creates a cache over a source.
    ///
    /// When the source holds a first window fetched ahead of time, the cache
    /// starts with it resident, so the first rows the table asks for are real
    /// rows instead of placeholders.
    public init(source: WindowedRowSource<Row>, policy: ViewportWindowingPolicy, placeholder: Row) {
        precondition(policy.windowSize > 0, "ViewportWindowingPolicy.windowSize must be > 0")
        precondition(policy.maxResidentWindows > 0, "ViewportWindowingPolicy.maxResidentWindows must be > 0")
        self.source = source
        self.policy = policy
        self.placeholder = placeholder

        if let preComputed = source.preComputedFirstWindow, !preComputed.isEmpty {
            let resolvedTotalCount = source.totalCount
            let upperBound = min(policy.windowSize, preComputed.count, resolvedTotalCount)
            if upperBound > 0 {
                let injected = upperBound == preComputed.count
                    ? preComputed
                    : Array(preComputed.prefix(upperBound))
                windows[0] = injected
                leastRecentlyUsedOrder.append(0)
                #log(.debug, "preComputed_first_window injected count=\(injected.count) totalCount=\(resolvedTotalCount)")
            }
        }
    }

    // MARK: - Viewport

    /// Stops the cache: a fetch already in flight changes nothing when it
    /// finishes, and ``onWindowLoaded`` is cleared. Call it before dropping the
    /// cache, so a late fetch cannot reload a table that shows something else.
    public func cancel() {
        isCancelled = true
        onWindowLoaded = nil
    }

    /// Reports the visible rows. Marks their windows recently used and fetches
    /// the missing ones in the background, plus the neighbouring windows when
    /// neighbour prefetching is on. Never fetches on the calling thread: rows of
    /// a missing window stay placeholders until the fetch settles.
    public func reportVisibleRange(_ range: Range<Int>) {
        guard !isCancelled else { return }
        guard totalCount > 0 else { return }
        let clampedLower = max(0, range.lowerBound)
        let clampedUpper = min(totalCount, range.upperBound)
        guard clampedLower < clampedUpper else { return }

        let firstWindow = clampedLower / policy.windowSize
        let lastWindow = (clampedUpper - 1) / policy.windowSize

        #log(.debug, "viewport_changed — first=\(clampedLower) last=\(clampedUpper - 1) total=\(self.totalCount)")

        for windowIndex in firstWindow...lastWindow {
            enqueueFetchIfNeeded(windowIndex: windowIndex)
        }

        guard policy.prefetchNeighbors else { return }

        if firstWindow > 0 {
            enqueueFetchIfNeeded(windowIndex: firstWindow - 1)
        }
        let lastValidWindow = (totalCount - 1) / policy.windowSize
        if lastWindow < lastValidWindow {
            enqueueFetchIfNeeded(windowIndex: lastWindow + 1)
        }
    }

    /// The row at `index`: the real row when its window is resident, otherwise
    /// the placeholder, in which case the window is fetched in the background
    /// and ``onWindowLoaded`` fires when it arrives.
    public func row(at index: Int) -> Row {
        precondition(
            index >= 0 && index < totalCount,
            "ViewportCache.row(at:): index \(index) out of bounds 0..<\(totalCount)"
        )
        let windowIndex = index / policy.windowSize
        if let cachedRows = windows[windowIndex] {
            promoteWindow(windowIndex)
            hitCount += 1
            return cachedRows[index - windowIndex * policy.windowSize]
        }

        // Count the miss and log it only when this call starts the fetch: a
        // table asks for every column of a row, so counting each call would
        // count one missing window once per cell.
        if !pendingWindows.contains(windowIndex) {
            missCount += 1
            #log(.debug, "cache_miss — row=\(index) window=\(windowIndex)")
            scheduleAsyncFetch(windowIndex: windowIndex)
        }
        return placeholder
    }

    /// Whether the row at `index` is resident, without fetching anything or
    /// changing the recently-used order.
    public func isRowResident(at index: Int) -> Bool {
        guard index >= 0, index < totalCount else { return false }
        return windows[index / policy.windowSize] != nil
    }

    /// Fetches the windows around `row` in the background, for a row the table
    /// is about to scroll to.
    public func requestPrefetch(around row: Int) {
        guard totalCount > 0 else { return }
        let clampedRow = max(0, min(totalCount - 1, row))
        let centerWindow = clampedRow / policy.windowSize
        let lastValidWindow = (totalCount - 1) / policy.windowSize

        enqueueFetchIfNeeded(windowIndex: centerWindow)
        if centerWindow > 0 {
            enqueueFetchIfNeeded(windowIndex: centerWindow - 1)
        }
        if centerWindow < lastValidWindow {
            enqueueFetchIfNeeded(windowIndex: centerWindow + 1)
        }
    }

    /// Fetches the windows covering `radius` rows on each side of `centerRow`
    /// on the calling thread, so they are resident when the call returns.
    ///
    /// The radius is capped at the policy's `prewarmSynchronousMaxRadius`. A
    /// source that is not a prewarm candidate is never fetched here: its range
    /// is reported as visible instead, so it is fetched in the background, and
    /// the call returns `false`. Also returns `false` when the radius was capped
    /// or the cache is cancelled, so a caller knows placeholders may still show.
    @discardableResult
    public func prewarmSynchronous(centerRow: Int, radius: Int) -> Bool {
        guard !isCancelled else { return false }
        let settleInterval = #signpost(.begin, "prewarm_sync", "center=\(centerRow) radius=\(radius)")
        defer { #signpost(.end, settleInterval) }
        guard totalCount > 0 else { return true }
        let cappedRadius = min(max(0, radius), policy.prewarmSynchronousMaxRadius)
        let clampedCenter = max(0, min(totalCount - 1, centerRow))
        let lowerRow = max(0, clampedCenter - cappedRadius)
        let upperRow = min(totalCount, clampedCenter + cappedRadius + 1)

        // A source whose rows are expensive to build would block the main
        // thread even within the radius cap — a SwiftUI `__swift5_types` window
        // took 14.47 s in MachOKitUI — so it is fetched in the background.
        if !source.isPrewarmCandidate {
            #log(.debug, "prewarmSync_skipped_nonCandidate — center=\(clampedCenter) radius=\(cappedRadius)")
            reportVisibleRange(lowerRow..<upperRow)
            return false
        }

        let firstWindow = lowerRow / policy.windowSize
        let lastWindow = (upperRow - 1) / policy.windowSize
        for windowIndex in firstWindow...lastWindow {
            ensureWindowResident(windowIndex)
        }
        return radius <= policy.prewarmSynchronousMaxRadius
    }

    // MARK: - Private

    /// Marks a resident window recently used, or starts a background fetch for
    /// a missing one unless a fetch is already in flight.
    private func enqueueFetchIfNeeded(windowIndex: Int) {
        guard windowIndex >= 0 else { return }
        if windows[windowIndex] != nil {
            promoteWindow(windowIndex)
            hitCount += 1
            return
        }
        guard !pendingWindows.contains(windowIndex) else { return }
        missCount += 1
        scheduleAsyncFetch(windowIndex: windowIndex)
    }

    /// Fetches a window on the calling thread. Only
    /// ``prewarmSynchronous(centerRow:radius:)`` calls it.
    private func ensureWindowResident(_ windowIndex: Int) {
        guard !isCancelled else { return }
        if windows[windowIndex] != nil {
            promoteWindow(windowIndex)
            hitCount += 1
            return
        }
        missCount += 1
        let range = windowRange(forWindow: windowIndex)
        #log(.debug, "fetch_begin — range=\(range.lowerBound)..<\(range.upperBound) cacheState=miss")
        let fetchInterval = #signpost(.begin, "window_fetch_sync", "range=\(range.lowerBound)..<\(range.upperBound)")
        let fetchStart = ProcessInfo.processInfo.systemUptime
        let rows = source.fetch(range)
        #signpost(.end, fetchInterval)
        let elapsedMillis = (ProcessInfo.processInfo.systemUptime - fetchStart) * 1_000
        lastFetchDurationMillis = elapsedMillis

        let isMainThread = Thread.isMainThread
        if isMainThread {
            mainThreadFetchCount += 1
        }
        #if DEBUG
        lastFetchOriginMainThread = isMainThread
        #endif

        #log(.debug, "fetch_end — range=\(range.lowerBound)..<\(range.upperBound) elapsedMs=\(elapsedMillis)")
        insertWindow(windowIndex: windowIndex, rows: rows)
    }

    private func scheduleAsyncFetch(windowIndex: Int) {
        pendingWindows.insert(windowIndex)
        let range = windowRange(forWindow: windowIndex)
        #log(.debug, "prewarm — range=\(range.lowerBound)..<\(range.upperBound)")
        // The interval runs from scheduling to the insert on the main actor:
        // how long the user sees placeholders for this window.
        let fetchInterval = #signpost(.begin, "window_fetch_async", "range=\(range.lowerBound)..<\(range.upperBound)")
        // Detached, not a plain `Task`: a plain one would inherit the caller's
        // main-actor isolation and fetch on the main thread.
        Task.detached(priority: .userInitiated) { [weak self, source] in
            let rows = source.fetch(range)
            source.prewarm(range)
            await MainActor.run { [weak self] in
                #signpost(.end, fetchInterval)
                guard let self, !self.isCancelled else { return }
                self.pendingWindows.remove(windowIndex)
                // A synchronous prewarm may have filled the slot meanwhile.
                if self.windows[windowIndex] == nil {
                    self.insertWindow(windowIndex: windowIndex, rows: rows)
                }
                self.onWindowLoaded?(range)
            }
        }
    }

    private func insertWindow(windowIndex: Int, rows: [Row]) {
        windows[windowIndex] = rows
        leastRecentlyUsedOrder.removeAll { $0 == windowIndex }
        leastRecentlyUsedOrder.insert(windowIndex, at: 0)
        while leastRecentlyUsedOrder.count > policy.maxResidentWindows {
            let evictedIndex = leastRecentlyUsedOrder.removeLast()
            windows[evictedIndex] = nil
            evictionCount += 1
            #log(.debug, "evict — window=\(evictedIndex) resident=\(self.windows.count)")
        }
    }

    private func promoteWindow(_ windowIndex: Int) {
        guard let position = leastRecentlyUsedOrder.firstIndex(of: windowIndex) else { return }
        if position == 0 { return }
        leastRecentlyUsedOrder.remove(at: position)
        leastRecentlyUsedOrder.insert(windowIndex, at: 0)
    }

    private func windowRange(forWindow windowIndex: Int) -> Range<Int> {
        let lower = windowIndex * policy.windowSize
        let upper = min(lower + policy.windowSize, totalCount)
        return lower..<upper
    }
}
