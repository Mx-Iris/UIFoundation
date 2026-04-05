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
