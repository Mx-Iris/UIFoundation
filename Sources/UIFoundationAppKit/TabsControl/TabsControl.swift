//
//  TabsControl.swift
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

/// `TabsControl` is the main class of the component, and is designed to suffice for implementing tabs in your app.
/// The only necessary thing for it to work is an implementation of its `dataSource`.
open class TabsControl: NSControl, NSTextDelegate {
    private var delegateInterceptor = TabsControlDelegateInterceptor()

    private lazy var scrollView = TabsScrollView(frame: bounds)
    private lazy var tabsView = NSView(frame: scrollView.bounds)

    private var editingTab: (title: String, button: TabButton)?

    private lazy var tabsControlCell = TabsControlCell(textCell: "")

    /// The Liquid-Glass decoration manager, created only while the current ``style`` opts into
    /// ``TabsControl/Style/controlDecoration`` (e.g. ``TabsControl/SystemStyle``).
    private var decorator: SystemTabDecorator?

    /// The capsule-shaped Liquid-Glass bar background, created only while the current ``style``
    /// requests it via ``TabsControl/ControlDecoration/showsBarTrack``.
    private var barTrackView: SystemBarTrackView?

    /// The index of the tab currently under the mouse, used to drive the hover pill and to hide
    /// separators adjacent to the hovered tab.
    private var hoveredButtonIndex: Int?

    /// The stacked-layout geometry for the current scroll offset, or `nil` while the tabs still fit
    /// and are laid out evenly. Recomputed on every layout pass, so it always matches what is on screen.
    private var stackingGeometry: StackingGeometry?

    /// Whether the tabs are currently stacked into piles rather than evenly divided.
    public var isStacking: Bool { stackingGeometry != nil }

    /// Guards against re-entrancy: laying out resizes the document view, which can feed back through
    /// the clip view's bounds-changed notification.
    private var isLayingOutTabButtons = false

    // MARK: - Data Source & Delegate

    /// The data source of the tabs control, providing all the necessary information for the class to build the tabs.
    @IBOutlet open weak var dataSource: DataSource?

    /// The delegate of the tabs control, providing additional possibilities for customization and precise behavior.
    @IBOutlet open weak var delegate: Delegate? {
        get { delegateInterceptor.receiver as? Delegate }
        set { delegateInterceptor.receiver = newValue as? NSObject }
    }

    // MARK: - Styling

    open var style: Style = DefaultStyle() {
        didSet {
            tabsControlCell.style = style
            tabButtons.forEach { $0.style = self.style }
            configureDecorator()
            updateTabs()
        }
    }

    /// Creates or tears down the ``decorator`` and the bar track to match whether the current
    /// ``style`` opts into control-level Liquid-Glass decoration.
    private func configureDecorator() {
        guard let decoration = style.controlDecoration else {
            decorator?.remove()
            decorator = nil
            barTrackView?.removeFromSuperview()
            barTrackView = nil
            return
        }

        if decorator == nil {
            decorator = SystemTabDecorator(container: tabsView)
        }

        if decoration.showsBarTrack {
            if barTrackView == nil {
                let track = SystemBarTrackView(frame: bounds)
                track.autoresizingMask = [.width, .height]
                addSubview(track, positioned: .below, relativeTo: scrollView)
                barTrackView = track
            }
        } else {
            barTrackView?.removeFromSuperview()
            barTrackView = nil
        }
    }

    // MARK: - Initializers & Setup

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    public override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    private func setup() {
        wantsLayer = true
        translatesAutoresizingMaskIntoConstraints = false
        cell = tabsControlCell
        configureSubviews()
    }

    private func configureSubviews() {
        scrollView.drawsBackground = false
        scrollView.hasHorizontalScroller = false
        scrollView.hasVerticalScroller = false
        scrollView.usesPredominantAxisScrolling = true
        scrollView.horizontalScrollElasticity = .allowed
        scrollView.verticalScrollElasticity = .none
        scrollView.autoresizingMask = [.width, .height]
        scrollView.translatesAutoresizingMaskIntoConstraints = true

        tabsView.autoresizingMask = [.width, .height]
        scrollView.documentView = tabsView

        addSubview(scrollView)

        startObservingScrollView()
    }

