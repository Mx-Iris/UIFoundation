//
//  DemoBrowserWindowController.swift
//  UIFoundationExample-macOS
//
//  The single window hosting the demo browser.
//

import AppKit

/// A demo that owns a strip of tabs, and so borrows the standard New Tab / Close Tab shortcuts from
/// the window while it is on screen.
protocol TabsShortcutHandling: AnyObject {
    func newTabFromShortcut()

    /// Closes the active tab and returns `true`. Returns `false` when that was the last tab, so ⌘W
    /// closes the window instead — the way Safari behaves.
    func closeTabFromShortcut() -> Bool
}

/// The browser window, which hands ⌘T / ⌘W to the demo on screen whenever that demo has tabs.
///
/// Intercepting here rather than in the demo's own view controller: a menu key equivalent is
/// dispatched down the *key window's* responder chain, and that chain starts at the first responder —
/// in this app usually the browser's sidebar — so it never passes through the detail pane at all. The
/// window is the one responder every chain ends at, and it is also what answers `performClose(_:)`
/// today, which is exactly what has to be taken away from ⌘W and given to the tabs.
final class DemoBrowserWindow: NSWindow {

    private var tabbedDemo: TabsShortcutHandling? {
        (contentViewController as? DemoBrowserSplitViewController)?.currentDemoViewController as? TabsShortcutHandling
    }

    override func performClose(_ sender: Any?) {
        if let tabbedDemo, tabbedDemo.closeTabFromShortcut() { return }
        super.performClose(sender)
    }

    @objc func newTab(_ sender: Any?) {
        tabbedDemo?.newTabFromShortcut()
    }

    /// Lets ⌘T fall through to whatever else claims it (Format ▸ Show Fonts) while the demo on screen
    /// has no tabs: a menu item whose action finds no target is disabled, and the main menu skips
    /// disabled items when it matches key equivalents.
    override func responds(to selector: Selector!) -> Bool {
        guard selector == #selector(newTab(_:)) else { return super.responds(to: selector) }
        return tabbedDemo != nil
    }
}

final class DemoBrowserWindowController: NSWindowController {

    convenience init() {
        let splitViewController = DemoBrowserSplitViewController()
        let window = DemoBrowserWindow(contentViewController: splitViewController)
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView]
        window.title = "UIFoundation Examples"
        window.titlebarSeparatorStyle = .line
        window.setContentSize(NSSize(width: 960, height: 640))
        window.minSize = NSSize(width: 720, height: 480)
        window.setFrameAutosaveName("UIFoundationExampleBrowserWindow")
        window.center()
        window.toolbar = NSToolbar()
        window.toolbarStyle = .unified
        self.init(window: window)
    }
}
