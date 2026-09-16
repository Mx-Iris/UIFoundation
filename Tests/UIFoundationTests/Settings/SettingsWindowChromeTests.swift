#if Settings && os(macOS)

import AppKit
import SwiftUI
import Testing

@testable import UIFoundationSettingsUI

/// Observes the settings window's chrome from the outside — deliberately
/// re-deriving how to reach SwiftUI's split view controller rather than reusing
/// the implementation's own lookup, so a wrong lookup cannot pass itself.
@MainActor
private enum ChromeInspector {
    static func splitViewControllers(in window: NSWindow) -> [NSSplitViewController] {
        guard let contentView = window.contentView else { return [] }
        var found: [NSSplitViewController] = []
        func walk(_ view: NSView) {
            if let splitView = view as? NSSplitView,
               let controller = splitView.delegate as? NSSplitViewController,
               !found.contains(where: { $0 === controller }) {
                found.append(controller)
            }
            view.subviews.forEach(walk)
        }
        walk(contentView)
        return found
    }

    static func collapseFlags(in window: NSWindow) -> [Bool] {
        splitViewControllers(in: window).flatMap { $0.splitViewItems.map(\.canCollapse) }
    }

    /// The width of the first split view item — the sidebar column.
    static func sidebarWidth(in window: NSWindow) -> CGFloat? {
        splitViewControllers(in: window)
            .first?
            .splitViewItems
            .first?
            .viewController
            .view
            .frame
            .width
    }
}

@MainActor
@Suite("Settings window chrome")
struct SettingsWindowChromeTests {
    /// Builds the real root view in an off-screen window and lets the main
    /// queue turn a few times, which is all the configuration needs.
    @available(macOS 14.0, *)
    private static func makeHostedWindow() async -> NSWindow {
        let rootView = SettingsRootView {
            SettingsPage("General", symbol: "gearshape") { Text("general") }
            SettingsPage("Advanced", symbol: "slider.horizontal.3") { Text("advanced") }
        }
        let hostingController = NSHostingController(rootView: rootView)
        let window = NSWindow(contentViewController: hostingController)
        window.setContentSize(NSSize(width: 715, height: 400))
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView]
        window.orderBack(nil)
        hostingController.view.layoutSubtreeIfNeeded()

