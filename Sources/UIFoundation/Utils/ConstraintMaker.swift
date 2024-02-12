#if canImport(AppKit) && !targetEnvironment(macCatalyst)
import AppKit
#endif

#if canImport(UIKit)
import UIKit
#endif

extension NSUIView: ConstraintMaker {}

protocol ConstraintMaker: NSUIView {}

extension ConstraintMaker {
    func makeConstraints(@ArrayBuilder<NSLayoutConstraint> _ constraintsBuilder: (_ make: Self) -> [NSLayoutConstraint]) {
        translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate(constraintsBuilder(self))
    }
}
