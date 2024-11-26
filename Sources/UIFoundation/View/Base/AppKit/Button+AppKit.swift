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
    
    open func removeTarget(_ target: AnyObject?) {
        actionProxy.removeForwardTarget(target)
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

    private var forwardTargetPairs: [AnyHashable: Pair] = [:]
    
    
    public func addForwardTarget(_ target: AnyObject?, action: Selector?, doubleAction: Selector?) {
        let pair = Pair(target: target, action: action, doubleAction: doubleAction)
        if let target {
            let address = Unmanaged.passUnretained(target).toOpaque()
            forwardTargetPairs[address] = pair
        } else {
            forwardTargetPairs[UUID()] = pair
        }
    }

    public func removeForwardTarget(_ target: AnyObject?) {
        if let target {
            let address = Unmanaged.passUnretained(target).toOpaque()
            forwardTargetPairs.removeValue(forKey: address)
        } else {
            forwardTargetPairs.removeAll()
        }
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
        forwardTargetPairs.map(\.value).forEach(invoke(_:))
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
        forwardTargetPairs.map(\.value).forEach(invoke(_:))
    }
}
#endif
