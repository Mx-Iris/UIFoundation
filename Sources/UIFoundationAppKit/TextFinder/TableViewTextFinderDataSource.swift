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
}

@available(macOS 12.0, *)
public extension TableViewTextFinderDataSource {
    func textFinderClient(_ client: TableViewTextFinderClient, textFieldForRow row: Int, column: Int) -> NSTextField? {
        nil
    }
}

#endif
