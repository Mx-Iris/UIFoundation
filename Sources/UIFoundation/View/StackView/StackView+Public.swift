#if canImport(AppKit) && !targetEnvironment(macCatalyst)
import AppKit
#endif

#if canImport(UIKit)
import UIKit
#endif



extension NSUIStackView {
    /// The spacing and sizing distribution of stacked views along the primary axis. Defaults to GravityAreas.
    public func distribution(_ dist: NSUIStackViewDistribution) -> Self {
        distribution = dist
        return self
    }

    /// The view alignment within the stack view.
    public func alignment(_ alignment: NSUIStackViewAlignment) -> Self {
        self.alignment = alignment
        return self
    }

    /// The minimum spacing, in points, between adjacent views in the stack view.
    public func spacing(_ spacing: CGFloat) -> Self {
        self.spacing = spacing
        return self
    }

    #if canImport(AppKit) && !targetEnvironment(macCatalyst)

    /// Indicate that the stack view removes hidden views from its view hierarchy.
    public func detachesHiddenViews(_ detaches: Bool = true) -> Self {
        detachesHiddenViews = detaches
        return self
    }

    /// Set the edge insets for the stack view
    public func stackPadding(_ edgeInset: CGFloat) -> Self {
        edgeInsets = NSUIEdgeInsets(edgeInset: edgeInset)
        return self
    }

    /// Set the edge insets for the stack view
    public func stackPadding(_ edgeInsets: NSUIEdgeInsets) -> Self {
        self.edgeInsets = edgeInsets
        return self
    }

    /// Sets the Auto Layout priority for the stack view to minimize its size, for a specified user interface axis.
    public func hugging(h: Float? = nil, v: Float? = nil) -> Self {
        if let h = NSUILayoutPriority.valueOrNil(h) {
            setHuggingPriority(h, for: .horizontal)
        }
        if let v = NSUILayoutPriority.valueOrNil(v) {
            setHuggingPriority(v, for: .vertical)
        }
        return self
    }

    public func clippingResistance(h: Float? = nil, v: Float? = nil) -> Self {
        if let h = NSLayoutConstraint.Priority.valueOrNil(h) {
            setClippingResistancePriority(h, for: .horizontal)
        }
        if let v = NSLayoutConstraint.Priority.valueOrNil(v) {
            setClippingResistancePriority(v, for: .vertical)
        }
        return self
    }

    // MARK: - Edge insets

    /// The geometric padding, in points, inside the stack view, surrounding its views.
    public func edgeInsets(_ edgeInsets: NSEdgeInsets) -> Self {
        self.edgeInsets = edgeInsets
        return self
    }

    /// The geometric padding, in points, inside the stack view, surrounding its views.
    @inlinable public func edgeInsets(top: CGFloat = 0, left: CGFloat = 0, bottom: CGFloat = 0, right: CGFloat = 0) -> Self {
        return edgeInsets(NSEdgeInsets(top: top, left: left, bottom: bottom, right: right))
    }

    /// The geometric padding, in points, inside the stack view, surrounding its views.
    public func edgeInsets(_ value: CGFloat) -> Self {
        return edgeInsets(NSEdgeInsets(top: value, left: value, bottom: value, right: value))
    }
    #endif
}

extension NSUIView {
    /// Set the hugging priorites for the stack
    public func contentHugging(h: NSUILayoutPriority? = nil, v: NSUILayoutPriority? = nil) -> Self {
        if let h {
            setContentHuggingPriority(h, for: .horizontal)
        }
        if let v {
            setContentHuggingPriority(v, for: .vertical)
        }
        return self
    }

    public func contentCompressionResistance(h: NSUILayoutPriority? = nil, v: NSUILayoutPriority? = nil) -> Self {
        if let h {
            setContentCompressionResistancePriority(h, for: .horizontal)
        }

        if let v {
            setContentCompressionResistancePriority(v, for: .vertical)
        }
        return self
    }

    public func contentCompressionResistance(h: Float? = nil, v: Float? = nil) -> Self {
        return contentCompressionResistance(h: .valueOrNil(h), v: .valueOrNil(v))
    }

    /// Set the hugging priorites for the stack
    public func contentHugging(h: Float? = nil, v: Float? = nil) -> Self {
        return contentHugging(h: .valueOrNil(h), v: .valueOrNil(v))
    }
}

extension NSUILayoutPriority {
    #if canImport(AppKit) && !targetEnvironment(macCatalyst)
    static let fittingSize: Self = .fittingSizeCompression
    #endif

    #if canImport(UIKit)
    static let fittingSize: Self = .fittingSizeLevel
    #endif
}

extension NSUIStackViewOrientationOrAxis {
    var nsLayoutConstraintOrientationOrAxis: NSUILayoutConstraintOrientationOrAxis {
        switch self {
        case .horizontal:
            return .horizontal
        case .vertical:
            return .vertical
        @unknown default:
            fatalError()
        }
    }
}

extension NSUIStackViewDistribution {
//    public static var defaultValue: Self {
//        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
//        return .gravityAreas
//        #endif
//
//        #if canImport(UIKit)
//        return .fill
//        #endif
//    }

    #if canImport(AppKit) && !targetEnvironment(macCatalyst)
    public static let defaultValue: Self = .gravityAreas
    #endif

    #if canImport(UIKit)
    public static let defaultValue: Self = .fill
    #endif
}

extension NSUIStackViewAlignment {
    #if canImport(AppKit) && !targetEnvironment(macCatalyst)
    public static let hStackCenter: Self = .centerY
    public static let vStackCenter: Self = .centerX
    #endif

    #if canImport(UIKit)
    public static let hStackCenter: Self = .center
    public static let vStackCenter: Self = .center
    #endif
}

#if canImport(AppKit) && !targetEnvironment(macCatalyst)

extension NSView {
    private static var __associated_gravityKey: UInt8 = 0
    var _gravity: NSStackView.Gravity? {
        get {
            objc_getAssociatedObject(
                self,
                &Self.__associated_gravityKey
            ) as? NSStackView.Gravity?
                ?? nil
        }
        set {
            objc_setAssociatedObject(
                self,
                &Self.__associated_gravityKey,
                newValue,
                .OBJC_ASSOCIATION_COPY
            )
        }
    }

    public func gravity(_ gravity: NSStackView.Gravity) -> Self {
        _gravity = gravity
        return self
    }
}

#endif
