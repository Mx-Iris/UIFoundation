#if canImport(AppKit) && !targetEnvironment(macCatalyst)

import Testing
import AppKit
import UIFoundationToolbox
@testable import UIFoundationAppKit

/// Somewhere for a `#selector` to land.
private final class ActionReceiver: NSObject {
    var receivedSenders: [AnyObject] = []

    @objc func receive(_ sender: Any?) {
        receivedSenders.append(sender as AnyObject)
    }

    static let selector = #selector(ActionReceiver.receive(_:))
}

/// Sends whatever target/action pair the host is carrying, the way AppKit would.
///
/// A click cannot be simulated headlessly, so this is the closest observable stand-in: it proves
/// the pair is actually wired, not merely stored.
@discardableResult
private func sendAction(from host: any TargetActionProvider) -> Bool {
    guard let action = host.action, let target = host.target else { return false }
    let sender: AnyObject = host
    _ = (target as AnyObject).perform(action, with: sender)
    return true
}

@Suite("ToolbarItem target/action")
@MainActor
struct ToolbarItemActionTests {

    // MARK: - The action host

    @Test("a control-hosting item wires the control, not the item wrapper")
    func actionHostIsTheHostedControl() {
        let button = NSToolbar.Button(.init("button"), title: "Button")
        #expect(button.actionHost === button.button)

        let popUpButton = NSToolbar.PopUpButton(.init("popUp"), menu: NSMenu())
        #expect(popUpButton.actionHost === popUpButton.button)

        let segmented = NSToolbar.SegmentedControl(.init("segmented"), labels: ["One", "Two"])
        #expect(segmented.actionHost === segmented.segmentedControl)
    }

    @Test("an item without its own control wires the toolbar item itself")
    func actionHostFallsBackToTheItem() {
        let item = NSToolbar.Item(.init("item"), title: "Item")
        #expect(item.actionHost === item.item)

        let menu = NSToolbar.Menu(.init("menu"), title: "Menu", menu: NSMenu())
        #expect(menu.actionHost === menu.item)

        let group = NSToolbar.Group(.init("group"), items: [])
        #expect(group.actionHost === group.item)

        let view = NSToolbar.View(.init("view"), view: NSButton())
        #expect(view.actionHost === view.item)
    }

    // MARK: - Chained modifiers

    @Test("target(_:action:) reaches the hosted control")
    func chainedTargetActionReachesTheControl() {
        let receiver = ActionReceiver()
        let button = NSToolbar.Button(.init("button"), title: "Button")
            .target(receiver, action: ActionReceiver.selector)

        #expect(button.button.target === receiver)
        #expect(button.button.action == ActionReceiver.selector)
        #expect(button.target === receiver)
        #expect(button.action == ActionReceiver.selector)
    }

    @Test("target(_:) and action(_:) compose, and are readable back")
    func separateChainedModifiersCompose() {
        let receiver = ActionReceiver()
        let item = NSToolbar.Item(.init("item"), title: "Item")
            .target(receiver)
            .action(ActionReceiver.selector)
            .label("Item")

        #expect(item.target === receiver)
        #expect(item.action == ActionReceiver.selector)

        sendAction(from: item.actionHost)
        #expect(receiver.receivedSenders.count == 1)
    }

    @Test("a segmented control takes the pair on the control rather than on the group item")
    func chainedModifiersOnASegmentedControl() {
        let receiver = ActionReceiver()
        let segmented = NSToolbar.SegmentedControl(.init("segmented"), labels: ["One", "Two"])
            .target(receiver, action: ActionReceiver.selector)

        #expect(segmented.segmentedControl.target === receiver)
        #expect(segmented.segmentedControl.action == ActionReceiver.selector)
    }

    // MARK: - Closure handler and target/action are mutually exclusive

    @Test("an installed closure hides the target/action pair it stands on")
    func closureHandlerHidesTheUnderlyingPair() {
        var invocations = 0
        let item = NSToolbar.Item(.init("item"), title: "Item")
            .onAction { _ in invocations += 1 }

        // The pair reads empty even though the host object carries the trampoline.
        #expect(item.target == nil)
        #expect(item.action == nil)
        #expect(item.item.target != nil)
        #expect(item.item.action != nil)

        sendAction(from: item.actionHost)
        #expect(invocations == 1)
    }

    @Test("assigning a target/action drops the closure and leaves no trampoline behind")
    func assigningAPairDropsTheClosure() {
        var invocations = 0
        let receiver = ActionReceiver()
        let item = NSToolbar.Item(.init("item"), title: "Item")
            .onAction { _ in invocations += 1 }

        item.target(receiver, action: ActionReceiver.selector)

        #expect(item.actionBlock == nil)
        #expect(item.item.target === receiver)
        #expect(item.item.action == ActionReceiver.selector)

        sendAction(from: item.actionHost)
        #expect(invocations == 0)
        #expect(receiver.receivedSenders.count == 1)
    }

