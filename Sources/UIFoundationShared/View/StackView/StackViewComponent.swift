#if canImport(AppKit) && !targetEnvironment(macCatalyst)
import AppKit
#endif

#if canImport(UIKit)
import UIKit
#endif

import UIFoundationTypealias

public protocol StackViewComponent: NSUIView {}

extension StackViewComponent {
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

    @inlinable
    public func size(_ size: CGSize) -> Self {
        self.size(width: size.width, height: size.height)
    }
}

extension NSUIView: StackViewComponent {}

private var __associated_gravityKey: UInt8 = 0
private var __associated_customSpacingKey: UInt8 = 0

extension StackViewComponent {
    #if canImport(AppKit) && !targetEnvironment(macCatalyst)
    var _gravity: NSStackView.Gravity? {
        get {
            objc_getAssociatedObject(
                self,
                &__associated_gravityKey
            ) as? NSStackView.Gravity?
                ?? nil
        }
        set {
            objc_setAssociatedObject(
                self,
                &__associated_gravityKey,
                newValue,
                .OBJC_ASSOCIATION_COPY
            )
        }
    }

    public func gravity(_ gravity: NSStackView.Gravity) -> Self {
        _gravity = gravity
        return self
    }
    #endif

    var _customSpacing: CGFloat? {
        get {
            objc_getAssociatedObject(
                self,
                &__associated_customSpacingKey
            ) as? CGFloat
        }
        set {
            objc_setAssociatedObject(
                self,
                &__associated_customSpacingKey,
                newValue,
                .OBJC_ASSOCIATION_COPY
            )
        }
    }

    public func customSpacing(_ customSpacing: CGFloat) -> Self {
        _customSpacing = customSpacing
        return self
    }
}
