#if FilterUI && os(macOS)

import AppKit
import ObjectiveC

/// The cell interface for AppKit filter fields with token capabilities.
@objcMembers open class FilterTokenFieldCell: NSTokenFieldCell, NSTokenFieldCellDelegate, FilterTokenTextStorageDelegate, NSLayoutManagerDelegate {
    public static var representedObjectKey: UInt8 = 0
    public static let wildCardPattern = try! NSRegularExpression(pattern: ".+\\*.+|^\\*.+\\*$")

    public override init(textCell string: String) {
        super.init(textCell: string)
        delegate = self
        font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        self.placeholderString = nil
        isScrollable = true
    }

    @available(*, unavailable)
    public required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Layout

    open override func drawingRect(forBounds rect: NSRect) -> NSRect {
        var rect = super.drawingRect(forBounds: rect)
        // rect.origin.y += stringValue.isEmpty ? 1 : 0
        rect.origin.x += 28 + 3
        rect.origin.y += 1
        rect.size.width -= 28 + 3 + 21
        return rect
    }

    //  open override func edit(withFrame rect: NSRect, in controlView: NSView, editor textObj: NSText, delegate: Any?, event: NSEvent?) {
//    super.edit(withFrame: rect.offsetBy(dx: 0, dy: 1), in: controlView, editor: textObj, delegate: delegate, event: event)
    //  }
//
    //  open override func select(withFrame rect: NSRect, in controlView: NSView, editor textObj: NSText, delegate: Any?, start selStart: Int, length selLength: Int) {
//    super.select(withFrame: rect.offsetBy(dx: 0, dy: 1), in: controlView, editor: textObj, delegate: delegate, start: selStart, length: selLength)
    //  }

    // MARK: - Drawing

    open override var placeholderString: String? {
        didSet { placeholderAttributedString = FilterSearchFieldCell.placeholderAttributedString(for: self) }
    }

    open override func drawFocusRingMask(withFrame cellFrame: NSRect, in controlView: NSView) {}

    open override func draw(withFrame cellFrame: NSRect, in controlView: NSView) {
        FilterSearchFieldCell.drawBackground(
            withFrame: cellFrame,
            in: controlView,
            hasActiveFilter: !stringValue.isEmpty
        )

        // drawInterior(withFrame: cellFrame.insetBy(dx: 0, dy: 1), in: controlView)
        drawInterior(withFrame: cellFrame, in: controlView)

        // if stringValue.isEmpty, controlView.window?.firstResponder == (controlView as? NSControl)?.currentEditor() {
        //   placeholderAttributedString?.draw(in: titleRect(forBounds: cellFrame.insetBy(dx: 0, dy: 1)))
        // }
    }

    // MARK: - Field Cell Delegate

    // public func tokenFieldCell(_ tokenFieldCell: NSTokenFieldCell, shouldAdd tokens: [Any], at index: Int) -> [Any] {
    //   return tokens
    // }

    public func tokenFieldCell(_ tokenFieldCell: NSTokenFieldCell, displayStringForRepresentedObject representedObject: Any) -> String? {
        (representedObject as? FilterTokenValue)?.objectValue as? String
    }

    public func tokenFieldCell(_ tokenFieldCell: NSTokenFieldCell, editingStringForRepresentedObject representedObject: Any) -> String? {
        guard let value = representedObject as? FilterTokenValue else { return nil }
        return value.objectValue as? String
    }

