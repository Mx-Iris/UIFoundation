//
//  Replicated from macOS 26's Spotlight.app (26.6.2).
//  Decision record: Documentations/Evolutions/0021-spotlight-panel-replica.md
//

#if SpotlightPanel && os(macOS)

import AppKit

extension SpotlightPanel {
    /// Draws the selected row the way Spotlight does: a neutral rounded band, inset from the
    /// panel's edges, that looks the same whether or not the panel is key.
    ///
    /// **Not the system's emphasised selection.** AppKit's default would paint
    /// `selectedContentBackgroundColor` — the user's accent colour — edge to edge and square. On a
    /// glass platter that reads as a coloured bar stamped across the panel, and it changes colour
    /// the moment focus moves. Spotlight's is `unemphasizedSelectedContentBackgroundColor`-like
    /// neutral grey and does not react to focus at all.
    ///
    /// `isEmphasized` is forced to `false` for the same reason: it is what drives a cell view's
    /// `backgroundStyle`, and leaving it true turns the row's text white — invisible against a
    /// light-grey band in the light appearance.
    final class ResultRowView: NSTableRowView {
        var selectionCornerRadius: CGFloat = 10
        var selectionHorizontalInset: CGFloat = 8

        override var isEmphasized: Bool {
            get { false }
            set { _ = newValue }
        }

        override func drawSelection(in dirtyRect: NSRect) {
            guard isSelected, selectionHighlightStyle != .none else { return }

            // `.inset` still hands the row view its full width — the style's inset applies to the
            // cell, not to the selection — so the band has to be inset here.
            let bandRect = bounds.insetBy(dx: selectionHorizontalInset, dy: 0)
            guard bandRect.width > 0 else { return }

            let bandPath = NSBezierPath(
                roundedRect: bandRect,
                xRadius: selectionCornerRadius,
                yRadius: selectionCornerRadius
            )
            NSColor.unemphasizedSelectedContentBackgroundColor.setFill()
            bandPath.fill()
        }
    }

    /// The scrolling result list.
    ///
    /// Row contents come from the data source; this type owns only the table, the selection
    /// rules and the measurement the sizing layer needs.
    final class ResultsView: NSView {
        private let scrollView = NSScrollView()
        private let tableView = NSTableView()

        /// Selection geometry, handed to every row view as it is made.
        var selectionCornerRadius: CGFloat = 10
        var selectionHorizontalInset: CGFloat = 8

        /// Called when the selection lands on a row, with the item it represents.
        var selectionDidChange: ((AnyHashable?) -> Void)?
        /// Called when a row is activated by clicking it.
        var itemDidActivate: ((AnyHashable) -> Void)?
        /// Asked before a row is allowed to take the selection.
        var canSelectItem: ((AnyHashable) -> Bool)?
        /// Builds the view for a row.
        var viewForItem: ((AnyHashable) -> NSView?)?

        private(set) var items: [AnyHashable] = []

