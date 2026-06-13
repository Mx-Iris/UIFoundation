#if canImport(AppKit) && !targetEnvironment(macCatalyst)
import AppKit
#endif

#if canImport(UIKit)
import UIKit
#endif

import UIFoundationTypealias
import UIFoundationToolbox

/// `NSUIStackView` configuration in the `.box` namespace.
///
/// Moved here from direct `NSUIStackView` extensions so stack configuration goes through the same
/// `.box` namespace as the rest of the toolbox. `StackViewAlignment` lives in this module, which is
/// why these extensions stay in `UIFoundationShared` rather than `UIFoundationToolbox`.
extension FrameworkToolbox where Base: NSUIStackView {
    /// The spacing and sizing distribution of stacked views along the primary axis.
    @discardableResult
    public func distribution(_ distribution: NSUIStackViewDistribution) -> Base {
        base.distribution = distribution
        return base
    }

    /// The view alignment within the stack view.
    @discardableResult
    public func alignment(_ alignment: StackViewAlignment) -> Base {
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        base.alignment = alignment.attribute(for: base.orientation)
        #endif

        #if canImport(UIKit)
        base.alignment = alignment.uiStackAlignment(for: base.axis)
        #endif
        return base
    }

    /// The minimum spacing, in points, between adjacent views in the stack view.
    @discardableResult
    public func spacing(_ spacing: CGFloat) -> Base {
        base.spacing = spacing
        return base
    }

    #if canImport(AppKit) && !targetEnvironment(macCatalyst)

    /// Indicate that the stack view removes hidden views from its view hierarchy.
    @discardableResult
    public func detachesHiddenViews(_ detaches: Bool = true) -> Base {
        base.detachesHiddenViews = detaches
        return base
    }

    /// Set a uniform edge inset for the stack view.
    @discardableResult
    public func stackPadding(_ edgeInset: CGFloat) -> Base {
        base.edgeInsets = NSUIEdgeInsets(edgeInset: edgeInset)
        return base
    }

    /// Set the edge insets for the stack view.
    @discardableResult
    public func stackPadding(_ edgeInsets: NSUIEdgeInsets) -> Base {
        base.edgeInsets = edgeInsets
        return base
    }

    /// Sets the Auto Layout priority for the stack view to minimize its size, per axis.
    @discardableResult
    public func hugging(h: Float? = nil, v: Float? = nil) -> Base {
        if let h = NSUILayoutPriority.valueOrNil(h) {
            base.setHuggingPriority(h, for: .horizontal)
        }
        if let v = NSUILayoutPriority.valueOrNil(v) {
            base.setHuggingPriority(v, for: .vertical)
        }
        return base
    }

    /// Sets the Auto Layout clipping-resistance priority for the stack view, per axis.
    @discardableResult
    public func clippingResistance(h: Float? = nil, v: Float? = nil) -> Base {
        if let h = NSLayoutConstraint.Priority.valueOrNil(h) {
            base.setClippingResistancePriority(h, for: .horizontal)
        }
        if let v = NSLayoutConstraint.Priority.valueOrNil(v) {
            base.setClippingResistancePriority(v, for: .vertical)
        }
        return base
    }

    /// The geometric padding, in points, inside the stack view, surrounding its views.
    @discardableResult
    public func edgeInsets(_ edgeInsets: NSEdgeInsets) -> Base {
        base.edgeInsets = edgeInsets
        return base
    }

    /// The geometric padding, in points, inside the stack view, surrounding its views.
    @discardableResult
    public func edgeInsets(top: CGFloat = 0, left: CGFloat = 0, bottom: CGFloat = 0, right: CGFloat = 0) -> Base {
        edgeInsets(NSEdgeInsets(top: top, left: left, bottom: bottom, right: right))
    }

    /// The geometric padding, in points, inside the stack view, surrounding its views.
    @discardableResult
    public func edgeInsets(_ value: CGFloat) -> Base {
        edgeInsets(NSEdgeInsets(top: value, left: value, bottom: value, right: value))
    }
    #endif
}
