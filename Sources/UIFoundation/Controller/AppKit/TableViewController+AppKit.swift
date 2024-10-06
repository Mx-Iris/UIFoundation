#if canImport(AppKit) && !targetEnvironment(macCatalyst)

import AppKit

@MainActor open class TableViewController: XiblessViewController<NSScrollView>, NSTableViewDataSource, NSTableViewDelegate {
    @MainActor public let tableView: TableView

    @MainActor public let scrollView: NSScrollView

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

        tableView.dataSource = self
        tableView.delegate = self
    }
}

#endif
