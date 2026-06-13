#if os(macOS)
import AppKit
#elseif canImport(UIKit)
import UIKit
#else
#error("Unsupported Platform")
#endif

import FrameworkToolbox
import UIFoundationTypealias

/// General-purpose Auto Layout size and content-priority helpers in the `.box` namespace.
///
/// These were previously exposed directly on `NSUIView` by the StackView module; they live here now
/// so they're reusable outside of stacks and don't pollute every view's API surface.
extension FrameworkToolbox where Base: NSUIView {
    @discardableResult
    public func size(_ size: CGSize) -> Base {
        self.size(width: size.width, height: size.height)
    }

    @discardableResult
    public func size(_ size: CGFloat) -> Base {
        self.size(width: size, height: size)
    }

    @discardableResult
    public func size(width: CGFloat? = nil, height: CGFloat? = nil, widthPriority: NSUILayoutPriority? = nil, heightPriority: NSUILayoutPriority? = nil) -> Base {
        base.translatesAutoresizingMaskIntoConstraints = false
        if let width {
            let constraint = base.widthAnchor.constraint(equalToConstant: width)
            constraint.isActive = true
            if let widthPriority { constraint.priority = widthPriority }
        }
        if let height {
            let constraint = base.heightAnchor.constraint(equalToConstant: height)
            constraint.isActive = true
            if let heightPriority { constraint.priority = heightPriority }
        }
        return base
    }

    @discardableResult
    public func minSize(_ size: CGSize) -> Base {
        self.minSize(width: size.width, height: size.height)
    }

    @discardableResult
    public func minSize(_ size: CGFloat) -> Base {
        self.minSize(width: size, height: size)
    }

    @discardableResult
    public func minSize(width: CGFloat? = nil, height: CGFloat? = nil, widthPriority: NSUILayoutPriority? = nil, heightPriority: NSUILayoutPriority? = nil) -> Base {
        base.translatesAutoresizingMaskIntoConstraints = false
        if let width {
            let constraint = base.widthAnchor.constraint(greaterThanOrEqualToConstant: width)
            constraint.isActive = true
            if let widthPriority { constraint.priority = widthPriority }
        }
        if let height {
            let constraint = base.heightAnchor.constraint(greaterThanOrEqualToConstant: height)
            constraint.isActive = true
            if let heightPriority { constraint.priority = heightPriority }
        }
        return base
    }

    @discardableResult
    public func maxSize(_ size: CGSize) -> Base {
        self.maxSize(width: size.width, height: size.height)
    }

    @discardableResult
    public func maxSize(_ size: CGFloat) -> Base {
        self.maxSize(width: size, height: size)
    }

    @discardableResult
    public func maxSize(width: CGFloat? = nil, height: CGFloat? = nil, widthPriority: NSUILayoutPriority? = nil, heightPriority: NSUILayoutPriority? = nil) -> Base {
        base.translatesAutoresizingMaskIntoConstraints = false
        if let width {
            let constraint = base.widthAnchor.constraint(lessThanOrEqualToConstant: width)
            constraint.isActive = true
            if let widthPriority { constraint.priority = widthPriority }
        }
        if let height {
            let constraint = base.heightAnchor.constraint(lessThanOrEqualToConstant: height)
            constraint.isActive = true
            if let heightPriority { constraint.priority = heightPriority }
        }
        return base
    }

    @discardableResult
    public func contentHugging(h: NSUILayoutPriority? = nil, v: NSUILayoutPriority? = nil) -> Base {
        if let h {
            base.setContentHuggingPriority(h, for: .horizontal)
        }
        if let v {
            base.setContentHuggingPriority(v, for: .vertical)
        }
        return base
    }

    @discardableResult
    public func contentHugging(h: Float? = nil, v: Float? = nil) -> Base {
        contentHugging(h: h.map { NSUILayoutPriority(rawValue: $0) }, v: v.map { NSUILayoutPriority(rawValue: $0) })
    }

    @discardableResult
    public func contentCompressionResistance(h: NSUILayoutPriority? = nil, v: NSUILayoutPriority? = nil) -> Base {
        if let h {
            base.setContentCompressionResistancePriority(h, for: .horizontal)
        }
        if let v {
            base.setContentCompressionResistancePriority(v, for: .vertical)
        }
        return base
    }

    @discardableResult
    public func contentCompressionResistance(h: Float? = nil, v: Float? = nil) -> Base {
        contentCompressionResistance(h: h.map { NSUILayoutPriority(rawValue: $0) }, v: v.map { NSUILayoutPriority(rawValue: $0) })
    }
}
