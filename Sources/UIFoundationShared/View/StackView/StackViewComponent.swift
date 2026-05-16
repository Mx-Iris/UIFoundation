#if canImport(AppKit) && !targetEnvironment(macCatalyst)
import AppKit
#endif

#if canImport(UIKit)
import UIKit
#endif

import UIFoundationTypealias
import AssociatedObject

public protocol StackViewComponent: NSUIView {}

extension StackViewComponent {
    @discardableResult
    public func size(_ size: CGSize) -> Self {
        self.size(width: size.width, height: size.height)
    }

    @discardableResult
    public func size(_ size: CGFloat) -> Self {
        self.size(width: size, height: size)
    }
    
    @discardableResult
    public func minSize(_ size: CGSize) -> Self {
        self.minSize(width: size.width, height: size.height)
    }

    @discardableResult
    public func minSize(_ size: CGFloat) -> Self {
        self.minSize(width: size, height: size)
    }
    
    @discardableResult
    public func maxSize(_ size: CGSize) -> Self {
        self.maxSize(width: size.width, height: size.height)
    }

    @discardableResult
    public func maxSize(_ size: CGFloat) -> Self {
        self.maxSize(width: size, height: size)
    }

    @discardableResult
    func size(width: CGFloat? = nil, height: CGFloat? = nil, widthPriority: NSUILayoutPriority? = nil, heightPriority: NSUILayoutPriority? = nil) -> Self {
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

    @discardableResult
    func minSize(width: CGFloat? = nil, height: CGFloat? = nil, widthPriority: NSUILayoutPriority? = nil, heightPriority: NSUILayoutPriority? = nil) -> Self {
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

    @discardableResult
    func maxSize(width: CGFloat? = nil, height: CGFloat? = nil, widthPriority: NSUILayoutPriority? = nil, heightPriority: NSUILayoutPriority? = nil) -> Self {
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

extension StackViewComponent {
    #if canImport(AppKit) && !targetEnvironment(macCatalyst)
    @AssociatedObject(.copy(.nonatomic))
    var _gravity: NSStackView.Gravity?

    @discardableResult
    public func gravity(_ gravity: NSStackView.Gravity) -> Self {
        _gravity = gravity
        return self
    }

    @AssociatedObject(.copy(.nonatomic))
    var _visibilityPriority: NSStackView.VisibilityPriority?

    @discardableResult
    public func visibilityPriority(_ visibilityPriority: NSStackView.VisibilityPriority) -> Self {
        _visibilityPriority = visibilityPriority
        return self
    }

    #endif

    @AssociatedObject(.copy(.nonatomic))
    var _customSpacing: CGFloat?

    @discardableResult
    public func customSpacing(_ customSpacing: CGFloat) -> Self {
        _customSpacing = customSpacing
        return self
    }
}