    public func tokenFieldCell(_ tokenFieldCell: NSTokenFieldCell, representedObjectForEditing editingString: String) -> Any? {
        // let hasKeyboardFocus = controlView?.window?.firstResponder == (controlView as? NSControl)?.currentEditor()
        let editingString = editingString.trimmingCharacters(in: .whitespacesAndNewlines)
        if Self.wildCardPattern.numberOfMatches(in: editingString, range: NSMakeRange(0, editingString.count)) > 0 {
            return FilterTokenValue(objectValue: editingString, comparisonType: nil)
        } else if editingString.hasPrefix("*") {
            return FilterTokenValue(objectValue: String(editingString.dropFirst()), comparisonType: .endsWith)
        } else if editingString.hasSuffix("*") {
            return FilterTokenValue(objectValue: String(editingString.dropLast()), comparisonType: .beginsWith)
        } else {
            return FilterTokenValue(objectValue: editingString, comparisonType: .contains)
            // return editingString
        }
    }

    public func tokenFieldCell(_ tokenFieldCell: NSTokenFieldCell, readFrom pboard: NSPasteboard) -> [Any]? {
        pboard.readObjects(forClasses: [FilterTokenValue.self])
    }

    public func tokenFieldCell(_ tokenFieldCell: NSTokenFieldCell, writeRepresentedObjects objects: [Any], to pboard: NSPasteboard) -> Bool {
        pboard.clearContents()
        if let objects = objects as? [NSPasteboardWriting] {
            return pboard.writeObjects(objects)
        } else {
            return false
        }
    }

    public func tokenFieldCell(_ tokenFieldCell: NSTokenFieldCell, menuForRepresentedObject representedObject: Any) -> NSMenu? {
        guard let value = representedObject as? FilterTokenValue else { return nil }

        let menu = NSMenu()
        menu.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        for type in FilterTokenComparisonType.allCases {
            let item = menu.addItem(
                withTitle: type.displayName,
                action: #selector(FilterTokenField.takeComparisonTypeFromSender(_:)),
                keyEquivalent: ""
            )
            item.tag = type.rawValue
            item.state = type == value.comparisonType ? .on : .off
            item.representedObject = representedObject
        }
        menu.autoenablesItems = false
        return menu
    }

    public func tokenFieldCell(_ tokenFieldCell: NSTokenFieldCell, hasMenuForRepresentedObject representedObject: Any) -> Bool {
        representedObject is FilterTokenValue
    }

    public func tokenFieldCell(_ tokenFieldCell: NSTokenFieldCell, styleForRepresentedObject representedObject: Any) -> NSTokenField.TokenStyle {
        representedObject is String ? .none : .squared
    }

    // MARK: - Text Storage Delegate

    public func tokenTextStorage(_ textStorage: FilterTokenTextStorage, updateTokenAttachment attachment: NSTextAttachment, forRange range: NSRange) {
        if (attachment.attachmentCell as? NSCell)?.representedObject is FilterTokenValue {
            updateTokenAttachment(attachment, forAttributedString: textStorage.attributedSubstring(from: range))
        }
    }

    // MARK: - Attachment Cells

    open override var attributedStringValue: NSAttributedString {
        get {
            let attrString = super.attributedStringValue
            attrString.enumerateAttribute(.attachment, in: NSMakeRange(0, attrString.length)) { [self] attachment, range, _ in
                if let attachment = attachment as? NSTextAttachment {
                    updateTokenAttachment(attachment, forAttributedString: attrString.attributedSubstring(from: range))
                }
            }
            return attrString
        }
        set {
            // print(NSApp.currentEvent?.type == .keyDown && NSApp.currentEvent?.keyCode == .return)
            let attrString = newValue
            attrString.enumerateAttribute(.attachment, in: NSMakeRange(0, attrString.length)) { [self] attachment, range, _ in
                if let attachment = attachment as? NSTextAttachment {
                    updateTokenAttachment(attachment, forAttributedString: attrString.attributedSubstring(from: range))
                }
            }
            super.attributedStringValue = attrString
        }
//    set {
//      var objects = [Any?]()
//      newValue.enumerateAttribute(.attachment, in: NSMakeRange(0, newValue.length)) { attachment, range, _ in
//        if let attachment = attachment as? NSTextAttachment {
//          //objects.append(representedObjectWithAttachment(attachment, attributedString: newValue.attributedSubstring(from: range)))
//          objects.append((attachment.attachmentCell as? NSCell)?.representedObject)
//        }
//      }
//      objectValue = objects
//    }
    }

