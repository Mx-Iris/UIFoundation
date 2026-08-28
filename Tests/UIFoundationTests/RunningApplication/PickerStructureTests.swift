#if RunningApplication && os(macOS)

import AppKit
import Testing
@testable import UIFoundationRunningApplication

/// Structural checks on a loaded picker: which columns exist, how wide they are, and
/// whether the chrome matches the style.
///
/// These exist because two bugs in a row reached a screenshot instead of a test. Both were
/// invisible to the type system and to every pure-function test:
///
/// - A style set at initialisation was ignored, because the base class built its columns
///   before the subclass had applied its configuration.
/// - The single list column kept `NSTableColumn`'s default 100pt width, so every row
///   rendered 100pt across and its labels truncated to a few characters.
@Suite("Picker structure")
@MainActor
struct PickerStructureTests {
    typealias Style = RunningPickerTabViewController.Style

    /// Loads a process picker inside a real window and lays it out.
    ///
    /// The window is not incidental. Assigning a frame to a detached view lets AppKit
    /// autoresize the table's columns as a side effect, which masks a column left at its
    /// default width — the exact bug these tests exist for. Hosting the picker in a window
    /// reproduces what the demo does.
    ///
    /// The window is returned alongside so the caller can keep it alive; releasing it
    /// mid-test tears the view hierarchy down.
    static func loadedPicker(
        style: Style,
        width: CGFloat = 800,
        fields: [RunningPickerTabViewController.ProcessField]? = nil
    ) -> (picker: RunningProcessPickerViewController, window: NSWindow) {
        var configuration = RunningPickerTabViewController.ProcessConfiguration(style: style)
        if let fields { configuration.allowsFields = fields }
        let picker = RunningProcessPickerViewController(configuration: configuration)
        let window = NSWindow(
            contentRect: .init(x: 0, y: 0, width: width, height: 600),
            styleMask: [.titled, .resizable],
            backing: .buffered,
            defer: false
        )
        window.contentViewController = picker
        window.layoutIfNeeded()
        picker.view.layoutSubtreeIfNeeded()
        return (picker, window)
    }

    /// Re-lays out after a change, the way the run loop would.
    static func relayout(_ picker: RunningProcessPickerViewController, in window: NSWindow) {
        window.layoutIfNeeded()
        picker.view.layoutSubtreeIfNeeded()
    }

    // MARK: - Style Applied at Load

    @Test("A style set at initialisation is the one that gets built")
    func styleAtInitialisationIsHonoured() {
        // The regression: columns were built from the default style because the subclass
        // applied its configuration after `super.viewDidLoad()` had already built them.
        let (listPicker, listWindow) = Self.loadedPicker(style: .list)
        #expect(listPicker.tableView.tableColumns.count == 1)
        #expect(listPicker.tableView.tableColumns.first?.identifier.rawValue == ListRowColumn.identifier)
        #expect(listPicker.tableView.headerView == nil)
        #expect(listPicker.tableView.rowHeight == 44)

        let (tablePicker, tableWindow) = Self.loadedPicker(style: .table)
        #expect(tablePicker.tableView.tableColumns.count > 1)
        #expect(tablePicker.tableView.headerView != nil)
        #expect(tablePicker.tableView.rowHeight == 28)
        withExtendedLifetime((listWindow, tableWindow)) {}
    }

    @Test("Configured fields become columns in the table style")
    func fieldsBecomeColumns() {
        let (picker, window) = Self.loadedPicker(style: .table, fields: [.icon, .name, .pid])
        #expect(picker.tableView.tableColumns.map(\.identifier.rawValue) == ["icon", "name", "pid"])
        withExtendedLifetime(window) {}
    }

    // MARK: - Column Width