    deinit {
        self.stopObservingScrollView()
    }

    // MARK: - Public Overrides

    open override func menu(for event: NSEvent) -> NSMenu? {
        return nil
    }

    // MARK: - Data Source

    /// Reloads all tabs of the tabs control. Used when the `dataSource` has changed for instance.
    open func reloadTabs() {
        reloadTabs(animated: false)
    }

    /// Reloads all tabs, optionally animating the change.
    ///
    /// When animated, existing tabs slide to their new slots and freshly inserted tabs fade in — a
    /// newly created button has no previous frame to travel from, so animating its frame would make
    /// it fly in from the origin.
    open func reloadTabs(animated: Bool) {
        guard let dataSource = dataSource else { return }

        let oldItemsCount = self.tabButtons.count
        let newItemsCount = dataSource.tabsControlNumberOfTabs(self)

        if newItemsCount < oldItemsCount {
            self.tabButtons.filter { $0.index >= newItemsCount }.forEach { $0.removeFromSuperview() }
        }

        let tabButtons = self.tabButtons
        var insertedButtons: [TabButton] = []
        for i in 0 ..< newItemsCount {
            let item = dataSource.tabsControl(self, itemAtIndex: i)

            var button: TabButton
            if i >= oldItemsCount {
                button = TabButton(
                    index: i,
                    item: item,
                    target: self,
                    action: #selector(TabsControl.selectTab(_:)),
                    style: style
                )
                button.isNewlyInserted = true
                insertedButtons.append(button)

                button.wantsLayer = true
                button.state = .off
                tabsView.addSubview(button)
            } else {
                button = tabButtons[i]
            }

            button.index = i
            button.item = item
            button.tabsControl = self

            button.editable = delegate?.tabsControl?(self, canEditTitleOfItem: item) == true
            button.buttonPosition = TabPosition.fromIndex(i, totalCount: newItemsCount)
            button.style = style

            button.title = dataSource.tabsControl(self, titleForItem: item)
            button.icon = dataSource.tabsControl?(self, iconForItem: item)
            button.menu = dataSource.tabsControl?(self, menuForItem: item)
            if let canClose = delegate?.tabsControl?(self, canCloseItem: item), canClose {
                button.closeIcon = dataSource.tabsControl?(self, closeIconForItem: item)
                button.closePosition = dataSource.tabsControl?(self, closePositionForItem: item)
                button.closeTarget = self
                button.closeAction = #selector(TabsControl.closeTab(_:))
            } else {
                button.closeIcon = nil
                button.closePosition = nil
                button.closeTarget = nil
                button.closeAction = nil
            }
            button.alternativeTitleIcon = dataSource.tabsControl?(self, titleAlternativeIconForItem: item)
        }

        layoutTabButtons(nil, animated: animated)
        if animated {
            animateInsertion(of: insertedButtons)
        }
        insertedButtons.forEach { $0.isNewlyInserted = false }
        invalidateRestorableState()
    }

    /// Fades freshly inserted tabs in. Tabs that the layout collapsed into a stacking pile are left
    /// alone — they are meant to be invisible.
    private func animateInsertion(of buttons: [TabButton]) {
        let visibleButtons = buttons.filter { $0.alphaValue > 0.0 }
        guard !visibleButtons.isEmpty else { return }

        visibleButtons.forEach { $0.alphaValue = 0.0 }
        NSAnimationContext.runAnimationGroup { context in
            // Matches the system tab bar's layout animation duration.
            context.duration = 0.15
            visibleButtons.forEach { $0.animator().alphaValue = 1.0 }
        }
    }

    // MARK: - Layout

    private func updateTabs(animated: Bool = false) {
        layoutTabButtons(nil, animated: animated)
        invalidateRestorableState()
    }

    private func layoutTabButtons(_ buttons: [TabButton]?, animated: Bool) {
        guard !isLayingOutTabButtons else { return }
        isLayingOutTabButtons = true
        defer { isLayingOutTabButtons = false }

        let tabButtons = buttons ?? tabButtons

        if let geometry = makeStackingGeometry(for: tabButtons) {
            stackingGeometry = geometry
            layoutStackedTabButtons(tabButtons, geometry: geometry, animated: animated)
        } else {
            stackingGeometry = nil
            layoutUnstackedTabButtons(tabButtons, animated: animated)
        }
    }

