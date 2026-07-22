//
//  TabButtonCell.swift
//  UIFoundation
//
//  Ported into UIFoundation from KPCTabsControl
//  (https://github.com/onekiloparsec/KPCTabsControl) by Cédric Foellmi
//  and Christian Tietze.
//
//  MIT License — Copyright (c) 2014-2016 Cédric Foellmi
//

#if TabsControl && os(macOS)

import AppKit

let titleMargin: CGFloat = 5.0

final class TabButtonCell: NSButtonCell {
    var hasTitleAlternativeIcon: Bool = false

    var isSelected: Bool { state == .on }

    var selectionState: TabsControl.SelectionState {
        isEnabled == false ? .unselectable : (isSelected ? .selected : .normal)
    }

    var showsIcon: Bool { (controlView as? TabButton)?.icon != nil }

    var showsMenu: Bool { (menu?.items.count ?? 0) > 0 }

    var buttonPosition: TabsControl.TabPosition = .middle {
        didSet { controlView?.needsDisplay = true }
    }

    var closePosition: TabsControl.ClosePosition?

    /// The width the title and icon are laid out against, when the tab is narrower than that.
    ///
    /// `-[NSTabButton setButtonWidthForTitleLayout:]`. A stacked tab is squeezed far below its natural
    /// width, and the system keeps laying its contents out against the *full* tab width regardless,
    /// letting the tab clip whatever no longer fits. A tab compressed to a sliver therefore shows no
    /// text at all, rather than a title truncated down to an ellipsis. Measured on a real `NSTabBar`:
    /// a 9 pt-wide tab still carries its full 33 pt title, sitting at x = 63.5 — entirely outside it.
    var titleLayoutWidth: CGFloat?

    /// Which edge of the tab the ``titleLayoutWidth`` box is pinned to.
    ///
    /// The `-setAlignment:` `NSTabBar` passes each button as it lays out a stacked bar: the frontmost
    /// tab centres its contents, a tab piled up *before* it pins them to its leading edge and one
    /// piled up after it to its trailing edge. Measured with the sixth of fourteen tabs selected, the
    /// title sits at +59.5, +57.5, +54.5, +51.5 through the leading pile and at −58.0, −56.5, −16.5
    /// through the trailing one — pushed out of sight on the side each pile folds towards.
    var titleLayoutAnchor: TabsControl.TitleAnchor = .center

    var style: TabsControl.Style

    // MARK: - Initializers & Copy

