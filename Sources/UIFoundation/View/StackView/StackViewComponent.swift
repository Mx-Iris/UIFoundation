#if canImport(AppKit) && !targetEnvironment(macCatalyst)
import AppKit
#endif

#if canImport(UIKit)
import UIKit
#endif



public protocol StackViewComponent: _NSUIView {}

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

extension _NSUIView: StackViewComponent {}
