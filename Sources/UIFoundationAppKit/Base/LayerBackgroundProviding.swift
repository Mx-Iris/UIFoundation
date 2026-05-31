#if canImport(AppKit) && !targetEnvironment(macCatalyst)

import AppKit
import AssociatedObject

/// Conform an `NSView` subclass to opt into `LayerBackgroundRenderer`-driven
/// rendering. The renderer is stored as an Objective-C associated object;
/// conformers do not declare any properties — the protocol's default
/// implementations forward `cornerRadius` / `backgroundColor` / `border*` /
/// `shadow*` to the renderer, and `updateLayerBackground()` /
/// `layoutLayerBackground()` plug into the host's `updateLayer()` / `layout()`
/// overrides. First access lazily creates the renderer and calls
/// `attach(to:)`, which enables layer backing on the host.
///
/// Typical usage on `NSTableCellView`:
/// ```swift
/// class MyCell: NSTableCellView, LayerBackgroundProviding {
///     override init(frame: NSRect) {
///         super.init(frame: frame)
///         attachToSelf()
///         cornerRadius = 6
///         backgroundColor = .controlBackgroundColor
///     }
///     override var wantsUpdateLayer: Bool { true }
///     override func updateLayer() { super.updateLayer(); updateLayerBackground() }
///     override func layout()      { super.layout();      layoutLayerBackground() }
/// }
/// ```
///
/// Note: `shadow` is not provided as a default implementation because
/// `NSView.shadow` is a stored property; class-hierarchy dispatch wins over
/// protocol extensions. Override it explicitly on the conformer if you want
/// to fan an `NSShadow` out to the renderer.
@MainActor
public protocol LayerBackgroundProviding: NSView {
    var isLayerBackingEnabled: Bool { get }
}

extension LayerBackgroundProviding {
    @AssociatedObject(.retain(.nonatomic))
    private var backgroundRenderer: LayerBackgroundRenderer = .init()

    public var isLayerBackingEnabled: Bool { true }

    public func attachToSelfIfNeeded() {
        if isLayerBackingEnabled {
            backgroundRenderer.attach(to: self)
        }
    }

    public var borderPositions: LayerBackgroundRenderer.BorderPositions {
        get { backgroundRenderer.borderPositions }
        set { backgroundRenderer.borderPositions = newValue }
    }

    public var borderLocation: LayerBackgroundRenderer.BorderLocation {
        get { backgroundRenderer.borderLocation }
        set { backgroundRenderer.borderLocation = newValue }
    }

    public var borderColor: NSColor? {
        get { backgroundRenderer.borderColor }
        set { backgroundRenderer.borderColor = newValue }
    }

    public var borderWidth: CGFloat {
        get { backgroundRenderer.borderWidth }
        set { backgroundRenderer.borderWidth = newValue }
    }

    public var borderInsets: NSEdgeInsets {
        get { backgroundRenderer.borderInsets }
        set { backgroundRenderer.borderInsets = newValue }
    }

    public var cornerRadius: CGFloat {
        get { backgroundRenderer.cornerRadius }
        set { backgroundRenderer.cornerRadius = newValue }
    }

    public var backgroundColor: NSColor? {
        get { backgroundRenderer.backgroundColor }
        set { backgroundRenderer.backgroundColor = newValue }
    }

    public var shadowColor: NSColor? {
        get { backgroundRenderer.shadowColor }
        set { backgroundRenderer.shadowColor = newValue }
    }

    public var shadowOpacity: Float {
        get { backgroundRenderer.shadowOpacity }
        set { backgroundRenderer.shadowOpacity = newValue }
    }

    public var shadowOffset: CGSize {
        get { backgroundRenderer.shadowOffset }
        set { backgroundRenderer.shadowOffset = newValue }
    }

    public var shadowRadius: CGFloat {
        get { backgroundRenderer.shadowRadius }
        set { backgroundRenderer.shadowRadius = newValue }
    }

    public var shadowPath: NSBezierPath? {
        get { backgroundRenderer.shadowPath }
        set { backgroundRenderer.shadowPath = newValue }
    }

    /// Hook for the conformer's `updateLayer()` override.
    public func updateLayerBackgroundIfNeeded() {
        if isLayerBackingEnabled {
            backgroundRenderer.updateLayer()
        }
    }

    /// Hook for the conformer's `layout()` override.
    public func layoutLayerBackgroundIfNeeded() {
        if isLayerBackingEnabled {
            backgroundRenderer.layout()
        }
    }
}

#endif
