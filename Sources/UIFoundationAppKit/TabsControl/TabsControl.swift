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

    private lazy var scrollView = NSScrollView(frame: bounds)
    private lazy var tabsView = NSView(frame: scrollView.bounds)

    private var editingTab: (title: String, button: TabButton)?

    private lazy var tabsControlCell = TabsControlCell(textCell: "")

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
            updateTabs()
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
        guard let dataSource = dataSource else { return }

        let oldItemsCount = self.tabButtons.count
        let newItemsCount = dataSource.tabsControlNumberOfTabs(self)

        if newItemsCount < oldItemsCount {
            self.tabButtons.filter { $0.index >= newItemsCount }.forEach { $0.removeFromSuperview() }
        }

        let tabButtons = self.tabButtons
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

                button.wantsLayer = true
                button.state = .off
                tabsView.addSubview(button)
            } else {
                button = tabButtons[i]
            }

            button.index = i
            button.item = item

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

        layoutTabButtons(nil, animated: false)
        invalidateRestorableState()
    }

    // MARK: - Layout

    private func updateTabs(animated: Bool = false) {
        layoutTabButtons(nil, animated: animated)
        invalidateRestorableState()
    }

    private func layoutTabButtons(_ buttons: [TabButton]?, animated: Bool) {
        let tabButtons = buttons ?? tabButtons
        var tabsViewWidth = CGFloat(0.0)

        let fullWidth = scrollView.frame.width / CGFloat(tabButtons.count)
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

        var buttonX = CGFloat(0)
        for (index, button) in tabButtons.enumerated() {
            let offset = style.tabButtonOffset(position: button.buttonPosition)
            let buttonFrame = CGRect(x: buttonX + offset.x, y: offset.y, width: buttonWidth, height: buttonHeight)
            buttonX += buttonWidth + offset.x

            button.layer?.zPosition = button.state == NSControl.StateValue.on ? CGFloat(Float.greatestFiniteMagnitude) : CGFloat(index)

            if animated && !button.isHidden {
                button.animator().frame = buttonFrame
            } else {
                button.frame = buttonFrame
            }

            if let selectable = delegate?.tabsControl?(self, canSelectItem: button.representedObject!) {
                button.isEnabled = selectable
            }

            tabsViewWidth += buttonWidth
        }

        let viewFrame = CGRect(x: 0.0, y: 0.0, width: tabsViewWidth, height: buttonHeight)
        if animated {
            tabsView.animator().frame = viewFrame
        } else {
            tabsView.frame = viewFrame
        }
    }

    // MARK: - ScrollView Observation

    private func startObservingScrollView() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(TabsControl.scrollViewDidScroll(_:)),
            name: NSView.frameDidChangeNotification,
            object: scrollView
        )
    }

    private func stopObservingScrollView() {
        NotificationCenter.default.removeObserver(
            self,
            name: NSView.frameDidChangeNotification,
            object: scrollView
        )
    }

    @objc private func scrollViewDidScroll(_ notification: Notification) {
        layoutTabButtons(nil, animated: false)
        invalidateRestorableState()
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
