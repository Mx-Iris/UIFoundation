#if canImport(AppKit) && !targetEnvironment(macCatalyst)

import AppKit
import WindowedRowsToolbox

/// The strings the find bar searches in each row of a windowed table: how many
/// columns, and how to write a row's strings into them.
///
/// `fill` runs on a background task for every displayed row, so it must only
/// read what it captured. Write exactly the strings the cells show — the find
/// bar highlights matches in the cells, so a string that differs from the cell
/// puts the highlight in the wrong place.
public struct WindowedFindIndexColumns<Row: Sendable>: Sendable {
    /// The number of searchable columns.
    public let count: Int

    /// Writes a row's strings into `columnStrings`, which always holds `count`
    /// entries. The buffer is reused from row to row, so every entry must be
    /// written.
    public let fill: @Sendable (_ row: Row, _ columnStrings: inout [String]) -> Void

    /// `count` must be at least 1: a find index needs a column.
    public init(count: Int, fill: @escaping @Sendable (_ row: Row, _ columnStrings: inout [String]) -> Void) {
        precondition(count > 0, "WindowedFindIndexColumns needs at least one column")
        self.count = count
        self.fill = fill
    }
}

/// Builds the find bar's index for a windowed table on a background task, with
/// a thin progress bar along the bottom of the find bar while it runs.
///
/// A windowed table holds only the rows around the visible ones, so the find
/// bar cannot read the rest from the table. The scanner reads every displayed
/// row straight from the source — never through the viewport cache, which
/// would miss on every row and evict the windows the table shows — and writes
/// their strings into a ``TextFinderExternalIndex``, which a
/// ``TableViewTextFinderClient`` or ``OutlineViewTextFinderClient`` then
/// installs.
///
/// One scan runs at a time: starting a scan, or cancelling, drops the one in
/// flight, whose result is never delivered.
@available(macOS 12.0, *)
@MainActor
public final class WindowedFindIndexScanner {
    /// The height of the progress bar.
    public var progressBarHeight: CGFloat = 2

    /// The colour of the progress bar's fill.
    public var progressBarColor: NSColor = .controlAccentColor {
        didSet { progressView.fillColor = progressBarColor }
    }

    /// Whether a scan is running.
    public private(set) var isScanning = false

    private var scanTask: Task<Void, Never>?
    private var scanGeneration: UInt = 0
    private weak var progressScrollView: NSScrollView?
    private lazy var progressView = WindowedFindIndexProgressView(fillColor: progressBarColor)

    /// The scan in flight, or `nil`. Await its value to wait for the index; a
    /// scan that is cancelled or replaced ends without delivering one.
    public var runningScan: Task<Void, Never>? { scanTask }

    public init() {}

    /// Scans the displayed rows and calls `completion` with their index on the
    /// main actor, unless another scan starts or ``cancel()`` is called first.
    ///
    /// The progress bar appears along the bottom of `scrollView`'s find bar. The
    /// find bar exists only once it has been shown, so a scan started just before
    /// the find bar opens attaches the bar on its next progress report.
    public func start<Row: Sendable>(
        rows displayedRows: WindowedDisplayedRows<Row>,
        columns: WindowedFindIndexColumns<Row>,
        showingProgressOver scrollView: NSScrollView?,
        completion: @escaping @MainActor (TextFinderExternalIndex) -> Void
    ) {
        cancel()
        let generation = scanGeneration
        let displayedRowCount = displayedRows.count
        guard displayedRowCount > 0 else {
            completion(TextFinderExternalIndex(numberOfColumns: columns.count))
            return
        }

        isScanning = true
        progressScrollView = scrollView
        progressView.progress = 0
        attachProgressViewIfNeeded()

        let chunkRowCount = 512
        let progressInterval: TimeInterval = 0.1
        let scanStart = ProcessInfo.processInfo.systemUptime
        scanTask = Task.detached(priority: .userInitiated) { [weak self] in
            var externalIndex = TextFinderExternalIndex(
                numberOfColumns: columns.count,
                estimatedRowCount: displayedRowCount
            )
            var columnStrings = [String](repeating: "", count: columns.count)
            var lastProgressReport = scanStart
            var displayedIndex = 0
            while displayedIndex < displayedRowCount {
                // A scanner that is gone has nobody to deliver to.
                if Task.isCancelled || self == nil { return }
                let chunkUpperBound = min(displayedIndex + chunkRowCount, displayedRowCount)
                for row in displayedRows.rows(in: displayedIndex ..< chunkUpperBound) {
                    columns.fill(row, &columnStrings)
                    externalIndex.appendRow(columnStrings: columnStrings)
                }
                displayedIndex = chunkUpperBound

                let now = ProcessInfo.processInfo.systemUptime
                if now - lastProgressReport > progressInterval {
                    lastProgressReport = now
                    let progress = Double(displayedIndex) / Double(displayedRowCount)
                    Task { @MainActor [weak self] in
                        guard let self, self.scanGeneration == generation else { return }
                        self.attachProgressViewIfNeeded()
                        self.progressView.progress = progress
                    }
                }
                await Task.yield()
            }

            let finishedIndex = externalIndex
            await MainActor.run { [weak self] in
                guard let self, self.scanGeneration == generation else { return }
                self.scanTask = nil
                self.isScanning = false
                self.progressView.removeFromSuperview()
                completion(finishedIndex)
            }
        }
    }

