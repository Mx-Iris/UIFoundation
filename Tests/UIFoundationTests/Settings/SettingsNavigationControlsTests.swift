#if Settings && os(macOS)

import AppKit
import SwiftUI
import Testing

@testable import UIFoundationSettingsUI

/// That the back / forward control actually reaches the window's toolbar, in the
/// shape Xcode's settings window uses, and that it tracks the navigator.
///
/// ``SettingsNavigatorTests`` covers the history semantics; this covers the wiring
/// between them and AppKit — a correct navigator whose buttons never appear is
/// still a broken feature.
@MainActor
@Suite("Settings navigation controls")
struct SettingsNavigationControlsTests {
    private static let sidebarWidth: CGFloat = 185

    /// Toolbar items SwiftUI did not install for itself — ours.
    private static func hostSuppliedToolbarItems(in window: NSWindow) -> [NSToolbarItem] {
        (window.toolbar?.items ?? []).filter {
            !$0.itemIdentifier.rawValue.hasPrefix("com.apple.SwiftUI")
                && !$0.itemIdentifier.rawValue.hasPrefix("NSToolbar")
        }
    }

    private static func segmentedControl(in window: NSWindow) -> NSSegmentedControl? {
        var found: NSSegmentedControl?
        func walk(_ view: NSView) {
            if found != nil { return }
            if let control = view as? NSSegmentedControl { found = control; return }
            view.subviews.forEach(walk)
        }
        for item in hostSuppliedToolbarItems(in: window) {
            if let itemView = item.view { walk(itemView) }
        }
        return found
    }

    @available(macOS 14.0, *)
    private static func makeHostedWindow(
        navigator: SettingsNavigator,
        showsNavigationControls: Bool = true
    ) async -> NSWindow {
        let rootView = SettingsRootView(
            configuration: .init(
                sidebarWidth: sidebarWidth,
                showsNavigationControls: showsNavigationControls
            ),
            navigator: navigator
        ) {
            SettingsPage("General", id: "general", symbol: "gearshape") { Text("general") }
            SettingsPage("Advanced", id: "advanced", symbol: "slider.horizontal.3") { Text("advanced") }
        }
        let hostingController = NSHostingController(rootView: rootView)
        let window = NSWindow(contentViewController: hostingController)
        window.setContentSize(NSSize(width: 715, height: 400))
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView]
        window.orderBack(nil)
        hostingController.view.layoutSubtreeIfNeeded()

