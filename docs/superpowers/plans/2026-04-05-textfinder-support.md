# NSTableView / NSOutlineView TextFinder Support — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Provide out-of-the-box NSTextFinder (Cmd+F) search support for NSTableView and NSOutlineView with precise in-cell text highlighting.

**Architecture:** A `TextIndexStore` maps a virtual contiguous string to (row, column) cell positions. `TableViewTextFinderClient` and `OutlineViewTextFinderClient` conform to `NSTextFinderClient`, using data source protocols for text content (with cell-extraction fallback) and TextKit 2 for glyph-level highlight rects.

**Tech Stack:** AppKit (NSTextFinder, NSTextFinderClient), TextKit 2 (NSTextContentStorage, NSTextLayoutManager), Swift 5 language mode, macOS 12+

---

## File Structure

| File | Responsibility |
|------|---------------|
| `Sources/UIFoundationAppKit/TextFinder/TextIndexStore.swift` | Token type, sorted token array, binary search lookup, build/rebuild/append |
| `Sources/UIFoundationAppKit/TextFinder/TableViewTextFinderDataSource.swift` | Protocol for table view searchable text data source |
| `Sources/UIFoundationAppKit/TextFinder/OutlineViewTextFinderDataSource.swift` | Protocol for outline view searchable text data source + search scope enum |
| `Sources/UIFoundationAppKit/TextFinder/TableViewTextFinderClient.swift` | NSTextFinderClient for NSTableView, owns TextIndexStore + NSTextFinder + TextKit 2 stack |
| `Sources/UIFoundationAppKit/TextFinder/OutlineViewTextFinderClient.swift` | NSTextFinderClient for NSOutlineView, adds on-demand indexing + auto-expand |

---

### Task 1: TextIndexStore — Token and Core Data Structure

**Files:**
- Create: `Sources/UIFoundationAppKit/TextFinder/TextIndexStore.swift`

- [ ] **Step 1: Create the TextIndexStore file with Token struct and core storage**

```swift
#if canImport(AppKit) && !targetEnvironment(macCatalyst)

import AppKit

@available(macOS 12.0, *)
class TextIndexStore {

    struct Token {
        let row: Int
        let column: Int
        let globalIndex: Int
        let string: String
        let item: AnyObject?
    }

    /// Boundary separator length between tokens.
    /// Prevents matches from spanning across cells.
    static let separatorLength: Int = 1

    private(set) var tokens: [Token] = []
    private(set) var totalLength: Int = 0

    /// Look up the token containing the given character index.
    /// Uses binary search for O(log n) performance.
    func token(at characterIndex: Int) -> Token {
        precondition(!tokens.isEmpty, "TextIndexStore is empty")
        var lowerBound = 0
        var upperBound = tokens.count - 1
        while lowerBound < upperBound {
            let middleIndex = lowerBound + (upperBound - lowerBound + 1) / 2
            if tokens[middleIndex].globalIndex <= characterIndex {
                lowerBound = middleIndex
            } else {
                upperBound = middleIndex - 1
            }
        }
        return tokens[lowerBound]
    }

    /// Remove all tokens and reset total length.
    func removeAll() {
        tokens.removeAll()
        totalLength = 0
    }

    /// Append a single token for the given row, column, string, and optional item.
    /// Automatically computes the globalIndex based on current totalLength.
    func appendToken(row: Int, column: Int, string: String, item: AnyObject? = nil) {
        let token = Token(
            row: row,
            column: column,
            globalIndex: totalLength,
            string: string,
            item: item
        )
        tokens.append(token)
        totalLength += string.utf16.count + TextIndexStore.separatorLength
    }
}

#endif
```

- [ ] **Step 2: Verify build compiles**

Run: `cd /Volumes/Repositories/Private/Personal/Library/Multi/UIFoundation && swift package update && swift build 2>&1 | xcsift`
Expected: Build succeeds with no errors.

- [ ] **Step 3: Commit**

```bash
git add Sources/UIFoundationAppKit/TextFinder/TextIndexStore.swift
git commit -m "feat(TextFinder): add TextIndexStore with Token and binary search lookup"
```

---

### Task 2: TableViewTextFinderDataSource Protocol

**Files:**
- Create: `Sources/UIFoundationAppKit/TextFinder/TableViewTextFinderDataSource.swift`

- [ ] **Step 1: Create the data source protocol file**

```swift
#if canImport(AppKit) && !targetEnvironment(macCatalyst)

import AppKit

@available(macOS 12.0, *)
public protocol TableViewTextFinderDataSource: AnyObject {
    /// Return the number of columns that should participate in text search.
    func numberOfSearchableColumns(in client: TableViewTextFinderClient) -> Int

    /// Return the searchable text for a given row and column.
    /// Return `nil` to fall back to extracting text from the cell's textField.
    func textFinderClient(_ client: TableViewTextFinderClient, stringForRow row: Int, column: Int) -> String?
}

#endif
```

