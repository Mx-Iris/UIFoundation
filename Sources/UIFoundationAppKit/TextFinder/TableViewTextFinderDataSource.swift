#if canImport(AppKit) && !targetEnvironment(macCatalyst)

import AppKit

@available(macOS 12.0, *)
public protocol TableViewTextFinderDataSource: AnyObject {
    /// Return the number of columns that should participate in text search.
    /// Called on the main thread.
    func numberOfSearchableColumns(in client: TableViewTextFinderClient) -> Int

    /// Return the searchable text for a given row and column.
    /// Return `nil` to fall back to an empty string for the cell.
    ///
    /// Always called on the **main thread**. Index building gathers strings in
    /// main-actor chunks, so implementations may freely read main-isolated
    /// state (view models, caches); they should still be cheap per call, as
    /// the client invokes this once per searchable cell.
    func textFinderClient(_ client: TableViewTextFinderClient, stringForRow row: Int, column: Int) -> String?

    /// Return the `NSTextField` that should be used for highlight rect computation
    /// and `contentView(at:)` callbacks for the given row/column.
    ///
    /// Implement this when your cell view is not an `NSTableCellView` or does not
    /// assign its text field to `NSTableCellView.textField`. Return `nil` to fall
    /// back to the default lookup (`cellView.textField`).
    func textFinderClient(_ client: TableViewTextFinderClient, textFieldForRow row: Int, column: Int) -> NSTextField?

    /// Optional fast path for grid-shaped content: return the UTF-16 lengths
    /// of the search strings for every searchable column of `row` — the
    /// element count must equal `numberOfSearchableColumns(in:)`.
    ///
    /// When this returns non-nil for every row, the client skips
    /// materializing cell strings during index building and stores a
    /// run-length compressed layout instead; cell strings are then produced
    /// on demand through `textFinderClient(_:stringForRow:column:)` during
    /// search and **must** have exactly the advertised UTF-16 length.
    ///
    /// The contract is all-or-nothing: returning `nil` for any row makes the
    /// client fall back to the materialized index for the whole build.
    /// Return `nil` (the default) when lengths cannot be computed without
    /// materializing the strings. Called on the main thread, once per row per
    /// index build — implementations should be O(1) and must not read cell
    /// views.
    func textFinderClient(_ client: TableViewTextFinderClient, searchStringLengthsForRow row: Int) -> [Int]?
}

@available(macOS 12.0, *)
public extension TableViewTextFinderDataSource {
    func textFinderClient(_ client: TableViewTextFinderClient, textFieldForRow row: Int, column: Int) -> NSTextField? {
        nil
    }

    func textFinderClient(_ client: TableViewTextFinderClient, searchStringLengthsForRow row: Int) -> [Int]? {
        nil
    }
}

#endif
