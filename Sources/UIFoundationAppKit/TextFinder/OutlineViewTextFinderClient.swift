#if canImport(AppKit) && !targetEnvironment(macCatalyst)

import AppKit

@available(macOS 12.0, *)
open class OutlineViewTextFinderClient: NSObject, NSTextFinderClient {

    // MARK: - Properties

    public weak var outlineView: NSOutlineView?

    public weak var dataSource: OutlineViewTextFinderDataSource? {
        didSet { rebuildIndex() }
    }

    public let textFinder = NSTextFinder()

    let indexStore = TextIndexStore()

    public var searchScope: OutlineViewSearchScope

    // MARK: - TextKit 2 Stack

    let textContentStorage = NSTextContentStorage()
    let textLayoutManager = NSTextLayoutManager()
    let textContainer = NSTextContainer()

    // MARK: - State

    /// The range of the currently selected match. NSTextFinder reads this via
    /// `firstSelectedRange` and starts Find Next searches from `NSMaxRange(currentMatchRange)`.
    /// Updated in `scrollRangeToVisible(_:)` whenever NSTextFinder navigates to a match.
    var currentMatchRange: NSRange = NSRange(location: 0, length: 0)

    /// Tracks items whose subtrees have already been indexed (for onDemand mode).
    var indexedCollapsedItems: Set<AnyHashable> = []

    /// Queue of collapsed items not yet indexed (for onDemand mode).
    var pendingCollapsedItems: [Any] = []

    // MARK: - Incremental Indexing

    /// Number of rows whose strings are gathered per main-actor chunk before
    /// yielding back to the run loop.
    private static let indexingChunkRowCount = 2048

    /// Single-slot cancel-replace task that gathers cell strings on the main
    /// actor in fixed-size chunks.
    private var indexingTask: Task<Void, Never>?

    /// Monotonically increasing counter used to discard stale indexing work.
    /// Accessed only on the main thread.
    private var indexingGeneration: UInt = 0

    // MARK: - Notifications

    private var expandObserver: NSObjectProtocol?
    private var collapseObserver: NSObjectProtocol?

    // MARK: - Initialization

    public init(outlineView: NSOutlineView, searchScope: OutlineViewSearchScope = .onDemand) {
        self.outlineView = outlineView
        self.searchScope = searchScope
        super.init()
        textFinder.client = self
        textFinder.findBarContainer = outlineView.enclosingScrollView
        setupTextKit()
        observeExpandCollapse()
        rebuildIndex()
    }

    deinit {
        if let expandObserver { NotificationCenter.default.removeObserver(expandObserver) }
        if let collapseObserver { NotificationCenter.default.removeObserver(collapseObserver) }
    }

    private func setupTextKit() {
        textLayoutManager.textContainer = textContainer
        textContentStorage.addTextLayoutManager(textLayoutManager)
        textContentStorage.primaryTextLayoutManager = textLayoutManager
        textContainer.lineFragmentPadding = 2
    }

    private func observeExpandCollapse() {
        guard let outlineView else { return }
        expandObserver = NotificationCenter.default.addObserver(
            forName: NSOutlineView.itemDidExpandNotification,
            object: outlineView,
            queue: .main
        ) { [weak self] _ in
            self?.invalidateIndex()
        }
        collapseObserver = NotificationCenter.default.addObserver(
            forName: NSOutlineView.itemDidCollapseNotification,
            object: outlineView,
            queue: .main
        ) { [weak self] _ in
            self?.invalidateIndex()
        }
    }

    // MARK: - Index Management

    public func invalidateIndex() {
        rebuildIndex()
    }

