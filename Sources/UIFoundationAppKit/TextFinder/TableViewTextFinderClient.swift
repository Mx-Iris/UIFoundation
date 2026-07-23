#if canImport(AppKit) && !targetEnvironment(macCatalyst)

import AppKit

@available(macOS 12.0, *)
open class TableViewTextFinderClient: NSObject, NSTextFinderClient {

    // MARK: - Properties

    public weak var tableView: NSTableView?

    public weak var dataSource: TableViewTextFinderDataSource? {
        didSet { invalidateIndex() }
    }

    public let textFinder = NSTextFinder()

    /// Active index storage. Materialized per-cell tokens by default; a
    /// run-length compressed layout when the data source implements
    /// `textFinderClient(_:searchStringLengthsForRow:)`.
    var indexStorage: any TextFinderIndexStorage = TextIndexStore()

    // MARK: - TextKit 2 Stack (shared, reused for highlight rect calculation)

    let textContentStorage = NSTextContentStorage()
    let textLayoutManager = NSTextLayoutManager()
    let textContainer = NSTextContainer()

    // MARK: - State

    /// The range of the currently selected match. NSTextFinder reads this via
    /// `firstSelectedRange` and starts Find Next searches from `NSMaxRange(currentMatchRange)`.
    /// Updated in `scrollRangeToVisible(_:)` whenever NSTextFinder navigates to a match.
    var currentMatchRange: NSRange = NSRange(location: 0, length: 0)

    // MARK: - Incremental Indexing

    /// Number of rows whose strings are gathered per main-actor chunk before
    /// yielding back to the run loop (materialized path).
    private static let materializedIndexingChunkRowCount = 2048

    /// Number of rows whose search-string lengths are gathered per main-actor
    /// chunk (run-length path). Much larger than the materialized chunk size
    /// because length callbacks are O(1) with no string work.
    private static let lengthsIndexingChunkRowCount = 65536

    /// Single-slot cancel-replace task that gathers cell strings on the main
    /// actor in fixed-size chunks.
    private var indexingTask: Task<Void, Never>?

    /// Testing seam — lets tests await completion of the in-flight chunked
    /// indexing pass.
    var indexingTaskForTesting: Task<Void, Never>? { indexingTask }

    /// Monotonically increasing counter used to discard stale indexing work.
    /// Accessed only on the main thread.
    private var indexingGeneration: UInt = 0

    /// `true` while the index no longer reflects the table content. Set by
    /// `invalidateIndex()`, cleared when a rebuild is kicked off. The rebuild
    /// itself is deferred until the next find interaction so that consumers
    /// who never use the find bar never pay for index construction.
    private(set) var indexIsDirty = true

    // MARK: - Initialization

    public init(tableView: NSTableView) {
        self.tableView = tableView
        super.init()
        textFinder.client = self
        textFinder.findBarContainer = tableView.enclosingScrollView
        setupTextKit()
    }

    private func setupTextKit() {
        textLayoutManager.textContainer = textContainer
        textContentStorage.addTextLayoutManager(textLayoutManager)
        textContentStorage.primaryTextLayoutManager = textLayoutManager
        textContainer.lineFragmentPadding = 2
    }

    // MARK: - Index Management

    /// Mark the index stale after a data change. The expensive rebuild is
    /// deferred until the next find interaction (`performTextFinderAction(_:)`
    /// or `prepareIndexIfNeeded()`) — except when the find bar is currently
    /// visible, in which case the index rebuilds immediately so on-screen
    /// search results stay live.
    public func invalidateIndex() {
        // Bump generation so any in-flight indexing task discards its results.
        indexingGeneration &+= 1
        indexingTask?.cancel()
        indexingTask = nil

        // Clear immediately so NSTextFinder sees an empty string until the
        // next rebuild lands.
        textFinder.noteClientStringWillChange()
        indexStorage = TextIndexStore()
        currentMatchRange = NSRange(location: 0, length: 0)
        indexIsDirty = true

        if let findBarContainer = textFinder.findBarContainer, findBarContainer.isFindBarVisible {
            rebuildIndex()
        }
    }

    /// Rebuild the index now if it is stale. Called automatically by
    /// `performTextFinderAction(_:)`; exposed for hosts that drive
    /// `textFinder` directly.
    public func prepareIndexIfNeeded() {
        guard indexIsDirty else { return }
        rebuildIndex()
    }

    /// Forward a find action to the underlying `NSTextFinder`, rebuilding the
    /// lazily invalidated index first. Prefer this over calling
    /// `textFinder.performAction(_:)` directly — the direct call skips the
    /// lazy rebuild and may search a stale (empty) document.
    public func performTextFinderAction(_ action: NSTextFinder.Action) {
        prepareIndexIfNeeded()
        textFinder.performAction(action)
    }