    /// Builds the stacking geometry when the current style allows stacking and the tabs no longer fit
    /// at their minimum width. Returns `nil` while the tabs still fit, in which case the classic
    /// evenly-divided layout is used.
    private func makeStackingGeometry(for tabButtons: [TabButton]) -> StackingGeometry? {
        guard let decoration = style.controlDecoration, decoration.allowsStacking else { return nil }
        guard tabButtons.count > 1 else { return nil }

        let minimumWidth = decoration.minimumTabWidth
        let visibleWidth = max(0.0, scrollView.frame.width - 2.0 * decoration.barContentInset)
        guard visibleWidth > 0.0, visibleWidth < minimumWidth * CGFloat(tabButtons.count) else { return nil }

        return StackingGeometry(
            tabCount: tabButtons.count,
            tabWidth: minimumWidth,
            visibleWidth: visibleWidth,
            scrollOffset: scrollView.contentView.bounds.origin.x,
            barHeight: tabsView.frame.height,
            frontmostIndex: selectedButtonIndex
        )
    }

    /// Places the tabs using the stacked geometry. Offsets from ``StackingGeometry`` are viewport
    /// relative, so the scroll offset is added back to express them in the scrolling document's
    /// coordinate space — the tabs then appear pinned to the viewport as it scrolls.
    private func layoutStackedTabButtons(_ tabButtons: [TabButton], geometry: StackingGeometry, animated: Bool) {
        let contentInset = style.controlDecoration?.barContentInset ?? 0.0
        let documentOrigin = contentInset + geometry.scrollOffset

        for (index, button) in tabButtons.enumerated() {
            let layout = geometry.layout(at: index)
            var buttonFrame = layout.frame
            buttonFrame.origin.x += documentOrigin

            button.layer?.zPosition = geometry.zPosition(at: index)

            let alpha: CGFloat = layout.isCollapsed ? 0.0 : 1.0
            if animated && !button.isHidden && !button.isNewlyInserted {
                button.animator().frame = buttonFrame
                button.animator().alphaValue = alpha
            } else {
                button.frame = buttonFrame
                button.alphaValue = alpha
            }

            if let selectable = delegate?.tabsControl?(self, canSelectItem: button.representedObject!) {
                button.isEnabled = selectable
            }
        }

        // The document is always the full un-stacked width so the scroll range stays correct.
        let viewFrame = CGRect(
            x: 0.0,
            y: 0.0,
            width: 2.0 * contentInset + geometry.contentWidth,
            height: geometry.barHeight
        )
        if tabsView.frame != viewFrame {
            tabsView.frame = viewFrame
        }

        if let decoration = style.controlDecoration {
            decorator?.update(
                buttons: tabButtons,
                selectedIndex: selectedButtonIndex,
                hoveredIndex: hoveredButtonIndex,
                decoration: decoration
            )
        }
    }

    private func layoutUnstackedTabButtons(_ tabButtons: [TabButton], animated: Bool) {
        var tabsViewWidth = CGFloat(0.0)

        // Decorating styles inset the tabs so their pills clear the rounded ends of the bar track.
        let contentInset = style.controlDecoration?.barContentInset ?? 0.0
        let availableWidth = max(0.0, scrollView.frame.width - 2.0 * contentInset)
        let fullWidth = tabButtons.isEmpty ? 0.0 : availableWidth / CGFloat(tabButtons.count)
        let buttonHeight = tabsView.frame.height

        var buttonWidth = CGFloat(0)
        switch style.tabButtonWidth {
        case .full:
            buttonWidth = fullWidth
        case let .flexible(minWidth, maxWidth):
            buttonWidth = max(minWidth, min(maxWidth, fullWidth))
        case let .fixed(width):
            buttonWidth = width
        }

        var buttonX = contentInset
        for (index, button) in tabButtons.enumerated() {
            let offset = style.tabButtonOffset(position: button.buttonPosition)
            let buttonFrame = CGRect(x: buttonX + offset.x, y: offset.y, width: buttonWidth, height: buttonHeight)
            buttonX += buttonWidth + offset.x

            // A modest finite depth, not `greatestFiniteMagnitude`: decoration sits just behind its
            // button at `zPosition - 0.5`, and at 1e38 that offset is lost to float precision, which
            // would let the glass composite *over* the title and blur it.
            button.layer?.zPosition = button.state == NSControl.StateValue.on ? 1000.0 : CGFloat(index)

            // Tabs may have been faded out by a previous stacked layout.
            button.alphaValue = 1.0

            if animated && !button.isHidden && !button.isNewlyInserted {
                button.animator().frame = buttonFrame
            } else {
                button.frame = buttonFrame
            }

            if let selectable = delegate?.tabsControl?(self, canSelectItem: button.representedObject!) {
                button.isEnabled = selectable
            }

            tabsViewWidth += buttonWidth
        }

        let contentWidth = contentInset > 0.0 ? (buttonX + contentInset) : tabsViewWidth
        let viewFrame = CGRect(x: 0.0, y: 0.0, width: contentWidth, height: buttonHeight)
        if animated {
            tabsView.animator().frame = viewFrame
        } else {
            tabsView.frame = viewFrame
        }

        if let decoration = style.controlDecoration {
            decorator?.update(
                buttons: tabButtons,
                selectedIndex: selectedButtonIndex,
                hoveredIndex: hoveredButtonIndex,
                decoration: decoration
            )
        }
    }

