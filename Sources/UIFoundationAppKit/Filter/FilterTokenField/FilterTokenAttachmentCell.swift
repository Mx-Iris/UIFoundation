#if FilterUI

import AppKit

@preconcurrency @objcMembers open class FilterTokenAttachmentCell: NSTextAttachmentCell {
    open var isSelected = false

    public var filterToken: FilterTokenValue? { representedObject as? FilterTokenValue }
    public var hasMenu: Bool { filterToken?.comparisonType != nil }

    // MARK: - Layout

    open override func cellBaselineOffset() -> NSPoint {
        NSMakePoint(0, (font?.descender ?? 0))
    }

    open override func cellSize() -> NSSize {
        let textSize = attributedTitle(for: attributedStringValue).size()
        return NSMakeSize(textSize.width.rounded() + (hasMenu ? 12 + 1 : 0) + 3 * 2 + 2 * 2, 15)
    }

    func menuChevronRect(forBounds rect: NSRect) -> NSRect {
        NSMakeRect(rect.minX + 1, rect.minY, 14, 15)
    }

    open override func titleRect(forBounds rect: NSRect) -> NSRect {
        NSMakeRect(rect.minX + 2 + (hasMenu ? 12 + 1 : 0) + 3, rect.minY, rect.width - (hasMenu ? 12 + 1 : 0) - 3 * 2 - 2, rect.height).integral
    }

    // open override func drawingRect(forBounds rect: NSRect) -> NSRect {
    //   rect.offsetBy(dx: 0, dy: 2)
    // }

    // MARK: - Drawing

    func tokenFillColor(named name: String, for controlView: NSView) -> NSColor {
        var color = NSColor(named: isSelected ? "tokenSelectedColor" : name, bundle: .module)!
        let isKeyOrMainWindow = controlView.window?.isKeyWindow == true || controlView.window?.isMainWindow == true
        if !isKeyOrMainWindow { color = color.withAlphaComponent(0.5) }
        return color
    }

    open override func draw(withFrame cellFrame: NSRect, in controlView: NSView?, characterIndex charIndex: Int, layoutManager: NSLayoutManager) {
        if let selectedRanges = (controlView as? NSTextView)?.selectedRanges {
            isSelected = selectedRanges.contains { $0.rangeValue.contains(charIndex) }
        } else {
            isSelected = false
        }

        // let isFirstResponder = controlView?.window?.firstResponder == controlView
        // drawInterior(withFrame: cellFrame.offsetBy(dx: 0, dy: isFirstResponder ? 0 : 1), in: controlView ?? NSView())
        // drawInterior(withFrame: cellFrame.offsetBy(dx: isFirstResponder ? 0, dy: 1), in: controlView ?? NSView())
        // drawInterior(withFrame: cellFrame.offsetBy(dx: 0, dy: 1), in: controlView ?? NSView())
        drawInterior(withFrame: cellFrame, in: controlView ?? NSView())
    }

    open override func draw(withFrame cellFrame: NSRect, in controlView: NSView?, characterIndex charIndex: Int) {
        drawInterior(withFrame: cellFrame, in: controlView ?? NSView())
    }

    open override func draw(withFrame cellFrame: NSRect, in controlView: NSView?) {
        drawInterior(withFrame: cellFrame, in: controlView ?? NSView())
    }

    open override func drawInterior(withFrame cellFrame: NSRect, in controlView: NSView) {
        // NSDottedFrameRect(cellFrame)
        drawBackground(withFrame: cellFrame, in: controlView)
        drawMenuChevron(withFrame: cellFrame, in: controlView)
        drawTitle(withFrame: cellFrame.integral, in: controlView)
    }

    func drawBackground(withFrame cellFrame: NSRect, in controlView: NSView) {
        var (keyRect, valueRect) = cellFrame.divided(atDistance: hasMenu ? 14 : 0, from: .minXEdge)
        if hasMenu { valueRect.origin.x += 1; valueRect.size.width -= 1 }

        NSGraphicsContext.current?.saveGraphicsState()
        keyRect.clip()
        tokenFillColor(named: "tokenRegularKeyColor", for: controlView).setFill()
        NSBezierPath(roundedRect: cellFrame.insetBy(dx: 2, dy: 0), xRadius: 2, yRadius: 2).fill()
        NSGraphicsContext.current?.restoreGraphicsState()

        NSGraphicsContext.current?.saveGraphicsState()
        valueRect.clip()
        tokenFillColor(named: "tokenRegularValueColor", for: controlView).setFill()
        NSBezierPath(roundedRect: cellFrame.insetBy(dx: 2, dy: 0), xRadius: 2, yRadius: 2).fill()
        NSGraphicsContext.current?.restoreGraphicsState()
    }

