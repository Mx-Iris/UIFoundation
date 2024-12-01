#if canImport(AppKit) && !targetEnvironment(macCatalyst)

import AppKit
import UIFoundationShared

open class TableViewController: XiblessViewController<NSScrollView> {
    public let tableView: TableView

    public let scrollView: NSScrollView

    public init() {
        let (scrollView, tableView) = TableView.scrollableTableView()
        self.scrollView = scrollView
        self.tableView = tableView
        super.init(viewGenerator: scrollView)
    }

    @available(macOS 11.0, *)
    convenience init(style: TableView.Style) {
        self.init()
        tableView.style = style
    }

    open override func commonInit() {
        super.commonInit()
    }
}

#endif
