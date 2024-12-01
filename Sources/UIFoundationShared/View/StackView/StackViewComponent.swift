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
    public func size(width: CGFloat? = nil, height: CGFloat? = nil) -> Self {
        translatesAutoresizingMaskIntoConstraints = false
        if let width {
            widthAnchor.constraint(equalToConstant: width).isActive = true
        }
        if let height {
            heightAnchor.constraint(equalToConstant: height).isActive = true
        }
        return self
    }

    @discardableResult
    public func size(_ size: CGSize) -> Self {
        self.size(width: size.width, height: size.height)
    }

    @discardableResult
    public func size(_ size: CGFloat) -> Self {
        self.size(width: size, height: size)
    }
}

extension NSUIView: StackViewComponent {}

private var __associated_gravityKey: UInt8 = 0
private var __associated_customSpacingKey: UInt8 = 0

extension StackViewComponent {
    #if canImport(AppKit) && !targetEnvironment(macCatalyst)
    @AssociatedObject(.copy(.nonatomic))
    var _gravity: NSStackView.Gravity?

    @discardableResult
    public func gravity(_ gravity: NSStackView.Gravity) -> Self {
        _gravity = gravity
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
