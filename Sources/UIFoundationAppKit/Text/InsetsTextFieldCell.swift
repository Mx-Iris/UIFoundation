#if canImport(AppKit) && !targetEnvironment(macCatalyst)

import AppKit
import UIFoundationToolbox

open class InsetsTextFieldCell: NSTextFieldCell {
    open var contentInsets: NSEdgeInsets = .box.zero

    open override func cellSize(forBounds rect: NSRect) -> NSSize {
        super.cellSize(forBounds: rect.box.inset(by: contentInsets))
    }

    open override func drawingRect(forBounds rect: NSRect) -> NSRect {
        super.drawingRect(forBounds: rect.box.inset(by: contentInsets))
    }

    open override func titleRect(forBounds rect: NSRect) -> NSRect {
        super.titleRect(forBounds: rect.box.inset(by: contentInsets))
    }

    open override func edit(withFrame rect: NSRect, in controlView: NSView, editor textObj: NSText, delegate: Any?, event: NSEvent?) {
        super.edit(withFrame: rect.box.inset(by: contentInsets), in: controlView, editor: textObj, delegate: delegate, event: event)
    }

    open override func select(withFrame rect: NSRect, in controlView: NSView, editor textObj: NSText, delegate: Any?, start selStart: Int, length selLength: Int) {
        super.select(withFrame: rect.box.inset(by: contentInsets), in: controlView, editor: textObj, delegate: delegate, start: selStart, length: selLength)
    }

    open override func drawInterior(withFrame cellFrame: NSRect, in controlView: NSView) {
        super.drawInterior(withFrame: rect.box.inset(by: contentInsets), in: controlView)
    }
}

#endif