    func rebuildIndex() {
        // Bump generation so any in-flight indexing task discards its results.
        indexingGeneration &+= 1
        let generation = indexingGeneration
        indexingTask?.cancel()

        // Clear immediately so NSTextFinder sees an empty string while
        // the chunked index is being rebuilt.
        textFinder.noteClientStringWillChange()
        indexStore.removeAll()
        indexedCollapsedItems.removeAll()
        pendingCollapsedItems.removeAll()
        currentMatchRange = NSRange(location: 0, length: 0)

        guard let outlineView, let dataSource else { return }
        let numberOfColumns = dataSource.numberOfSearchableColumns(in: self)
        let numberOfRows = outlineView.numberOfRows
        guard numberOfRows > 0 else { return }

        let capturedSearchScope = searchScope

        // All data-source callbacks must stay on the main thread: consumers
        // implement them on main-isolated view models, and calling them from
        // a background queue raced with main-thread access to that same state
        // (torn reads/writes of cached display strings produced over-released
        // String storage that crashed later when the index store released its
        // tokens). Running on the main actor also lets item lookup and expand
        // state be read inline instead of through an up-front row snapshot;
        // yielding between fixed-size chunks keeps large trees from stalling
        // the run loop. Expand/collapse during a yield triggers
        // invalidateIndex via the notification observers, which bumps the
        // generation and discards this pass.
        indexingTask = Task { @MainActor [weak self] in
            struct TokenData {
                let row: Int
                let column: Int
                let string: String
                let item: Any?
            }

            var tokenData: [TokenData] = []
            tokenData.reserveCapacity(numberOfRows * numberOfColumns)
            var collapsedItems: [Any] = []

            var rowIndex = 0
            while rowIndex < numberOfRows {
                guard let self, !Task.isCancelled, self.indexingGeneration == generation,
                      let outlineView = self.outlineView, let dataSource = self.dataSource,
                      outlineView.numberOfRows == numberOfRows else { return }
                let chunkUpperBound = min(rowIndex + Self.indexingChunkRowCount, numberOfRows)
                while rowIndex < chunkUpperBound {
                    let item = outlineView.item(atRow: rowIndex)
                    for columnIndex in 0 ..< numberOfColumns {
                        let string: String
                        if let item,
                           let providedString = dataSource.textFinderClient(self, stringForItem: item, column: columnIndex) {
                            string = providedString
                        } else {
                            string = ""
                        }
                        tokenData.append(TokenData(row: rowIndex, column: columnIndex, string: string, item: item))
                    }
                    if let item, outlineView.isExpandable(item), !outlineView.isItemExpanded(item) {
                        collapsedItems.append(item)
                    }
                    rowIndex += 1
                }
                await Task.yield()
            }

            guard let self, !Task.isCancelled, self.indexingGeneration == generation else { return }
            self.textFinder.noteClientStringWillChange()
            self.indexStore.removeAll()
            for token in tokenData {
                self.indexStore.appendToken(
                    row: token.row,
                    column: token.column,
                    string: token.string,
                    item: token.item
                )
            }
            self.pendingCollapsedItems = collapsedItems

            if capturedSearchScope == .all {
                self.indexAllCollapsedSubtrees(numberOfColumns: numberOfColumns)
            }

            // If the find bar is visible, re-trigger search so the user
            // sees results immediately instead of a stale "Not Found".
            if self.indexStore.totalLength > 0,
               let findBarContainer = self.textFinder.findBarContainer,
               findBarContainer.isFindBarVisible {
                self.textFinder.performAction(.nextMatch)
            }
        }
    }

    func indexRow(_ row: Int, item: Any?, numberOfColumns: Int) {
        guard let outlineView else { return }
        for columnIndex in 0 ..< numberOfColumns {
            let cellString = resolveString(forItem: item, row: row, column: columnIndex)
            indexStore.appendToken(
                row: row,
                column: columnIndex,
                string: cellString,
                item: item
            )
        }

        // Track collapsed items with children for potential on-demand indexing
        if let item, outlineView.isExpandable(item), !outlineView.isItemExpanded(item) {
            pendingCollapsedItems.append(item)
        }
    }

    func indexAllCollapsedSubtrees(numberOfColumns: Int) {
        while !pendingCollapsedItems.isEmpty {
            indexNextCollapsedSubtree(numberOfColumns: numberOfColumns)
        }
    }

    /// Index the next collapsed subtree in the pending queue.
    /// Returns true if new tokens were added.
    @discardableResult
    func indexNextCollapsedSubtree(numberOfColumns: Int) -> Bool {
        guard let dataSource else { return false }
        guard let nextItem = pendingCollapsedItems.first else { return false }
        pendingCollapsedItems.removeFirst()

        if let itemIdentifier = hashableIdentifier(for: nextItem) {
            guard !indexedCollapsedItems.contains(itemIdentifier) else { return false }
            indexedCollapsedItems.insert(itemIdentifier)
        }

        guard let children = dataSource.textFinderClient(self, childItemsOfItem: nextItem) else { return false }
        let previousTokenCount = indexStore.tokens.count
        indexSubtreeChildren(children, numberOfColumns: numberOfColumns)
        return indexStore.tokens.count > previousTokenCount
    }

    private func indexSubtreeChildren(_ children: [Any], numberOfColumns: Int) {
        guard let dataSource, let outlineView else { return }
        for child in children {
            let childRow = outlineView.row(forItem: child)
            let effectiveRow = childRow >= 0 ? childRow : -1

            for columnIndex in 0 ..< numberOfColumns {
                let cellString = resolveString(forItem: child, row: effectiveRow, column: columnIndex)
                indexStore.appendToken(
                    row: effectiveRow,
                    column: columnIndex,
                    string: cellString,
                    item: child
                )
            }

            // Recursively queue child's children if it has any
            if let grandchildren = dataSource.textFinderClient(self, childItemsOfItem: child), !grandchildren.isEmpty {
                pendingCollapsedItems.append(child)
            }
        }
    }

    /// Resolve text for an item: data source first, then cell extraction fallback.
    func resolveString(forItem item: Any?, row: Int, column: Int) -> String {
        if let item, let dataSource,
           let providedString = dataSource.textFinderClient(self, stringForItem: item, column: column) {
            return providedString
        }
        guard row >= 0 else { return "" }
        return extractCellString(row: row, column: column)
    }

