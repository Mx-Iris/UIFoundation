#if canImport(AppKit) && !targetEnvironment(macCatalyst)

import AppKit

open class TableView: NSTableView {
    public static let defaultTableColumnIdentifier = NSUserInterfaceItemIdentifier("DefaultTableColumnIdentifier")

    public override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        addTableColumn(NSTableColumn(identifier: Self.defaultTableColumnIdentifier))
        headerView = nil
        backgroundColor = .clear
        intercellSpacing = .zero
        if #available(macOS 11.0, *) {
            style = .inset
        }
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    open class func scrollableTableView() -> (scrollView: ScrollView, tableView: TableView) {
        let scrollView = ScrollView()
        let tableView = TableView()
        scrollView.do {
            $0.documentView = tableView
            $0.hasVerticalScroller = true
        }
        return (scrollView, tableView)
    }
}

#endif
