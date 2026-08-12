#if canImport(AppKit) && !targetEnvironment(macCatalyst)

import Testing
import AppKit
@testable import UIFoundationAppKit

/// A host that answers from a pair of plain arrays, nearest entry first.
private final class NavigationHistorySpy: NSToolbar.Navigation.DataSource, NSToolbar.Navigation.Delegate {
    var backwardEntries: [String] = []
    var forwardEntries: [String] = []
    var resolvedEntryIndices: [(index: Int, direction: NSToolbar.Navigation.Direction)] = []

    var navigatedDirections: [NSToolbar.Navigation.Direction] = []
    var chosenHistoryRows: [(index: Int, direction: NSToolbar.Navigation.Direction)] = []

    private func entries(in direction: NSToolbar.Navigation.Direction) -> [String] {
        switch direction {
        case .backward: backwardEntries
        case .forward: forwardEntries
        }
    }

    func navigationToolbarItem(
        _ item: NSToolbar.Navigation,
        canNavigateIn direction: NSToolbar.Navigation.Direction
    ) -> Bool {
        !entries(in: direction).isEmpty
    }

    func navigationToolbarItem(
        _ item: NSToolbar.Navigation,
        numberOfHistoryEntriesIn direction: NSToolbar.Navigation.Direction
    ) -> Int {
        entries(in: direction).count
    }

    func navigationToolbarItem(
        _ item: NSToolbar.Navigation,
        historyEntryAt index: Int,
        in direction: NSToolbar.Navigation.Direction
    ) -> NSToolbar.Navigation.HistoryEntry {
        resolvedEntryIndices.append((index, direction))
        return .init(title: entries(in: direction)[index])
    }

    func navigationToolbarItem(
        _ item: NSToolbar.Navigation,
        didNavigateIn direction: NSToolbar.Navigation.Direction
    ) {
        navigatedDirections.append(direction)
    }

    func navigationToolbarItem(
        _ item: NSToolbar.Navigation,
        didSelectHistoryEntryAt index: Int,
        in direction: NSToolbar.Navigation.Direction
    ) {
        chosenHistoryRows.append((index, direction))
    }
}

/// A host that wants the chevrons and nothing else, to prove the history half of
/// the data source really is optional.
private final class MinimalNavigationHost: NSToolbar.Navigation.DataSource, NSToolbar.Navigation.Delegate {
    var canGoBackward = false

    func navigationToolbarItem(
        _ item: NSToolbar.Navigation,
        canNavigateIn direction: NSToolbar.Navigation.Direction
    ) -> Bool {
        direction == .backward ? canGoBackward : false
    }

    func navigationToolbarItem(
        _ item: NSToolbar.Navigation,
        didNavigateIn direction: NSToolbar.Navigation.Direction
    ) {}
}

/// A host whose second history row cannot be chosen.
private final class PartlyDisabledHistoryHost: NSToolbar.Navigation.DataSource, NSToolbar.Navigation.Delegate {
    func navigationToolbarItem(
        _ item: NSToolbar.Navigation,
        canNavigateIn direction: NSToolbar.Navigation.Direction
    ) -> Bool {
        direction == .backward
    }

    func navigationToolbarItem(
        _ item: NSToolbar.Navigation,
        numberOfHistoryEntriesIn direction: NSToolbar.Navigation.Direction
    ) -> Int {
        direction == .backward ? 2 : 0
    }

    func navigationToolbarItem(
        _ item: NSToolbar.Navigation,
        historyEntryAt index: Int,
        in direction: NSToolbar.Navigation.Direction
    ) -> NSToolbar.Navigation.HistoryEntry {
        .init(title: "Row \(index)", isEnabled: index == 0)
    }

    func navigationToolbarItem(
        _ item: NSToolbar.Navigation,
        didNavigateIn direction: NSToolbar.Navigation.Direction
    ) {}
}

/// A host with exactly one step of history, which navigating uses up.
private final class SingleStepHistoryHost: NSToolbar.Navigation.DataSource, NSToolbar.Navigation.Delegate {
    var remainingBackwardSteps = 1

    func navigationToolbarItem(
        _ item: NSToolbar.Navigation,
        canNavigateIn direction: NSToolbar.Navigation.Direction
    ) -> Bool {
        direction == .backward && remainingBackwardSteps > 0
    }

    func navigationToolbarItem(
        _ item: NSToolbar.Navigation,
        didNavigateIn direction: NSToolbar.Navigation.Direction
    ) {
        remainingBackwardSteps -= 1
    }
}

