#if canImport(AppKit) && !targetEnvironment(macCatalyst)

import AppKit
import UIFoundationToolbox

/// Drives `cornerRadius` / `backgroundColor` / `border*` / `shadow*` rendering on
/// a host view's backing layer. Designed for composition — any `NSView` subclass
/// (e.g. `NSTableCellView`, `NSCollectionViewItem.view`) can hold a renderer,
/// `attach(to:)` it once after `super.init`, and forward `updateLayer()` /
/// `layout()` to drive the visuals. `LayerBackedView` uses this internally.
public final class LayerBackgroundRenderer {
    public struct BorderPositions: OptionSet, Hashable {
        public let rawValue: Int

        public init(rawValue: Int) {
            self.rawValue = rawValue
        }

        public static let left = Self(rawValue: 1 << 0)
        public static let right = Self(rawValue: 1 << 1)
        public static let top = Self(rawValue: 1 << 2)
        public static let bottom = Self(rawValue: 1 << 3)
        public static var all: BorderPositions {
            [.top, .left, .right, .bottom]
        }
    }

    public enum BorderLocation {
        case inside
        case center
        case outside
    }

    public weak var owner: NSView?

    private var borderLayer: CAShapeLayer?

    public init() {}

    /// Bind the renderer to a host view. Enables layer backing and switches to the
    /// `updateLayer` redraw path. Call once, typically right after `super.init(frame:)`.
    public func attach(to view: NSView) {
        owner = view
        view.wantsLayer = true
        view.layerContentsRedrawPolicy = .onSetNeedsDisplay
    }

    public var borderPositions: BorderPositions = [] {
        didSet {
            guard borderPositions != oldValue else { return }
            createBorderLayerIfNeeded()
            setNeedsDisplay()
        }
    }

    public var borderLocation: BorderLocation = .inside {
        didSet { setNeedsDisplay() }
    }

    public var borderColor: NSColor? {
        didSet {
            createBorderLayerIfNeeded()
            setNeedsDisplay()
        }
    }

    public var borderWidth: CGFloat = 0 {
        didSet {
            createBorderLayerIfNeeded()
            setNeedsDisplay()
        }
    }

    public var borderInsets: NSEdgeInsets = .zero {
        didSet { setNeedsDisplay() }
    }

    public var cornerRadius: CGFloat = 0 {
        didSet { setNeedsDisplay() }
    }

    public var backgroundColor: NSColor? {
        didSet { setNeedsDisplay() }
    }

    public var shadowColor: NSColor? {
        didSet { setNeedsDisplay() }
    }

    public var shadowOpacity: Float = 0.0 {
        didSet { setNeedsDisplay() }
    }

    public var shadowOffset: CGSize = .init(width: 0, height: -3) {
        didSet { setNeedsDisplay() }
    }

    public var shadowRadius: CGFloat = 3 {
        didSet { setNeedsDisplay() }
    }

    public var shadowPath: NSBezierPath? {
        didSet { setNeedsDisplay() }
    }

    public var shadow: NSShadow? {
        get {
            guard shadowColor != nil else { return nil }
            let result = NSShadow()
            result.shadowColor = shadowColor
            result.shadowOffset = shadowOffset
            result.shadowBlurRadius = shadowRadius
            return result
        }
        set {
            shadowColor = newValue?.shadowColor
            shadowOffset = newValue?.shadowOffset ?? .zero
            shadowRadius = newValue?.shadowBlurRadius ?? 0
        }
    }

    /// Apply the current configuration to the owner's backing layer.
    /// Call from the owner's `updateLayer()` override.
    public func updateLayer() {
        guard let owner, let layer = owner.layer else { return }

        let usesRoundedPath = cornerRadius > 0 && borderPositions == .all
        let borderPath = NSBezierPath(
            bounds: owner.bounds,
            cornerRadius: cornerRadius,
            borderWidth: borderWidth,
            borderInsets: borderInsets,
            borderLocation: borderLocation,
            borderPositions: borderPositions,
        ).box.cgPath

        borderLayer?.path = borderPath
        borderLayer?.strokeColor = borderColor?.cgColor
        borderLayer?.fillColor = NSColor.clear.cgColor
        borderLayer?.lineWidth = borderWidth
        // When the path already encodes the rounded shape we don't need the
        // layer-level corner mask — masking would clip the curved stroke.
        // For partial borders fall back to the layer mask so straight strokes
        // don't bleed past the host's rounded corners.
        borderLayer?.cornerRadius = usesRoundedPath ? 0 : cornerRadius
        borderLayer?.masksToBounds = !usesRoundedPath && cornerRadius > 0

        layer.cornerRadius = cornerRadius
        layer.backgroundColor = backgroundColor?.cgColor
        layer.shadowColor = shadowColor?.cgColor
        layer.shadowOpacity = shadowOpacity
        layer.shadowOffset = shadowOffset
        layer.shadowRadius = shadowRadius
        layer.shadowPath = shadowPath?.box.cgPath
        layer.masksToBounds = owner.clipsToBounds
    }