    init(textCell string: String, style: TabsControl.Style) {
        self.style = style
        super.init(textCell: string)

        self.isBordered = true
        self.backgroundStyle = .light
        self.highlightsBy = .changeBackgroundCellMask
        self.lineBreakMode = .byTruncatingTail
        self.focusRingType = .none
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func copy() -> Any {
        let copy = TabButtonCell(textCell: title, style: style)

        copy.hasTitleAlternativeIcon = hasTitleAlternativeIcon
        copy.buttonPosition = buttonPosition
        copy.closePosition = closePosition
        copy.state = state
        copy.isHighlighted = isHighlighted

        return copy
    }

    // MARK: - Properties & Rects

    static func popupImage() -> NSImage {
        guard let url = Bundle.module.url(forResource: "PullDownTemplate", withExtension: "pdf", subdirectory: "Templates"),
              let image = NSImage(contentsOf: url) else {
            assertionFailure("TabsControl: missing bundled resource PullDownTemplate.pdf")
            return NSImage()
        }
        return image.imageWithTint(NSColor.darkGray)
    }

    func hasRoomToDrawFullTitle(inRect rect: NSRect) -> Bool {
        let title = style.attributedTitle(content: self.title, selectionState: selectionState)
        let requiredMinimumWidth = title.size().width + 2.0 * titleMargin
        let titleDrawRect = titleRect(forBounds: rect)
        return titleDrawRect.width >= requiredMinimumWidth
    }

    override func cellSize(forBounds aRect: NSRect) -> NSSize {
        let title = style.attributedTitle(content: self.title, selectionState: selectionState)
        let titleSize = title.size()
        let popupSize = (menu == nil) ? NSSize.zero : TabButtonCell.popupImage().size
        let cellSize = NSSize(width: titleSize.width + (popupSize.width * 2) + 36, height: max(titleSize.height, popupSize.height))
        controlView?.invalidateIntrinsicContentSize()
        return cellSize
    }

    override func trackMouse(with theEvent: NSEvent,
                             in cellFrame: NSRect,
                             of controlView: NSView,
                             untilMouseUp flag: Bool) -> Bool {
        if hitTest(
            for: theEvent,
            in: controlView.superview!.frame,
            of: controlView.superview!
        ) != [] {
            let popupRect = style.popupRectWithFrame(cellFrame, closePosition: closePosition)
            let location = controlView.convert(theEvent.locationInWindow, from: nil)

            if (menu?.items.count ?? 0) > 0 && popupRect.contains(location) {
                menu?.popUp(
                    positioning: menu!.items.first,
                    at: NSPoint(x: popupRect.midX, y: popupRect.maxY),
                    in: controlView
                )

                return true
            }
        }

        return super.trackMouse(with: theEvent, in: cellFrame, of: controlView, untilMouseUp: flag)
    }

    override func titleRect(forBounds theRect: NSRect) -> NSRect {
        let title = style.attributedTitle(content: self.title, selectionState: selectionState)
        return style.titleRect(title: title, inBounds: theRect, showingIcon: showsIcon, showingMenu: showsMenu, closePosition: closePosition)
    }

    // MARK: - Editing

    func edit(fieldEditor: NSText, inView view: NSView, delegate: NSTextDelegate) {
        isHighlighted = true

        let frame = editingRectForBounds(view.bounds)
        select(
            withFrame: frame,
            in: view,
            editor: fieldEditor,
            delegate: delegate,
            start: 0,
            length: 0
        )

        fieldEditor.drawsBackground = false
        fieldEditor.isHorizontallyResizable = true
        fieldEditor.isEditable = true

        let editorSettings = style.titleEditorSettings()
        fieldEditor.font = editorSettings.font
        fieldEditor.alignment = editorSettings.alignment
        fieldEditor.textColor = editorSettings.textColor

        // Replace content so that resizing is triggered.
        fieldEditor.string = ""
        fieldEditor.insertText(title ?? "")
        fieldEditor.selectAll(self)

        title = ""
    }

    func finishEditing(fieldEditor: NSText, newValue: String) {
        endEditing(fieldEditor)
        title = newValue
    }

    func editingRectForBounds(_ rect: NSRect) -> NSRect {
        return titleRect(forBounds: rect)
    }

    // MARK: - Drawing

    /// The rectangle the tab's contents are laid out in, which is the tab itself until stacking
    /// squeezes it — see ``titleLayoutWidth``. Anything falling outside the tab is clipped away by
    /// the control's own drawing, exactly as the system's pill clips its content view.
    func contentLayoutRect(forBounds bounds: NSRect) -> NSRect {
        guard let titleLayoutWidth, titleLayoutWidth > bounds.width else { return bounds }

        let originX: CGFloat
        switch titleLayoutAnchor {
        case .leading:
            originX = bounds.minX
        case .center:
            originX = bounds.midX - titleLayoutWidth / 2.0
        case .trailing:
            originX = bounds.maxX - titleLayoutWidth
        }
        return NSRect(x: originX, y: bounds.minY, width: titleLayoutWidth, height: bounds.height)
    }

    override func draw(withFrame frame: NSRect, in controlView: NSView) {
        style.drawTabButtonBezel(frame: frame, position: buttonPosition, isSelected: isSelected)

        let contentFrame = contentLayoutRect(forBounds: frame)
        if hasRoomToDrawFullTitle(inRect: contentFrame) || hasTitleAlternativeIcon == false {
            let title = style.attributedTitle(content: self.title, selectionState: selectionState)
            _ = drawTitle(title, withFrame: contentFrame, in: controlView)
        }

        if showsMenu {
            drawPopupButtonWithFrame(frame)
        }
    }

    override func drawTitle(_ title: NSAttributedString, withFrame frame: NSRect, in controlView: NSView) -> NSRect {
        let titleRect = self.titleRect(forBounds: frame)
        title.draw(in: titleRect)
        return titleRect
    }

    fileprivate func drawPopupButtonWithFrame(_ frame: NSRect) {
        let image = TabButtonCell.popupImage()
        image.draw(
            in: style.popupRectWithFrame(frame, closePosition: closePosition),
            from: .zero,
            operation: .sourceOver,
            fraction: 1.0,
            respectFlipped: true,
            hints: nil
        )
    }
}

#endif
