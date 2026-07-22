//
//  DemoBrowserWindowController.swift
//  UIFoundationExample-macOS
//
//  The single window hosting the demo browser.
//

import AppKit

final class DemoBrowserWindowController: NSWindowController {

    convenience init() {
        let splitViewController = DemoBrowserSplitViewController()
        let window = NSWindow(contentViewController: splitViewController)
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
