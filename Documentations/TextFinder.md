# TextFinder

> `NSTextFinder` (find bar / ⌘F) integration for `NSTableView` and
> `NSOutlineView`, exposing every searchable cell as one contiguous virtual
> document. macOS 12+, AppKit only.

---

## Components

| Type | Role |
|------|------|
| `TableViewTextFinderClient` | `NSTextFinderClient` over an `NSTableView` |
| `OutlineViewTextFinderClient` | `NSTextFinderClient` over an `NSOutlineView`, with expand/collapse awareness and three search scopes (`expandedOnly` / `onDemand` / `all`) |
| `TableViewTextFinderDataSource` / `OutlineViewTextFinderDataSource` | Consumer-implemented string providers |
| `TextIndexStore` | Materialized index storage: one token (owned `String`) per searchable cell |
| `RunLengthTextIndexStore` | Length-only index storage: run-length compressed per-column length patterns, strings materialized on demand |
| `OutlineViewExternalTextIndex` / `PooledTextIndexStore` | Host-built index over an outline's top-level rows: one contiguous UTF-16 pool + flat cell-offset table, buildable on any thread |

Both clients concatenate every searchable cell into a virtual document whose
character positions `NSTextFinder` searches; each cell ends with a search
boundary so matches never span cells.

## Usage

```swift
let textFinderClient = TableViewTextFinderClient(tableView: tableView)
textFinderClient.dataSource = self

// Responder chain entry point (⌘F, ⌘G, …):
override func performTextFinderAction(_ sender: Any?) {
    let action = (sender as? NSMenuItem).flatMap { NSTextFinder.Action(rawValue: $0.tag) } ?? .showFindInterface
    textFinderClient.performTextFinderAction(action)
}

// After any data change that affects cell strings:
textFinderClient.invalidateIndex()
```

Always route actions through `performTextFinderAction(_:)` (or call
`prepareIndexIfNeeded()` first) — driving `textFinderClient.textFinder`
directly skips the lazy index rebuild described below and searches a stale
(empty) document.

## Lazy index invalidation

`invalidateIndex()` does **not** rebuild the index. It cancels any in-flight
build, clears the storage, notes the string change to `NSTextFinder`, and
marks the index dirty. The actual rebuild happens at the first find
interaction:

- `performTextFinderAction(_:)` / `prepareIndexIfNeeded()` rebuild a dirty
  index before forwarding the action;
- while the find bar is visible, `invalidateIndex()` rebuilds immediately so
  on-screen results stay live (and re-triggers `.nextMatch` when the rebuild
  lands, replacing a stale "Not Found").

Consequences: consumers that reload frequently but never use the find bar pay
nothing for indexing, and `NSOutlineView` expand/collapse notifications (which
invalidate the outline client) become cheap dirty marks instead of full
rebuilds.

Index building itself runs as a single-slot cancel-replace `Task` on the main
actor, gathering data-source callbacks in fixed-size chunks with
`Task.yield()` between chunks — callbacks may freely read main-isolated state
and large tables do not stall the run loop. A generation counter discards
stale passes.

## Run-length fast path (tables)

For grid-shaped content (hex dumps, fixed-width columns) materializing one
`String` per cell is prohibitive — millions of rows × columns means gigabytes
of token storage before the first search. `TableViewTextFinderDataSource` can
opt into a length-only index:

```swift
func textFinderClient(_ client: TableViewTextFinderClient, searchStringLengthsForRow row: Int) -> [Int]? {
    // O(1), no string formatting, no cell-view access.
    [addressColumnLength(for: row), hexColumnLength(for: row), asciiColumnLength(for: row)]
}
```

Contract:

- The element count must equal `numberOfSearchableColumns(in:)`.
- All-or-nothing: a `nil` for any row falls the whole build back to the
  materialized index.
- During search, `textFinderClient(_:stringForRow:column:)` materializes cells
  on demand and **must** return strings with exactly the advertised UTF-16
  lengths. Mismatches assert in debug builds and are padded/truncated in
  release builds so `NSTextFinder` never sees inconsistent ranges.

The client then builds a `RunLengthTextIndexStore`: consecutive rows sharing
one per-column length pattern collapse into a single run, so memory is
O(runs) — for uniform grids effectively O(1) — and the build makes zero
string allocations. `token(at:)` binary-searches the run table and divides
into it, then walks the (small) per-run column pattern. Rows whose total
length is zero own no characters and are skipped entirely.

Search cost itself is unchanged — `NSTextFinder` still scans the virtual
document linearly on the main thread — but the scan only materializes the
cells it actually visits, and nothing is paid before the user searches.

## External index (outlines)

Content whose row strings cannot be produced through the synchronous
data-source walk at all — viewport-windowed rows that must be fetched on a
background task — can take over index construction entirely:

```swift
// Data source:
func textFinderClientBuildsIndexExternally(_ client: OutlineViewTextFinderClient) -> Bool { true }
func textFinderClientNeedsExternalIndexRebuild(_ client: OutlineViewTextFinderClient) {
    startBackgroundScan()   // host-owned, cancel-replace
}

// Background scan (any thread):
var externalIndex = OutlineViewExternalTextIndex(numberOfColumns: 3, estimatedRowCount: rowCount)
for row in fetchRowsSomehow() {
    externalIndex.appendRow(columnStrings: renderColumns(row))  // must mirror the cells
}
// Completion (main thread):
textFinderClient.installExternalIndex(externalIndex)
```

When the data source opts in, a stale index is not rebuilt in place: the
client clears its storage and calls
`textFinderClientNeedsExternalIndexRebuild(_:)`; installing the finished
index re-triggers the pending search if the find bar is visible. The pooled
storage keeps every cell string in one contiguous UTF-16 buffer, so
million-row indexes cost megabytes of contiguous memory, and `NSTextFinder`'s
linear scan decodes straight from the pool with zero data-source callbacks.

External tokens carry **top-level row indices**. When the outline has
expanded child rows, the client converts by walking to the n-th level-0 row;
in the flat case (no expansion) the index is used directly. Child rows are
not part of an external index — index top-level content only.

## Known limitations

- Navigating to a match inside a collapsed outline subtree expands ancestors,
  which fires expand notifications and (with the find bar visible) rebuilds
  the index, resetting the saved match position — Find Next may restart from
  the top of the document after an auto-expand. Pre-existing behavior,
  unchanged by the lazy rework.
- The materialized path still reserves capacity for `rows × columns` tokens
  up front; prefer the lengths fast path for very large tables.
