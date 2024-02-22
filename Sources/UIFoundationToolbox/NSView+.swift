#if canImport(AppKit)

import AppKit
import FrameworkToolbox

extension FrameworkToolbox where Base: NSView {
    
    public func scrollPageDown() {
        base.scroll(base.visibleRect.box.moved(dy: base.visibleRect.height).origin)
    }

    public func scrollPageUp() {
        base.scroll(base.visibleRect.box.moved(dy: -base.visibleRect.height).origin)
    }

    public func scrollToBeginningOfDocument() {
        base.scroll(CGPoint(x: base.visibleRect.origin.x, y: base.frame.minY))
    }

    public func scrollToEndOfDocument() {
        base.scroll(CGPoint(x: base.visibleRect.origin.x, y: base.frame.maxY))
    }
    
}

#endif
