#if QuickActionBar

import AppKit

extension QuickActionBar {
    final class ResultsView: NSView {
        private let scrollView = NSScrollView()
        private let tableView = QuickActionBar.ResultsTableView()
        private let horizontalView = NSBox()

        var quickActionBarWindow: QuickActionBar.Window? {
            window as? QuickActionBar.Window
        }

        var quickActionBar: QuickActionBar!

        var showKeyboardShortcuts = false

        var currentSearchTerm = ""

        var identifiers: [AnyHashable] = [] {
            didSet {
                reconfigure()
            }
        }

        @inlinable var selectedRow: Int {
            return tableView.selectedRow
        }

        override init(frame frameRect: NSRect) {
            super.init(frame: frameRect)
            self.translatesAutoresizingMaskIntoConstraints = false
            setContentHuggingPriority(.defaultLow, for: .horizontal)
        }

        @available(*, unavailable)
        required init?(coder _: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        private let keyboardShortcutFont = NSFont.monospacedDigitSystemFont(ofSize: 16, weight: .medium)
        private var shortcutKeyboardMap: [AnyHashable: Int] = [:]
    }
}

extension QuickActionBar.ResultsView {
    func configure() {
        translatesAutoresizingMaskIntoConstraints = false

        addSubview(scrollView)
        scrollView.translatesAutoresizingMaskIntoConstraints = false

        scrollView.contentView = QuickActionBar.FlippedClipView()

        horizontalView.boxType = .separator
        horizontalView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(horizontalView)
        addConstraint(NSLayoutConstraint(item: horizontalView, attribute: .left, relatedBy: .equal, toItem: self, attribute: .left, multiplier: 1.0, constant: 0))
        addConstraint(NSLayoutConstraint(item: horizontalView, attribute: .top, relatedBy: .equal, toItem: self, attribute: .top, multiplier: 1.0, constant: 0))
        addConstraint(NSLayoutConstraint(item: horizontalView, attribute: .right, relatedBy: .equal, toItem: self, attribute: .right, multiplier: 1.0, constant: 0))

        addConstraint(NSLayoutConstraint(item: scrollView, attribute: .left, relatedBy: .equal, toItem: self, attribute: .left, multiplier: 1.0, constant: 0))
        addConstraint(NSLayoutConstraint(item: scrollView, attribute: .top, relatedBy: .equal, toItem: self, attribute: .top, multiplier: 1.0, constant: 0))
        addConstraint(NSLayoutConstraint(item: scrollView, attribute: .right, relatedBy: .equal, toItem: self, attribute: .right, multiplier: 1.0, constant: 0))
        addConstraint(NSLayoutConstraint(item: scrollView, attribute: .bottom, relatedBy: .equal, toItem: self, attribute: .bottom, multiplier: 1.0, constant: 0))

        scrollView.addConstraint(NSLayoutConstraint(item: scrollView, attribute: .width, relatedBy: .equal, toItem: nil, attribute: .notAnAttribute, multiplier: 1, constant: quickActionBar.width))
        scrollView.addConstraint(NSLayoutConstraint(item: scrollView, attribute: .height, relatedBy: .equal, toItem: nil, attribute: .notAnAttribute, multiplier: 1, constant: quickActionBar.height))

        scrollView.backgroundColor = NSColor.clear
        scrollView.drawsBackground = false
        scrollView.autohidesScrollers = true
        scrollView.documentView = tableView
        scrollView.hasHorizontalScroller = false
        scrollView.hasVerticalScroller = true
        scrollView.verticalScroller = QuickActionBar.TransparentBackgroundScroller()

        tableView.dataSource = self
        tableView.delegate = self
        tableView.parent = self
        tableView.headerView = nil
        tableView.backgroundColor = NSColor.clear
        tableView.intercellSpacing = NSSize(width: 0, height: 5)

        if #available(macOS 10.13, *) {
            tableView.usesAutomaticRowHeights = true
        } else {
            tableView.rowHeight = quickActionBar.rowHeight
        }

        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("searchresult"))
        tableView.addTableColumn(column)

        tableView.action = #selector(didClickRow)
        tableView.doubleAction = #selector(didDoubleClickRow)
    }
}

// MARK: - Table Data

