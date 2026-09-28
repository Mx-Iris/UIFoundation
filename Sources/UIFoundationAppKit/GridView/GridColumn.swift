#if canImport(AppKit) && !targetEnvironment(macCatalyst)

import AppKit

/// A declarative description of one `NSGridView` column, applied positionally via
/// ``GridView/columns(_:)``.
///
/// Because the DSL is row-major, columns are configured separately: the first ``GridColumn`` in the
/// list maps to column `0`, the second to column `1`, and so on. Columns beyond the grid's actual
/// column count are ignored.
public struct GridColumn {
    /// An explicit, required-priority column width. Leave `nil` to size from content.
    var width: CGFloat?

    /// Extra padding before the column's leading edge, additive with `gridView.columnSpacing`.
    var leadingPadding: CGFloat?

    /// Extra padding after the column's trailing edge, additive with `gridView.columnSpacing`.
    var trailingPadding: CGFloat?

    /// The horizontal placement applied to every cell in the column.
    var xPlacement: NSGridCell.Placement?

    /// Whether the column is hidden (collapsed to zero width).
    var isHidden: Bool?

    /// Creates a column with default (inherited) configuration.
    public init() {}
}

// MARK: - Chained modifiers

extension GridColumn {
    /// Sets an explicit, required-priority width for the column.
    public func width(_ width: CGFloat) -> GridColumn {
        var column = self
        column.width = width
        return column
    }

    /// Sets extra padding before the column's leading edge (additive with `columnSpacing`).
    public func leadingPadding(_ padding: CGFloat) -> GridColumn {
        var column = self
        column.leadingPadding = padding
        return column
    }

    /// Sets extra padding after the column's trailing edge (additive with `columnSpacing`).
    public func trailingPadding(_ padding: CGFloat) -> GridColumn {
        var column = self
        column.trailingPadding = padding
        return column
    }

    /// Sets the padding before and after the column.
    public func padding(leading: CGFloat = 0, trailing: CGFloat = 0) -> GridColumn {
        var column = self
        column.leadingPadding = leading
        column.trailingPadding = trailing
        return column
    }

    /// Sets the horizontal placement applied to every cell in the column.
    public func xPlacement(_ placement: NSGridCell.Placement) -> GridColumn {
        var column = self
        column.xPlacement = placement
        return column
    }

    /// Sets whether the column is hidden.
    public func hidden(_ hidden: Bool = true) -> GridColumn {
        var column = self
        column.isHidden = hidden
        return column
    }
}

#endif