    @Test("The list column fills the table's width", arguments: [CGFloat(400), 800, 1600])
    func listColumnFillsTheTable(width: CGFloat) {
        let (picker, window) = Self.loadedPicker(style: .list, width: width)
        defer { withExtendedLifetime(window) {} }
        guard let column = picker.tableView.tableColumns.first else {
            Issue.record("expected one column")
            return
        }
        let tableWidth = picker.tableView.bounds.width
        #expect(tableWidth > 0, "table has no width to fill")
        // NSTableColumn starts at 100pt; anything near that means the sizing pass was lost.
        #expect(column.width > 100, "column still at NSTableColumn's default width")
        // Not an exact match: the inset table style reserves padding on both edges.
        #expect(column.width >= tableWidth * 0.9,
                "column \(column.width) vs table \(tableWidth)")
    }

    @Test("The list column is given a width when it is built, not left at the default")
    func listColumnGetsAnExplicitWidthWhenBuilt() {
        // Asserted without an intervening layout on purpose. Whether AppKit later
        // autoresizes the column depends on whether the table's frame happens to change,
        // which is precisely why relying on it failed: switching style in a window that is
        // not being resized never triggers it, and the column stays 100pt wide.
        let (picker, window) = Self.loadedPicker(style: .table)
        defer { withExtendedLifetime(window) {} }

        picker.updateStyle(.list)
        guard let column = picker.tableView.tableColumns.first else {
            Issue.record("expected one column")
            return
        }
        // Only the width matters here, not how it compares to the table: in the table
        // style the table is as wide as its columns combined, so the two are not
        // comparable across the switch. Filling the visible width is covered separately,
        // after a layout.
        #expect(column.width != 100, "column left at NSTableColumn's default width")
        #expect(column.width > 300, "column \(column.width) is implausibly narrow")
    }

    @Test("The list column keeps filling the table after a resize")
    func listColumnFollowsAResize() {
        let (picker, window) = Self.loadedPicker(style: .list, width: 600)
        defer { withExtendedLifetime(window) {} }
        window.setContentSize(.init(width: 1200, height: 600))
        Self.relayout(picker, in: window)

        guard let column = picker.tableView.tableColumns.first else {
            Issue.record("expected one column")
            return
        }
        #expect(column.width >= picker.tableView.bounds.width * 0.9,
                "column \(column.width) vs table \(picker.tableView.bounds.width)")
    }

    // MARK: - Chrome

    @Test("The sort control appears only in the list style")
    func sortControlVisibility() {
        let list = Self.loadedPicker(style: .list)
        let table = Self.loadedPicker(style: .table)
        #expect(list.picker.sortControl.isHidden == false)
        #expect(table.picker.sortControl.isHidden == true)
        withExtendedLifetime((list.window, table.window)) {}
    }

    @Test("The sort menu offers every sortable field and nothing else")
    func sortMenuContents() {
        let (picker, window) = Self.loadedPicker(style: .list, fields: [.icon, .name, .pid, .platform])
        defer { withExtendedLifetime(window) {} }
        let titles = picker.sortControl.menu?.items.map(\.title) ?? []
        // `icon` has no header title, so it is not sortable and must not appear as a blank.
        #expect(titles.count == 3, "\(titles)")
        #expect(!titles.contains(""), "\(titles)")
    }

    // MARK: - Runtime Switching

    @Test("Switching style rebuilds the columns and the chrome")
    func switchingStyleRebuilds() {
        let (picker, window) = Self.loadedPicker(style: .table)
        defer { withExtendedLifetime(window) {} }
        let originalColumnCount = picker.tableView.tableColumns.count

        // The window is never resized across the switch — exactly the situation that left
        // the column at its default width.
        picker.updateStyle(.list)
        Self.relayout(picker, in: window)
        #expect(picker.tableView.tableColumns.count == 1)
        #expect(picker.tableView.headerView == nil)
        #expect(picker.tableView.rowHeight == 44)
        #expect(picker.sortControl.isHidden == false)
        #expect(picker.tableView.tableColumns[0].width >= picker.tableView.bounds.width * 0.9)

        picker.updateStyle(.table)
        Self.relayout(picker, in: window)
        #expect(picker.tableView.tableColumns.count == originalColumnCount)
        #expect(picker.tableView.headerView != nil)
        #expect(picker.tableView.rowHeight == 28)
        #expect(picker.sortControl.isHidden == true)
    }

    @Test("Switching to the same style is a no-op")
    func switchingToTheSameStyleDoesNothing() {
        let (picker, window) = Self.loadedPicker(style: .list)
        defer { withExtendedLifetime(window) {} }
        let columnBefore = picker.tableView.tableColumns.first
        picker.updateStyle(.list)
        #expect(picker.tableView.tableColumns.first === columnBefore)
    }
}

#endif
