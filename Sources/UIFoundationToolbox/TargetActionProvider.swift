//
//  TargetActionProvider.swift
//  UIFoundation
//
//  Created by JH on 12/8/24.
//

import Foundation
import FoundationToolbox
import FrameworkToolbox
import AssociatedObject

/// An object with a target and action.
public protocol TargetActionProvider: NSObject {
    /// The action handler of the object.
    typealias ActionBlock = (Self) -> Void
    var target: AnyObject? { get set }
    var action: Selector? { get set }
}

class ActionTrampoline<T: TargetActionProvider>: NSObject {
    var action: (T) -> Void

    init(action: @escaping (T) -> Void) {
        self.action = action
    }

    @objc func invoke(_ sender: NSObject) {
        guard let sender = sender as? T else { return }
        action(sender)
    }
}

extension FrameworkToolbox where Base: TargetActionProvider {
    /// The action handler of the object.
    public var actionBlock: Base.ActionBlock? {
        nonmutating set {
            if let newValue = newValue {
                actionTrampoline = ActionTrampoline(action: newValue)
                base.target = actionTrampoline
                base.action = #selector(ActionTrampoline<Base>.invoke(_:))
            } else {
                actionTrampoline = nil
                if base.action == #selector(ActionTrampoline<Base>.invoke(_:)) {
                    base.action = nil
                }
            }
        }
        get { actionTrampoline?.action }
    }

    /// Sets the action handler of the object.
    @discardableResult
    public func action(_ action: Base.ActionBlock?) -> Base {
        actionBlock = action
        return base
    }

    var actionTrampoline: ActionTrampoline<Base>? {
        get { getAssociatedValue("actionTrampoline") }
        nonmutating set { setAssociatedValue(newValue, key: "actionTrampoline") }
    }

    /// Performs the `action`.
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