    func rebuildIndex() {
        // Bump generation so any in-flight indexing task discards its results.
        indexingGeneration &+= 1
        let generation = indexingGeneration
        indexingTask?.cancel()
        indexIsDirty = false

        // Clear immediately so NSTextFinder sees an empty string while
        // the chunked index is being rebuilt.
        textFinder.noteClientStringWillChange()
        indexStorage = TextIndexStore()
        currentMatchRange = NSRange(location: 0, length: 0)

        guard let tableView, let dataSource else { return }
        let numberOfColumns = dataSource.numberOfSearchableColumns(in: self)
        let numberOfRows = tableView.numberOfRows
        guard numberOfRows > 0, numberOfColumns > 0 else { return }

        // All data-source callbacks must stay on the main thread: consumers
        // implement them on main-isolated view models, and calling them from
        // a background queue raced with main-thread access to that same state
        // (torn reads/writes of cached display strings produced over-released
        // String storage that crashed later when the index store released its
        // tokens). Yielding between fixed-size chunks keeps large tables from
        // stalling the run loop.
        indexingTask = Task { @MainActor [weak self] in
            // Fast path: run-length index built from data-source-provided
            // string lengths — no cell strings are materialized. A `nil` from
            // any row opts out and falls back to the materialized build.
            var probedFirstRowLengths: [Int]?
            do {
                guard let self, !Task.isCancelled, self.indexingGeneration == generation else { return }
                probedFirstRowLengths = self.dataSource?.textFinderClient(self, searchStringLengthsForRow: 0)
            }

            var lengthsPathFailed = false
            if let firstRowLengths = probedFirstRowLengths, firstRowLengths.count == numberOfColumns {
                var runLengthBuilder = RunLengthTextIndexStore.Builder()
                runLengthBuilder.appendRow(columnLengths: firstRowLengths)

                var rowIndex = 1
                lengthsGatheringLoop: while rowIndex < numberOfRows {
                    guard let self, !Task.isCancelled, self.indexingGeneration == generation,
                          let dataSource = self.dataSource,
                          self.tableView?.numberOfRows == numberOfRows else { return }
                    let chunkUpperBound = min(rowIndex + Self.lengthsIndexingChunkRowCount, numberOfRows)
                    while rowIndex < chunkUpperBound {
                        guard let columnLengths = dataSource.textFinderClient(self, searchStringLengthsForRow: rowIndex),
                              columnLengths.count == numberOfColumns else {
                            lengthsPathFailed = true
                            break lengthsGatheringLoop
                        }
                        runLengthBuilder.appendRow(columnLengths: columnLengths)
                        rowIndex += 1
                    }
                    await Task.yield()
                }

                if !lengthsPathFailed {
                    guard let self, !Task.isCancelled, self.indexingGeneration == generation else { return }
                    let builtStorage = runLengthBuilder.build { [weak self] row, column in
                        guard let self else { return "" }
                        return self.resolveString(forRow: row, column: column)
                    }
                    self.finishRebuild(installing: builtStorage)
                    return
                }
            }

            var tokenStrings: [(row: Int, column: Int, string: String)] = []
            tokenStrings.reserveCapacity(numberOfRows * numberOfColumns)

            var rowIndex = 0
            while rowIndex < numberOfRows {
                guard let self, !Task.isCancelled, self.indexingGeneration == generation,
                      let dataSource = self.dataSource,
                      self.tableView?.numberOfRows == numberOfRows else { return }
                let chunkUpperBound = min(rowIndex + Self.materializedIndexingChunkRowCount, numberOfRows)
                while rowIndex < chunkUpperBound {
                    for columnIndex in 0 ..< numberOfColumns {
                        let string = dataSource.textFinderClient(self, stringForRow: rowIndex, column: columnIndex) ?? ""
                        tokenStrings.append((rowIndex, columnIndex, string))
                    }
                    rowIndex += 1
                }
                await Task.yield()
            }

            guard let self, !Task.isCancelled, self.indexingGeneration == generation else { return }
            let materializedStore = TextIndexStore()
            for tokenString in tokenStrings {
                materializedStore.appendToken(
                    row: tokenString.row,
                    column: tokenString.column,
                    string: tokenString.string
                )
            }
            self.finishRebuild(installing: materializedStore)
        }
    }

    /// Install a freshly built index and, if the find bar is visible,
    /// re-trigger the search so the user sees results immediately instead of
    /// a stale "Not Found".
    private func finishRebuild(installing storage: any TextFinderIndexStorage) {
        textFinder.noteClientStringWillChange()
        indexStorage = storage
        if indexStorage.totalLength > 0,
           let findBarContainer = textFinder.findBarContainer,
           findBarContainer.isFindBarVisible {
            textFinder.performAction(.nextMatch)
        }
    }

    /// Get the string for a cell: ask data source first, fall back to cell text field.
    func resolveString(forRow row: Int, column: Int) -> String {
        if let dataSource, let providedString = dataSource.textFinderClient(self, stringForRow: row, column: column) {
            return providedString
        }
        return extractCellString(row: row, column: column)
    }

