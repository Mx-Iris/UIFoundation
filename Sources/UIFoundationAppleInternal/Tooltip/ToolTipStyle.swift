#if canImport(AppKit) && !targetEnvironment(macCatalyst)

import AppKit

/// Per-instance customization payload for the system tooltip.
///
/// All fields are optional. When a field is `nil`, the corresponding hook on
/// ``CustomToolTipManager`` falls through to the system's original
/// implementation (`callSuper()`). When non-`nil`, the value overrides the
/// system default.
///
/// Two predefined values are provided:
/// - ``system`` — every field `nil`; behaves exactly like the system tooltip.
/// - ``default`` — a tasteful tweak: SF 12pt + labelColor on a rounded
///   layer-backed panel with a 1-point separator border and a subtle shadow.
public struct ToolTipStyle {

    // MARK: - Text

    /// Font used to render the tooltip string.
    public var font: NSFont?

    /// Foreground color of the tooltip string.
    public var textColor: NSColor?

    // MARK: - Background

    /// Background color of the tooltip panel.
    ///
    /// Setting any non-`nil` value disables the system `NSVisualEffectMaterial.toolTip`
    /// blur because `-[NSToolTipManager _drawToolTipBackgroundInView:]` falls back
    /// to a solid `NSRectFill` when this value differs from `NSColor.toolTipColor`.
    public var backgroundColor: NSColor?

    // MARK: - Geometry

    /// Inner padding around the tooltip string. Matches the system
    /// `-[NSToolTipManager toolTipContentMargin]` (default `width: 6, height: 2`).
    public var contentMargin: CGSize?

    /// Vertical distance between the cursor and the tooltip panel.
    /// Defaults to `cursorScale * 18` in the system implementation.
    public var yOffsetFromCursor: CGFloat?

    /// Initial show delay. When non-`nil`, ``CustomToolTipManager/install()``
    /// pushes it through `-[NSToolTipManager setInitialToolTipDelay:]`.
    public var initialDelay: TimeInterval?

    // MARK: - Layer backing (replaces NSVisualEffectView)

    /// Corner radius applied to the tooltip panel.
    ///
    /// When any of ``cornerRadius`` / ``borderColor`` / ``borderWidth`` /
    /// ``shadowColor`` / ``shadowOffset`` / ``shadowRadius`` is non-`nil`,
    /// ``isLayerBackingEnabled`` evaluates to `true` and the hook replaces the
    /// system `NSVisualEffectView` content view with a
    /// `LayerBackedView` so the corners, border, and shadow can be drawn.
    public var cornerRadius: CGFloat?

    /// Border stroke color.
    public var borderColor: NSColor?

    /// Border stroke width.
    public var borderWidth: CGFloat?

    /// Panel shadow color.
    public var shadowColor: NSColor?

    /// Panel shadow offset.
    public var shadowOffset: CGSize?

    /// Panel shadow blur radius.
    public var shadowRadius: CGFloat?

    public init(
        font: NSFont? = nil,
        textColor: NSColor? = nil,
        backgroundColor: NSColor? = nil,
        contentMargin: CGSize? = nil,
        yOffsetFromCursor: CGFloat? = nil,
        initialDelay: TimeInterval? = nil,
        cornerRadius: CGFloat? = nil,
        borderColor: NSColor? = nil,
        borderWidth: CGFloat? = nil,
        shadowColor: NSColor? = nil,
        shadowOffset: CGSize? = nil,
        shadowRadius: CGFloat? = nil
    ) {
        self.font = font
        self.textColor = textColor
        self.backgroundColor = backgroundColor
        self.contentMargin = contentMargin
        self.yOffsetFromCursor = yOffsetFromCursor
        self.initialDelay = initialDelay
        self.cornerRadius = cornerRadius
        self.borderColor = borderColor
        self.borderWidth = borderWidth
        self.shadowColor = shadowColor
        self.shadowOffset = shadowOffset
        self.shadowRadius = shadowRadius
    }

    /// `true` when any field that requires a custom layer-backed content view
    /// is set. The hook reads this to decide whether to swap
    /// `NSVisualEffectView` out for `LayerBackedView`.
    ///
    /// `shadowOffset` and `shadowRadius` intentionally do **not** participate
    /// in the gate: a `CALayer` shadow is only visible when its `shadowColor`
    /// is set, so a style with only `shadowOffset` / `shadowRadius` would
    /// otherwise trigger a swap that drops the system blur without drawing a
    /// shadow in return. Set ``shadowColor`` to opt the layer in.
    public var isLayerBackingEnabled: Bool {
        cornerRadius != nil
            || borderColor != nil
            || borderWidth != nil
            || shadowColor != nil
            || backgroundColor != nil
    }

    /// Builder-style mutation helper.
    ///
    /// ```swift
    /// view.box.customTooltipStyle = .default.with { $0.cornerRadius = 8 }
    /// ```
    public func with(_ mutation: (inout ToolTipStyle) -> Void) -> ToolTipStyle {
        var copy = self
        mutation(&copy)
        return copy
    }
}

// MARK: - Presets

extension ToolTipStyle {

    /// Every field `nil`. Behaves exactly like the unmodified system tooltip.
    public static let system: ToolTipStyle = ToolTipStyle()

    /// Recommended preset that tweaks the system look without straying too far:
    /// SF 12pt + labelColor on a rounded layer-backed panel with a separator
    /// border and a subtle shadow.
    public static let `default`: ToolTipStyle = ToolTipStyle(
        font: .systemFont(ofSize: 12),
        textColor: .labelColor,
        backgroundColor: .controlBackgroundColor,
        contentMargin: CGSize(width: 8, height: 4),
        cornerRadius: 6,
        borderColor: .separatorColor,
        borderWidth: 1,
        shadowColor: NSColor.black.withAlphaComponent(0.18),
        shadowOffset: CGSize(width: 0, height: -1),
        shadowRadius: 3
    )
}

#endif
