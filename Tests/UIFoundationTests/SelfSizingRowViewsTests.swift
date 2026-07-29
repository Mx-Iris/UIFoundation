#if canImport(AppKit) && !targetEnvironment(macCatalyst)

import AppKit
import XCTest
@testable import UIFoundationAppKit

/// Covers the self-sizing row views: that they report their rows as an intrinsic height, that the
/// scroll view around them follows, and that a disclosure does not animate.
final class SelfSizingRowViewsTests: XCTestCase {
    // MARK: - Fixtures

    final class Node: NSObject {
        let title: String
        let children: [Node]

        init(title: String, children: [Node] = []) {
            self.title = title
            self.children = children
        }
    }

    /// Serves a two-level tree and records the animation duration in force whenever the outline
    /// view reports a disclosure.
    final class TreeSource: NSObject, NSOutlineViewDataSource, NSOutlineViewDelegate {
        let roots: [Node]
        private(set) var durationsWhileExpanding: [TimeInterval] = []
        private(set) var durationsWhileCollapsing: [TimeInterval] = []

        init(roots: [Node]) { self.roots = roots }

        func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
            (item as? Node)?.children.count ?? roots.count
        }

        func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
            (item as? Node)?.children[index] ?? roots[index]
        }

        func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
            !((item as? Node)?.children.isEmpty ?? true)
        }

        // A view-based outline view is the common case, and only view-based rows carry a real
        // `NSButton` for the disclosure triangle — which one of the tests below clicks.
        func outlineView(_ outlineView: NSOutlineView, viewFor tableColumn: NSTableColumn?, item: Any) -> NSView? {
            let cellView = NSTableCellView()
            let textField = NSTextField(labelWithString: (item as? Node)?.title ?? "")
            cellView.addSubview(textField)
            cellView.textField = textField
            return cellView
        }

        func outlineViewItemDidExpand(_ notification: Notification) {
            durationsWhileExpanding.append(NSAnimationContext.current.duration)
        }

        func outlineViewItemDidCollapse(_ notification: Notification) {
            durationsWhileCollapsing.append(NSAnimationContext.current.duration)
        }
    }

    final class RowSource: NSObject, NSTableViewDataSource, NSTableViewDelegate {
        var rowCount: Int
        init(rowCount: Int) { self.rowCount = rowCount }
        func numberOfRows(in tableView: NSTableView) -> Int { rowCount }
    }

    /// Hosts a view in a real window: a detached outline view never builds the row views the
    /// disclosure triangle lives on.
    @discardableResult
    private func host(_ view: NSView) -> NSWindow {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 300, height: 400),
            styleMask: [.titled], backing: .buffered, defer: false
        )
        window.contentView?.addSubview(view)
        view.frame = NSRect(x: 0, y: 0, width: 300, height: 400)
        window.contentView?.layoutSubtreeIfNeeded()
        return window
    }

    private func makeTree<OutlineViewType: NSOutlineView>(_ type: OutlineViewType.Type) -> (OutlineViewType, TreeSource, Node) {
        let root = Node(
            title: "root",
            children: ["first", "second"].map { Node(title: $0, children: [Node(title: "leaf")]) }
        )
        let source = TreeSource(roots: [root])

        let outlineView = OutlineViewType()
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("column"))
        outlineView.addTableColumn(column)
        outlineView.outlineTableColumn = column
        outlineView.rowHeight = 24
        outlineView.dataSource = source
        outlineView.delegate = source
        return (outlineView, source, root)
    }

    private func disclosureButton(in view: NSView) -> NSButton? {
        if let button = view as? NSButton { return button }
        for subview in view.subviews {
            if let found = disclosureButton(in: subview) { return found }
        }
        return nil
    }

    // MARK: - Intrinsic size

    func testTableReportsItsRowsAsAnIntrinsicHeight() {
        let tableView = SelfSizingTableView()
        let source = RowSource(rowCount: 3)
        tableView.rowHeight = 20
        tableView.dataSource = source
        tableView.delegate = source
        host(tableView)
        tableView.reloadData()

        XCTAssertEqual(tableView.intrinsicContentSize.width, NSView.noIntrinsicMetric, "width is left to the host")
        XCTAssertGreaterThanOrEqual(
            tableView.intrinsicContentSize.height, 60,
            "three 20pt rows, plus whatever inset the table's style reserves"
        )

        source.rowCount = 6
        tableView.reloadData()
        XCTAssertGreaterThanOrEqual(tableView.intrinsicContentSize.height, 120, "twice the rows, at least twice the height")
    }

    func testEmptyTableReportsNoHeight() {
        let tableView = SelfSizingTableView()
        let source = RowSource(rowCount: 0)
        tableView.dataSource = source
        tableView.delegate = source
        host(tableView)
        tableView.reloadData()

        XCTAssertEqual(tableView.intrinsicContentSize.height, 0)
    }

    func testScrollViewTakesItsIntrinsicSizeFromTheDocumentView() {
        let (outlineView, _, root) = makeTree(SelfSizingOutlineView.self)
        let scrollView = SelfSizingScrollView()
        scrollView.documentView = outlineView
        host(scrollView)
        outlineView.reloadData()

        let collapsedHeight = scrollView.intrinsicContentSize.height
        outlineView.expandItem(root)

        XCTAssertGreaterThan(
            scrollView.intrinsicContentSize.height, collapsedHeight,
            "expanding a row must make the scroll view taller, not scroll inside it"
        )
        XCTAssertEqual(scrollView.intrinsicContentSize.height, outlineView.intrinsicContentSize.height)
    }

    func testScrollViewClampsToItsMinimumAndMaximum() {
        let tableView = SelfSizingTableView()
        let source = RowSource(rowCount: 10)
        tableView.rowHeight = 20
        tableView.dataSource = source
        tableView.delegate = source

        let scrollView = SelfSizingScrollView()
        scrollView.documentView = tableView
        host(scrollView)
        tableView.reloadData()

        scrollView.maximumContentSize = NSSize(width: NSView.noIntrinsicMetric, height: 50)
        XCTAssertEqual(scrollView.intrinsicContentSize.height, 50, "past the cap the scrollers take over")

        scrollView.maximumContentSize = NSSize(width: NSView.noIntrinsicMetric, height: NSView.noIntrinsicMetric)
        scrollView.minimumContentSize = NSSize(width: NSView.noIntrinsicMetric, height: 10_000)
        XCTAssertEqual(scrollView.intrinsicContentSize.height, 10_000, "the floor wins over a shorter content")
    }

    // MARK: - Disclosure

    /// The control: a plain outline view discloses on AppKit's default timeline. Without this the
    /// tests below would pass against an implementation that does nothing at all.
    func testPlainOutlineViewDisclosesOnAppKitsDefaultTimeline() {
        let (outlineView, source, root) = makeTree(OutlineView.self)
        host(outlineView)
        outlineView.reloadData()

        outlineView.expandItem(root)

        XCTAssertEqual(source.durationsWhileExpanding, [0.25], "AppKit's default animation duration")
    }

    func testDisclosureDoesNotAnimate() {
        let (outlineView, source, root) = makeTree(SelfSizingOutlineView.self)
        host(outlineView)
        outlineView.reloadData()

        outlineView.expandItem(root)
        outlineView.collapseItem(root)

        XCTAssertEqual(source.durationsWhileExpanding, [0], "expanding must not animate")
        XCTAssertEqual(source.durationsWhileCollapsing, [0], "collapsing must not animate either")
    }

    /// The path that matters in an app: the user clicking the disclosure triangle. It is an
    /// `NSButton` whose `_outlineControlClicked:` action routes through
    /// `expandItem(_:expandChildren:)`, which is the only reason overriding that one method is
    /// enough — this pins it.
    func testClickingTheDisclosureTriangleGoesThroughTheSameOverride() throws {
        let (outlineView, source, _) = makeTree(SelfSizingOutlineView.self)
        host(outlineView)
        outlineView.reloadData()
        outlineView.layoutSubtreeIfNeeded()

        let rowView = try XCTUnwrap(outlineView.rowView(atRow: 0, makeIfNecessary: true))
        let triangle = try XCTUnwrap(disclosureButton(in: rowView), "a view-based row carries a disclosure button")
        triangle.performClick(nil)

        XCTAssertEqual(outlineView.numberOfRows, 3, "clicking the triangle expands the row")
        XCTAssertEqual(source.durationsWhileExpanding, [0], "a clicked disclosure must not animate either")
    }

    func testDisclosureAnimatesAgainWhenAskedTo() {
        let (outlineView, source, root) = makeTree(SelfSizingOutlineView.self)
        outlineView.animatesExpansionAndCollapse = true
        host(outlineView)
        outlineView.reloadData()

        outlineView.expandItem(root)

        XCTAssertEqual(source.durationsWhileExpanding, [0.25], "opting back in restores AppKit's timeline")
    }

    func testExpandingUpdatesTheIntrinsicHeight() {
        let (outlineView, _, root) = makeTree(SelfSizingOutlineView.self)
        host(outlineView)
        outlineView.reloadData()

        let collapsedHeight = outlineView.intrinsicContentSize.height
        outlineView.expandItem(root)
        let expandedHeight = outlineView.intrinsicContentSize.height
        outlineView.collapseItem(root)

        XCTAssertGreaterThan(expandedHeight, collapsedHeight, "a disclosure changes the row count, so the height follows")
        XCTAssertEqual(outlineView.intrinsicContentSize.height, collapsedHeight, "and collapsing takes it back")
    }
}

#endif
