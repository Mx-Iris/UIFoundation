#if canImport(AppKit) && !targetEnvironment(macCatalyst)

import AppKit

/// A declarative description of a single `NSGridView` cell, consumed by ``GridRow`` inside the
/// ``GridView`` result-builder DSL.
///
/// A cell wraps an optional content view (`nil` produces an empty cell backed by
/// `NSGridCell.emptyContentView`) together with the placement, alignment, and spanning
/// configuration applied to the underlying `NSGridCell` once the grid is assembled.
///
/// - Note: `placementConstraints` is mutually exclusive with `xPlacement` / `yPlacement`. Setting
///   both produces competing placement constraints inside `NSGridView`; pick one.
public struct GridCell {
    /// The view placed in the cell. `nil` leaves the cell empty (`NSGridCell.emptyContentView`).
    public var contentView: NSView?

    /// The number of columns this cell spans. Values greater than `1` merge the cell horizontally.
    public var columnSpan: Int

    /// The number of rows this cell spans. Values greater than `1` merge the cell vertically.
    public var rowSpan: Int

    /// The horizontal placement of the content view within the cell.
    public var xPlacement: NSGridCell.Placement?

    /// The vertical placement of the content view within the cell.
    public var yPlacement: NSGridCell.Placement?

    /// The baseline alignment of the content view within the row.
    public var rowAlignment: NSGridRow.Alignment?

    /// Custom placement constraints. Mutually exclusive with `xPlacement` / `yPlacement`.
    public var customPlacementConstraints: [NSLayoutConstraint]?

    /// Creates a cell wrapping the given content view.
    ///
    /// - Parameter contentView: The view to place in the cell, or `nil` for an empty cell.
    public init(_ contentView: NSView? = nil) {
        self.contentView = contentView
        self.columnSpan = 1
        self.rowSpan = 1
    }

    /// An empty cell, backed by `NSGridCell.emptyContentView` once assembled.
    public static var empty: GridCell { GridCell() }
}

// MARK: - Chained modifiers

extension GridCell {
    /// Sets the number of columns this cell spans (horizontal merge).
    public func columns(_ count: Int) -> GridCell {
        var cell = self
        cell.columnSpan = max(1, count)
        return cell
    }

    /// Sets the number of rows this cell spans (vertical merge).
    public func rows(_ count: Int) -> GridCell {
        var cell = self
        cell.rowSpan = max(1, count)
        return cell
    }

    /// Sets the horizontal placement of the content view within the cell.
    public func xPlacement(_ placement: NSGridCell.Placement) -> GridCell {
        var cell = self
        cell.xPlacement = placement
        return cell
    }

    /// Sets the vertical placement of the content view within the cell.
    public func yPlacement(_ placement: NSGridCell.Placement) -> GridCell {
        var cell = self
        cell.yPlacement = placement
        return cell
    }

    /// Sets the baseline alignment of the content view within the row.
    public func rowAlignment(_ alignment: NSGridRow.Alignment) -> GridCell {
        var cell = self
        cell.rowAlignment = alignment
        return cell
    }

    /// Sets custom placement constraints. Mutually exclusive with `xPlacement` / `yPlacement`.
    public func placementConstraints(_ constraints: [NSLayoutConstraint]) -> GridCell {
        var cell = self
        cell.customPlacementConstraints = constraints
        return cell
    }
}

#endif
