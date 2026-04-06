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

    var currentSelectedLocation: Int = 0

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
        textFinder.noteClientStringWillChange()
        rebuildIndex()
    }

    func rebuildIndex() {
        indexStore.removeAll()
        guard let tableView, let dataSource else { return }
        let numberOfColumns = dataSource.numberOfSearchableColumns(in: self)
        let numberOfRows = tableView.numberOfRows
        for rowIndex in 0 ..< numberOfRows {
            for columnIndex in 0 ..< numberOfColumns {
                let cellString = resolveString(forRow: rowIndex, column: columnIndex)
                indexStore.appendToken(row: rowIndex, column: columnIndex, string: cellString)
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
        currentSelectedLocation = NSMaxRange(range)
        return token.string
    }

    public func stringLength() -> Int {
        indexStore.totalLength
    }

    public var firstSelectedRange: NSRange {
        var location = currentSelectedLocation + TextIndexStore.separatorLength
        if location >= indexStore.totalLength {
            location = 0
        }
        return NSRange(location: location, length: 0)
    }

    // MARK: - NSTextFinderClient — Scrolling & Content View

    public func scrollRangeToVisible(_ range: NSRange) {
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