/// The behaviour that made this item worth extracting.
///
/// Two of these tests are regressions for AppKit behaviours that are invisible in
/// the API and cost a debugging session each: a segment menu only opens on a long
/// press while the control has an action, and an empty `NSMenu` still pops as an
/// empty box. The long press itself cannot be driven headlessly, so what is
/// asserted here is the state the item leaves the control in — an action that is
/// never `nil`, and a menu that is detached rather than emptied.
@Suite("NSToolbar.Navigation")
@MainActor
struct ToolbarNavigationItemTests {

    private func makeItem(dataSource: NavigationHistorySpy) -> NSToolbar.Navigation {
        let item = NSToolbar.Navigation()
        item.dataSource = dataSource
        item.delegate = dataSource
        item.validate()
        return item
    }

    /// Sends the control's action the way AppKit would, so the item's own
    /// dispatch is what runs.
    @discardableResult
    private func sendAction(of control: NSControl) -> Bool {
        guard let action = control.action else {
            Issue.record("the control has no action to send")
            return false
        }
        return NSApplication.shared.sendAction(action, to: control.target, from: control)
    }

    @discardableResult
    private func sendAction(of menuItem: NSMenuItem) -> Bool {
        guard let action = menuItem.action else {
            Issue.record("the menu row has no action to send")
            return false
        }
        return NSApplication.shared.sendAction(action, to: menuItem.target, from: menuItem)
    }

    // MARK: - Control shape

    @Test("the control is a momentary two-segment pair with no menu indicators")
    func controlShape() {
        let item = NSToolbar.Navigation()
        let control = item.segmentedControl

        #expect(control.segmentCount == 2)
        // Momentary because pressing a chevron is an action, not a choice:
        // .selectOne would leave the segment lit afterwards.
        #expect(control.trackingMode == .momentary)
        // A menu indicator would make the pair read as two pop-up buttons; the
        // system's own navigation controls have none.
        #expect(!control.showsMenuIndicator(forSegment: 0))
        #expect(!control.showsMenuIndicator(forSegment: 1))
    }

    /// A canary, not a claim about our code: measured on macOS 26, the indicator
    /// already defaults to off and `setMenu(_:forSegment:)` does not turn it on,
    /// so the item does not re-assert it per attachment. If a future release
    /// starts flipping it, this goes red and the re-assertion belongs back in
    /// ``NSToolbar/Navigation/validate()``.
    @Test("attaching a history menu does not raise a menu indicator")
    func attachingAMenuLeavesTheIndicatorOff() {
        let host = NavigationHistorySpy()
        host.backwardEntries = ["Overview"]
        let item = makeItem(dataSource: host)

        #expect(item.segmentedControl.menu(forSegment: 0) != nil)
        #expect(!item.segmentedControl.showsMenuIndicator(forSegment: 0))
    }

    @Test("each segment carries a direction-aware chevron and a tooltip")
    func segmentPresentation() {
        let item = NSToolbar.Navigation()
        item.backwardTitle = "Zurück"
        item.forwardTitle = "Vorwärts"

        #expect(item.segmentedControl.image(forSegment: 0) != nil)
        #expect(item.segmentedControl.image(forSegment: 1) != nil)
        #expect(item.segmentedControl.toolTip(forSegment: 0) == "Zurück")
        #expect(item.segmentedControl.toolTip(forSegment: 1) == "Vorwärts")
        // The image's description is what VoiceOver reads, so it has to follow
        // the title too.
        #expect(item.segmentedControl.image(forSegment: 0)?.accessibilityDescription == "Zurück")
    }

    @Test("the hosted item reports itself as navigational")
    func hostedItemIsNavigational() {
        guard #available(macOS 11.0, *) else { return }
        let item = NSToolbar.Navigation()
        #expect(item.item.isNavigational)
        #expect(item.item.view === item.segmentedControl)
    }

    // MARK: - Availability

    @Test("a segment is live only while the data source says that move exists")
    func segmentEnablementFollowsTheDataSource() {
        let host = NavigationHistorySpy()
        let item = makeItem(dataSource: host)

        #expect(!item.segmentedControl.isEnabled(forSegment: 0))
        #expect(!item.segmentedControl.isEnabled(forSegment: 1))

        host.backwardEntries = ["Overview"]
        item.validate()
        #expect(item.segmentedControl.isEnabled(forSegment: 0))
        #expect(!item.segmentedControl.isEnabled(forSegment: 1))

        host.forwardEntries = ["Details"]
        item.validate()
        #expect(item.segmentedControl.isEnabled(forSegment: 1))
    }

