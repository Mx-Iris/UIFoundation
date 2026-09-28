#if canImport(AppKit) && !targetEnvironment(macCatalyst)

import AppKit

/// A declarative description of one `NSGridView` row, produced by the ``GridView`` DSL.
///
/// The cells are declared with the ``GridRowContentBuilder`` result builder; chained modifiers
/// configure the underlying `NSGridRow` (height, padding, placement, alignment, visibility) once
/// the grid is assembled.
public struct GridRow {
    /// The cells in this row, in leading-to-trailing order.
    var cells: [GridCell]

    /// An explicit, required-priority row height. Leave `nil` to size from content.
    var height: CGFloat?

    /// Extra padding above the row, additive with `gridView.rowSpacing`.
    var topPadding: CGFloat?

    /// Extra padding below the row, additive with `gridView.rowSpacing`.
    var bottomPadding: CGFloat?

    /// The vertical placement applied to every cell in the row.
    var yPlacement: NSGridCell.Placement?

    /// The baseline alignment applied to every cell in the row.
    var rowAlignment: NSGridRow.Alignment?

    /// Whether the row is hidden (collapsed to zero height).
    var isHidden: Bool?

    /// Creates a row from the cells declared in the builder.
    public init(@GridRowContentBuilder _ cells: () -> [GridCell]) {
        self.cells = cells()
    }
}

// MARK: - Chained modifiers

extension GridRow {
    /// Sets an explicit, required-priority height for the row.
    public func height(_ height: CGFloat) -> GridRow {
        var row = self
        row.height = height
        return row
    }

    /// Sets extra padding above the row (additive with `rowSpacing`).
    public func topPadding(_ padding: CGFloat) -> GridRow {
        var row = self
        row.topPadding = padding
        return row
    }

    /// Sets extra padding below the row (additive with `rowSpacing`).
    public func bottomPadding(_ padding: CGFloat) -> GridRow {
        var row = self
        row.bottomPadding = padding
        return row
    }

    /// Sets the padding above and below the row.
    public func padding(top: CGFloat = 0, bottom: CGFloat = 0) -> GridRow {
        var row = self
        row.topPadding = top
        row.bottomPadding = bottom
        return row
    }

    /// Sets the vertical placement applied to every cell in the row.
    public func yPlacement(_ placement: NSGridCell.Placement) -> GridRow {
        var row = self
        row.yPlacement = placement
        return row
    }

    /// Sets the baseline alignment applied to every cell in the row.
    public func rowAlignment(_ alignment: NSGridRow.Alignment) -> GridRow {
        var row = self
        row.rowAlignment = alignment
        return row
    }

    /// Sets whether the row is hidden.
    public func hidden(_ hidden: Bool = true) -> GridRow {
        var row = self
        row.isHidden = hidden
        return row
    }
}

#endif