    /// Resize the border sublayer to track the owner's bounds.
    /// Call from the owner's `layout()` override.
    public func layout() {
        guard let owner, let borderLayer else { return }
        borderLayer.frame = owner.bounds
        borderLayer.path = NSBezierPath(
            bounds: owner.bounds,
            cornerRadius: cornerRadius,
            borderWidth: borderWidth,
            borderInsets: borderInsets,
            borderLocation: borderLocation,
            borderPositions: borderPositions,
        ).box.cgPath
    }

    private func setNeedsDisplay() {
        owner?.needsDisplay = true
    }

    private func createBorderLayerIfNeeded() {
        guard let owner else { return }

        let shouldShowBorderLayer = borderWidth > 0 && borderColor != nil && borderPositions != []
        guard shouldShowBorderLayer else {
            if let existingBorderLayer = borderLayer {
                existingBorderLayer.removeFromSuperlayer()
                borderLayer = nil
            }
            return
        }

        guard borderLayer == nil else { return }

        let newBorderLayer = CAShapeLayer()
        newBorderLayer.frame = owner.bounds
        owner.layer?.addSublayer(newBorderLayer)
        borderLayer = newBorderLayer
    }
}

extension NSBezierPath {
    fileprivate convenience init(
        bounds: NSRect,
        cornerRadius: CGFloat,
        borderWidth: CGFloat,
        borderInsets: NSEdgeInsets,
        borderLocation: LayerBackgroundRenderer.BorderLocation,
        borderPositions: LayerBackgroundRenderer.BorderPositions,
    ) {
        self.init()

        let lineOffset: CGFloat
        let lineCapOffset: CGFloat
        switch borderLocation {
        case .inside:
            lineOffset = borderWidth / 2
            lineCapOffset = 0
        case .center:
            lineOffset = 0
            lineCapOffset = borderWidth / 2
        case .outside:
            lineOffset = -borderWidth / 2
            lineCapOffset = borderWidth
        }

        // Rounded full border: stroke a rounded rect whose centerline tracks
        // the requested borderLocation, with the radius adjusted so the
        // visible edge stays flush with the host's `layer.cornerRadius`.
        if cornerRadius > 0 && borderPositions == .all {
            let strokeRect = NSRect(
                x: lineOffset + borderInsets.left,
                y: lineOffset + borderInsets.bottom,
                width: bounds.width - 2 * lineOffset - borderInsets.left - borderInsets.right,
                height: bounds.height - 2 * lineOffset - borderInsets.top - borderInsets.bottom
            )
            let strokeRadius = max(0, cornerRadius - lineOffset)
            appendRoundedRect(strokeRect, xRadius: strokeRadius, yRadius: strokeRadius)
            return
        }

        let verticalInset = borderInsets.top - borderInsets.bottom

        let showsTop = borderPositions.contains(.top)
        let showsLeft = borderPositions.contains(.left)
        let showsBottom = borderPositions.contains(.bottom)
        let showsRight = borderPositions.contains(.right)

        let leftEdgeX = lineOffset + verticalInset
        let rightEdgeX = bounds.width - lineOffset - verticalInset
        let topEdgeY = bounds.height - lineOffset - verticalInset
        let bottomEdgeY = lineOffset + verticalInset

        let horizontalStartX = (showsLeft ? -lineCapOffset + verticalInset : 0) + borderInsets.left
        let horizontalEndX = bounds.width + (showsRight ? lineCapOffset - verticalInset : 0) - borderInsets.right
        let verticalStartY = (showsBottom ? lineCapOffset - verticalInset : 0) + borderInsets.bottom
        let verticalEndY = bounds.height - (showsTop ? -lineCapOffset + verticalInset : 0) - borderInsets.top

        if showsTop {
            move(to: NSPoint(x: horizontalStartX, y: topEdgeY))
            line(to: NSPoint(x: horizontalEndX, y: topEdgeY))
        }

        if showsLeft {
            move(to: NSPoint(x: leftEdgeX, y: verticalStartY))
            line(to: NSPoint(x: leftEdgeX, y: verticalEndY))
        }

        if showsBottom {
            move(to: NSPoint(x: horizontalEndX, y: bottomEdgeY))
            line(to: NSPoint(x: horizontalStartX, y: bottomEdgeY))
        }

        if showsRight {
            move(to: NSPoint(x: rightEdgeX, y: verticalEndY))
            line(to: NSPoint(x: rightEdgeX, y: verticalStartY))
        }
    }
}

extension NSEdgeInsets {
    package static let zero = NSEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
}

#endif
