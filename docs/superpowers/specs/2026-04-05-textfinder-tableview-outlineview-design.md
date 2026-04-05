# NSTableView / NSOutlineView TextFinder Support

**Date:** 2026-04-05
**Module:** UIFoundationAppKit
**Status:** Approved

## Goal

Provide out-of-the-box NSTextFinder (Cmd+F find bar) support for NSTableView and NSOutlineView. The user creates a client object, assigns a data source, and search just works — including precise in-cell text highlighting via TextKit 2.

## Data Source Design

Two protocols allow callers to provide searchable text per row/column. When the data source returns `nil` for a cell, the client falls back to extracting `textField.stringValue` from the cell view.

### TableViewTextFinderDataSource

```swift
public protocol TableViewTextFinderDataSource: AnyObject {
    func numberOfSearchableColumns(in client: TableViewTextFinderClient) -> Int
    func textFinderClient(_ client: TableViewTextFinderClient, stringForRow row: Int, column: Int) -> String?
}
```

### OutlineViewTextFinderDataSource

```swift
public protocol OutlineViewTextFinderDataSource: AnyObject {
    func numberOfSearchableColumns(in client: OutlineViewTextFinderClient) -> Int
    func textFinderClient(_ client: OutlineViewTextFinderClient, stringForItem item: Any, column: Int) -> String?
    func textFinderClient(_ client: OutlineViewTextFinderClient, childItemsOfItem item: Any?) -> [Any]?
}
```

The `childItemsOfItem` method is used for on-demand indexing of collapsed subtrees. Returning `nil` means the item has no children (or should not be expanded for search).

## Index Store

`TextIndexStore` maps between a virtual contiguous character string and (row, column) cell positions.

### Token

```swift
struct Token {
    let row: Int
    let column: Int
    let globalIndex: Int
    let string: String
    let item: Any?       // non-nil for outline view items
}
```

### Lookup Strategy

Tokens are stored in a sorted array by `globalIndex`. Character index → Token lookup uses binary search for O(log n) performance.

### Separator

Each token is separated by a boundary marker (empty gap of length 1) so that `endsWithSearchBoundary` can return `true`, preventing matches from spanning across cells.

## Search Scope (OutlineView only)

```swift
public enum OutlineViewSearchScope {
    case expandedOnly   // only index currently expanded/visible rows
    case onDemand       // start with expanded; progressively index collapsed subtrees when current matches are exhausted
    case all            // index everything upfront regardless of expand state
}
```

Default: `.onDemand`

### On-Demand Indexing Behavior

1. Initial index is built from expanded rows only.
2. When NSTextFinder requests `string(at:...)` beyond the current index range, or when `firstSelectedRange` would wrap around, the client asks the data source for child items of the next un-indexed node and appends them to the index.
3. `noteClientStringWillChange()` is called before each index mutation.
4. Expand/collapse notifications trigger incremental index updates.

## NSTextFinderClient Implementation

### TableViewTextFinderClient

- Conforms to `NSTextFinderClient`
- Holds a weak reference to `NSTableView`
- Owns an `NSTextFinder` instance (configured with `findBarContainer = scrollView`)
- Owns a `TextIndexStore` for character ↔ cell mapping
- Owns a TextKit 2 stack (`NSTextContentStorage` + `NSTextLayoutManager` + `NSTextContainer`) for computing highlight rects
- Key methods:
  - `string(at:effectiveRange:endsWithSearchBoundary:)` — returns the token string for the character index
  - `stringLength()` — total virtual string length from the index store
  - `scrollRangeToVisible(_:)` — scrolls the table to the matching row
  - `contentView(at:effectiveCharacterRange:)` — returns the NSTextField from the matching cell
  - `rects(forCharacterRange:)` — uses TextKit 2 to compute glyph-level rects in the text field
  - `drawCharacters(in:forContentView:)` — draws the highlighted text fragment

### OutlineViewTextFinderClient

- Conforms to `NSTextFinderClient`
- Holds a weak reference to `NSOutlineView`
- Adds search scope management and on-demand indexing
- `contentView(at:effectiveCharacterRange:)` auto-expands collapsed parent nodes before returning the cell view
- `scrollRangeToVisible(_:)` expands the parent chain, then scrolls

### Cell Text Extraction Fallback

When the data source returns `nil` for a cell, the client:
1. Calls `tableView.view(atColumn:row:makeIfNecessary:false)` to get the existing cell view
2. Casts to `NSTableCellView` and reads `textField.stringValue`
3. If the cell is not currently loaded (returns nil), falls back to `makeIfNecessary: true`

## Index Invalidation

The client provides a public `invalidateIndex()` method. Callers should invoke it when the underlying data changes (e.g., `reloadData`). Internally:
1. Calls `textFinder.noteClientStringWillChange()`
2. Rebuilds the `TextIndexStore` from scratch

For outline view, expand/collapse events are observed automatically and trigger incremental updates.

## TextKit 2 Highlighting

A single shared TextKit 2 stack is reused for all highlight rect calculations:

1. Set `textContentStorage.attributedString` to the target text field's `attributedStringValue`
2. Set `textContainer.containerSize` to the text field's `titleRect` size
3. Convert the local character range to `NSTextRange`
4. Use `textLayoutManager.enumerateTextSegments(in:type:)` to get glyph-level rects

Minimum deployment: macOS 12+ (NSTextLayoutManager requirement).

## File Layout

```
Sources/UIFoundationAppKit/TextFinder/
├── TextIndexStore.swift
├── TableViewTextFinderDataSource.swift
├── OutlineViewTextFinderDataSource.swift
├── TableViewTextFinderClient.swift
└── OutlineViewTextFinderClient.swift
```

## Usage Example

```swift
// NSTableView
let finderClient = TableViewTextFinderClient(tableView: tableView)
finderClient.dataSource = self

// NSOutlineView
let finderClient = OutlineViewTextFinderClient(outlineView: outlineView, searchScope: .onDemand)
finderClient.dataSource = self

// Data changes
func reloadData() {
    tableView.reloadData()
    finderClient.invalidateIndex()
}
```

## Properties

- `allowsMultipleSelection`: `false`
- `isEditable`: `false`
- `isSelectable`: `false`

## Platform

macOS only (`#if canImport(AppKit) && !targetEnvironment(macCatalyst)`). Minimum macOS 12+ for TextKit 2.
