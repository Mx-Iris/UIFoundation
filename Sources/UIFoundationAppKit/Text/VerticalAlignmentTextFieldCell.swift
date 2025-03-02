#if canImport(AppKit) && !targetEnvironment(macCatalyst)

import AppKit
import UIFoundationToolbox

open class VerticalAlignmentTextFieldCell: InsetsTextFieldCell {
    
    public enum VerticalAlignment {
        case top
        case center
        case bottom
    }
    
    private var isEditingOrSelecting: Bool = false

    public var verticalAlignment: VerticalAlignment = .center
    
    open override func drawingRect(forBounds theRect: NSRect) -> NSRect {
        // Get the parent's idea of where we should draw
        var newRect: NSRect = super.drawingRect(forBounds: theRect)

        // When the text field is being edited or selected, we have to turn off the magic because it screws up
        // the configuration of the field editor.  We sneak around this by intercepting selectWithFrame and editWithFrame and sneaking a
        // reduced, centered rect in at the last minute.

        if !isEditingOrSelecting {
            // Get our ideal size for current text
            let textSize: NSSize = cellSize(forBounds: theRect)

            // Center in the proposed rect
            let heightDelta: CGFloat = newRect.size.height - textSize.height
            if heightDelta > 0 {
                switch verticalAlignment {
                case .top:
                    break
                case .center:
                    newRect.origin.y += heightDelta / 2
                    newRect.size.height -= heightDelta
                case .bottom:
                    newRect.origin.y = newRect.maxY - heightDelta
                    newRect.size.height -= heightDelta
                }
            }
        }

        return newRect
    }

    open override func select(
        withFrame rect: NSRect,
        in controlView: NSView,
        editor textObj: NSText,
        delegate: Any?,
        start selStart: Int,
        length selLength: Int
    ) // (var aRect: NSRect, inView controlView: NSView, editor textObj: NSText, delegate anObject: AnyObject?, start selStart: Int, length selLength: Int)
    {
        let arect = drawingRect(forBounds: rect)
        isEditingOrSelecting = true
        super.select(withFrame: arect, in: controlView, editor: textObj, delegate: delegate, start: selStart, length: selLength)
        isEditingOrSelecting = false
    }

    open override func edit(
        withFrame rect: NSRect,
        in controlView: NSView,
        editor textObj: NSText,
        delegate: Any?,
        event: NSEvent?
    ) {
        let aRect = drawingRect(forBounds: rect)
        isEditingOrSelecting = true
        super.edit(withFrame: aRect, in: controlView, editor: textObj, delegate: delegate, event: event)
        isEditingOrSelecting = false
    }
}

#endif
