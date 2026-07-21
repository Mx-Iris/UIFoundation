//
//  TabButton.swift
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

open class TabButton: NSButton {
    private var closeButton: NSButton?
    private var iconView: NSImageView?
    private var alternativeTitleIconView: NSImageView?
    private var trackingArea: NSTrackingArea?

    private var tabButtonCell: TabButtonCell { cell as! TabButtonCell }

    /// The owning control, used to report hover changes so it can drive its Liquid-Glass decoration.
    weak var tabsControl: TabsControl?

    /// Whether the close button is currently revealed, so repeated mouse-moved events don't restart
    /// its fade animation.
    private var showsCloseButton = false

    /// Set for the duration of the reload that created this button, so an animated layout can open it
    /// out of nothing instead of sliding it in from wherever its frame happened to be.
    var isNewlyInserted = false

    open var item: Any? {
        get { cell?.representedObject }
        set { cell?.representedObject = newValue }
    }

    open var style: TabsControl.Style {
        didSet { tabButtonCell.style = style }
    }

    /// The button is aware of its last known index in the tab bar.
    var index: Int

    open var buttonPosition: TabsControl.TabPosition {
        get { tabButtonCell.buttonPosition }
        set { tabButtonCell.buttonPosition = newValue }
    }

    open var representedObject: Any? {
        get { tabButtonCell.representedObject }
        set { tabButtonCell.representedObject = newValue }
    }

    open var editable: Bool {
        get { tabButtonCell.isEditable }
        set { tabButtonCell.isEditable = newValue }
    }

    var closeTarget: AnyObject?

    var closeAction: Selector?

    open var closePosition: TabsControl.ClosePosition? {
        didSet { tabButtonCell.closePosition = closePosition }
    }

    open var closeIcon: NSImage? {
        didSet {
            if closeIcon != nil && closeButton == nil {
                let closeButton = NSButton()
                closeButton.isBordered = false
                closeButton.target = self
                closeButton.action = #selector(closeButtonAction)
                closeButton.alphaValue = 0
                addSubview(closeButton)
                self.closeButton = closeButton
            } else if closeIcon == nil, closeButton != nil {
                closeButton?.removeFromSuperview()
                closeButton = nil
            }
            closeButton?.image = closeIcon
            needsDisplay = true
        }
    }

    open var icon: NSImage? {
        didSet {
            if icon != nil && iconView == nil {
                let iconView = NSImageView(frame: .zero)
                iconView.imageFrameStyle = .none
                addSubview(iconView)
                self.iconView = iconView
            } else if icon == nil && iconView != nil {
                iconView?.removeFromSuperview()
                iconView = nil
            }
            iconView?.image = icon
            needsDisplay = true
        }
    }

    open var alternativeTitleIcon: NSImage? {
        didSet {
            tabButtonCell.hasTitleAlternativeIcon = (alternativeTitleIcon != nil)

            if alternativeTitleIcon != nil && alternativeTitleIconView == nil {
                let alternativeTitleIconView = NSImageView(frame: .zero)
                alternativeTitleIconView.imageFrameStyle = .none
                addSubview(alternativeTitleIconView)
                self.alternativeTitleIconView = alternativeTitleIconView
            } else if alternativeTitleIcon == nil && alternativeTitleIconView != nil {
                alternativeTitleIconView?.removeFromSuperview()
                alternativeTitleIconView = nil
            }
            alternativeTitleIconView?.image = alternativeTitleIcon
            needsDisplay = true
        }
    }

    // MARK: - Init

    @available(*, unavailable)
    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    init(index: Int, item: Any?, target: AnyObject?, action: Selector?, style: TabsControl.Style) {
        self.index = index
        self.style = style
        let tabButtonCell = TabButtonCell(textCell: "", style: style)
        super.init(frame: .zero)

        tabButtonCell.representedObject = item
        tabButtonCell.imagePosition = .noImage

        tabButtonCell.target = target
        tabButtonCell.action = action

        tabButtonCell.sendAction(on: .leftMouseDown)
        self.cell = tabButtonCell
    }

    open override func copy() -> Any {
        let copy = TabButton(index: index, item: nil, target: nil, action: nil, style: style)
        copy.frame = frame
        copy.cell = cell?.copy() as? NSCell
        copy.icon = icon
        copy.closeIcon = closeIcon
        copy.closePosition = closePosition
        copy.closeTarget = closeTarget
        copy.closeAction = closeAction
        copy.alternativeTitleIcon = alternativeTitleIcon
        copy.state = state
        return copy
    }

    open override var menu: NSMenu? {
        get { cell?.menu }
        set {
            cell?.menu = newValue
            updateTrackingAreas()
        }
    }

    // MARK: - Drawing

