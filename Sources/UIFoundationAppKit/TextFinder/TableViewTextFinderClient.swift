#if canImport(AppKit) && !targetEnvironment(macCatalyst)

import AppKit

@available(macOS 12.0, *)
open class TableViewTextFinderClient: NSObject, NSTextFinderClient {

    // MARK: - Properties

    public weak var tableView: NSTableView?

    public weak var dataSource: TableViewTextFinderDataSource? {
        didSet { rebuildIndex() }
    }

    public let textFinder = NSTextFinder()

    let indexStore = TextIndexStore()

    // MARK: - TextKit 2 Stack (shared, reused for highlight rect calculation)

    let textContentStorage = NSTextContentStorage()
    let textLayoutManager = NSTextLayoutManager()
    let textContainer = NSTextContainer()

    // MARK: - State

    /// The range of the currently selected match. NSTextFinder reads this via
    /// `firstSelectedRange` and starts Find Next searches from `NSMaxRange(currentMatchRange)`.
    /// Updated in `scrollRangeToVisible(_:)` whenever NSTextFinder navigates to a match.
    var currentMatchRange: NSRange = NSRange(location: 0, length: 0)

    // MARK: - Background Indexing

    private let indexingQueue = DispatchQueue(label: "com.uifoundation.textfinder.table.indexing", qos: .userInitiated)

    /// Monotonically increasing counter used to cancel stale background work.
    /// Only written on the main thread; read from the background queue to detect cancellation.
    private var indexingGeneration: UInt = 0

    // MARK: - Initialization

    public init(tableView: NSTableView) {
        self.tableView = tableView
        super.init()
        textFinder.client = self
        textFinder.findBarContainer = tableView.enclosingScrollView
        setupTextKit()
        rebuildIndex()
    }

    private func setupTextKit() {
        textLayoutManager.textContainer = textContainer
        textContentStorage.addTextLayoutManager(textLayoutManager)
        textContentStorage.primaryTextLayoutManager = textLayoutManager
        textContainer.lineFragmentPadding = 2
    }

    // MARK: - Index Management

    /// Rebuild the entire index from scratch. Call after data changes.
    public func invalidateIndex() {
        rebuildIndex()
    }

    func rebuildIndex() {
        // Bump generation so any in-flight background work is discarded.
        indexingGeneration &+= 1
        let generation = indexingGeneration

        // Clear immediately so NSTextFinder sees an empty string while
        // the background index is being built.
        textFinder.noteClientStringWillChange()
        indexStore.removeAll()
        currentMatchRange = NSRange(location: 0, length: 0)

        guard let tableView, let dataSource else { return }
        let numberOfColumns = dataSource.numberOfSearchableColumns(in: self)
        let numberOfRows = tableView.numberOfRows
        guard numberOfRows > 0, numberOfColumns > 0 else { return }

        indexingQueue.async { [weak self, weak dataSource] in
            guard let self, let dataSource else { return }

            var tokenStrings: [(row: Int, column: Int, string: String)] = []
            tokenStrings.reserveCapacity(numberOfRows * numberOfColumns)

            for rowIndex in 0 ..< numberOfRows {
                // Check cancellation periodically
                guard self.indexingGeneration == generation else { return }
                for columnIndex in 0 ..< numberOfColumns {
                    let string = dataSource.textFinderClient(self, stringForRow: rowIndex, column: columnIndex) ?? ""
                    tokenStrings.append((rowIndex, columnIndex, string))
                }
            }

            guard self.indexingGeneration == generation else { return }

            DispatchQueue.main.async { [weak self] in
                guard let self, self.indexingGeneration == generation else { return }
                self.textFinder.noteClientStringWillChange()
                self.indexStore.removeAll()
                for tokenString in tokenStrings {
                    self.indexStore.appendToken(
                        row: tokenString.row,
                        column: tokenString.column,
                        string: tokenString.string
                    )
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
        guard currentMatchRange.location <= indexStore.totalLength,
              NSMaxRange(currentMatchRange) <= indexStore.totalLength else {
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
        let token = indexStore.token(at: range.location)
        tableView.scrollRowToVisible(token.row)
    }

    public func contentView(at index: Int, effectiveCharacterRange outRange: NSRangePointer) -> NSView {
        let token = indexStore.token(at: index)
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
