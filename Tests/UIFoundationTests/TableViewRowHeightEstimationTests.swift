#if AppleInternal && os(macOS)

import AppKit
import Testing
import FrameworkToolbox
import UIFoundationAppleInternal

/// Covers `NSTableView.box.estimatesRowHeights`, the switch for AppKit's private row-height
/// estimation, and the reason it exists.
///
/// The fixture has the shape that goes wrong in practice: a source list outline whose group rows
/// make its rows differ in height, long enough that the table estimates, scrolled far past its
/// second group row. Reverse-engineering notes:
/// `Researchs/AppKit-NSTableView-RowHeightEstimation-Internals.md`.
@Suite("NSTableView row height estimation", .serialized)
@MainActor
struct TableViewRowHeightEstimationTests {
    @Test("Setting the delegate of a source list with group rows turns estimation on")
    func settingDelegateTurnsEstimationOn() throws {
        let fixture = Fixture(estimatesRowHeights: nil)
        let estimatesRowHeights = try #require(fixture.outlineView.box.estimatesRowHeights, "AppKit dropped the private switch")

        #expect(estimatesRowHeights)
    }

    @Test("Estimation stays off until the delegate changes")
    func estimationStaysOffUntilDelegateChanges() throws {
        let fixture = Fixture(estimatesRowHeights: false)
        try #require(fixture.outlineView.box.estimatesRowHeights != nil, "AppKit dropped the private switch")

        _ = fixture.overlapsAfterReloadingFarDown()
        #expect(fixture.outlineView.box.estimatesRowHeights == false)

        fixture.outlineView.delegate = nil
        fixture.outlineView.delegate = fixture.source
        #expect(fixture.outlineView.box.estimatesRowHeights == true)
    }

    @Test("With estimation off, a reload far down draws no row over another")
    func reloadFarDownKeepsRowsInPlace() throws {
        let fixture = Fixture(estimatesRowHeights: false)
        try #require(fixture.outlineView.box.estimatesRowHeights != nil, "AppKit dropped the private switch")

        #expect(fixture.overlapsAfterReloadingFarDown().isEmpty)
    }

    /// Switching discards the table's row geometry but neither reloads the table nor moves the row
    /// views on screen, so rows placed from an estimate stay where it put them — the guide's
    /// contract. The reload the guide asks for afterwards is what puts them right.
    @Test("Switching estimation off with estimated rows on screen, then reloading, puts every row where the table places it")
    func reloadAfterSwitchingPlacesRowsOnScreen() throws {
        let fixture = Fixture(estimatesRowHeights: nil)
        try #require(fixture.outlineView.box.estimatesRowHeights == true, "AppKit dropped the private switch, or no longer estimates here")
        fixture.scroll(toOriginY: 27000)
        fixture.window.displayIfNeeded()

        fixture.outlineView.box.estimatesRowHeights = false
        fixture.outlineView.reloadData()
        fixture.outlineView.layoutSubtreeIfNeeded()
        fixture.window.displayIfNeeded()

        let misplacedRows = fixture.misplacedRowViews()
        #expect(misplacedRows.isEmpty, "\(misplacedRows.count) rows not where the table places them: \(misplacedRows.prefix(3))")
    }

    /// The reason the switch exists. Should AppKit ever place these rows correctly on its own,
    /// this test fails with "Known issue was not recorded" — the cue to find out on which releases
    /// the switch is still needed.
    @Test("With estimation on, AppKit draws rows over each other after a reload far down")
    func estimationMisplacesRowsAfterReloadFarDown() {
        let fixture = Fixture(estimatesRowHeights: nil)

        let overlaps = fixture.overlapsAfterReloadingFarDown()

        withKnownIssue("AppKit leaves row views where its old estimate put them") {
            #expect(overlaps.isEmpty)
        }
    }
}

// MARK: - Fixture

extension TableViewRowHeightEstimationTests {
    /// A grouped list the size and shape of a runtime-object sidebar: nine group rows over 1,183
    /// rows, some of them expandable, in a window, with every group expanded.
    @MainActor
    final class Fixture {
        let window: NSWindow
        let scrollView: NSScrollView
        let outlineView: NSOutlineView
        let source: GroupedListSource

        /// `estimatesRowHeights` is written after the delegate, since setting the delegate turns
        /// estimation on; `nil` leaves AppKit's own choice.
        init(estimatesRowHeights: Bool?) {
            outlineView = NSOutlineView()
            outlineView.addTableColumn(NSTableColumn(identifier: NSUserInterfaceItemIdentifier("Column")))
            outlineView.headerView = nil
            outlineView.style = .sourceList
            outlineView.rowHeight = 24

            scrollView = NSScrollView(frame: NSRect(x: 0, y: 0, width: 300, height: 600))
            scrollView.documentView = outlineView
            scrollView.hasVerticalScroller = true

            window = NSWindow(
                contentRect: NSRect(x: -6000, y: -6000, width: 300, height: 600),
                styleMask: [.titled],
                backing: .buffered,
                defer: false
            )
            window.isReleasedWhenClosed = false
            window.contentView = scrollView
            // On screen, but outside every display: a table that was never shown does not tile
            // its rows the way the bug needs.
            window.orderFrontRegardless()

            source = GroupedListSource()
            outlineView.dataSource = source
            outlineView.delegate = source
            if let estimatesRowHeights {
                outlineView.box.estimatesRowHeights = estimatesRowHeights
            }

            outlineView.reloadData()
            for group in source.groups {
                outlineView.expandItem(group)
            }
            scrollView.layoutSubtreeIfNeeded()
            window.displayIfNeeded()
        }

