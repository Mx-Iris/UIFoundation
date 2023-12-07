#if canImport(AppKit)

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
}

#endif
