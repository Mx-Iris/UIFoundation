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
    /// Called on the main thread.
    func numberOfSearchableColumns(in client: OutlineViewTextFinderClient) -> Int

    /// Return the searchable text for a given item and column.
    /// Return `nil` to fall back to an empty string for the cell.
    ///
    /// Always called on the **main thread**. Index building gathers strings in
    /// main-actor chunks, so implementations may freely read main-isolated
    /// state (view models, caches); they should still be cheap per call, as
    /// the client invokes this once per searchable cell.
    func textFinderClient(_ client: OutlineViewTextFinderClient, stringForItem item: Any, column: Int) -> String?

    /// Return the child items for the given parent item (nil = root).
    /// Used for on-demand and full-tree indexing of collapsed nodes.
    /// Return `nil` if the item has no children.
    func textFinderClient(_ client: OutlineViewTextFinderClient, childItemsOfItem item: Any?) -> [Any]?

    /// Return the `NSTextField` that should be used for highlight rect computation
    /// and `contentView(at:)` callbacks for the given row/column.
    ///
    /// Implement this when your cell view is not an `NSTableCellView` or does not
    /// assign its text field to `NSTableCellView.textField`. Return `nil` to fall
    /// back to the default lookup (`cellView.textField`).
    func textFinderClient(_ client: OutlineViewTextFinderClient, textFieldForRow row: Int, column: Int) -> NSTextField?

    /// Return `true` when the host builds the find index externally — via
    /// `OutlineViewTextFinderClient.installExternalIndex(_:)` — instead of
    /// the synchronous data-source walk. Use this for content whose row
    /// strings cannot be produced on demand on the main thread (e.g.
    /// viewport-windowed rows that require background fetching).
    ///
    /// When `true`, a stale index is not rebuilt in place: the client clears
    /// its storage and calls
    /// `textFinderClientNeedsExternalIndexRebuild(_:)`, and the host is
    /// expected to build an `OutlineViewExternalTextIndex` (typically on a
    /// background task) and install it when done. Defaults to `false`.
    func textFinderClientBuildsIndexExternally(_ client: OutlineViewTextFinderClient) -> Bool

    /// Kick off the host's external index build. Called on the main thread
    /// whenever the (externally built) index is stale and a find interaction
    /// needs it — the host should cancel-replace any build already in
    /// flight, then call `installExternalIndex(_:)` on the main thread when
    /// the build completes. Defaults to a no-op.
    func textFinderClientNeedsExternalIndexRebuild(_ client: OutlineViewTextFinderClient)
}

@available(macOS 12.0, *)
public extension OutlineViewTextFinderDataSource {
    func textFinderClient(_ client: OutlineViewTextFinderClient, textFieldForRow row: Int, column: Int) -> NSTextField? {
        nil
    }

    func textFinderClientBuildsIndexExternally(_ client: OutlineViewTextFinderClient) -> Bool {
        false
    }

    func textFinderClientNeedsExternalIndexRebuild(_ client: OutlineViewTextFinderClient) {}
}

#endif