        deinit {
            MainActor.assumeIsolated {
                window.orderOut(nil)
            }
        }

        /// At a series of positions past the second group row: scrolls there, reloads, scrolls a
        /// little further, and records every two rows then drawn over each other — laying the
        /// table out after each step, as a scroll or a reload in a window would.
        ///
        /// A series rather than one position because whether a given position shows the bug
        /// depends on where the group rows fall relative to the visible rows, which moves with the
        /// window's height.
        func overlapsAfterReloadingFarDown() -> [String] {
            var overlaps: [String] = []
            for originY in stride(from: CGFloat(17000), through: 27000, by: 500) {
                scroll(toOriginY: originY)
                outlineView.reloadData()
                outlineView.layoutSubtreeIfNeeded()
                scroll(toOriginY: originY + 100)
                overlaps += overlappingRowViewPairs().map { pair in "at y \(Int(originY)): \(pair)" }
            }
            return overlaps
        }

        func scroll(toOriginY originY: CGFloat) {
            let clipView = scrollView.contentView
            clipView.scroll(to: NSPoint(x: 0, y: originY))
            scrollView.reflectScrolledClipView(clipView)
            outlineView.layoutSubtreeIfNeeded()
        }

        /// The titles of every two displayed row views whose frames overlap.
        func overlappingRowViewPairs() -> [String] {
            let rowViews = displayedRowViews().filter { rowView in !rowView.isFloating }
            var pairs: [String] = []
            for firstIndex in rowViews.indices {
                for secondIndex in rowViews.indices where secondIndex > firstIndex {
                    let overlap = rowViews[firstIndex].frame.intersection(rowViews[secondIndex].frame)
                    if overlap.height > 1, overlap.width > 1 {
                        pairs.append("\(title(of: rowViews[firstIndex])) / \(title(of: rowViews[secondIndex]))")
                    }
                }
            }
            return pairs
        }

        /// Every displayed row view whose frame is not at the position `rect(ofRow:)` gives for its
        /// row.
        func misplacedRowViews() -> [String] {
            displayedRowViews().compactMap { rowView in
                let row = outlineView.row(for: rowView)
                guard row >= 0 else { return nil }
                let expectedMinY = outlineView.rect(ofRow: row).minY
                guard abs(rowView.frame.minY - expectedMinY) > 0.5 else { return nil }
                return "\(title(of: rowView)) at y \(rowView.frame.minY), expected \(expectedMinY)"
            }
        }

        private func displayedRowViews() -> [NSTableRowView] {
            outlineView.subviews
                .compactMap { $0 as? NSTableRowView }
                .filter { rowView in !rowView.isHidden && rowView.alphaValue > 0.01 }
        }

        private func title(of rowView: NSTableRowView) -> String {
            let cellView = rowView.subviews.lazy.compactMap { $0 as? TitleCellView }.first
            return cellView?.titleLabel.stringValue ?? "<no cell>"
        }
    }

    final class TitleCellView: NSTableCellView {
        static let reuseIdentifier = NSUserInterfaceItemIdentifier("TitleCellView")

        let titleLabel = NSTextField(labelWithString: "")

        init() {
            super.init(frame: .zero)
            identifier = Self.reuseIdentifier
            addSubview(titleLabel)
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
    }

    /// Nine groups whose sizes follow an image's kinds, all rows the same height.
    ///
    /// From the third group on, every tenth row holds one child and stays collapsed — the nested
    /// types of a sidebar. They are load-bearing: with no expandable row anywhere, AppKit places
    /// every row correctly even while estimating, and the bug does not show.
    final class GroupedListSource: NSObject, NSOutlineViewDataSource, NSOutlineViewDelegate {
        final class Group: NSObject {
            let title: String
            let rows: [Row]

            init(title: String, rows: [Row]) {
                self.title = title
                self.rows = rows
            }
        }

        final class Row: NSObject {
            let title: String
            let children: [Row]

            init(title: String, children: [Row] = []) {
                self.title = title
                self.children = children
            }
        }

        let groups: [Group]

        override init() {
            let rowCounts = [700, 250, 45, 60, 25, 70, 3, 12, 18]
            groups = rowCounts.enumerated().map { groupIndex, rowCount in
                Group(
                    title: "Group \(groupIndex)",
                    rows: (0 ..< rowCount).map { rowIndex in
                        let isExpandable = groupIndex >= 2 && rowIndex % 10 == 0
                        let children = isExpandable ? [Row(title: "Child \(groupIndex).\(rowIndex)")] : []
                        return Row(title: "Row \(groupIndex).\(rowIndex)", children: children)
                    }
                )
            }
            super.init()
        }

        func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
            switch item {
            case nil: return groups.count
            case let group as Group: return group.rows.count
            case let row as Row: return row.children.count
            default: return 0
            }
        }

        func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
            switch item {
            case let group as Group: return group.rows[index]
            case let row as Row: return row.children[index]
            default: return groups[index]
            }
        }

        func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
            switch item {
            case is Group: return true
            case let row as Row: return !row.children.isEmpty
            default: return false
            }
        }

        func outlineView(_ outlineView: NSOutlineView, isGroupItem item: Any) -> Bool {
            item is Group
        }

        func outlineView(_ outlineView: NSOutlineView, viewFor tableColumn: NSTableColumn?, item: Any) -> NSView? {
            let cellView = outlineView.makeView(withIdentifier: TitleCellView.reuseIdentifier, owner: nil) as? TitleCellView ?? TitleCellView()
            cellView.titleLabel.stringValue = (item as? Group)?.title ?? (item as? Row)?.title ?? ""
            return cellView
        }
    }
}

#endif