        init() {
            super.init(frame: .zero)
            setUp()
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        private func setUp() {
            translatesAutoresizingMaskIntoConstraints = false

            tableView.headerView = nil
            tableView.backgroundColor = .clear
            // `.inset` is what gives the selection a rounded band with a margin either side, the
            // way Spotlight draws it. `.plain` produces a square, full-bleed highlight whose
            // corners cut straight through the platter's rounded ones.
            tableView.style = .inset
            tableView.selectionHighlightStyle = .regular
            tableView.allowsEmptySelection = true
            tableView.allowsMultipleSelection = false
            tableView.usesAutomaticRowHeights = true
            tableView.intercellSpacing = CGSize(width: 0, height: 2)
            tableView.addTableColumn(NSTableColumn(identifier: .spotlightPanelResultColumn))
            tableView.dataSource = self
            tableView.delegate = self
            tableView.target = self
            tableView.action = #selector(didClickRow)

            scrollView.translatesAutoresizingMaskIntoConstraints = false
            scrollView.documentView = tableView
            scrollView.drawsBackground = false
            scrollView.backgroundColor = .clear
            scrollView.hasVerticalScroller = true
            scrollView.autohidesScrollers = true
            scrollView.scrollerStyle = .overlay

            addSubview(scrollView)
            NSLayoutConstraint.activate([
                scrollView.topAnchor.constraint(equalTo: topAnchor),
                scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
                scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
                scrollView.bottomAnchor.constraint(equalTo: bottomAnchor),
            ])
        }

        // MARK: Content

        func setItems(_ newItems: [AnyHashable]) {
            items = newItems
            tableView.reloadData()
            selectFirstSelectableRow()
        }

        /// How tall the rows are, all of them, which is what the platter behavior clamps.
        ///
        /// Measured through `rect(ofRow:)` rather than by multiplying a row height, because
        /// automatic row heights make the latter meaningless and because the first row's `minY`
        /// already carries whatever inset the table style reserves.
        var measuredContentHeight: CGFloat {
            guard !items.isEmpty else { return 0 }
            tableView.layoutSubtreeIfNeeded()
            let lastRowIndex = items.count - 1
            let topInset = tableView.rect(ofRow: 0).minY
            return tableView.rect(ofRow: lastRowIndex).maxY + topInset
        }

        // MARK: Selection

        var selectedItem: AnyHashable? {
            let selectedRow = tableView.selectedRow
            guard items.indices.contains(selectedRow) else { return nil }
            return items[selectedRow]
        }

        @discardableResult
        func selectFirstSelectableRow() -> Bool {
            guard let firstIndex = items.indices.first(where: isSelectable) else {
                tableView.deselectAll(nil)
                return false
            }
            select(rowIndex: firstIndex)
            return true
        }

        @discardableResult
        func selectNextSelectableRow() -> Bool {
            let startingRow = tableView.selectedRow
            let nextIndex = items.indices
                .dropFirst(max(startingRow + 1, 0))
                .first(where: isSelectable)
            guard let nextIndex else { return false }
            select(rowIndex: nextIndex)
            return true
        }

        @discardableResult
        func selectPreviousSelectableRow() -> Bool {
            let startingRow = tableView.selectedRow
            guard startingRow > 0 else { return false }
            let previousIndex = items.indices
                .prefix(startingRow)
                .last(where: isSelectable)
            guard let previousIndex else { return false }
            select(rowIndex: previousIndex)
            return true
        }

        private func isSelectable(rowIndex: Int) -> Bool {
            guard items.indices.contains(rowIndex) else { return false }
            return canSelectItem?(items[rowIndex]) ?? true
        }

        private func select(rowIndex: Int) {
            tableView.selectRowIndexes(IndexSet(integer: rowIndex), byExtendingSelection: false)
            tableView.scrollRowToVisible(rowIndex)
            selectionDidChange?(items[rowIndex])
        }

        @objc private func didClickRow() {
            let clickedRow = tableView.clickedRow
            guard items.indices.contains(clickedRow), isSelectable(rowIndex: clickedRow) else { return }
            itemDidActivate?(items[clickedRow])
        }
    }
}

// MARK: - Table data source and delegate

extension SpotlightPanel.ResultsView: NSTableViewDataSource {
    func numberOfRows(in tableView: NSTableView) -> Int {
        items.count
    }
}

extension SpotlightPanel.ResultsView: NSTableViewDelegate {
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard items.indices.contains(row) else { return nil }
        return viewForItem?(items[row])
    }

    func tableView(_ tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView? {
        let rowView = SpotlightPanel.ResultRowView()
        rowView.selectionCornerRadius = selectionCornerRadius
        rowView.selectionHorizontalInset = selectionHorizontalInset
        return rowView
    }

    func tableView(_ tableView: NSTableView, shouldSelectRow row: Int) -> Bool {
        isSelectable(rowIndex: row)
    }
}

private extension NSUserInterfaceItemIdentifier {
    static let spotlightPanelResultColumn = NSUserInterfaceItemIdentifier("SpotlightPanelResultColumn")
}

#endif
