#if canImport(AppKit) && !targetEnvironment(macCatalyst)

import AppKit
import FrameworkToolbox

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
    
    public func setTarget(_ target: AnyObject, action: Selector) {
        base.target = target
        base.action = action
    }
}

#endif