    open override func updateTrackingAreas() {
        if let trackingArea = trackingArea {
            removeTrackingArea(trackingArea)
        }

        let item = cell?.representedObject

        let userInfo: [String: Any]? = item.map { ["item": $0] }

        let trackingArea = NSTrackingArea(
            rect: bounds,
            // `.mouseMoved` lets the owning control re-evaluate hover as the pointer crosses into or
            // out of a stacking region within a single tab.
            options: [.mouseEnteredAndExited, .mouseMoved, .activeInActiveApp, .inVisibleRect],
            owner: self,
            userInfo: userInfo
        )
        self.trackingArea = trackingArea

        addTrackingArea(trackingArea)

        if let window = window, let event = NSApp.currentEvent {
            let mouseLocation = window.mouseLocationOutsideOfEventStream
            let convertedMouseLocation = convert(mouseLocation, from: nil)

            if bounds.contains(convertedMouseLocation) {
                mouseEntered(with: event)
            } else {
                mouseExited(with: event)
            }
        }

        super.updateTrackingAreas()
    }

    open override func mouseMoved(with event: NSEvent) {
        updateHover(true)
    }

    open override func mouseEntered(with theEvent: NSEvent) {
        needsDisplay = true
        updateHover(true)
    }

    open override func mouseExited(with theEvent: NSEvent) {
        needsDisplay = true
        updateHover(false)
    }

    /// Hover affordances are decided by the owning control, which knows whether the pointer is over a
    /// stacking pile (where the tab underneath must stay inert). Standalone buttons decide for themselves.
    private func updateHover(_ isHovered: Bool) {
        if let tabsControl {
            tabsControl.tabButton(self, didChangeHover: isHovered)
        } else {
            setShowsCloseButton(isHovered)
        }
    }

    /// The close button fades on its own clock in the system tab bar: `-[NSTabButton
    /// initWithFrame:tabBarViewItem:]` registers a dedicated 0.16 s `alphaValue` animation on it,
    /// distinct from the 0.15 s the surrounding relayout uses.
    private static let closeButtonFadeDuration: TimeInterval = 0.16

    /// Reveals or hides the hover affordances — currently the close button.
    func setShowsCloseButton(_ shows: Bool) {
        guard shows != showsCloseButton else { return }
        showsCloseButton = shows
        NSAnimationContext.runAnimationGroup { context in
            context.duration = Self.closeButtonFadeDuration
            closeButton?.animator().alphaValue = shows ? 1 : 0
        }
    }

    open override func mouseDown(with theEvent: NSEvent) {
        super.mouseDown(with: theEvent)
        if isEnabled == false {
            NSSound.beep()
        }
    }

    open override func resetCursorRects() {
        addCursorRect(bounds, cursor: NSCursor.arrow)
    }

    open override func draw(_ dirtyRect: NSRect) {
        let scale: CGFloat = (layer != nil) ? layer!.contentsScale : 1.0
        if let closePosition {
            let closeButtonFrame = style.closeButtonFrame(tabRect: bounds, atPosition: closePosition)
            closeButton?.frame = closeButtonFrame
            if let closeIcon, closeIcon.size.width > closeButtonFrame.height * scale {
                let smallIcon = NSImage(size: closeButtonFrame.size)
                smallIcon.addRepresentation(NSBitmapImageRep(data: closeIcon.tiffRepresentation!)!)
                closeButton?.image = smallIcon
            }
        }
        let iconFrames = style.iconFrames(tabRect: bounds, closePosition: closePosition)
        iconView?.frame = iconFrames.iconFrame
        alternativeTitleIconView?.frame = iconFrames.alternativeTitleIconFrame

        if let icon, icon.size.width > (iconFrames.iconFrame).height * scale {
            let smallIcon = NSImage(size: iconFrames.iconFrame.size)
            smallIcon.addRepresentation(NSBitmapImageRep(data: icon.tiffRepresentation!)!)
            iconView?.image = smallIcon
        }

        if let alternativeTitleIcon, alternativeTitleIcon.size.width > (iconFrames.alternativeTitleIconFrame).height * scale {
            let smallIcon = NSImage(size: iconFrames.alternativeTitleIconFrame.size)
            smallIcon.addRepresentation(NSBitmapImageRep(data: alternativeTitleIcon.tiffRepresentation!)!)
            alternativeTitleIconView?.image = smallIcon
        }

        let hasRoom = tabButtonCell.hasRoomToDrawFullTitle(inRect: bounds)
        alternativeTitleIconView?.isHidden = hasRoom
        toolTip = (hasRoom == true) ? nil : title

        super.draw(dirtyRect)
    }

    // MARK: - Editing

    func edit(fieldEditor: NSText, delegate: NSTextDelegate) {
        tabButtonCell.edit(fieldEditor: fieldEditor, inView: self, delegate: delegate)
    }

    func finishEditing(fieldEditor: NSText, newValue: String) {
        tabButtonCell.finishEditing(fieldEditor: fieldEditor, newValue: newValue)
    }

    @objc func closeButtonAction() {
        if let closeAction, let closeTarget {
            NSApp.sendAction(closeAction, to: closeTarget, from: self)
        }
    }
}

#endif
