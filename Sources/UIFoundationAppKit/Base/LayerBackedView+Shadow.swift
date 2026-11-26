#if canImport(AppKit) && !targetEnvironment(macCatalyst) && AppKitPlus && canImport(AppKitPlus)

import AppKit
import AppKitPlus

/// The five shadow members `LayerBackgroundProviding` gives `LayerBackedView` with the
/// `AppKitPlus` trait off, kept with it on by writing through to `NSLayerBackedView`'s
/// `shadowProperties`, which owns the view's shadow there. Code that sets them compiles and
/// behaves the same on both sides of the trait; new code under the trait can set
/// `shadowProperties` directly.
///
/// Two defaults differ from the renderer's: unset, the offset is zero and the radius 0 (the
/// renderer's are `(0, -3)` and 3), and `shadowColor` reads AppKitPlus's black instead of `nil`.
/// Neither draws anything until the opacity is raised.
extension LayerBackedView {
    /// The colour of the shadow. `nil` draws no shadow.
    public var shadowColor: NSColor? {
        get { shadowProperties.color }
        set { shadowProperties.color = newValue ?? .clear }
    }

    /// The opacity of the shadow, from 0 to 1. It multiplies the alpha of `shadowColor`.
    public var shadowOpacity: Float {
        get { Float(shadowProperties.opacity) }
        set { shadowProperties.opacity = CGFloat(newValue) }
    }

    /// The offset of the shadow, as `NSShadow.shadowOffset` takes it.
    public var shadowOffset: CGSize {
        get { shadowProperties.offset }
        set { shadowProperties.offset = newValue }
    }

    /// The blur radius of the shadow.
    public var shadowRadius: CGFloat {
        get { shadowProperties.radius }
        set { shadowProperties.radius = newValue }
    }

    /// The outline the shadow follows, in the coordinates of the view's layer. `nil` follows the
    /// view's visible content.
    public var shadowPath: NSBezierPath? {
        get { shadowProperties.path }
        set { shadowProperties.path = newValue }
    }
}

#endif
