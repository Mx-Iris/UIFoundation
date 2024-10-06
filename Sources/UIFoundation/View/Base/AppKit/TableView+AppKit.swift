#if canImport(AppKit) && !targetEnvironment(macCatalyst)

import AppKit

open class TableView: NSTableView {
    public override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        commonInit()
        headerView = nil
        backgroundColor = .clear
        intercellSpacing = .zero
        if #available(macOS 11.0, *) {
            style = .inset
        }
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    private func commonInit() {
        wantsLayer = true
        setup()
    }

    open func setup() {}
}

open class SingleColumnTableView: TableView {
    public static let defaultTableColumnIdentifier = NSUserInterfaceItemIdentifier("DefaultTableColumnIdentifier")

    open override func setup() {
        super.setup()
        addTableColumn(NSTableColumn(identifier: Self.defaultTableColumnIdentifier))
    }
}

public protocol TableViewProtocol: NSTableView {}

extension NSTableView: TableViewProtocol {}

extension TableViewProtocol {
    public static func scrollableTableView() -> (NSScrollView, Self) {
        let scrollView = ScrollView()
        let tableView = Self()
        scrollView.do {
            $0.documentView = tableView
            $0.hasVerticalScroller = true
        }
        return (scrollView, tableView)
    }
}

extension NSTableView {
    public class func scrollableTableView<ScrollViewType: NSScrollView, TableViewType: NSTableView>() -> (ScrollViewType, TableViewType) {
        let scrollView = ScrollViewType()
        let tableView = TableViewType()
        scrollView.do {
            $0.documentView = tableView
            $0.hasVerticalScroller = true
        }
        return (scrollView, tableView)
    }
}

#endif