    /// Extract text from the cell's textField as a fallback.
    func extractCellString(row: Int, column: Int) -> String {
        guard let tableView else { return "" }
        let cellView = tableView.view(atColumn: column, row: row, makeIfNecessary: false)
            ?? tableView.view(atColumn: column, row: row, makeIfNecessary: true)
        if let tableCellView = cellView as? NSTableCellView, let textField = tableCellView.textField {
            return textField.stringValue
        }
        return ""
    }

    // MARK: - NSTextFinderClient — Core

    public var allowsMultipleSelection: Bool { false }

    public var isEditable: Bool { false }

    public var isSelectable: Bool { false }

    public func string(at characterIndex: Int, effectiveRange outRange: NSRangePointer, endsWithSearchBoundary outFlag: UnsafeMutablePointer<ObjCBool>) -> String {
        let token = indexStorage.token(at: characterIndex)
        let range = NSRange(location: token.globalIndex, length: token.string.utf16.count)
        outRange.pointee = range
        outFlag.pointee = true
        return token.string
    }

    public func stringLength() -> Int {
        indexStorage.totalLength
    }

    public var firstSelectedRange: NSRange {
        guard currentMatchRange.location <= indexStorage.totalLength,
              NSMaxRange(currentMatchRange) <= indexStorage.totalLength else {
            return NSRange(location: 0, length: 0)
        }
        return currentMatchRange
    }

    // MARK: - NSTextFinderClient — Scrolling & Content View

    public func scrollRangeToVisible(_ range: NSRange) {
        // Remember the match so `firstSelectedRange` reflects NSTextFinder's
        // current position — this is what makes Find Next advance past the
        // current match instead of rematching it.
        currentMatchRange = range
        guard let tableView else { return }
        let token = indexStorage.token(at: range.location)
        tableView.scrollRowToVisible(token.row)
    }

    public func contentView(at index: Int, effectiveCharacterRange outRange: NSRangePointer) -> NSView {
        let token = indexStorage.token(at: index)
        outRange.pointee = NSRange(location: token.globalIndex, length: token.string.utf16.count)
        return resolveTextField(for: token) ?? NSView()
    }

    /// Get the NSTextField for a given token's cell.
    func resolveTextField(for token: TextIndexStore.Token) -> NSTextField? {
        guard let tableView else { return nil }
        if let providedTextField = dataSource?.textFinderClient(self, textFieldForRow: token.row, column: token.column) {
            return providedTextField
        }
        guard let cellView = tableView.view(atColumn: token.column, row: token.row, makeIfNecessary: false) as? NSTableCellView else {
            return nil
        }
        return cellView.textField
    }

    // MARK: - NSTextFinderClient — Highlight Rects

    public func rects(forCharacterRange range: NSRange) -> [NSValue]? {
        let token = indexStorage.token(at: range.location)
        let localLocation = range.location - token.globalIndex
        let localRange = NSRange(location: localLocation, length: range.length)
        guard let textField = resolveTextField(for: token) else { return nil }
        return computeHighlightRects(forLocalRange: localRange, in: textField)
    }

    public func drawCharacters(in range: NSRange, forContentView view: NSView) {
        let token = indexStorage.token(at: range.location)
        let localLocation = range.location - token.globalIndex
        let localRange = NSRange(location: localLocation, length: range.length)
        guard let textRange = makeTextRange(from: localRange),
              let graphicsContext = NSGraphicsContext.current?.cgContext else { return }
        if let layoutFragment = textLayoutManager.textLayoutFragment(for: textRange.location) {
            let origin = layoutFragment.layoutFragmentFrame.pixelAligned.origin
            layoutFragment.draw(at: origin, in: graphicsContext)
        }
    }

    // MARK: - TextKit 2 Helpers

    func computeHighlightRects(forLocalRange localRange: NSRange, in textField: NSTextField) -> [NSValue]? {
        guard let textFieldCell = textField.cell else { return nil }
        let textBounds = textFieldCell.titleRect(forBounds: textField.bounds)
        textContentStorage.attributedString = textField.attributedStringValue
        textContainer.containerSize = textBounds.size
        guard let textRange = makeTextRange(from: localRange) else { return nil }
        var rects: [NSValue] = []
        textLayoutManager.enumerateTextSegments(in: textRange, type: .standard) { _, segmentRect, _, _ in
            rects.append(NSValue(rect: segmentRect))
            return true
        }
        return rects
    }

    func makeTextRange(from nsRange: NSRange) -> NSTextRange? {
        guard let startLocation = textContentStorage.location(
            textContentStorage.documentRange.location,
            offsetBy: nsRange.location
        ) else { return nil }
        let endLocation = textContentStorage.location(startLocation, offsetBy: nsRange.length)
        return NSTextRange(location: startLocation, end: endLocation)
    }
}

#endif