extension QuickActionBar.ResultsView {
    fileprivate func reconfigure() {
        buildShortcuts()

        tableView.reloadData()

        if identifiers.count > 0 {
            _ = selectFirstSelectableRow()
        }

        quickActionBarWindow?.handleResultsCountChanged(hasResults: identifiers.count > 0)
    }

    // Map the first 10 selectable identifiers to the return + (1...9) keyboard shortcuts.
    fileprivate func buildShortcuts() {
        guard let content = contentSource else { fatalError() }
        shortcutKeyboardMap.removeAll()
        guard showKeyboardShortcuts else { return }

        var count = 0
        for identifier in identifiers {
            if content.quickActionBar(quickActionBar, canSelectItem: identifier) {
                shortcutKeyboardMap[identifier] = count
                count += 1
                if count > 9 {
                    break
                }
            }
        }
    }
}

extension QuickActionBar.ResultsView: NSTableViewDelegate, NSTableViewDataSource {
    @inlinable func reloadData() {
        tableView.reloadData()
    }

    @inlinable var contentSource: QuickActionBarContentSource? {
        quickActionBar.contentSource
    }

    func numberOfRows(in _: NSTableView) -> Int {
        return identifiers.count
    }

    func tableView(_ tableView: NSTableView, viewFor _: NSTableColumn?, row: Int) -> NSView? {
        let itemIdentifier = identifiers[row]

        let reuseCellView = tableView.makeView(withIdentifier: .init(String(describing: QuickActionBar.ResultsTableCellView.self)), owner: nil) as? QuickActionBar.ResultsTableCellView

        if let cellView = reuseCellView {
            quickActionBar.reuseCellView = cellView.contentView
        }

        let contentView = contentSource?.quickActionBar(
            quickActionBar,
            viewForItem: itemIdentifier,
            searchTerm: currentSearchTerm
        )

        if contentView === reuseCellView?.contentView {
            return reuseCellView
        } else {
            return QuickActionBar.ResultsTableCellView(contentView: contentView ?? NSView(), shortcutKey: showKeyboardShortcuts == true ? shortcutKeyboardMap[itemIdentifier] : nil)
        }
    }

    func tableView(_ tableView: NSTableView, shouldSelectRow row: Int) -> Bool {
        if row < 0 { return false }
        return contentSource?.quickActionBar(
            quickActionBar,
            canSelectItem: identifiers[row]
        ) ?? false
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        assert(selectedRow < identifiers.count)

        guard selectedRow > 0 else {
            return
        }

        contentSource?.quickActionBar(quickActionBar, didSelectItem: identifiers[selectedRow])
    }

    func tableView(_ tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView? {
        if let rowView = tableView.makeView(withIdentifier: .init(String(describing: ResultsRowView.self)), owner: nil) as? ResultsRowView {
            return rowView
        } else {
            let rowView = ResultsRowView()
            rowView.identifier = .init(String(describing: ResultsRowView.self))
            return rowView
        }
    }
}

// MARK: - Table Actions

extension QuickActionBar.ResultsView {
    @objc private func didClickRow() {
        if quickActionBar.requiredClickCount == .single {
            rowAction()
        }
    }

    @objc private func didDoubleClickRow() {
        rowAction()
    }

    func performShortcutAction(for itemIndex: Int) -> Bool {
        guard itemIndex >= 0, itemIndex <= 9 else {
            return false
        }

        guard let which = shortcutKeyboardMap.first(where: { $0.value == itemIndex }) else {
            return false
        }

        quickActionBarWindow?.userDidActivateItem = true

        quickActionBar.contentSource?.quickActionBar(quickActionBar, didActivateItem: which.key)

        window?.resignMain()

        return true
    }

    func rowAction() {
        let selectedRow = tableView.selectedRow
        if selectedRow < 0 || selectedRow >= identifiers.count {
            return
        }

        if
            tableView.clickedRow >= 0,
            tableView(tableView, shouldSelectRow: tableView.clickedRow) == false {
            return
        }

        quickActionBarWindow?.userDidActivateItem = true

        let itemIdentifier = identifiers[selectedRow]
        quickActionBar.contentSource?.quickActionBar(quickActionBar, didActivateItem: itemIdentifier)

        window?.resignMain()
    }