- [ ] **Step 2: Verify build compiles**

Run: `cd /Volumes/Repositories/Private/Personal/Library/Multi/UIFoundation && swift build 2>&1 | xcsift`
Expected: Build succeeds.

- [ ] **Step 3: Commit**

```bash
git add Sources/UIFoundationAppKit/TextFinder/TableViewTextFinderDataSource.swift
git commit -m "feat(TextFinder): add TableViewTextFinderDataSource protocol"
```

---

### Task 3: OutlineViewTextFinderDataSource Protocol and SearchScope Enum

**Files:**
- Create: `Sources/UIFoundationAppKit/TextFinder/OutlineViewTextFinderDataSource.swift`

- [ ] **Step 1: Create the data source protocol and search scope enum**

```swift
#if canImport(AppKit) && !targetEnvironment(macCatalyst)

import AppKit

/// Controls how deeply the outline view text finder indexes the tree.
@available(macOS 12.0, *)
public enum OutlineViewSearchScope {
    /// Only index rows that are currently expanded/visible.
    case expandedOnly
    /// Start with expanded rows; progressively index collapsed subtrees
    /// when current matches are exhausted.
    case onDemand
    /// Index the entire tree upfront regardless of expand state.
    case all
}

@available(macOS 12.0, *)
public protocol OutlineViewTextFinderDataSource: AnyObject {
    /// Return the number of columns that should participate in text search.
    func numberOfSearchableColumns(in client: OutlineViewTextFinderClient) -> Int

    /// Return the searchable text for a given item and column.
    /// Return `nil` to fall back to extracting text from the cell's textField.
    func textFinderClient(_ client: OutlineViewTextFinderClient, stringForItem item: Any, column: Int) -> String?

    /// Return the child items for the given parent item (nil = root).
    /// Used for on-demand and full-tree indexing of collapsed nodes.
    /// Return `nil` if the item has no children.
    func textFinderClient(_ client: OutlineViewTextFinderClient, childItemsOfItem item: Any?) -> [Any]?
}

#endif
```

- [ ] **Step 2: Verify build compiles**

Run: `cd /Volumes/Repositories/Private/Personal/Library/Multi/UIFoundation && swift build 2>&1 | xcsift`
Expected: Build succeeds.

- [ ] **Step 3: Commit**

```bash
git add Sources/UIFoundationAppKit/TextFinder/OutlineViewTextFinderDataSource.swift
git commit -m "feat(TextFinder): add OutlineViewTextFinderDataSource protocol and OutlineViewSearchScope enum"
```

---

### Task 4: TableViewTextFinderClient — Core NSTextFinderClient Implementation

**Files:**
- Create: `Sources/UIFoundationAppKit/TextFinder/TableViewTextFinderClient.swift`

This is the largest task. The client owns the NSTextFinder, TextIndexStore, and TextKit 2 stack.

- [ ] **Step 1: Create TableViewTextFinderClient with initializer, properties, and index building**

```swift
#if canImport(AppKit) && !targetEnvironment(macCatalyst)

import AppKit

@available(macOS 12.0, *)
open class TableViewTextFinderClient: NSObject, NSTextFinderClient {

    // MARK: - Properties

    public weak var tableView: NSTableView?

    public weak var dataSource: TableViewTextFinderDataSource?

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

    open override var isSelectable: Bool { false }

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

// MARK: - CGRect pixel alignment helper

private extension CGRect {
    var pixelAligned: CGRect {
        NSIntegralRectWithOptions(self, .alignAllEdgesNearest)
    }
}

#endif
```

- [ ] **Step 2: Verify build compiles**

Run: `cd /Volumes/Repositories/Private/Personal/Library/Multi/UIFoundation && swift build 2>&1 | xcsift`
Expected: Build succeeds with no errors.

- [ ] **Step 3: Commit**

```bash
git add Sources/UIFoundationAppKit/TextFinder/TableViewTextFinderClient.swift
git commit -m "feat(TextFinder): add TableViewTextFinderClient with full NSTextFinderClient conformance"
```

---

### Task 5: OutlineViewTextFinderClient — NSTextFinderClient with On-Demand Indexing

**Files:**
- Create: `Sources/UIFoundationAppKit/TextFinder/OutlineViewTextFinderClient.swift`

- [ ] **Step 1: Create OutlineViewTextFinderClient**

