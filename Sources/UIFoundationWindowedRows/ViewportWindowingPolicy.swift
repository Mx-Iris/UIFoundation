/// Named tiers for ``WindowedRowSource/prewarmPriority``. Lower values run
/// first when a host prewarms the first windows of several sources within one
/// time budget.
public enum WindowedRowsPrewarmPriority {
    /// Sources likely to be the user's first selection. Run first.
    public static let firstPaint = 0
    /// Between the first-paint and secondary tiers.
    public static let standard = 5
    /// Large sources unlikely to be the first selection. They run after the
    /// first-paint tier, so a limited budget goes to the more visible sources
    /// first.
    public static let secondary = 10
}

/// How a ``ViewportCache`` and a ``WindowedRowsController`` divide a source into
/// windows and how they pace the work a scroll or a keystroke causes.
public struct ViewportWindowingPolicy: Sendable, Equatable {
    /// Rows per window: the unit the cache fetches and evicts. Default 256.
    public var windowSize: Int

    /// The most windows the cache keeps resident. Default 4.
    public var maxResidentWindows: Int

    /// When `true`, the cache also fetches the window before and the window
    /// after the visible range, in the background.
    public var prefetchNeighbors: Bool

    /// The most rows on each side of the centre row that
    /// ``ViewportCache/prewarmSynchronous(centerRow:radius:)`` fetches on the
    /// main thread; a larger radius is capped to it. Default 64.
    public var prewarmSynchronousMaxRadius: Int

    /// The window, in milliseconds, in which a burst of visible-range reports is
    /// merged into one. Default 16 ms, one frame at 60 Hz. `0` forwards every
    /// report as it comes.
    public var scrollCoalesceMillis: Int

    /// How long, in milliseconds, a search keyword must stay unchanged before a
    /// search starts. Every keyword starts a scan of the whole source, so without
    /// it typing "hello" into a million-row table starts five scans. Default
    /// 200 ms. `0` applies every keyword at once. Clearing the keyword always
    /// applies at once.
    public var searchDebounceMillis: Int

    public init(
        windowSize: Int = 256,
        maxResidentWindows: Int = 4,
        prefetchNeighbors: Bool = true,
        prewarmSynchronousMaxRadius: Int = 64,
        scrollCoalesceMillis: Int = 16,
        searchDebounceMillis: Int = 200
    ) {
        self.windowSize = windowSize
        self.maxResidentWindows = maxResidentWindows
        self.prefetchNeighbors = prefetchNeighbors
        self.prewarmSynchronousMaxRadius = prewarmSynchronousMaxRadius
        self.scrollCoalesceMillis = scrollCoalesceMillis
        self.searchDebounceMillis = searchDebounceMillis
    }

    public static let `default` = ViewportWindowingPolicy()
}
