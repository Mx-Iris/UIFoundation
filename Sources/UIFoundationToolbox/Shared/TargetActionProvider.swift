import Foundation
import FoundationToolbox
import FrameworkToolbox
import AssociatedObject

public protocol TargetActionProvider: NSObject {
    typealias ActionBlock = (Self) -> Void
    var target: AnyObject? { get set }
    var action: Selector? { get set }
}

final class ActionTrampoline<T: TargetActionProvider>: NSObject {
    var action: (T) -> Void

    init(action: @escaping (T) -> Void) {
        self.action = action
    }

    @objc func invoke(_ sender: NSObject) {
        guard let sender = sender as? T else { return }
        action(sender)
    }
}

extension NSObject {
    /// The trampoline `box.actionBlock` installs as the target, retained here because `target` is weak.
    /// Declared on `NSObject` because the macro in an extension of `TargetActionProvider` itself is a
    /// circular reference; `FrameworkToolbox.actionTrampoline` restores the type.
    @AssociatedObject(.retain(.nonatomic))
    fileprivate var targetActionTrampoline: NSObject?
}

extension FrameworkToolbox where Base: TargetActionProvider, Base: NSObject {
    /// The action handler of the object.
    public var actionBlock: Base.ActionBlock? {
        nonmutating set {
            if let newValue = newValue {
                base.actionTrampoline = ActionTrampoline(action: newValue)
                base.target = base.actionTrampoline
                base.action = #selector(ActionTrampoline<Base>.invoke(_:))
            } else {
                base.actionTrampoline = nil
                if base.action == #selector(ActionTrampoline<Base>.invoke(_:)) {
                    base.action = nil
                }
            }
        }
        get { base.actionTrampoline?.action }
    }

    /// Sets the action handler of the object.
    @discardableResult
    public func action(_ action: Base.ActionBlock?) -> Base {
        actionBlock = action
        return base
    }

    var actionTrampoline: ActionTrampoline<Base>? {
        get { base.targetActionTrampoline as? ActionTrampoline<Base> }
        set { base.targetActionTrampoline = newValue }
    }

    public func performAction() {
        if let actionBlock = actionBlock {
            actionBlock(base)
        } else if let action = base.action, let target = base.target, target.responds(to: action) {
            _ = target.perform(action)
        }
    }

    public func setTarget(_ target: AnyObject?, action: Selector?) {
        base.target = target
        base.action = action
    }
}

#if canImport(AppKit) && !targetEnvironment(macCatalyst)

import AppKit

extension NSControl: TargetActionProvider {}
extension NSCell: TargetActionProvider {}
extension NSToolbarItem: TargetActionProvider {}
extension NSMenuItem: TargetActionProvider {}
extension NSGestureRecognizer: TargetActionProvider {}
extension NSColorPanel: TargetActionProvider {
    public var action: Selector? {
        get { nil }
        set { setAction(newValue) }
    }

    /// The target object that receives action messages from the color panel.
    public var target: AnyObject? {
        get { value(forKey: "target") as? AnyObject }
        set { setTarget(newValue) }
    }
}

extension TargetActionProvider where Self: NSGestureRecognizer {
    /// Initializes the gesture recognizer with the specified action handler.
    public init(action: @escaping ActionBlock) {
        self.init()
        self.actionBlock = action
    }
}

extension TargetActionProvider where Self: NSCell {
    /// Initializes the cell with the specified action handler.
    public init(action: @escaping ActionBlock) {
        self.init()
        self.actionBlock = action
    }
}

#endif
