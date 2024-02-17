#if canImport(AppKit) && !targetEnvironment(macCatalyst)

import AppKit

open class Button: NSButton {
    public override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        commonInit()
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    private func commonInit() {
        wantsLayer = true
        setup()
    }

    open func setup() {}
}

open class MultipleTargetButton: NSButton {
    public override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        commonInit()
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    private func commonInit() {
        wantsLayer = true
        setup()
    }

    open func setup() {
        target = actionProxy
        action = actionProxy.actionSelector
    }

    open override var target: AnyObject? {
        set {
            if newValue === actionProxy {
                super.target = newValue
            }
        }
        get {
            super.target
        }
    }

    open override var action: Selector? {
        set {
            if newValue == actionProxy.actionSelector {
                super.action = newValue
            }
        }
        get {
            super.action
        }
    }

    private lazy var actionProxy: ActionProxy = .init(owner: self)

    open func addTarget(_ target: AnyObject?, action: Selector?) {
        actionProxy.addForwardTarget(target, action: action, doubleAction: nil)
    }
}

final class ActionProxy<Owner: AnyObject>: NSObject {
    private class Pair {
        weak var target: AnyObject?
        var action: Selector?
        var doubleAction: Selector?
        init() {}
        init(target: AnyObject?, action: Selector?, doubleAction: Selector?) {
            self.target = target
            self.action = action
            self.doubleAction = doubleAction
        }

        deinit {
            target = nil
            action = nil
            doubleAction = nil
        }
    }

    public unowned let owner: Owner
    public let actionSelector: Selector = #selector(ActionProxy.action(_:))
    public init(owner: Owner) {
        self.owner = owner
    }

    private var currentTargetPair: Pair = .init()
    private var forwardTargetPairs: [Pair] = []

    public func addForwardTarget(_ target: AnyObject?, action: Selector?, doubleAction: Selector?) {
        forwardTargetPairs.append(Pair(target: target, action: action, doubleAction: doubleAction))
    }

    @objc private func action(_ sender: Any?) {
        func invoke(_ pair: Pair) {
            guard let action = pair.action else { return }
            if let app = NSApp {
                app.sendAction(action, to: pair.target, from: sender)
            } else {
                _ = pair.target?.perform(action, with: sender)
            }
        }
        invoke(currentTargetPair)
        forwardTargetPairs.forEach(invoke(_:))
    }

    @objc private func doubleAction(_ sender: Any?) {
        func invoke(_ pair: Pair) {
            guard let target = pair.target, let doubleAction = pair.doubleAction else { return }
            if let app = NSApp {
                app.sendAction(doubleAction, to: target, from: sender)
            } else {
                _ = target.perform(doubleAction, with: sender)
            }
        }
        invoke(currentTargetPair)
        forwardTargetPairs.forEach(invoke(_:))
    }
}
#endif
