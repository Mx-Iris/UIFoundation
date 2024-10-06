#if canImport(AppKit) && !targetEnvironment(macCatalyst)
import AppKit
#endif

#if canImport(UIKit)
import UIKit
#endif

import UIFoundationTypealias

extension NSUIView: ConstraintMaker {}

public protocol ConstraintMaker: NSUIView {}

extension ConstraintMaker {
    public func makeConstraints(@ArrayBuilder<NSLayoutConstraint> _ constraintsBuilder: (_ make: Self) -> [NSLayoutConstraint]) {
        translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate(constraintsBuilder(self))
    }
}
