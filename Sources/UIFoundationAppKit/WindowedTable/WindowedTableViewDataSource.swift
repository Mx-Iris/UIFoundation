#if canImport(AppKit) && !targetEnvironment(macCatalyst)

import AppKit
import UIFoundationWindowedRows

/// Shows the rows of a ``WindowedRowsController`` in a view-based
/// `NSTableView`: the table's data source, its scroll reporting, and its find
/// bar.
///
/// Created with the table, it becomes the table's data source and watches the
/// table's scroll view: the visible rows go to the controller as you scroll,
/// and dragging the scroll bar's knob holds every fetch until the drag ends.
/// The table's delegate still makes the cells — read the row with
/// ``WindowedRowsController/row(atDisplayedRow:)``, which is the controller's
/// placeholder until the row's window arrives.
///
/// The controller's events are the table's to perform. Pass them to
/// ``handle(_:)``, which reloads rows, forwards visible ranges and settles the
/// rows in view; a host with more to do on an event performs the rest itself:
///
/// ```swift
/// controller.onEvent = { [weak dataSource] event in dataSource?.handle(event) }
/// ```
///
/// The find bar searches every displayed row, not just the loaded ones: when it
/// needs its index, a ``WindowedFindIndexScanner`` builds it in the background
/// from the strings ``searchableColumns`` gives. Use ``textFinderClient`` for
/// find actions, never its `textFinder` directly.
///
/// The table must already sit in its scroll view: the find bar and the scroll
/// reporting attach to it here.
@available(macOS 12.0, *)
@MainActor
public final class WindowedTableViewDataSource<Row: Sendable>: NSObject, NSTableViewDataSource, @MainActor TableViewTextFinderDataSource {
    /// The table this data source fills.
    public private(set) weak var tableView: NSTableView?

    /// The controller whose rows the table shows. While it is `nil` the table
    /// shows no rows and reports nothing, which lets a host that shows other
    /// content in the same table turn the data source off.
    public var controller: WindowedRowsController<Row>? {
        didSet {
            guard controller !== oldValue else { return }
            invalidateFindIndex()
        }
    }

    /// The find bar client of the table. Send find actions through its
    /// `performTextFinderAction(_:)`.
    public let textFinderClient: TableViewTextFinderClient

    /// The strings the find bar searches, asked for whenever a scan starts so it
    /// sees the current state. `nil`, or returning `nil`, leaves the find bar
    /// with nothing to search.
    public var searchableColumns: (@MainActor () -> WindowedFindIndexColumns<Row>?)?

    /// The label in a cell that the find bar highlights a match in, for a
    /// displayed row and column, if the delegate makes such cells.
    public var textFieldForCell: (@MainActor (_ row: Int, _ column: Int) -> NSTextField?)?

    /// Builds the find index; set its progress bar's look here.
    public let findIndexScanner = WindowedFindIndexScanner()

    public init(tableView: NSTableView, controller: WindowedRowsController<Row>? = nil) {
        self.tableView = tableView
        self.controller = controller
        self.textFinderClient = TableViewTextFinderClient(tableView: tableView)
        super.init()
        tableView.dataSource = self
        textFinderClient.dataSource = self
        observeScrolling(of: tableView)
    }

    // MARK: - Events

    /// Performs a controller event on the table.
    ///
    /// Reloads all rows, or the rows of a window that arrived; forwards a
    /// visible range or settles the rows around a centre in the controller's
    /// cache; scrolls to a row. A full reload also drops the find index, which
    /// is rebuilt when the find bar next needs it — at once if it is open.
    public func handle(_ event: WindowedRowsController<Row>.Event) {
        guard let tableView else { return }
        switch event {
        case .reloadAllRows:
            tableView.reloadData()
            invalidateFindIndex()
        case .reloadRows(let rowIndexes):
            tableView.reloadData(forRowIndexes: rowIndexes, columnIndexes: IndexSet(integersIn: 0 ..< tableView.numberOfColumns))
        case .forwardVisibleRange(let range):
            controller?.installedCache?.reportVisibleRange(range)
        case .settle(let centerRow, let radius), .prewarm(let centerRow, let radius):
            controller?.installedCache?.prewarmSynchronous(centerRow: centerRow, radius: radius)
        case .scrollToRow(let rowIndex):
            tableView.scrollRowToVisible(rowIndex)
            controller?.installedCache?.requestPrefetch(around: rowIndex)
        case .cacheDidClear, .cacheDidInstall, .windowDidLoad, .searchDidChange, .searchProgressDidUpdate,
             .loadingIndicatorVisibilityDidChange, .dragDidBegin, .dragDidEnd:
            break
        }
    }

