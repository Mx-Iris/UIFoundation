#if canImport(AppKit) && !targetEnvironment(macCatalyst)

import AppKit
import FrameworkToolbox
import AssociatedObject
import FoundationToolbox

extension FrameworkToolbox where Base: NSControl {
    public func heightForWidth(_ width: CGFloat) -> CGFloat {
        base.sizeThatFits(NSSize(width: width, height: CGFloat.greatestFiniteMagnitude)).height
    }

    public var bestHeight: CGFloat {
        base.sizeThatFits(NSSize.box.max).height
    }

    public var bestWidth: CGFloat {
        base.sizeThatFits(NSSize.box.max).width
    }

    public var bestSize: NSSize {
        base.sizeThatFits(NSSize.box.max)
    }
}

extension FrameworkToolbox where Base: NSControl {
    public func setAction(_ action: @escaping (Base?) -> Void) {
        if let actionHandler = base.actionHandler {
            actionHandler.action = {
                action($0 as? Base)
            }
        } else {
            let actionHandler = NSControl.ActionHandler()
            actionHandler.action = {
                action($0 as? Base)
            }
            setTarget(actionHandler, action: #selector(NSControl.ActionHandler.handleAction(_:)))
            base.actionHandler = actionHandler
        }
    }
    
    public func typedCell<Cell: NSCell>() -> Cell? {
        base.cell as? Cell
    }
}

extension NSControl {
    internal class ActionHandler: NSObject {
        var action: ((Any?) -> Void)?

        @objc func handleAction(_ sender: Any?) {
            action?(sender)
        }
    }

    @AssociatedObject(.retain(.nonatomic))
    internal var actionHandler: ActionHandler?
}

#endif
