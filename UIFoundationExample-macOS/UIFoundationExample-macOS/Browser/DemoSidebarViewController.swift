//
//  DemoSidebarViewController.swift
//  UIFoundationExample-macOS
//
//  Source-list sidebar that lists the demo catalog grouped by category.
//

import AppKit
import UIFoundation

final class DemoSidebarViewController: NSViewController {

    /// Called when the user selects a demo.
    var onSelectDemo: ((Demo) -> Void)?

    private let outlineView = NSOutlineView()
    private let scrollView = NSScrollView()
    private let rootNodes: [SidebarNode]

    init() {
        rootNodes = DemoCatalog.grouped.map { group in
            let categoryNode = SidebarNode(.category(group.category))
            categoryNode.children = group.demos.map { SidebarNode(.demo($0)) }
            return categoryNode
        }
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = NSView()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("title"))
        outlineView.addTableColumn(column)
        outlineView.outlineTableColumn = column
        outlineView.headerView = nil
        outlineView.style = .sourceList
        outlineView.rowSizeStyle = .default
        outlineView.floatsGroupRows = false
        outlineView.dataSource = self
        outlineView.delegate = self

        scrollView.documentView = outlineView
        scrollView.autohidesScrollers = true
        scrollView.hasVerticalScroller = true
        scrollView.drawsBackground = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])

        outlineView.expandItem(nil, expandChildren: true)
    }

    /// Selects the first selectable (available) demo, firing ``onSelectDemo``.
    func selectFirstAvailableDemo() {
        _ = view  // force the outline view to load (loadViewIfNeeded() is macOS 14+)
        for categoryNode in rootNodes {
            for demoNode in categoryNode.children where demoNode.demo?.isAvailable == true {
                let row = outlineView.row(forItem: demoNode)
                guard row >= 0 else { continue }
                outlineView.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
                return
            }
        }
    }
}

// MARK: - NSOutlineViewDataSource

extension DemoSidebarViewController: NSOutlineViewDataSource {
    func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
        (item as? SidebarNode)?.children.count ?? rootNodes.count
    }

    func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
        (item as? SidebarNode)?.children[index] ?? rootNodes[index]
    }

    func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
        (item as? SidebarNode)?.isCategory ?? false
    }
}

// MARK: - NSOutlineViewDelegate

extension DemoSidebarViewController: NSOutlineViewDelegate {
    func outlineView(_ outlineView: NSOutlineView, isGroupItem item: Any) -> Bool {
        (item as? SidebarNode)?.isCategory ?? false
    }

    func outlineView(_ outlineView: NSOutlineView, shouldSelectItem item: Any) -> Bool {
        (item as? SidebarNode)?.demo?.isAvailable ?? false
    }

    func outlineView(_ outlineView: NSOutlineView, viewFor tableColumn: NSTableColumn?, item: Any) -> NSView? {
        guard let node = item as? SidebarNode else { return nil }

        if node.isCategory {
            let cell = labelCell(identifier: "category", text: node.title.uppercased())
            cell.textField?.font = .systemFont(ofSize: 11, weight: .semibold)
            cell.textField?.textColor = .secondaryLabelColor
            return cell
        }

        let isAvailable = node.demo?.isAvailable ?? true
        let cell = labelCell(identifier: "demo", text: node.title)
        cell.textField?.font = .systemFont(ofSize: 13)
        cell.textField?.textColor = isAvailable ? .labelColor : .tertiaryLabelColor
        return cell
    }

    func outlineViewSelectionDidChange(_ notification: Notification) {
        let row = outlineView.selectedRow
        guard row >= 0,
              let node = outlineView.item(atRow: row) as? SidebarNode,
              let demo = node.demo
        else { return }
        onSelectDemo?(demo)
    }

    private func labelCell(identifier: String, text: String) -> NSTableCellView {
        let cellIdentifier = NSUserInterfaceItemIdentifier(identifier)
        let cell: NSTableCellView = outlineView.box.makeView(identifier: cellIdentifier) {
            let cell = NSTableCellView()
            cell.identifier = cellIdentifier

            let textField = NSTextField(labelWithString: "")
            textField.lineBreakMode = .byTruncatingTail
            textField.translatesAutoresizingMaskIntoConstraints = false
            cell.addSubview(textField)
            cell.textField = textField

            NSLayoutConstraint.activate([
                textField.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 6),
                textField.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -6),
                textField.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
            ])
            return cell
        }
        cell.textField?.stringValue = text
        return cell
    }
}

// MARK: - SidebarNode

/// Reference-type node backing the outline view (NSOutlineView requires stable
/// item identity, which a `Demo` value type cannot provide).
private final class SidebarNode: NSObject {
    enum Kind {
        case category(String)
        case demo(Demo)
    }

    let kind: Kind
    var children: [SidebarNode] = []

    init(_ kind: Kind) {
        self.kind = kind
    }

    var isCategory: Bool {
        if case .category = kind { return true }
        return false
    }

    var demo: Demo? {
        if case let .demo(demo) = kind { return demo }
        return nil
    }

    var title: String {
        switch kind {
        case let .category(name): return name
        case let .demo(demo): return demo.title
        }
    }
}
