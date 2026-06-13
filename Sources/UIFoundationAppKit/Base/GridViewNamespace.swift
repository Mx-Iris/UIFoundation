#if canImport(AppKit) && !targetEnvironment(macCatalyst)

import AppKit

/// A namespace for `NSGridView` cell modifiers, reached through `view.gridView`.
///
/// Keeping the modifiers behind `.gridView` avoids polluting every `NSView`'s API surface. Each
/// modifier stores its value via an associated object (see `NSView._makeGridCell()`) and returns the
/// underlying view, so a plain view can take part in the ``GridView`` DSL while staying chainable:
///
/// ```swift
/// GridRow {
///     nameField.gridView.columns(2).gridView.xPlacement(.leading)
/// }
/// ```
public struct GridViewNamespace {
    let base: NSView

    init(_ base: NSView) {
        self.base = base
    }

    /// Sets the number of columns this view's cell spans (horizontal merge).
    @discardableResult
    public func columns(_ count: Int) -> NSView {
        base._gridCellColumnSpan = max(1, count)
        return base
    }

    /// Sets the number of rows this view's cell spans (vertical merge).
    @discardableResult
    public func rows(_ count: Int) -> NSView {
        base._gridCellRowSpan = max(1, count)
        return base
    }

    /// Sets the horizontal placement of this view within its cell.
    @discardableResult
    public func xPlacement(_ placement: NSGridCell.Placement) -> NSView {
        base._gridCellXPlacement = placement
        return base
    }

    /// Sets the vertical placement of this view within its cell.
    @discardableResult
    public func yPlacement(_ placement: NSGridCell.Placement) -> NSView {
        base._gridCellYPlacement = placement
        return base
    }

    /// Sets the baseline alignment of this view within its row.
    @discardableResult
    public func rowAlignment(_ alignment: NSGridRow.Alignment) -> NSView {
        base._gridCellRowAlignment = alignment
        return base
    }

    /// Sets custom placement constraints. Mutually exclusive with `xPlacement` / `yPlacement`.
    @discardableResult
    public func placementConstraints(_ constraints: [NSLayoutConstraint]) -> NSView {
        base._gridCellPlacementConstraints = constraints
        return base
    }
}

extension NSView {
    /// The `NSGridView` cell-modifier namespace for this view (e.g. `view.gridView.columns(2)`).
    public var gridView: GridViewNamespace {
        GridViewNamespace(self)
    }
}

#endif
