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
}

#endif