    func drawMenuChevron(withFrame cellFrame: NSRect, in controlView: NSView) {
        guard hasMenu, #available(macOS 11.0, *) else { return }
        guard let image = NSImage(systemSymbolName: "chevron.down", accessibilityDescription: nil)?
            .withSymbolConfiguration(NSImage.SymbolConfiguration(pointSize: 6, weight: .bold, scale: .medium))?
            .tinted(with: isSelected ? .alternateSelectedControlTextColor : .controlTextColor) else { return }

        image.draw(in: image.size.centered(in: menuChevronRect(forBounds: cellFrame)).integral)
    }

    func drawTitle(withFrame cellFrame: NSRect, in controlView: NSView) {
        var primaryColor = isSelected ? NSColor.alternateSelectedControlTextColor : NSColor.controlTextColor
        var secondaryColor = isSelected ? NSColor.alternateSelectedControlTextColor : NSColor.secondaryLabelColor
        let isKeyOrMainWindow = controlView.window?.isKeyWindow == true || controlView.window?.isMainWindow == true
        if !isKeyOrMainWindow { primaryColor = primaryColor.withAlphaComponent(0.5) }
        if !isKeyOrMainWindow { secondaryColor = secondaryColor.withAlphaComponent(0.5) }

        let string = NSAttributedString(string: stringValue, attributes: [.font: font!, .foregroundColor: primaryColor])
        attributedTitle(for: string, foregroundColor: secondaryColor).draw(in: titleRect(forBounds: cellFrame))
    }

    func attributedTitle(for string: NSAttributedString, foregroundColor color: NSColor = .clear) -> NSAttributedString {
        let string = NSMutableAttributedString(attributedString: string)
        switch filterToken?.comparisonType {
        case .doesNotContain: string.insert(NSAttributedString(string: "≠ ", attributes: [.foregroundColor: color]), at: 0)
        case .beginsWith: string.append(NSAttributedString(string: " ···", attributes: [.foregroundColor: color]))
        case .endsWith: string.insert(NSAttributedString(string: "··· ", attributes: [.foregroundColor: color]), at: 0)
        default: break
        }
        return string
    }

    // MARK: - Menu

    open override func wantsToTrackMouse(for theEvent: NSEvent, in cellFrame: NSRect, of controlView: NSView?, atCharacterIndex charIndex: Int) -> Bool {
        guard let controlView else { return false }

        let location = controlView.convert(theEvent.locationInWindow, from: nil)
        if menuChevronRect(forBounds: cellFrame).contains(location) {
            return true
        } else if drawingRect(forBounds: cellFrame).contains(location), theEvent.type == .rightMouseDown {
            return true
        }

        return super.wantsToTrackMouse(for: theEvent, in: cellFrame, of: controlView, atCharacterIndex: charIndex)
    }

    open override func trackMouse(with theEvent: NSEvent, in cellFrame: NSRect, of controlView: NSView?, untilMouseUp flag: Bool) -> Bool {
        guard let controlView else { return false }

        let location = controlView.convert(theEvent.locationInWindow, from: nil)
        if menuChevronRect(forBounds: cellFrame).contains(location), let menu {
            return menu.popUp(positioning: nil, at: NSMakePoint(cellFrame.minX, -menu.size.height + 3), in: controlView)
        } else if drawingRect(forBounds: cellFrame).contains(location), theEvent.type == .rightMouseDown, let menu {
            return menu.popUp(positioning: nil, at: NSMakePoint(cellFrame.minX, -menu.size.height + 3), in: controlView)
        }

        return super.trackMouse(with: theEvent, in: cellFrame, of: controlView, untilMouseUp: flag)
    }
}

#endif
