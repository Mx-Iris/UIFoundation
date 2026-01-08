#if canImport(AppKit) && !targetEnvironment(macCatalyst)

import AppKit
import FrameworkToolbox
import SwiftStdlibToolbox

extension FrameworkToolbox where Base: NSTableView {
    public func makeView<View: NSView>(ofClass cls: View.Type, owner: Any? = nil, viewBuilder: (() -> View) = { .init() }) -> View {
        if let reuseView = base.makeView(withIdentifier: .init(cls), owner: owner) as? View {
            return reuseView
        } else {
            let view = viewBuilder()
            view.identifier = .init(cls)
            return view
        }
    }

    public func makeViewFromNib<View: NSView>(ofClass cls: View.Type, owner: Any? = nil) -> View? {
        return base.makeView(withIdentifier: .init(cls), owner: owner) as? View
    }

    public var hasValidClickedRow: Bool {
        isValidRow(base.clickedRow)
    }

    public var hasValidClickedColumn: Bool {
        isValidColumn(base.clickedColumn)
    }

    public var hasValidSelectedRow: Bool {
        isValidRow(base.selectedRow)
    }

    public var hasValidSelectedColumn: Bool {
        isValidColumn(base.selectedColumn)
    }

    public func isValidRow(_ row: Int) -> Bool {
        row >= 0 && row < base.numberOfRows
    }

    public func isValidColumn(_ column: Int) -> Bool {
        column >= 0 && column < base.numberOfColumns
    }

    /// Toggles the sorting order of the sort descriptor.
    public func toggleSortDescriptorOrder() {
        var sortDescriptors = base.sortDescriptors
        if let reversed = sortDescriptors.first?.reversed {
            sortDescriptors.removeFirst()
            sortDescriptors = [reversed] + sortDescriptors
            base.sortDescriptors = sortDescriptors
        }
    }

    /// An index set containing the indexes for a right event.
    ///
    /// - Parameter event: The right click event.
    ///
    /// The returned indexset contains:
    /// - if right-click on a **selected row**, all selected rows,
    /// - else if right-click on a **non-selected row**, that row,
    /// - else an empty index set.
    public func rightClickRowIndexes(for event: NSEvent) -> IndexSet {
        rightClickRowIndexes(for: event.box.location(in: base))
    }

    /// An index set containing the indexes for a point.
    ///
    /// - Parameter location: The point in the table view’s bound.
    ///
    /// The returned indexset contains:
    /// - if right-click on a **selected row**, all selected rows,
    /// - else if right-click on a **non-selected row**, that row,
    /// - else an empty index set.
    public func rightClickRowIndexes(for point: CGPoint) -> IndexSet {
        let row = base.row(at: point)
        let selectedRowIndexes = base.selectedRowIndexes
        return row != -1 ? selectedRowIndexes.contains(row) ? selectedRowIndexes : [row] : []
    }

    /// Deselects the rows at the specified indexes.
    ///
    /// - Parameter indexes: The indexes of the rows to deselect.
    public func deselectRows(at indexes: IndexSet) {
        indexes.forEach { base.deselectRow($0) }
    }

    /// Selects the row after the currently selected.
    ///
    /// If no row is currently selected, the first row is selected.
    ///
    /// - Parameter extend: A Boolean value indicating whether the selection should be extended.
    public func selectNextRow(byExtendingSelection extend: Bool = false) {
        let row = (base.selectedRowIndexes.last ?? -1) + 1
        guard base.numberOfRows > 0, row < base.numberOfRows else { return }
        base.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: extend)
    }

    /// Selects the row before the currently selected.
    ///
    /// If no row is currently selected, the last row is selected.
    ///
    /// - Parameter extend: A Boolean value indicating whether the selection should be extended.
    public func selectPreviousRow(byExtendingSelection extend: Bool = false) {
        let row = (base.selectedRowIndexes.first ?? base.numberOfRows) - 1
        guard base.numberOfRows > 0, row > 0, row < base.numberOfRows else { return }
        base.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: extend)
    }

    /// Marks the table view as needing redisplay, so it will reload the data for visible cells and draw the new values.
    ///
    /// - Parameter maintainingSelection: A Boolean value indicating whether the table view should maintain it's selection after reloading.
    public func reloadData(maintainingSelection: Bool) {
        let selectedRowIndexes = base.selectedRowIndexes
        base.reloadData()
        if maintainingSelection, !selectedRowIndexes.isEmpty {
            base.selectRowIndexes(selectedRowIndexes, byExtendingSelection: false)
        }
    }

    /// Returns the row indexes currently visible.
    public var visibleRowIndexes: IndexSet {
        IndexSet(base.rows(in: base.visibleRect).values)
    }

    /// Returns the row views currently visible.
    public var visibleRowViews: [NSTableRowView] {
        visibleRowIndexes.compactMap { base.rowView(atRow: $0, makeIfNecessary: false) }
    }

    /// Returns the column indexes currently visible.
    public var visibleColumnIndexes: IndexSet {
        base.columnIndexes(in: base.visibleRect)
    }

    /// Returns the columns currently visible.
    public var visibleColumns: [NSTableColumn] {
        visibleColumnIndexes.compactMap { base.tableColumns[$0] }
    }

    /// Returns the cell views currently visible.
    public var visibleCellViews: [NSTableCellView] {
        visibleRowViews.flatMap { $0.cellViews }
    }

    /// Returns the cell views of a column currently visible.
    ///
    /// - Parameter column: The column fot the visible cell views.
    public func visibleCells(for column: NSTableColumn) -> [NSTableCellView] {
        let rowIndexes = visibleRowIndexes
        var cells = [NSTableCellView]()
        if let columnIndex = base.tableColumns.firstIndex(of: column) {
            for rowIndex in rowIndexes {
                if let cellView = base.view(atColumn: columnIndex, row: rowIndex, makeIfNecessary: false) as? NSTableCellView {
                    cells.append(cellView)
                }
            }
        }
        return cells
    }

    /// Returns the row view at the specified location.
    ///
    /// - Parameter location: The location of the row view.
    /// - Returns: The row view, or `nil` if there isn't any row view at the location.
    public func rowView(at location: CGPoint) -> NSTableRowView? {
        let index = base.row(at: location)
        guard index >= 0 else { return nil }
        return base.rowView(atRow: index, makeIfNecessary: false)
    }

    /// Returns the table cell view at the specified location.
    ///
    /// - Parameter location: The location of the table cell view.
    /// - Returns: The table cell view, or `nil` if there isn't any table cell view at the location.
    public func cellView(at location: CGPoint) -> NSTableCellView? {
        guard let rowView = rowView(at: location) else { return nil }
        return rowView.cellViews.first(where: { $0.frame.contains(location) })
    }
}





#endif