        for _ in 0 ..< 15 {
            try? await Task.sleep(for: .milliseconds(20))
        }
        return window
    }

    /// One item, not two. Xcode's settings navigation is a single toolbar item;
    /// two adjacent items would draw as two separate controls.
    @Test("the navigation control is a single toolbar item")
    func oneToolbarItem() async {
        guard #available(macOS 14.0, *) else { return }
        let window = await Self.makeHostedWindow(navigator: SettingsNavigator(initialPageID: "general"))
        defer { window.close() }

        let items = Self.hostSuppliedToolbarItems(in: window)
        #expect(items.count == 1, "expected one navigation item, got \(items.map(\.itemIdentifier.rawValue))")
    }

    /// Every attribute here was read off a view-hierarchy capture of Xcode's own
    /// settings window. They are what `.controlGroupStyle(.navigation)` produces
    /// and what the other spellings do not — a plain `ControlGroup` resolves to a
    /// native item with no hosting view, and two `ToolbarItem`s draw as two
    /// separate controls.
    @Test("it is the same segmented control Xcode's settings window uses")
    func matchesXcodesControl() async {
        guard #available(macOS 14.0, *) else { return }
        let window = await Self.makeHostedWindow(navigator: SettingsNavigator(initialPageID: "general"))
        defer { window.close() }

        let control = Self.segmentedControl(in: window)
        #expect(control != nil, "no NSSegmentedControl inside the navigation toolbar item")
        #expect(control?.segmentCount == 2)
        // Momentary because pressing a chevron is an action, not a choice —
        // .selectOne would leave the segment lit afterwards.
        #expect(control?.trackingMode == .momentary, "tracking mode is \(String(describing: control?.trackingMode))")
        #expect(control?.segmentStyle == .separated, "segment style is \(String(describing: control?.segmentStyle))")
    }

    @Test("each segment is enabled only when that move is available")
    func segmentEnablementTracksTheNavigator() async {
        guard #available(macOS 14.0, *) else { return }
        let navigator = SettingsNavigator(initialPageID: "general")
        let window = await Self.makeHostedWindow(navigator: navigator)
        defer { window.close() }

        guard let control = Self.segmentedControl(in: window) else {
            Issue.record("no segmented control to inspect")
            return
        }

        #expect(!control.isEnabled(forSegment: 0), "back is live with nothing behind it")
        #expect(!control.isEnabled(forSegment: 1), "forward is live with nothing ahead")

        navigator.navigate(to: "advanced")
        for _ in 0 ..< 10 { try? await Task.sleep(for: .milliseconds(20)) }
        #expect(control.isEnabled(forSegment: 0), "back stayed dead after visiting a second page")
        #expect(!control.isEnabled(forSegment: 1))

        navigator.goBack()
        for _ in 0 ..< 10 { try? await Task.sleep(for: .milliseconds(20)) }
        #expect(!control.isEnabled(forSegment: 0))
        #expect(control.isEnabled(forSegment: 1), "forward stayed dead after going back")
    }

    @Test("it sits at the leading edge of the detail pane, past the sidebar")
    func controlSitsBesideTheDetailPane() async {
        guard #available(macOS 14.0, *) else { return }
        let window = await Self.makeHostedWindow(navigator: SettingsNavigator(initialPageID: "general"))
        defer { window.close() }

        let originsInWindow = Self.hostSuppliedToolbarItems(in: window).compactMap { item -> CGFloat? in
            guard let view = item.view, let superview = view.superview else { return nil }
            return superview.convert(view.frame.origin, to: nil).x
        }

        #expect(originsInWindow.count == 1, "the toolbar item has no laid-out view")
        #expect(
            originsInWindow.allSatisfy { $0 >= Self.sidebarWidth },
            "expected the control past the \(Self.sidebarWidth) pt sidebar, got \(originsInWindow)"
        )
    }

    @Test("hiding the controls leaves the navigator working")
    func hidingTheControlsKeepsTheNavigator() async {
        guard #available(macOS 14.0, *) else { return }
        let navigator = SettingsNavigator(initialPageID: "general")
        let window = await Self.makeHostedWindow(navigator: navigator, showsNavigationControls: false)
        defer { window.close() }

        #expect(Self.hostSuppliedToolbarItems(in: window).isEmpty)

        navigator.navigate(to: "advanced")
        #expect(navigator.goBack() == "general")
        #expect(navigator.currentPageID == "general")
    }

    /// The navigator is the single source of truth, so a page selected in code
    /// has to reach the view — otherwise `navigate(to:)` would silently do
    /// nothing to what is on screen.
    @Test("selecting a page in code drives the view")
    func codeSelectionDrivesTheView() async {
        guard #available(macOS 14.0, *) else { return }
        let navigator = SettingsNavigator(initialPageID: "general")
        let window = await Self.makeHostedWindow(navigator: navigator)
        defer { window.close() }

        navigator.navigate(to: "advanced")
        for _ in 0 ..< 10 {
            try? await Task.sleep(for: .milliseconds(20))
        }

        #expect(window.title.contains("Advanced"), "the window title still reads \"\(window.title)\"")
    }

    /// ⌘[ / ⌘] cannot live on the segmented control — measured: `NSSegmentedControl`
    /// has no per-segment key-equivalent API, and a `performKeyEquivalent`
    /// override on it never fires because a window dispatches key equivalents
    /// through its `contentView` while the toolbar hangs off the titlebar. They
    /// ride on a zero-sized SwiftUI button in the content instead, and this is
    /// what proves that path still works.
    @Test("⌘[ and ⌘] move through the history")
    func keyboardShortcutsWork() async {
        guard #available(macOS 14.0, *) else { return }
        let navigator = SettingsNavigator(initialPageID: "general")
        let window = await Self.makeHostedWindow(navigator: navigator)
        defer { window.close() }

        navigator.navigate(to: "advanced")
        for _ in 0 ..< 10 { try? await Task.sleep(for: .milliseconds(20)) }

        #expect(window.performKeyEquivalent(with: Self.commandKeyEvent("[")))
        for _ in 0 ..< 10 { try? await Task.sleep(for: .milliseconds(20)) }
        #expect(navigator.currentPageID == "general", "⌘[ did not go back")

        #expect(window.performKeyEquivalent(with: Self.commandKeyEvent("]")))
        for _ in 0 ..< 10 { try? await Task.sleep(for: .milliseconds(20)) }
        #expect(navigator.currentPageID == "advanced", "⌘] did not go forward")
    }

    private static func commandKeyEvent(_ characters: String) -> NSEvent {
        NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: .command,
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            characters: characters,
            charactersIgnoringModifiers: characters,
            isARepeat: false,
            keyCode: 0
        )!
    }
}

#endif
