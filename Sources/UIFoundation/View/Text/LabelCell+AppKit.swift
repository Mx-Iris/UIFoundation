#if canImport(AppKit) && !targetEnvironment(macCatalyst)

import AppKit
import UIFoundationToolbox

open class LabelCell: NSTextFieldCell {
    open var contentInsets: NSEdgeInsets = .box.zero {
        didSet {}
    }

    open override func cellSize(forBounds rect: NSRect) -> NSSize {
        var size = super.cellSize(forBounds: rect)
        size.height += contentInsets.top + contentInsets.bottom
        size.width += contentInsets.left + contentInsets.right
        return size
    }

    open override func drawingRect(forBounds rect: NSRect) -> NSRect {
        let rect = super.drawingRect(forBounds: rect)
        return rect.box.inset(by: contentInsets)
    }

    open override func titleRect(forBounds rect: NSRect) -> NSRect {
        let rect = super.titleRect(forBounds: rect)
        return rect.box.inset(by: contentInsets)
    }

    open override func edit(withFrame rect: NSRect, in controlView: NSView, editor textObj: NSText, delegate: Any?, event: NSEvent?) {
        let insetRect = rect.box.inset(by: contentInsets)
        super.edit(withFrame: insetRect, in: controlView, editor: textObj, delegate: delegate, event: event)
    }

    open override func select(withFrame rect: NSRect, in controlView: NSView, editor textObj: NSText, delegate: Any?, start selStart: Int, length selLength: Int) {
        let insetRect = rect.box.inset(by: contentInsets)
        super.select(withFrame: insetRect, in: controlView, editor: textObj, delegate: delegate, start: selStart, length: selLength)
    }

    open override func drawInterior(withFrame cellFrame: NSRect, in controlView: NSView) {
        let insetRect = cellFrame.box.inset(by: contentInsets)
        super.drawInterior(withFrame: insetRect, in: controlView)
    }
}

#endif