    /// Stops the running scan; its result is dropped.
    public func cancel() {
        scanGeneration &+= 1
        scanTask?.cancel()
        scanTask = nil
        isScanning = false
        progressView.removeFromSuperview()
    }

    /// Puts the progress bar along the find bar's bottom edge. `NSScrollView`
    /// lays the find bar out by frame, so the bar follows its width through its
    /// autoresizing mask rather than constraints.
    private func attachProgressViewIfNeeded() {
        guard let findBarView = progressScrollView?.findBarView else { return }
        guard progressView.superview !== findBarView else { return }
        let yPosition = findBarView.isFlipped ? findBarView.bounds.height - progressBarHeight : 0
        progressView.frame = CGRect(x: 0, y: yPosition, width: findBarView.bounds.width, height: progressBarHeight)
        progressView.autoresizingMask = findBarView.isFlipped ? [.width, .minYMargin] : [.width, .maxYMargin]
        findBarView.addSubview(progressView)
    }
}

/// A thin determinate progress bar: a transparent track whose fill grows with
/// `progress`.
///
/// The fill's colour is set only in `updateLayer`, resolved under
/// `performAsCurrentDrawingAppearance`: `updateLayer` can run outside the
/// display cycle, where no appearance is current, and a dynamic colour would
/// resolve against the wrong one.
@MainActor
final class WindowedFindIndexProgressView: NSView {
    /// Completion between 0 and 1; the fill's width follows it.
    var progress: Double = 0 {
        didSet {
            progress = min(max(progress, 0), 1)
            needsLayout = true
        }
    }

    var fillColor: NSColor {
        get { fillView.fillColor }
        set { fillView.fillColor = newValue }
    }

    private final class FillView: NSView {
        var fillColor: NSColor {
            didSet { needsDisplay = true }
        }

        init(fillColor: NSColor) {
            self.fillColor = fillColor
            super.init(frame: .zero)
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        override var wantsUpdateLayer: Bool { true }

        override func updateLayer() {
            effectiveAppearance.performAsCurrentDrawingAppearance {
                layer?.backgroundColor = fillColor.cgColor
            }
        }

        override func viewDidChangeEffectiveAppearance() {
            super.viewDidChangeEffectiveAppearance()
            needsDisplay = true
        }
    }

    private let fillView: FillView

    init(fillColor: NSColor) {
        fillView = FillView(fillColor: fillColor)
        super.init(frame: .zero)
        wantsLayer = true
        fillView.wantsLayer = true
        addSubview(fillView)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// The fill's current width, for tests.
    var fillWidth: CGFloat { fillView.frame.width }

    override func layout() {
        super.layout()
        fillView.frame = CGRect(x: 0, y: 0, width: bounds.width * CGFloat(progress), height: bounds.height)
    }

    override func resize(withOldSuperviewSize oldSize: NSSize) {
        super.resize(withOldSuperviewSize: oldSize)
        needsLayout = true
    }
}

#endif
