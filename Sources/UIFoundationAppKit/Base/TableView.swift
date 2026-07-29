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

extension NSTableView {
    /// The size a self-sizing table reports: its rows, measured off the table itself.
    ///
    /// `rect(ofRow:)` is expressed in the table view's own coordinate space, so the first row's
    /// `minY` already encodes the top inset reserved by `.inset` / `.sourceList` styles, and the
    /// last row's `maxY` already folds in every row height plus the intercell spacing between
    /// rows. The table reserves a symmetric bottom inset, so mirror the top inset below the last
    /// row to obtain the full content height.
    ///
    /// Shared by ``SelfSizingTableView`` and ``SelfSizingOutlineView``: an outline view *is* a
    /// table view, but the two inherit from different UIFoundation bases, so this is the only way
    /// for them to agree on the measurement.
    var selfSizingRowsContentSize: NSSize {
        let rowCount = numberOfRows
        guard rowCount > 0 else {
            return NSSize(width: NSView.noIntrinsicMetric, height: 0)
        }
        let topInset = rect(ofRow: 0).minY
        let contentMaxY = rect(ofRow: rowCount - 1).maxY
        return NSSize(width: NSView.noIntrinsicMetric, height: contentMaxY + topInset)
    }
}

/// `SingleColumnTableView` variant whose intrinsic content height equals the sum of its row
/// heights. Pair with ``SelfSizingScrollView`` so the scroll view can shrink to exactly fit the
/// rows.
open class SelfSizingTableView: SingleColumnTableView {
    open override var intrinsicContentSize: NSSize {
        selfSizingRowsContentSize
    }

    open override func invalidateIntrinsicContentSize() {
        super.invalidateIntrinsicContentSize()
        // The scroll view's own intrinsic size is derived from this one, and nothing tells it to
        // ask again.
        enclosingScrollView?.invalidateIntrinsicContentSize()
    }

    open override func reloadData() {
        super.reloadData()
        invalidateIntrinsicContentSize()
    }

    open override func noteHeightOfRows(withIndexesChanged indexSet: IndexSet) {
        super.noteHeightOfRows(withIndexesChanged: indexSet)
        invalidateIntrinsicContentSize()
    }

    open override func noteNumberOfRowsChanged() {
        super.noteNumberOfRowsChanged()
        invalidateIntrinsicContentSize()
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
