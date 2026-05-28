#if canImport(AppKit) && !targetEnvironment(macCatalyst)

import AppKit

open class TableView: NSTableView {
    public override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        commonInit()
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    private func commonInit() {
        headerView = nil
        backgroundColor = .clear
        intercellSpacing = .zero
        if #available(macOS 11.0, *) {
            style = .inset
        }
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
        NSTableView.scrollableTableView()
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
    
    public class func scrollableSingleColumnTableView<ScrollViewType: NSScrollView, TableViewType: NSTableView>() -> (scrollView: ScrollViewType, tableView: TableViewType) {
        let scrollView = ScrollViewType()
        let documentView = TableViewType()
        
        scrollView.do {
            $0.documentView = documentView
            $0.hasVerticalScroller = true
        }
        documentView.do {
            $0.headerView = nil
            $0.addTableColumn(NSTableColumn(identifier: "\(Self.self)"))
        }

        return (scrollView, documentView)
    }
}

#endif