```swift
#if canImport(AppKit) && !targetEnvironment(macCatalyst)

import AppKit

@available(macOS 12.0, *)
open class OutlineViewTextFinderClient: NSObject, NSTextFinderClient {

    // MARK: - Properties

    public weak var outlineView: NSOutlineView?

    public weak var dataSource: OutlineViewTextFinderDataSource?

    public let textFinder = NSTextFinder()

    let indexStore = TextIndexStore()

    public var searchScope: OutlineViewSearchScope

    // MARK: - TextKit 2 Stack

    let textContentStorage = NSTextContentStorage()
    let textLayoutManager = NSTextLayoutManager()
    let textContainer = NSTextContainer()

    // MARK: - State

    var currentSelectedLocation: Int = 0

    /// Tracks items whose subtrees have already been indexed (for onDemand mode).
    var indexedCollapsedItems: Set<ObjectIdentifier> = []

    /// Queue of collapsed items not yet indexed (for onDemand mode).
    var pendingCollapsedItems: [AnyObject] = []

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
        textFinder.noteClientStringWillChange()
        rebuildIndex()
    }

    func rebuildIndex() {
        indexStore.removeAll()
        indexedCollapsedItems.removeAll()
        pendingCollapsedItems.removeAll()
        guard let outlineView, let dataSource else { return }
        let numberOfColumns = dataSource.numberOfSearchableColumns(in: self)
        let numberOfRows = outlineView.numberOfRows

        for rowIndex in 0 ..< numberOfRows {
            let item = outlineView.item(atRow: rowIndex)
            indexRow(rowIndex, item: item, numberOfColumns: numberOfColumns)
        }

        if searchScope == .all {
            indexAllCollapsedSubtrees(numberOfColumns: numberOfColumns)
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
                item: item as AnyObject?
            )
        }

        // Track collapsed items with children for potential on-demand indexing
        if let item, outlineView.isExpandable(item), !outlineView.isItemExpanded(item) {
            if let itemObject = item as? AnyObject {
                pendingCollapsedItems.append(itemObject)
            }
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

        let itemIdentifier = ObjectIdentifier(nextItem)
        guard !indexedCollapsedItems.contains(itemIdentifier) else { return false }
        indexedCollapsedItems.insert(itemIdentifier)

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
                    item: child as AnyObject?
                )
            }

            // Recursively queue child's children if it has any
            if let grandchildren = dataSource.textFinderClient(self, childItemsOfItem: child), !grandchildren.isEmpty {
                if let childObject = child as? AnyObject {
                    pendingCollapsedItems.append(childObject)
                }
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

    open override var isSelectable: Bool { false }

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
            // Wrap around — try expanding the index first (on-demand)
            if searchScope == .onDemand && !pendingCollapsedItems.isEmpty {
                expandIndexOnDemand()
                // Re-check after expansion
                if location < indexStore.totalLength {
                    return NSRange(location: location, length: 0)
                }
            }
            location = 0
        }
        return NSRange(location: location, length: 0)
    }

    // MARK: - NSTextFinderClient — Scrolling & Content View

    public func scrollRangeToVisible(_ range: NSRange) {
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

// MARK: - CGRect pixel alignment helper

private extension CGRect {
    var pixelAligned: CGRect {
        NSIntegralRectWithOptions(self, .alignAllEdgesNearest)
    }
}

#endif
```

- [ ] **Step 2: Verify build compiles**

Run: `cd /Volumes/Repositories/Private/Personal/Library/Multi/UIFoundation && swift build 2>&1 | xcsift`
Expected: Build succeeds with no errors.

- [ ] **Step 3: Commit**

```bash
git add Sources/UIFoundationAppKit/TextFinder/OutlineViewTextFinderClient.swift
git commit -m "feat(TextFinder): add OutlineViewTextFinderClient with on-demand indexing and auto-expand"
```

---

### Task 6: Build Verification and Final Cleanup

**Files:**
- Possibly modify any files from Tasks 1–5 if build issues arise

- [ ] **Step 1: Full build verification**

Run: `cd /Volumes/Repositories/Private/Personal/Library/Multi/UIFoundation && swift package update && swift build 2>&1 | xcsift`
Expected: Build succeeds with zero errors.

- [ ] **Step 2: Check for warnings**

Run: `cd /Volumes/Repositories/Private/Personal/Library/Multi/UIFoundation && swift build 2>&1 | xcsift --print-warnings`
Expected: No new warnings introduced by our code.

- [ ] **Step 3: Run existing tests to ensure no regressions**

Run: `cd /Volumes/Repositories/Private/Personal/Library/Multi/UIFoundation && swift test 2>&1 | xcsift`
Expected: All existing tests pass.

- [ ] **Step 4: Verify file structure matches spec**

Run: `ls -la Sources/UIFoundationAppKit/TextFinder/`
Expected:
```
TextIndexStore.swift
TableViewTextFinderDataSource.swift
OutlineViewTextFinderDataSource.swift
TableViewTextFinderClient.swift
OutlineViewTextFinderClient.swift
```

- [ ] **Step 5: Final commit if any cleanup was needed**

Only if changes were made during verification:
```bash
git add -A Sources/UIFoundationAppKit/TextFinder/
git commit -m "fix(TextFinder): address build warnings and cleanup"
```