        for _ in 0 ..< 10 {
            try? await Task.sleep(for: .milliseconds(20))
        }
        return window
    }

    @Test("the sidebar cannot be collapsed")
    func sidebarCannotCollapse() async {
        guard #available(macOS 14.0, *) else { return }
        let window = await Self.makeHostedWindow()
        defer { window.close() }

        let flags = ChromeInspector.collapseFlags(in: window)
        #expect(!flags.isEmpty, "no split view controller was reachable — the lookup in SettingsWindowSupport is stale")
        #expect(flags.allSatisfy { $0 == false }, "expected every split view item to refuse collapsing, got \(flags)")
    }

    @Test("collapsing stays disabled after a resize")
    func stillDisabledAfterResize() async {
        guard #available(macOS 14.0, *) else { return }
        let window = await Self.makeHostedWindow()
        defer { window.close() }

        window.setContentSize(NSSize(width: 900, height: 520))
        window.contentView?.layoutSubtreeIfNeeded()
        try? await Task.sleep(for: .milliseconds(60))

        let flags = ChromeInspector.collapseFlags(in: window)
        #expect(!flags.isEmpty)
        #expect(flags.allSatisfy { $0 == false }, "a resize brought collapsing back: \(flags)")
    }

    /// Embedding the settings UI inside a host that has its own sidebar must not
    /// lock that sidebar open.
    ///
    /// A window-wide downward search finds both split views — the host's and
    /// SwiftUI's — so an implementation that configures everything it finds
    /// passes the tests above while breaking the host.
    @Test("embedding leaves the host's own sidebar collapsible")
    func doesNotTouchHostSidebar() async {
        guard #available(macOS 14.0, *) else { return }

        let hostSidebarViewController = NSViewController()
        hostSidebarViewController.view = NSView(frame: NSRect(x: 0, y: 0, width: 200, height: 400))

        let embeddedSettings = NSHostingController(
            rootView: SettingsRootView {
                SettingsPage("General", symbol: "gearshape") { Text("general") }
                SettingsPage("Advanced", symbol: "slider.horizontal.3") { Text("advanced") }
            }
        )

        let hostSplitViewController = NSSplitViewController()
        let hostSidebarItem = NSSplitViewItem(sidebarWithViewController: hostSidebarViewController)
        hostSplitViewController.addSplitViewItem(hostSidebarItem)
        hostSplitViewController.addSplitViewItem(NSSplitViewItem(viewController: embeddedSettings))

        let window = NSWindow(contentViewController: hostSplitViewController)
        window.setContentSize(NSSize(width: 900, height: 460))
        window.styleMask = [.titled, .closable, .resizable]
        window.orderBack(nil)
        hostSplitViewController.view.layoutSubtreeIfNeeded()
        defer { window.close() }

        for _ in 0 ..< 10 {
            try? await Task.sleep(for: .milliseconds(20))
        }

        // The settings pane's own sidebar is locked…
        let settingsControllers = ChromeInspector.splitViewControllers(in: window)
            .filter { $0 !== hostSplitViewController }
        let settingsFlags = settingsControllers.flatMap { $0.splitViewItems.map(\.canCollapse) }
        #expect(!settingsFlags.isEmpty, "the embedded settings split view was never found")
        #expect(settingsFlags.allSatisfy { $0 == false }, "the embedded sidebar stayed collapsible: \(settingsFlags)")

        // …while the host's is left exactly as the host set it up.
        #expect(
            hostSidebarItem.canCollapse,
            "the host's own sidebar was locked open — the chrome escaped its scope"
        )
    }

    /// The sidebar toggle has to be *gone*, not emptied out.
    ///
    /// Hiding the item's `view` leaves the `NSToolbarItem` itself visible, and
    /// from macOS 26 every visible item gets an `NSToolbarPlatterView` of its
    /// own — so an emptied-out item draws as a blank glass capsule beside the
    /// traffic lights. Measured on macOS 27: the platter is keyed off the item
    /// being visible, not off `isBordered` (which SwiftUI already leaves
    /// `false` here) and not off what its view is doing.
    ///
    /// This asserts on the toolbar rather than on the rendering because the
    /// platter only exists in a real app bundle — a command-line test binary
    /// carries an older SDK stamp in `LC_BUILD_VERSION` and never gets Liquid
    /// Glass, so a pixel-level check would pass here while the bug shipped.
    @Test("the sidebar toggle is removed from the toolbar, not emptied out")
    func sidebarToggleIsRemoved() async {
        guard #available(macOS 14.0, *) else { return }
        let controller = SettingsWindowController {
            SettingsPage("General", symbol: "gearshape") { Text("general") }
            SettingsPage("Advanced", symbol: "slider.horizontal.3") { Text("advanced") }
        }
        controller.showWindow(nil)
        defer { controller.close() }

        for _ in 0 ..< 10 {
            try? await Task.sleep(for: .milliseconds(20))
        }

        let toolbarItems = controller.window?.toolbar?.items ?? []
        #expect(!toolbarItems.isEmpty, "no toolbar items at all — this window no longer has the shape the test assumes")

        let toggleIdentifier = "com.apple.SwiftUI.navigationSplitView.toggleSidebar"
        #expect(
            !toolbarItems.contains { $0.itemIdentifier.rawValue == toggleIdentifier },
            "the sidebar toggle is still installed: \(toolbarItems.map(\.itemIdentifier.rawValue))"
        )

        let itemsHiddenThroughTheirView = toolbarItems.filter { $0.view?.isHidden == true }
        #expect(
            itemsHiddenThroughTheirView.isEmpty,
            """
            an item is being suppressed by hiding its view, which leaves its glass platter behind: \
            \(itemsHiddenThroughTheirView.map(\.itemIdentifier.rawValue))
            """
        )
    }

    /// Removing the toggle must not cost the configured sidebar width.
    ///
    /// `toolbar(removing:)` wraps the list in a `ModifiedContent`, and applied
    /// *after* `navigationSplitViewColumnWidth` it swallows that preference —
    /// the sidebar then falls back to `NavigationSplitView`'s own minimum and
    /// the detail pane's toolbar items slide left with it. Nothing throws and
    /// nothing logs; the window just comes up narrow. Measured on macOS 27:
    /// 144pt instead of the requested 185.
    @Test("removing the toggle leaves the configured sidebar width intact")
    func sidebarKeepsItsConfiguredWidth() async {
        guard #available(macOS 14.0, *) else { return }

        let configuration = SettingsConfiguration(sidebarWidth: 185)
        let controller = SettingsWindowController(configuration: configuration) {
            SettingsPage("General", symbol: "gearshape") { Text("general") }
            SettingsPage("Advanced", symbol: "slider.horizontal.3") { Text("advanced") }
        }
        controller.showWindow(nil)
        defer { controller.close() }

        for _ in 0 ..< 10 {
            try? await Task.sleep(for: .milliseconds(20))
        }

        let width = ChromeInspector.sidebarWidth(in: controller.window!)
        #expect(width != nil, "the sidebar column was never found")
        #expect(
            width == configuration.sidebarWidth,
            "expected the configured \(configuration.sidebarWidth)pt sidebar, got \(width.map(String.init(describing:)) ?? "nil")"
        )
    }
}

#endif
