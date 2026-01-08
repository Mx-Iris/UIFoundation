#if os(macOS)

import AppKit
import FrameworkToolbox
import SwiftStdlibToolbox

extension FrameworkToolbox where Base: NSTableRowView {
    /// The cell views that the row view is displaying.
    public var cellViews: [NSTableCellView] {
        (0 ..< base.numberOfColumns).compactMap { base.view(atColumn: $0) as? NSTableCellView }
    }

    /// The  cell view for the specified column.
    public func cellView(for column: NSTableColumn) -> NSTableCellView? {
        if let index = tableView?.tableColumns.firstIndex(of: column) {
            return base.view(atColumn: index) as? NSTableCellView
        }
        return nil
    }

    /// The enclosing table view that displays the row view.
    public var tableView: NSTableView? {
        firstSuperview(for: NSTableView.self)
    }

    /// The row index of the row, or `nil` if the row isn't displayed in a table view.
    public var row: Int? {
        guard let row = tableView?.row(for: base), row >= 0 else { return nil }
        return row
    }

    /// The next row view,  or `nil` if there isn't a next row view or the row isn't displayed in a table view.
    public var nextRowView: NSTableRowView? {
        guard let tableView = tableView, let row = row, row < tableView.numberOfRows - 1 else { return nil }
        return tableView.rowView(atRow: row + 1, makeIfNecessary: false)
    }

    /// The previous row view,  or `nil` if there isn't a next row view or the row isn't displayed in a table view.
    public var previousRowView: NSTableRowView? {
        guard let tableView = tableView, let row = row, row > 0 else { return nil }
        return tableView.rowView(atRow: row - 1, makeIfNecessary: false)
    }

    /// A Boolean value indicating whether the row is displaying row actions.
    public var isDisplayingRowAction: Bool {
        get { base.subviews.contains(where: { $0.className == "NSTableViewActionButtonsGroupView" }) }
    }
}


#endif
