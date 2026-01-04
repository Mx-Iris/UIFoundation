#if canImport(AppKit) && !targetEnvironment(macCatalyst)
import AppKit
#endif

#if canImport(UIKit)
import UIKit
#endif

import SwiftStdlibToolbox
import UIFoundationTypealias

extension NSUIView: ConstraintMaker {}

public protocol ConstraintMaker: NSUIView {}

extension ConstraintMaker {
    @discardableResult
    public func makeConstraints(@ArrayBuilder<NSLayoutConstraint> _ constraintsBuilder: (_ make: Self) -> [NSLayoutConstraint]) -> [NSLayoutConstraint] {
        translatesAutoresizingMaskIntoConstraints = false
        let constraints = constraintsBuilder(self)
        NSLayoutConstraint.activate(constraints)
        return constraints
    }
}