    @Test("with no data source both halves are dead rather than crashing")
    func noDataSource() {
        let item = NSToolbar.Navigation()
        item.validate()

        #expect(!item.segmentedControl.isEnabled(forSegment: 0))
        #expect(!item.segmentedControl.isEnabled(forSegment: 1))
        #expect(item.segmentedControl.menu(forSegment: 0) == nil)
    }

    // MARK: - Contract: an empty history detaches the menu

    /// A segment wired to a menu with no rows still pops an empty box on a long
    /// press, so "no history" has to mean no menu at all.
    @Test("an empty history detaches the menu instead of emptying it")
    func emptyHistoryDetachesTheMenu() {
        let host = NavigationHistorySpy()
        let item = makeItem(dataSource: host)

        #expect(item.segmentedControl.menu(forSegment: 0) == nil)
        #expect(item.segmentedControl.menu(forSegment: 1) == nil)

        host.backwardEntries = ["Overview", "Index"]
        item.validate()
        #expect(item.segmentedControl.menu(forSegment: 0) != nil)
        #expect(item.segmentedControl.menu(forSegment: 1) == nil, "forward has no history but got a menu")

        host.backwardEntries = []
        item.validate()
        #expect(item.segmentedControl.menu(forSegment: 0) == nil, "the menu was emptied instead of detached")
    }

    // MARK: - Contract: the action is never nil

    /// A control with segment menus and no action opens them on an ordinary
    /// click, which silently removes single-step navigation. The item owns the
    /// wiring, so neither a missing delegate nor a host clearing it can leave
    /// the control action-less.
    @Test("the control keeps an action with no delegate attached")
    func actionSurvivesAMissingDelegate() {
        let item = NSToolbar.Navigation()
        item.validate()

        #expect(item.segmentedControl.action != nil)
        #expect(item.segmentedControl.target != nil)
    }

    /// The control is internal, so no host can clear the action — what is left to
    /// guard is the item clearing it itself. Validation rewrites both menus every
    /// pass, which is the plausible place for a future edit to reset the wiring
    /// along with them.
    @Test("the action survives menus being attached and detached")
    func actionSurvivesMenuChurn() {
        let host = NavigationHistorySpy()
        let item = makeItem(dataSource: host)

        for entries in [["Overview", "Index"], [], ["Details"]] {
            host.backwardEntries = entries
            item.validate()
            #expect(item.segmentedControl.action != nil, "the action went away with \(entries.count) entries")
            #expect(item.segmentedControl.target === item)
        }
    }

    // MARK: - History menu contents

    @Test("the menu is filled only when it opens, nearest entry first")
    func historyMenuIsFilledOnDemand() {
        let host = NavigationHistorySpy()
        host.backwardEntries = ["Details", "Index", "Overview"]
        let item = makeItem(dataSource: host)

        // Validation settles whether there is a menu; it must not pay for the
        // rows, which a host may resolve an icon for.
        #expect(host.resolvedEntryIndices.isEmpty, "rows were built during validation")

        guard let menu = item.segmentedControl.menu(forSegment: 0) else {
            Issue.record("the backward segment has no menu to open")
            return
        }
        item.menuNeedsUpdate(menu)

        #expect(menu.items.map(\.title) == ["Details", "Index", "Overview"])
        #expect(host.resolvedEntryIndices.map(\.index) == [0, 1, 2])
        #expect(host.resolvedEntryIndices.allSatisfy { $0.direction == .backward })
    }

    @Test("re-opening the menu rebuilds it rather than appending")
    func historyMenuIsRebuiltEachTime() {
        let host = NavigationHistorySpy()
        host.forwardEntries = ["Details"]
        let item = makeItem(dataSource: host)

        guard let menu = item.segmentedControl.menu(forSegment: 1) else {
            Issue.record("the forward segment has no menu to open")
            return
        }
        item.menuNeedsUpdate(menu)
        host.forwardEntries = ["Index", "Overview"]
        item.menuNeedsUpdate(menu)

        #expect(menu.items.map(\.title) == ["Index", "Overview"])
    }