    @Test("installing a closure over a target/action pair replaces it")
    func closureReplacesAnExistingPair() {
        var invocations = 0
        let receiver = ActionReceiver()
        let button = NSToolbar.Button(.init("button"), title: "Button")
            .target(receiver, action: ActionReceiver.selector)

        button.onAction { _ in invocations += 1 }

        sendAction(from: button.actionHost)
        #expect(invocations == 1)
        #expect(receiver.receivedSenders.isEmpty)
    }

    @Test("clearing the closure leaves the host with no pair at all")
    func clearingTheClosureDetachesTheTrampoline() {
        let button = NSToolbar.Button(.init("button"), title: "Button")
            .onAction { _ in }

        button.actionBlock = nil

        #expect(button.button.target == nil)
        #expect(button.button.action == nil)
        #expect(button.target == nil)
        #expect(button.action == nil)
    }

    // MARK: - The `action:` initializer parameter

    /// Regression: the typed closure used to be a stored property with a `didSet` that installed
    /// the trampoline, and **a property observer does not fire for an assignment made inside the
    /// initializer** — so `Item` and `Button` stored the closure passed to `init(…, action:)` and
    /// wired nothing at all. `SegmentedControl`, the only other item taking that parameter,
    /// escaped it by calling the installer a second time from its own `commonInit()`.
    @Test("a closure passed to the initializer is actually wired", arguments: [0, 1, 2])
    func initializerClosureIsInstalled(itemIndex: Int) {
        var invocations = 0
        let item: ActionableToolbarItem = switch itemIndex {
        case 0: NSToolbar.Item(.init("item"), title: "Item") { _ in invocations += 1 }
        case 1: NSToolbar.Button(.init("button"), title: "Button") { _ in invocations += 1 }
        default: NSToolbar.SegmentedControl(.init("segmented"), labels: ["One"]) { _ in invocations += 1 }
        }

        #expect(sendAction(from: item.actionHost), "the initializer left the host unwired")
        #expect(invocations == 1)
    }

    // MARK: - Forwarded NSToolbarItem properties

    @Test("isBordered is available on every item, not only on NSToolbar.Item")
    func isBorderedIsOnTheBase() {
        let menu = NSToolbar.Menu(.init("menu"), title: "Menu", menu: NSMenu()).isBordered(true)
        #expect(menu.isBordered)
        #expect(menu.item.isBordered)

        let search = NSToolbar.Search(.init("search"))
        search.isBordered = true
        #expect(search.isBordered)
    }

    @Test("isNavigational is available on every item")
    func isNavigationalIsOnTheBase() {
        let item = NSToolbar.Item(.init("item"), title: "Item").isNavigational(true)
        #expect(item.isNavigational)
        #expect(item.item.isNavigational)
    }

    /// Canary on the AppKit behaviour the base-class placement rests on: `NSToolbarItem` forwards
    /// `isBordered` to its custom view, which is what makes one `isBordered` correct for both an
    /// item that draws its own button and an item hosting an `NSButton`. AppKit's header scopes the
    /// property to items *without* a custom view; measured on macOS 26, the setter forwards anyway.
    @Test("NSToolbarItem forwards isBordered to a hosted view")
    func isBorderedForwardsToTheHostedView() {
        let hosted = NSButton(title: "Hosted", target: nil, action: nil)
        hosted.isBordered = false

        let item = NSToolbarItem(itemIdentifier: .init("probe"))
        item.view = hosted
        item.isBordered = true

        #expect(hosted.isBordered)
    }

    /// Canary on the other half of the same behaviour, and on the reason `NSToolbar.Navigation`
    /// is deliberately *not* an ``ActionableToolbarItem``: a pair assigned to an item reaches the
    /// item's custom view, so exposing `target` / `action` on the common base would hand out a
    /// door to `Navigation`'s internal segmented control — whose pair is wired once in `init` and
    /// must stay unreachable, or its segment menus open on a plain click and single-step
    /// navigation disappears.
    @Test("NSToolbarItem forwards target and action to a hosted view")
    func targetAndActionForwardToTheHostedView() {
        let receiver = ActionReceiver()
        let hosted = NSButton(title: "Hosted", target: nil, action: nil)

        let item = NSToolbarItem(itemIdentifier: .init("probe"))
        item.view = hosted
        item.target = receiver
        item.action = ActionReceiver.selector

        #expect(hosted.target === receiver)
        #expect(hosted.action == ActionReceiver.selector)
    }

    @Test("Navigation stays outside the actionable hierarchy")
    func navigationIsNotActionable() {
        let navigation: ToolbarItem = NSToolbar.Navigation(.init("navigation"))
        #expect(!(navigation is ActionableToolbarItem))

        // Its own wiring is intact and points at itself, not at any host-supplied target.
        #expect(navigation.item.view != nil)
    }

    @Test("Search and TrackingSeparator stay outside it too")
    func searchAndTrackingSeparatorAreNotActionable() {
        let search: ToolbarItem = NSToolbar.Search(.init("search"))
        #expect(!(search is ActionableToolbarItem))

        let separator: ToolbarItem = NSToolbar.TrackingSeparator(
            .init("separator"),
            splitView: NSSplitView(),
            dividerIndex: 0
        )
        #expect(!(separator is ActionableToolbarItem))
    }
}

#endif
