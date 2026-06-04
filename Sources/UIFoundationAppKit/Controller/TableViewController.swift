#if canImport(AppKit) && !targetEnvironment(macCatalyst)

import AppKit

open class TableViewController: ScrollViewController<TableView> {
    public var tableView: TableView { documentView }

    public init() {
        super.init(viewGenerator: TableView())
        scrollView.hasVerticalScroller = true
    }

    @available(macOS 11.0, *)
    public convenience init(style: TableView.Style) {
        self.init()
        tableView.style = style
    }
}

#endif