    /// The rows come from the data source, including whether each one can be
    /// chosen; AppKit's automatic enabling would overrule a disabled row.
    @Test("a disabled entry stays disabled")
    func disabledEntryStaysDisabled() {
        let host = PartlyDisabledHistoryHost()
        let item = NSToolbar.Navigation()
        item.dataSource = host
        item.delegate = host
        item.validate()

        guard let menu = item.segmentedControl.menu(forSegment: 0) else {
            Issue.record("the backward segment has no menu to open")
            return
        }
        item.menuNeedsUpdate(menu)
        // The overrule happens in `update()`, which AppKit runs just before the
        // menu appears — reading straight after filling would pass either way.
        menu.update()

        #expect(menu.items[0].isEnabled)
        #expect(!menu.items[1].isEnabled)
    }

    // MARK: - Dispatch

    /// Driven through ``NSToolbar/Navigation/performNavigation(in:)`` rather than
    /// through the control, because a momentary click cannot be faked: measured,
    /// assigning `selectedSegment` on a momentary `NSSegmentedControl` reads back
    /// as -1, AppKit's "nothing is being tracked". The action's own read of that
    /// property is covered by ``segmentActionIsLive()`` and by hand in the demo.
    @Test("navigating reports its direction to the delegate")
    func navigationReportsDirection() {
        let host = NavigationHistorySpy()
        host.backwardEntries = ["Overview"]
        host.forwardEntries = ["Details"]
        let item = makeItem(dataSource: host)

        item.performNavigation(in: .backward)
        item.performNavigation(in: .forward)

        #expect(host.navigatedDirections == [.backward, .forward])
    }

    /// The action cannot be aimed at a segment here, but it can be sent — and a
    /// selector that did not resolve on the target would come back `false`. That
    /// is what keeps the never-`nil`-action contract from being satisfied by a
    /// dangling selector.
    @Test("the segment action resolves on the item")
    func segmentActionIsLive() {
        let host = NavigationHistorySpy()
        host.backwardEntries = ["Overview"]
        let item = makeItem(dataSource: host)

        #expect(sendAction(of: item.segmentedControl))
        #expect(host.navigatedDirections.isEmpty, "an untracked control somehow named a segment")
    }

    @Test("choosing a history row reports its index and direction")
    func historyRowReportsItsIndex() {
        let host = NavigationHistorySpy()
        host.backwardEntries = ["Details", "Index", "Overview"]
        let item = makeItem(dataSource: host)

        guard let menu = item.segmentedControl.menu(forSegment: 0) else {
            Issue.record("the backward segment has no menu to open")
            return
        }
        item.menuNeedsUpdate(menu)
        sendAction(of: menu.items[2])

        #expect(host.chosenHistoryRows.count == 1)
        #expect(host.chosenHistoryRows.first?.index == 2)
        #expect(host.chosenHistoryRows.first?.direction == .backward)
    }

    @Test("navigating refreshes the control without the host asking")
    func navigatingRevalidates() {
        let host = SingleStepHistoryHost()
        let item = NSToolbar.Navigation()
        item.dataSource = host
        item.delegate = host
        item.validate()
        #expect(item.segmentedControl.isEnabled(forSegment: 0))

        item.performNavigation(in: .backward)

        #expect(
            !item.segmentedControl.isEnabled(forSegment: 0),
            "the exhausted segment stayed live until the next validation cycle"
        )
    }

    // MARK: - Optional history

    /// A host that implements only the two required methods gets working
    /// chevrons and no history menus, which is the point of the defaults.
    @Test("a host can skip the history half of the data source entirely")
    func historyIsOptional() {
        let host = MinimalNavigationHost()
        let item = NSToolbar.Navigation()
        item.dataSource = host
        item.delegate = host

        host.canGoBackward = true
        item.validate()

        #expect(item.segmentedControl.isEnabled(forSegment: 0))
        #expect(item.segmentedControl.menu(forSegment: 0) == nil)
        #expect(item.segmentedControl.action != nil)
    }

    // MARK: - Toolbar integration

    /// AppKit's own validation cycle needs a key window and cannot be observed
    /// here, so what this pins down is the half that is ours: the native item
    /// AppKit validates has to forward to the managed wrapper. Without the
    /// forwarding the data source would never be asked anything.
    @Test("the native item's validation reaches the managed item")
    func nativeValidationReachesTheManagedItem() {
        let host = NavigationHistorySpy()
        let item = NSToolbar.Navigation()
        item.dataSource = host
        item.delegate = host

        let toolbar = NSToolbar(items: [item])
        #expect(toolbar.box.managedItems.count == 1)

        host.backwardEntries = ["Overview"]
        #expect(!item.segmentedControl.isEnabled(forSegment: 0))

        item.item.validate()
        #expect(item.segmentedControl.isEnabled(forSegment: 0))
    }
}

#endif
