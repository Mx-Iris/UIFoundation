#if canImport(AppKit) && !targetEnvironment(macCatalyst)
import AppKit
#endif

#if canImport(UIKit)
import UIKit
#endif

import UIFoundationTypealias
import AssociatedObject

public protocol StackViewComponent: NSUIView {}

// MARK: - Deprecated size helpers (moved to the `.box` namespace)

extension StackViewComponent {
    @available(*, deprecated, message: "Use `.box.size(_:)` instead.")
    @discardableResult
    @inlinable
    public func size(_ size: CGSize) -> Self {
        self.size(width: size.width, height: size.height)
    }

    @available(*, deprecated, message: "Use `.box.size(_:)` instead.")
    @discardableResult
    @inlinable
    public func size(_ size: CGFloat) -> Self {
        self.size(width: size, height: size)
    }

    @available(*, deprecated, message: "Use `.box.minSize(_:)` instead.")
    @discardableResult
    @inlinable
    public func minSize(_ size: CGSize) -> Self {
        self.minSize(width: size.width, height: size.height)
    }

    @available(*, deprecated, message: "Use `.box.minSize(_:)` instead.")
    @discardableResult
    @inlinable
    public func minSize(_ size: CGFloat) -> Self {
        self.minSize(width: size, height: size)
    }

    @available(*, deprecated, message: "Use `.box.maxSize(_:)` instead.")
    @discardableResult
    @inlinable
    public func maxSize(_ size: CGSize) -> Self {
        self.maxSize(width: size.width, height: size.height)
    }

    @available(*, deprecated, message: "Use `.box.maxSize(_:)` instead.")
    @discardableResult
    @inlinable
    public func maxSize(_ size: CGFloat) -> Self {
        self.maxSize(width: size, height: size)
    }

    @available(*, deprecated, message: "Use `.box.size(width:height:widthPriority:heightPriority:)` instead.")
    @discardableResult
    public func size(width: CGFloat? = nil, height: CGFloat? = nil, widthPriority: NSUILayoutPriority? = nil, heightPriority: NSUILayoutPriority? = nil) -> Self {
        translatesAutoresizingMaskIntoConstraints = false
        if let width {
            widthAnchor.constraint(equalToConstant: width).do {
                $0.isActive = true
                if let widthPriority {
                    $0.priority = widthPriority
                }
            }
        }
        if let height {
            heightAnchor.constraint(equalToConstant: height).do {
                $0.isActive = true
                if let heightPriority {
                    $0.priority = heightPriority
                }
            }
        }
        return self
    }

    @available(*, deprecated, message: "Use `.box.minSize(width:height:widthPriority:heightPriority:)` instead.")
    @discardableResult
    public func minSize(width: CGFloat? = nil, height: CGFloat? = nil, widthPriority: NSUILayoutPriority? = nil, heightPriority: NSUILayoutPriority? = nil) -> Self {
        translatesAutoresizingMaskIntoConstraints = false
        if let width {
            widthAnchor.constraint(greaterThanOrEqualToConstant: width).do {
                $0.isActive = true
                if let widthPriority {
                    $0.priority = widthPriority
                }
            }
        }
        if let height {
            heightAnchor.constraint(greaterThanOrEqualToConstant: height).do {
                $0.isActive = true
                if let heightPriority {
                    $0.priority = heightPriority
                }
            }
        }
        return self
    }

    @available(*, deprecated, message: "Use `.box.maxSize(width:height:widthPriority:heightPriority:)` instead.")
    @discardableResult
    public func maxSize(width: CGFloat? = nil, height: CGFloat? = nil, widthPriority: NSUILayoutPriority? = nil, heightPriority: NSUILayoutPriority? = nil) -> Self {
        translatesAutoresizingMaskIntoConstraints = false
        if let width {
            widthAnchor.constraint(lessThanOrEqualToConstant: width).do {
                $0.isActive = true
                if let widthPriority {
                    $0.priority = widthPriority
                }
            }
        }
        if let height {
            heightAnchor.constraint(lessThanOrEqualToConstant: height).do {
                $0.isActive = true
                if let heightPriority {
                    $0.priority = heightPriority
                }
            }
        }
        return self
    }
}

extension NSUIView: StackViewComponent {}

// MARK: - Stack-specific per-component modifiers

// Associated storage backing the `.stackView` per-component modifiers (see `StackViewNamespace`).
// Setters are module-internal (no `private(set)`) so the namespace wrapper in another file can
// mutate them. Read back during stack assembly in `StackView.swift`.
extension StackViewComponent {
    #if canImport(AppKit) && !targetEnvironment(macCatalyst)
    @usableFromInline
    @AssociatedObject(.copy(.nonatomic))
    var _gravity: NSStackView.Gravity?

    @available(*, deprecated, message: "Use `stackView.gravity(_:)` instead.")
    @discardableResult
    @inlinable
    public func gravity(_ gravity: NSStackView.Gravity) -> Self {
        _gravity = gravity
        return self
    }

    @usableFromInline
    @AssociatedObject(.copy(.nonatomic))
    var _visibilityPriority: NSStackView.VisibilityPriority?

    @available(*, deprecated, message: "Use `stackView.visibilityPriority(_:)` instead.")
    @discardableResult
    @inlinable
    public func visibilityPriority(_ visibilityPriority: NSStackView.VisibilityPriority) -> Self {
        _visibilityPriority = visibilityPriority
        return self
    }

    #endif

    @usableFromInline
    @AssociatedObject(.copy(.nonatomic))
    var _customSpacing: CGFloat?

    @available(*, deprecated, message: "Use `stackView.customSpacing(_:)` instead.")
    @discardableResult
    @inlinable
    public func customSpacing(_ customSpacing: CGFloat) -> Self {
        _customSpacing = customSpacing
        return self
    }

    @usableFromInline
    @AssociatedObject(.copy(.nonatomic))
    var _fillsCrossAxis: Bool?

    @available(*, deprecated, message: "Use `stackView.fill()` instead.")
    @discardableResult
    @inlinable
    public func fill() -> Self {
        _fillsCrossAxis = true
        return self
    }
}