    func extractCellString(row: Int, column: Int) -> String {
        guard let outlineView else { return "" }
        let cellView = outlineView.view(atColumn: column, row: row, makeIfNecessary: false)
            ?? outlineView.view(atColumn: column, row: row, makeIfNecessary: true)
        if let tableCellView = cellView as? NSTableCellView, let textField = tableCellView.textField {
            return textField.stringValue
        }
        return ""
    }

    // MARK: - Item Identity

    /// Create a hashable identifier for an item.
    /// Reference types use ObjectIdentifier; Hashable value types use AnyHashable.
    private func hashableIdentifier(for item: Any) -> AnyHashable? {
        if type(of: item) is AnyClass {
            return ObjectIdentifier(item as AnyObject)
        }
        if let hashable = item as? AnyHashable {
            return hashable
        }
        return nil
    }

    // MARK: - On-Demand Indexing

    /// Attempt to expand the index when we've exhausted current matches.
    func expandIndexOnDemand() {
        guard searchScope == .onDemand, !pendingCollapsedItems.isEmpty, let dataSource else { return }
        let numberOfColumns = dataSource.numberOfSearchableColumns(in: self)
        textFinder.noteClientStringWillChange()
        indexNextCollapsedSubtree(numberOfColumns: numberOfColumns)
    }

    // MARK: - NSTextFinderClient — Core

    public var allowsMultipleSelection: Bool { false }

    public var isEditable: Bool { false }

    public var isSelectable: Bool { false }

    public func string(at characterIndex: Int, effectiveRange outRange: NSRangePointer, endsWithSearchBoundary outFlag: UnsafeMutablePointer<ObjCBool>) -> String {
        let token = indexStore.token(at: characterIndex)
        let range = NSRange(location: token.globalIndex, length: token.string.utf16.count)
        outRange.pointee = range
        outFlag.pointee = true
        return token.string
    }

    public func stringLength() -> Int {
        indexStore.totalLength
    }

    public var firstSelectedRange: NSRange {
        // If the saved match range is out of bounds (e.g. the index shrunk on
        // rebuild), fall back to the start of the document.
        guard currentMatchRange.location <= indexStore.totalLength,
              NSMaxRange(currentMatchRange) <= indexStore.totalLength else {
            // On-demand scope: try expanding first in case the position is
            // inside a yet-to-be-indexed subtree.
            if searchScope == .onDemand && !pendingCollapsedItems.isEmpty {
                expandIndexOnDemand()
                if currentMatchRange.location <= indexStore.totalLength,
                   NSMaxRange(currentMatchRange) <= indexStore.totalLength {
                    return currentMatchRange
                }
            }
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

        guard let outlineView else { return }
        let token = indexStore.token(at: range.location)
        // Expand parent chain if needed
        if let item = token.item {
            expandParentChain(for: item)
        }
        let resolvedRow = token.item.flatMap { outlineView.row(forItem: $0) } ?? token.row
        if resolvedRow >= 0 {
            outlineView.scrollRowToVisible(resolvedRow)
        }
    }

    public func contentView(at index: Int, effectiveCharacterRange outRange: NSRangePointer) -> NSView {
        let token = indexStore.token(at: index)
        outRange.pointee = NSRange(location: token.globalIndex, length: token.string.utf16.count)

        // Auto-expand parent chain so the cell becomes visible
        if let item = token.item {
            expandParentChain(for: item)
        }

        return resolveTextField(for: token) ?? NSView()
    }

    /// Expand all collapsed ancestors of the given item.
    func expandParentChain(for item: Any) {
        guard let outlineView else { return }
        var parentItem: Any? = outlineView.parent(forItem: item)
        while let parent = parentItem {
            if outlineView.isExpandable(parent) && !outlineView.isItemExpanded(parent) {
                outlineView.expandItem(parent)
            }
            parentItem = outlineView.parent(forItem: parent)
        }
    }

    func resolveTextField(for token: TextIndexStore.Token) -> NSTextField? {
        guard let outlineView else { return nil }
        let row: Int
        if let item = token.item {
            row = outlineView.row(forItem: item)
        } else {
            row = token.row
        }
        guard row >= 0 else { return nil }
        if let providedTextField = dataSource?.textFinderClient(self, textFieldForRow: row, column: token.column) {
            return providedTextField
        }
        guard let cellView = outlineView.view(atColumn: token.column, row: row, makeIfNecessary: false) as? NSTableCellView else {
            return nil
        }
        return cellView.textField
    }

    // MARK: - NSTextFinderClient — Highlight Rects

    public func rects(forCharacterRange range: NSRange) -> [NSValue]? {
        let token = indexStore.token(at: range.location)
        let localLocation = range.location - token.globalIndex
        let localRange = NSRange(location: localLocation, length: range.length)
        guard let textField = resolveTextField(for: token) else { return nil }
        return computeHighlightRects(forLocalRange: localRange, in: textField)
    }

    public func drawCharacters(in range: NSRange, forContentView view: NSView) {
        let token = indexStore.token(at: range.location)
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