    func backAction() {
        quickActionBar.quickActionBarWindow?.pressedLeftArrowInResultsView()
    }
}

// MARK: - Safe external selection

extension QuickActionBar.ResultsView {
    /// Selects the first selectable row in the table.
    func selectFirstSelectableRow() -> Bool {
        for index in 0 ..< identifiers.count {
            if tableView(tableView, shouldSelectRow: index) {
                tableView.selectRowIndexes(IndexSet(integer: index), byExtendingSelection: false)
                return true
            }
        }
        return false
    }

    /// Move the selection to the next selectable row.
    func selectNextSelectableRow() -> Bool {
        var currentSelection = tableView.selectedRow
        while currentSelection < (identifiers.count - 1) {
            currentSelection += 1
            if tableView(tableView, shouldSelectRow: currentSelection) {
                tableView.selectRowIndexes(IndexSet(integer: currentSelection), byExtendingSelection: false)
                tableView.scrollRowToVisible(currentSelection)
                return true
            }
        }
        return false
    }

    /// Move the selection to the previous selectable row.
    func selectPreviousSelectableRow() -> Bool {
        var currentSelection = tableView.selectedRow
        while currentSelection > 0 {
            currentSelection -= 1
            if tableView(tableView, shouldSelectRow: currentSelection) {
                tableView.selectRowIndexes(IndexSet(integer: currentSelection), byExtendingSelection: false)
                tableView.scrollRowToVisible(currentSelection)
                return true
            }
        }
        return false
    }
}

// MARK: - Handle key events in the results table

extension QuickActionBar {
    final class ResultsTableView: NSTableView {
        weak var parent: QuickActionBar.ResultsView?

        override func keyDown(with event: NSEvent) {
            guard let parent = parent else { fatalError() }

            if event.keyCode == 0x24 { // kVK_Return
                parent.rowAction()
            } else if event.keyCode == 0x7B { // kVK_LeftArrow
                parent.backAction()
            } else if event.modifierFlags.contains(.command),
                      let characters = event.characters,
                      let shortcutIndex = Int(characters) {
                if parent.performShortcutAction(for: shortcutIndex) {
                    return
                } else {
                    super.keyDown(with: event)
                }
            } else {
                super.keyDown(with: event)
            }
        }
    }

    final class ResultsTableCellView: NSTableCellView {
        let contentView: NSView

        init(contentView: NSView, shortcutKey: Int?) {
            self.contentView = contentView
            super.init(frame: .zero)

            contentView.translatesAutoresizingMaskIntoConstraints = false
            contentView.setContentHuggingPriority(.defaultLow, for: .horizontal)

            identifier = .init(String(describing: QuickActionBar.ResultsTableCellView.self))
            translatesAutoresizingMaskIntoConstraints = false
            addSubview(contentView)
            
            contentView.leadingAnchor.constraint(equalTo: leadingAnchor).isActive = true
            contentView.topAnchor.constraint(equalTo: topAnchor).isActive = true
            contentView.bottomAnchor.constraint(equalTo: bottomAnchor).isActive = true

            var inset: CGFloat = -24
            if #available(macOS 11, *) {
                inset = 0
            }
            
            if let shortcutKey {
                let shortcutLabel = NSTextField(labelWithString: shortcutKey == 0 ? "\u{21A9}\u{FE0E}" : "\u{2318}\(shortcutKey)")
                shortcutLabel.alignment = .right
                shortcutLabel.translatesAutoresizingMaskIntoConstraints = false
                shortcutLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 16, weight: .medium)
                shortcutLabel.textColor = .secondaryLabelColor
                shortcutLabel.setContentHuggingPriority(.init(999), for: .horizontal)
                shortcutLabel.setContentHuggingPriority(.required, for: .vertical)
                addSubview(shortcutLabel)

                shortcutLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: inset).isActive = true
                shortcutLabel.centerYAnchor.constraint(equalTo: centerYAnchor).isActive = true
                shortcutLabel.leadingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: 4).isActive = true
            } else {
                contentView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: inset).isActive = true
            }
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
    }
}

// MARK: - Custom row drawing

private class ResultsRowView: NSTableRowView {
    override func drawSelection(in dirtyRect: NSRect) {
        if selectionHighlightStyle != .none {
            NSColor.controlAccentColor.setFill()
            let path = NSBezierPath(roundedRect: bounds.insetBy(dx: 12, dy: 2), xRadius: 15, yRadius: 15)
            path.fill()
        }
    }
}

#endif
