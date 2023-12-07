#if canImport(AppKit) && !targetEnvironment(macCatalyst)

import AppKit

@MainActor open class TableViewController: XiblessViewController<ScrollView>, NSTableViewDataSource, NSTableViewDelegate {
    @MainActor public let tableView: TableView

    @MainActor public let scrollView: ScrollView

    public init(style: TableView.Style) {
        let (scrollView, tableView) = TableView.scrollableTableView()
        self.scrollView = scrollView
        self.tableView = tableView
        super.init(viewGenerator: scrollView)
        self.tableView.style = style
    }

    open override func commonInit() {
        super.commonInit()

        tableView.dataSource = self
        tableView.delegate = self
    }
}

#endif
