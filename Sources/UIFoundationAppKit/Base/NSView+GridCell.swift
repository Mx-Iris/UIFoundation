#if canImport(AppKit) && !targetEnvironment(macCatalyst)

import AppKit
import AssociatedObject

/// Associated storage backing the `.gridView` cell modifiers (see ``GridViewNamespace``).
///
/// The values are written by ``GridViewNamespace`` (and the deprecated direct modifiers below) and
/// read back into a ``GridCell`` while the grid is assembled. Storage setters are module-internal so
/// the namespace wrapper in another file can mutate them.
extension NSView {
    @AssociatedObject(.copy(.nonatomic))
    var _gridCellColumnSpan: Int?

    @AssociatedObject(.copy(.nonatomic))
    var _gridCellRowSpan: Int?

    @AssociatedObject(.copy(.nonatomic))
    var _gridCellXPlacement: NSGridCell.Placement?

    @AssociatedObject(.copy(.nonatomic))
    var _gridCellYPlacement: NSGridCell.Placement?

    @AssociatedObject(.copy(.nonatomic))
    var _gridCellRowAlignment: NSGridRow.Alignment?

    @AssociatedObject(.copy(.nonatomic))
    var _gridCellPlacementConstraints: [NSLayoutConstraint]?

    /// Builds a ``GridCell`` describing this view, folding in any cell modifiers applied to it.
    func _makeGridCell() -> GridCell {
        var cell = GridCell(self)
        if let columnSpan = _gridCellColumnSpan { cell.columnSpan = columnSpan }
        if let rowSpan = _gridCellRowSpan { cell.rowSpan = rowSpan }
        cell.xPlacement = _gridCellXPlacement
        cell.yPlacement = _gridCellYPlacement
        cell.rowAlignment = _gridCellRowAlignment
        cell.customPlacementConstraints = _gridCellPlacementConstraints
        return cell
    }
}

// MARK: - Deprecated direct modifiers (use the `.gridView` namespace)

extension NSView {
    @available(*, deprecated, message: "Use `gridView.columns(_:)` instead.")
    @discardableResult
    public func gridCellColumns(_ count: Int) -> Self {
        _gridCellColumnSpan = max(1, count)
        return self
    }

    @available(*, deprecated, message: "Use `gridView.rows(_:)` instead.")
    @discardableResult
    public func gridCellRows(_ count: Int) -> Self {
        _gridCellRowSpan = max(1, count)
        return self
    }

    @available(*, deprecated, message: "Use `gridView.xPlacement(_:)` instead.")
    @discardableResult
    public func gridCellXPlacement(_ placement: NSGridCell.Placement) -> Self {
        _gridCellXPlacement = placement
        return self
    }

    @available(*, deprecated, message: "Use `gridView.yPlacement(_:)` instead.")
    @discardableResult
    public func gridCellYPlacement(_ placement: NSGridCell.Placement) -> Self {
        _gridCellYPlacement = placement
        return self
    }

    @available(*, deprecated, message: "Use `gridView.rowAlignment(_:)` instead.")
    @discardableResult
    public func gridCellRowAlignment(_ alignment: NSGridRow.Alignment) -> Self {
        _gridCellRowAlignment = alignment
        return self
    }

    @available(*, deprecated, message: "Use `gridView.placementConstraints(_:)` instead.")
    @discardableResult
    public func gridCellPlacementConstraints(_ constraints: [NSLayoutConstraint]) -> Self {
        _gridCellPlacementConstraints = constraints
        return self
    }
}

#endif