    /// Called by a ``TabButton`` when the mouse enters or leaves it, so the decoration can move its
    /// hover pill and refresh separator visibility. No-op unless the current ``style`` decorates.
    func tabButton(_ button: TabButton, didChangeHover isHovered: Bool) {
        // A pointer resting on a pile targets the pile, not whichever tab happens to lie beneath it:
        // no hover highlight and no close button. Matches the system, which clears the hovered index
        // whenever the point falls in a stacking region. A tab collapsed into a pile never hovers.
        var effectiveHover = isHovered
        if isHovered {
            if button.alphaValue <= 0.0 {
                effectiveHover = false
            } else if let geometry = stackingGeometry, let window {
                let localPoint = convert(window.mouseLocationOutsideOfEventStream, from: nil)
                if !stackingRegion(at: localPoint, geometry: geometry).isEmpty {
                    effectiveHover = false
                }
            }
        }

        button.setShowsCloseButton(effectiveHover)

        let newHoveredIndex: Int?
        if effectiveHover {
            newHoveredIndex = button.index
        } else {
            newHoveredIndex = (hoveredButtonIndex == button.index) ? nil : hoveredButtonIndex
        }

        guard newHoveredIndex != hoveredButtonIndex else { return }
        hoveredButtonIndex = newHoveredIndex

        guard let decoration = style.controlDecoration else { return }
        decorator?.update(
            buttons: tabButtons,
            selectedIndex: selectedButtonIndex,
            hoveredIndex: hoveredButtonIndex,
            decoration: decoration
        )
    }

    // MARK: - Stacking Interaction

    /// The pile, if any, that a point in the control's own coordinate space lands on.
    private func stackingRegion(at localPoint: NSPoint, geometry: StackingGeometry) -> StackingRegion {
        let regions = geometry.stackingRegions(selectedIndex: selectedButtonIndex)
        guard !regions.isEmpty else { return [] }

        let contentInset = style.controlDecoration?.barContentInset ?? 0.0
        let viewportX = localPoint.x - contentInset

        var selectedFrame: NSRect?
        if let selected = selectedButtonIndex, selected >= 0, selected < tabButtons.count {
            selectedFrame = geometry.layout(at: selected).frame
        }

        return geometry.region(atViewportX: viewportX, existingRegions: regions, selectedFrame: selectedFrame)
    }

    open override func hitTest(_ point: NSPoint) -> NSView? {
        guard let geometry = stackingGeometry else { return super.hitTest(point) }

        let localPoint = convert(point, from: superview)
        guard bounds.contains(localPoint) else { return super.hitTest(point) }

        // A click on a pile scrolls the bar open instead of selecting whichever tab happens to be
        // under the pointer, matching -[NSTabBar hitTest:].
        if !stackingRegion(at: localPoint, geometry: geometry).isEmpty { return self }

        // Stacked tabs overlap, and NSView hit-tests in subview order rather than by `zPosition`,
        // so the visually topmost tab has to be resolved explicitly.
        let pointInTabs = tabsView.convert(localPoint, from: self)
        let candidates = tabButtons.filter { $0.alphaValue > 0.0 && $0.frame.contains(pointInTabs) }
        if let topmost = candidates.max(by: { ($0.layer?.zPosition ?? 0.0) < ($1.layer?.zPosition ?? 0.0) }) {
            return topmost.hitTest(pointInTabs) ?? topmost
        }

        return super.hitTest(point)
    }