    // MARK: - Find Bar

    /// Drops the find index after the displayed strings changed — a reload, a
    /// new search keyword, a different way of formatting a column. A scan in
    /// flight is cancelled; with the find bar open, a new one starts at once.
    public func invalidateFindIndex() {
        findIndexScanner.cancel()
        textFinderClient.invalidateIndex()
    }

    private func startFindIndexScan() {
        guard let controller,
              let displayedRows = controller.makeDisplayedRows(),
              let columns = searchableColumns?() else {
            // Nothing to search: an empty index, so the find bar finds nothing
            // instead of waiting for one.
            findIndexScanner.cancel()
            textFinderClient.installExternalIndex(TextFinderExternalIndex(numberOfColumns: 1))
            return
        }
        findIndexScanner.start(rows: displayedRows, columns: columns, showingProgressOver: tableView?.enclosingScrollView) { [weak self] index in
            self?.textFinderClient.installExternalIndex(index)
        }
    }

    // MARK: - Scroll Reporting

    private func observeScrolling(of tableView: NSTableView) {
        guard let scrollView = tableView.enclosingScrollView else { return }
        scrollView.contentView.postsBoundsChangedNotifications = true
        let center = NotificationCenter.default
        center.addObserver(self, selector: #selector(clipViewBoundsDidChange(_:)), name: NSView.boundsDidChangeNotification, object: scrollView.contentView)
        center.addObserver(self, selector: #selector(scrollViewWillStartLiveScroll(_:)), name: NSScrollView.willStartLiveScrollNotification, object: scrollView)
        center.addObserver(self, selector: #selector(scrollViewDidEndLiveScroll(_:)), name: NSScrollView.didEndLiveScrollNotification, object: scrollView)
    }

    @objc private func clipViewBoundsDidChange(_ notification: Notification) {
        reportVisibleRows()
    }

    /// Reports the rows in view to the controller. A host calls it after it
    /// changed the table's frame or rows itself, when no scroll posted a
    /// notification.
    public func reportVisibleRows() {
        guard let tableView, let controller, controller.installedCache != nil else { return }
        let visibleRows = tableView.rows(in: tableView.visibleRect)
        guard visibleRows.length > 0 else { return }
        let lowerBound = max(0, visibleRows.location)
        let upperBound = min(controller.numberOfDisplayedRows, visibleRows.location + visibleRows.length)
        guard lowerBound < upperBound else { return }
        controller.reportVisibleRange(lowerBound ..< upperBound)
    }

    @objc private func scrollViewWillStartLiveScroll(_ notification: Notification) {
        controller?.userDidBeginDragging()
    }

    @objc private func scrollViewDidEndLiveScroll(_ notification: Notification) {
        controller?.userDidEndDragging()
    }

    // MARK: - NSTableViewDataSource

    public func numberOfRows(in tableView: NSTableView) -> Int {
        controller?.numberOfDisplayedRows ?? 0
    }

    // MARK: - TableViewTextFinderDataSource

    public func numberOfSearchableColumns(in client: TableViewTextFinderClient) -> Int {
        searchableColumns?()?.count ?? 0
    }

    public func textFinderClient(_ client: TableViewTextFinderClient, stringForRow row: Int, column: Int) -> String? {
        // The index is built externally; the client never walks the rows.
        nil
    }

    public func textFinderClient(_ client: TableViewTextFinderClient, textFieldForRow row: Int, column: Int) -> NSTextField? {
        textFieldForCell?(row, column)
    }

    public func textFinderClientBuildsIndexExternally(_ client: TableViewTextFinderClient) -> Bool {
        true
    }

    public func textFinderClientNeedsExternalIndexRebuild(_ client: TableViewTextFinderClient) {
        startFindIndexScan()
    }
}

#endif