    open override func setUpFieldEditorAttributes(_ textObj: NSText) -> NSText {
        let textObj = super.setUpFieldEditorAttributes(textObj)

        if let textView = textObj as? NSTextView, let layoutManager = textView.textContainer?.layoutManager {
            if let textStorage = layoutManager.textStorage, !(textStorage is FilterTokenTextStorage) {
                let newTextStorage = FilterTokenTextStorage(textStorage: textStorage)
                layoutManager.replaceTextStorage(newTextStorage)
            }

            (layoutManager.textStorage as? FilterTokenTextStorage)?.tokenDelegate = self

            // textView.wantsLayer = true
            // textView.layer?.borderWidth = 1
            // textView.layer?.borderColor = NSColor.systemPink.withAlphaComponent(0.2).cgColor
            // textView.setValue(nil, forKey: "placeholderAttributedString")
        }

        return textObj
    }

    //  public func layoutManager(
//    _ layoutManager: NSLayoutManager,
//    shouldSetLineFragmentRect lineFragmentRect: UnsafeMutablePointer<NSRect>,
//    lineFragmentUsedRect: UnsafeMutablePointer<NSRect>,
//    baselineOffset: UnsafeMutablePointer<CGFloat>,
//    in textContainer: NSTextContainer,
//    forGlyphRange glyphRange: NSRange
    //  ) -> Bool {
//    //let lineHeightMultiple: CGFloat = 1.6
//    let fontLineHeight = layoutManager.defaultLineHeight(for: font!)
//    let lineHeight = fontLineHeight + 1
//    let baselineNudge = (lineHeight - fontLineHeight)
//    // The following factor is a result of experimentation:
//    * 0.6
//
//    var rect = lineFragmentRect.pointee
//    rect.size.height = lineHeight
//
//    var usedRect = lineFragmentUsedRect.pointee
//    usedRect.size.height = max(lineHeight, usedRect.size.height) // keep emoji sizes
//
//    lineFragmentRect.pointee = rect
//    lineFragmentUsedRect.pointee = usedRect
//    baselineOffset.pointee = baselineOffset.pointee + baselineNudge
//
//    return true
    //  }

    open override func endEditing(_ textObj: NSText) {
        if let textView = textObj as? NSTextView, let layoutManager = textView.textContainer?.layoutManager {
            (layoutManager.textStorage as? FilterTokenTextStorage)?.tokenDelegate = nil
        }

        super.endEditing(textObj)
    }

    func updateTokenAttachment(_ attachment: NSTextAttachment, forAttributedString attrString: NSAttributedString) {
        guard objc_getAssociatedObject(attachment, &Self.representedObjectKey) == nil else { return }
        guard let cell = attachment.attachmentCell as? NSCell else { return }

        let object = representedObjectWithAttachment(attachment, attributedString: attrString)
        objc_setAssociatedObject(attachment, &Self.representedObjectKey, object, .OBJC_ASSOCIATION_RETAIN)

        let newCell = FilterTokenAttachmentCell()
        newCell.font = font
        newCell.menu = cell.menu
        newCell.objectValue = cell.objectValue
        newCell.representedObject = cell.representedObject
        newCell.attachment = attachment
        attachment.attachmentCell = newCell
    }

    func representedObjectWithAttachment(_ attachment: NSTextAttachment, attributedString attrString: NSAttributedString) -> Any? {
        if let object = objc_getAssociatedObject(attachment, &Self.representedObjectKey) {
            return object as? FilterTokenValue
        }

        let cell = NSTokenFieldCell()
        cell.attributedStringValue = attrString
        return (cell.objectValue as? NSArray)?.firstObject ?? attrString.string
    }
}

#endif