    open override func mouseDown(with event: NSEvent) {
        guard let geometry = stackingGeometry else {
            super.mouseDown(with: event)
            return
        }

        let localPoint = convert(event.locationInWindow, from: nil)
        let region = stackingRegion(at: localPoint, geometry: geometry)
        guard !region.isEmpty else {
            super.mouseDown(with: event)
            return
        }

        scrollStack(to: geometry.scrollTarget(for: region))
    }

    /// Animates the bar to a new scroll offset, expanding the pile that was clicked.
    private func scrollStack(to offset: CGFloat) {
        let clipView = scrollView.contentView
        let target = NSPoint(x: offset, y: clipView.bounds.origin.y)

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.25
            context.allowsImplicitAnimation = true
            clipView.animator().setBoundsOrigin(target)
        }
        scrollView.reflectScrolledClipView(clipView)
    }

    // MARK: - ScrollView Observation

    private func startObservingScrollView() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(TabsControl.scrollViewDidScroll(_:)),
            name: NSView.frameDidChangeNotification,
            object: scrollView
        )

        // Stacked layout is a function of the scroll offset, so every scroll has to re-run it.
        // This mirrors -[NSTabBar _clipViewBoundsChanged:].
        scrollView.contentView.postsBoundsChangedNotifications = true
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(TabsControl.clipViewBoundsDidChange(_:)),
            name: NSView.boundsDidChangeNotification,
            object: scrollView.contentView
        )
    }

    private func stopObservingScrollView() {
        NotificationCenter.default.removeObserver(
            self,
            name: NSView.frameDidChangeNotification,
            object: scrollView
        )
        NotificationCenter.default.removeObserver(
            self,
            name: NSView.boundsDidChangeNotification,
            object: scrollView.contentView
        )
    }

    @objc private func scrollViewDidScroll(_ notification: Notification) {
        layoutTabButtons(nil, animated: false)
        invalidateRestorableState()
    }

    @objc private func clipViewBoundsDidChange(_ notification: Notification) {
        guard isStacking else { return }
        layoutTabButtons(nil, animated: false)
    }

    // MARK: - Reordering

    private func reorderTab(_ tab: TabButton, withEvent event: NSEvent) {
        var orderedTabs = tabButtons
        let tabX = tab.frame.minX
        let dragPoint = tabsView.convert(event.locationInWindow, from: nil)

        var prevPoint = dragPoint
        var reordered = false

        let draggingTab = tab.copy() as! TabButton
        addSubview(draggingTab)
        tab.isHidden = true

        var temporarySelectedButtonIndex = selectedButtonIndex!
        while true {
            guard let event = window?.nextEvent(matching: [.leftMouseUp, .leftMouseDragged]) else { break }

            if event.type == .leftMouseUp {
                NSAnimationContext.current.completionHandler = { [self] in
                    draggingTab.removeFromSuperview()
                    tab.isHidden = false

                    if reordered == true {
                        let items = orderedTabs.compactMap { $0.representedObject }
                        delegate?.tabsControl?(self, didReorderItems: items)
                    }

                    reloadTabs()
                    invalidateRestorableState()
                    selectedButtonIndex = temporarySelectedButtonIndex
                }
                draggingTab.animator().frame = tab.frame
                break
            }

            let nextPoint = tabsView.convert(event.locationInWindow, from: nil)
            let nextX = tabX + (nextPoint.x - dragPoint.x)

            var r = draggingTab.frame
            r.origin.x = nextX
            draggingTab.frame = r

            let movingLeft = (nextPoint.x < prevPoint.x)
            prevPoint = nextPoint

            let primaryIndex = orderedTabs.firstIndex(of: tab)!
            var secondaryIndex: Int?

            if movingLeft == true && draggingTab.frame.midX < tab.frame.minX && tab !== orderedTabs.first! {
                // shift left
                secondaryIndex = primaryIndex - 1
            } else if movingLeft == false && draggingTab.frame.midX > tab.frame.maxX && tab != orderedTabs.last! {
                secondaryIndex = primaryIndex + 1
            }

            if let secondIndex = secondaryIndex {
                orderedTabs.swapAt(primaryIndex, secondIndex)

                // Shouldn't indexes be swapped too? But if we do so, it doesn't work!
                orderedTabs[primaryIndex].buttonPosition = TabPosition.fromIndex(primaryIndex, totalCount: orderedTabs.count)
                orderedTabs[secondIndex].buttonPosition = TabPosition.fromIndex(secondIndex, totalCount: orderedTabs.count)

                temporarySelectedButtonIndex += secondIndex - primaryIndex
                layoutTabButtons(orderedTabs, animated: true)
                invalidateRestorableState()
                reordered = true
            }
        }
    }

    // MARK: - Close

    @objc private func closeTab(_ sender: Any?) {
        guard let button = sender as? TabButton,
              let item = button.representedObject,
              delegate?.tabsControl?(self, canCloseItem: item) == true else
        { return }
        let buttonIndex = button.index

        button.removeFromSuperview()

        let tabButtons = tabButtons

        layoutTabButtons(nil, animated: true)

        for (index, tabButton) in tabButtons.enumerated() {
            tabButton.index = index
        }

        delegate?.tabsControl?(self, didCloseItem: item)

        guard let currentSelectedButtonIndex = selectedButtonIndex else { return }

        if buttonIndex == currentSelectedButtonIndex {
            // The selected tab itself was closed: select an adjacent enabled tab.
            var nextButtonIndex: Int?
            if tabButtons.isEmpty {
                nextButtonIndex = nil
            } else if buttonIndex == 0 {
                nextButtonIndex = 0
            } else {
                nextButtonIndex = buttonIndex - 1
            }
            if let nextButtonIndex, let nextButton = tabButtons[safe: nextButtonIndex], nextButton.isEnabled {
                selectedButtonIndex = nextButtonIndex
            } else {
                selectedButtonIndex = nil
            }
            if let action, let target {
                NSApp.sendAction(action, to: target, from: self)
            }
            delegate?.tabsControlDidChangeSelection?(self, item: selectedButton?.representedObject)
        } else if buttonIndex < currentSelectedButtonIndex {
            // A tab before the selection was closed: shift the selection so the same tab stays selected.
            selectedButtonIndex = currentSelectedButtonIndex - 1
        }
    }

    // MARK: - Selection

    @objc private func selectTab(_ sender: Any?) {
        guard let button = sender as? TabButton,
              button.isEnabled
        else { return }

        selectedButtonIndex = button.index
        invalidateRestorableState()

        if let action, let target {
            NSApp.sendAction(action, to: target, from: self)
        }

        // `selectedButtonIndex`'s `didSet` already posts `selectionDidChangeNotification`.
        delegate?.tabsControlDidChangeSelection?(self, item: button.representedObject)

        guard let currentEvent = NSApp.currentEvent else { return }

        if currentEvent.type == .leftMouseDown && currentEvent.clickCount > 1 {
            editTabButton(button)
        } else if let item = button.representedObject,
            delegate?.tabsControl?(self, canReorderItem: item) == true {

            guard let event = window?.nextEvent(matching: [.leftMouseUp, .leftMouseDragged], until: Date.distantFuture, inMode: .eventTracking, dequeue: false),
                  event.type == NSEvent.EventType.leftMouseDragged
            else { return }

            reorderTab(button, withEvent: currentEvent)
        }
    }

    private func scrollToSelectedButton() {
        guard let selectedButton = selectedButton else { return }

        NSAnimationContext.runAnimationGroup({ context in
            context.allowsImplicitAnimation = true
            selectedButton.scrollToVisible(selectedButton.bounds)
        }, completionHandler: nil)
    }

    private var selectedButton: TabButton? {
        guard let index = selectedButtonIndex else { return nil }
        return tabButtons.first(where: { $0.index == index })
    }

    public private(set) var selectedButtonIndex: Int? {
        didSet {
            scrollToSelectedButton()

            updateButtonStatesForSelection()
            layoutTabButtons(nil, animated: false)
            invalidateRestorableState()

            NotificationCenter.default.post(name: TabsControl.selectionDidChangeNotification, object: self)
        }
    }

    /// Selects an item at a given index. Selecting an invalid index unselects all tabs.
    ///
    /// - parameter index: An integer indicating the index of the item to be selected.
    open func selectItemAtIndex(_ index: Int) {
        guard let button = tabButtons[safe: index] else { return }
        selectTab(button)
    }

    private func updateButtonStatesForSelection() {
        for button in tabButtons {
            guard let selectedIndex = selectedButtonIndex else {
                button.state = NSControl.StateValue.off
                continue
            }

            button.state = button.index == selectedIndex ? NSControl.StateValue.on : NSControl.StateValue.off
        }
    }

    // MARK: - Editing

    /// Starts editing the tab as if the user double-clicked on it. If `index` is out of bounds, it does nothing.
    open func editTabAtIndex(_ index: Int) {
        guard let tabButton = tabButtons[safe: index] else { return }

        editTabButton(tabButton)
    }

    func editTabButton(_ tab: TabButton) {
        guard let representedObject = tab.representedObject,
              delegate?.tabsControl?(self, canEditTitleOfItem: representedObject) == true
        else { return }

        guard let fieldEditor = window?.fieldEditor(true, for: tab)
        else { return }

        window?.makeFirstResponder(self)

        editingTab = (tab.title, tab)
        tab.edit(fieldEditor: fieldEditor, delegate: self)
    }

    // MARK: - NSTextDelegate

    open func textDidEndEditing(_ notification: Notification) {
        guard let fieldEditor = notification.object as? NSText else {
            assertionFailure("Expected field editor.")
            return
        }

        let newValue = fieldEditor.string
        editingTab?.button.finishEditing(fieldEditor: fieldEditor, newValue: newValue)
        window?.makeFirstResponder(self)

        defer {
            self.editingTab = nil
        }

        guard let item = editingTab?.button.representedObject,
              newValue != editingTab?.title
        else { return }

        delegate?.tabsControl?(self, setTitle: newValue, forItem: item)
        editingTab?.button.representedObject = dataSource?.tabsControl(self, itemAtIndex: selectedButtonIndex!)
    }

    // MARK: - Drawing

    open override var isOpaque: Bool {
        return false
    }

    open override var isFlipped: Bool {
        return true
    }

    // MARK: - Tab Widths

    open func currentTabWidth() -> CGFloat {
        let tabs = tabButtons
        guard let firstTab = tabs.first else { return 0.0 }
        return firstTab.frame.width
    }

    // MARK: - State Restoration

    private enum RestorationKeys {
        static let scrollXOffset = "scrollOrigin"
        static let selectedButtonIndex = "selectedButtonIndex"
    }

    open override func encodeRestorableState(with coder: NSCoder) {
        super.encodeRestorableState(with: coder)

        let scrollXOffset: CGFloat = scrollView.contentView.bounds.origin.x
        let selectedButtonIndex: Int = self.selectedButtonIndex ?? NSNotFound

        coder.encode(Double(scrollXOffset), forKey: RestorationKeys.scrollXOffset)
        coder.encode(selectedButtonIndex, forKey: RestorationKeys.selectedButtonIndex)
    }

    open override func restoreState(with coder: NSCoder) {
        super.restoreState(with: coder)

        let scrollXOffset = coder.decodeDouble(forKey: RestorationKeys.scrollXOffset)
        let selectedButtonIndex = coder.decodeInteger(forKey: RestorationKeys.selectedButtonIndex)

        var bounds = scrollView.contentView.bounds
        bounds.origin.x = CGFloat(scrollXOffset)
        scrollView.contentView.bounds = bounds

        guard selectedButtonIndex != NSNotFound,
              let selectedButton = tabButtons.first(where: { $0.index == selectedButtonIndex })
        else { return }

        selectTab(selectedButton)
    }

    // MARK: - Helpers

    private var tabButtons: [TabButton] {
        return tabsView.subviews.compactMap { $0 as? TabButton }.sorted(by: { $0.index < $1.index })
    }
}

#endif
