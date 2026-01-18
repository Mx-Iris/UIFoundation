#if canImport(AppKit) && !targetEnvironment(macCatalyst)

import AppKit
import FrameworkToolbox
import SwiftStdlibToolbox

extension FrameworkToolbox where Base: NSTableView {
    @inlinable
    public func makeView<View: NSView>(ofClass cls: View.Type, owner: Any? = nil, viewBuilder: (() -> View) = { .init() }) -> View {
        if let reuseView = base.makeView(withIdentifier: .init(cls), owner: owner) as? View {
            return reuseView
        } else {
            let view = viewBuilder()
            view.identifier = .init(cls)
            return view
        }
    }

    @inlinable
    public func makeViewFromNib<View: NSView>(ofClass cls: View.Type, owner: Any? = nil) -> View? {
        return base.makeView(withIdentifier: .init(cls), owner: owner) as? View
    }

    @inlinable
    public var hasValidClickedRow: Bool {
        isValidRow(base.clickedRow)
    }

    @inlinable
    public var hasValidClickedColumn: Bool {
        isValidColumn(base.clickedColumn)
    }

    @inlinable
    public var hasValidSelectedRow: Bool {
        isValidRow(base.selectedRow)
    }

    @inlinable
    public var hasValidSelectedColumn: Bool {
        isValidColumn(base.selectedColumn)
    }
    
    @inlinable
    public func isValidRow(_ row: Int) -> Bool {
        row >= 0 && row < base.numberOfRows
    }

    @inlinable
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
    
    public struct ScrollPosition: OptionSet {
        public let rawValue: UInt

        @inlinable
        public init(rawValue: UInt) {
            self.rawValue = rawValue
        }

        @inlinable
        public static var top: ScrollPosition { ScrollPosition(rawValue: 1 << 0) }
        @inlinable
        public static var centeredVertically: ScrollPosition { ScrollPosition(rawValue: 1 << 1) }
        @inlinable
        public static var bottom: ScrollPosition { ScrollPosition(rawValue: 1 << 2) }
        
        @inlinable
        public static var left: ScrollPosition { ScrollPosition(rawValue: 1 << 3) }
        @inlinable
        public static var centeredHorizontally: ScrollPosition { ScrollPosition(rawValue: 1 << 4) }
        @inlinable
        public static var right: ScrollPosition { ScrollPosition(rawValue: 1 << 5) }
        
        @inlinable
        public static var leadingEdge: ScrollPosition { ScrollPosition(rawValue: 1 << 6) }
        @inlinable
        public static var trailingEdge: ScrollPosition { ScrollPosition(rawValue: 1 << 7) }
        @inlinable
        public static var nearestVerticalEdge: ScrollPosition { ScrollPosition(rawValue: 1 << 8) }
        @inlinable
        public static var nearestHorizontalEdge: ScrollPosition { ScrollPosition(rawValue: 1 << 9) }
    }

    public func scrollRowToVisible(_ row: Int, animated: Bool = true, scrollPosition: ScrollPosition) {
        guard isValidRow(row) else { return }

        if scrollPosition == [] {
            base.scrollRowToVisible(row)
            return
        }

        let rowRect = base.rect(ofRow: row)
        let visibleRect = base.visibleRect
        guard let clipView = base.enclosingScrollView?.contentView else { return }

        var finalY = visibleRect.origin.y

        if scrollPosition.contains(.top) || scrollPosition.contains(.leadingEdge) {
            finalY = rowRect.origin.y
        } else if scrollPosition.contains(.centeredVertically) {
            finalY = rowRect.midY - (visibleRect.height / 2.0)
        } else if scrollPosition.contains(.bottom) || scrollPosition.contains(.trailingEdge) {
            finalY = rowRect.maxY - visibleRect.height
        } else if scrollPosition.contains(.nearestHorizontalEdge) {
            let distToTop = abs(visibleRect.minY - rowRect.minY)
            let distToBottom = abs(visibleRect.maxY - rowRect.maxY)
            if distToTop < distToBottom {
                finalY = rowRect.origin.y
            } else {
                finalY = rowRect.maxY - visibleRect.height
            }
        }

        let maxScrollY = clipView.documentRect.height - visibleRect.height
        finalY = max(0, min(finalY, maxScrollY))

        let finalPoint = NSPoint(x: visibleRect.origin.x, y: finalY)
        scrollToPoint(finalPoint, animated: animated)
    }

    public func scrollColumnToVisible(_ column: Int, animated: Bool = true, scrollPosition: ScrollPosition) {
        guard isValidColumn(column) else { return }

        if scrollPosition == [] {
            base.scrollColumnToVisible(column)
            return
        }

        let colRect = base.rect(ofColumn: column)
        let visibleRect = base.visibleRect
        guard let clipView = base.enclosingScrollView?.contentView else { return }

        var finalX = visibleRect.origin.x

        if scrollPosition.contains(.left) || scrollPosition.contains(.leadingEdge) {
            finalX = colRect.origin.x
        } else if scrollPosition.contains(.centeredHorizontally) {
            finalX = colRect.midX - (visibleRect.width / 2.0)
        } else if scrollPosition.contains(.right) || scrollPosition.contains(.trailingEdge) {
            finalX = colRect.maxX - visibleRect.width
        } else if scrollPosition.contains(.nearestVerticalEdge) {
            let distToLeft = abs(visibleRect.minX - colRect.minX)
            let distToRight = abs(visibleRect.maxX - colRect.maxX)
            if distToLeft < distToRight {
                finalX = colRect.origin.x
            } else {
                finalX = colRect.maxX - visibleRect.width
            }
        }

        let maxScrollX = clipView.documentRect.width - visibleRect.width
        finalX = max(0, min(finalX, maxScrollX))

        let finalPoint = NSPoint(x: finalX, y: visibleRect.origin.y)
        scrollToPoint(finalPoint, animated: animated)
    }

    private func scrollToPoint(_ point: NSPoint, animated: Bool) {
        guard let scrollView = base.enclosingScrollView else { return }

        if animated {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.25
                context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                scrollView.contentView.animator().setBoundsOrigin(point)
            } completionHandler: {
                scrollView.reflectScrolledClipView(scrollView.contentView)
            }
        } else {
            scrollView.contentView.scroll(to: point)
            scrollView.reflectScrolledClipView(scrollView.contentView)
        }
    }
}





#endif
