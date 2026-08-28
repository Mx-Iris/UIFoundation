#if RunningApplication && os(macOS)

import AppKit

@available(macOS 11.0, *)
extension RunningPickerTabViewController {
    /// How a picker tab presents its items.
    ///
    /// Both styles are backed by the same table view and the same diffable data source —
    /// the list style is a single full-width column with its header hidden — so selection,
    /// type-select and context menus behave identically in either.
    public enum Style: Hashable, Sendable, CaseIterable {
        /// Multi-column table. Every field occupies its own column, and sorting is driven
        /// by clicking a column header.
        case table

        /// Single-column rows carrying a name, inline badges, and a subtitle. Sorting is
        /// driven by a pop-up beside the search field, since there are no headers to click.
        case list
    }
}

@available(macOS 11.0, *)
extension RunningPickerTabViewController.Style {
    /// Row height used when the caller has not set one. A list row stacks a title over a
    /// subtitle and needs the extra height; a table row holds a single line of text.
    var defaultRowHeight: CGFloat {
        switch self {
        // 28 rather than 25: the table's badges are pills, and 25pt leaves them cramped.
        case .table: 28
        case .list: 44
        }
    }

    /// Intercell spacing used when the caller has not set one. List rows carry their own
    /// internal padding, so they need far less separation than table rows.
    var defaultCellSpacing: CGSize {
        switch self {
        case .table: CGSize(width: 0, height: 10)
        case .list: CGSize(width: 0, height: 2)
        }
    }

    /// The table style sorts by clicking a column header; the list style has no headers
    /// to click and gets a pop-up instead. Neither shows both.
    var showsColumnHeaders: Bool { self == .table }

    var showsSortControl: Bool { self == .list }

    /// The list style gives the search field the full width above the rows, matching how
    /// searching is the primary way into a long list.
    var searchFieldFillsWidth: Bool { self == .list }
}

#endif
