//
//  AppDelegate.swift
//  UIFoundationExample-macOS
//
//  Created by JH on 2023/11/5.
//

import AppKit
import UIFoundation

@main
final class AppDelegate: NSObject, NSApplicationDelegate {

    private var browserWindowController: DemoBrowserWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        CustomToolTipManager.install()
        installNewTabMenuItem()

        let windowController = DemoBrowserWindowController()
        windowController.showWindow(nil)
        windowController.window?.makeKeyAndOrderFront(nil)
        browserWindowController = windowController
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    /// Gives the File menu a New Tab item for demos that answer `newTab(_:)`.
    ///
    /// ⌘W needs no item of its own: the stock Close already dispatches `performClose(_:)` down the
    /// responder chain, and the browser's split view controller nominates the demo on screen as a
    /// supplemental target for it. ⌘T has no such route, so it takes an item — and taking it needs the
    /// combination to be free first. An item inserted into a menu whose main menu already carries that
    /// key equivalent has it **silently cleared on the way in**, which leaves a New Tab item that looks
    /// right and never fires. Format ▸ Show Fonts is the stock owner of ⌘T; a demo browser has no use
    /// for the font panel, so it simply gives the key up.
    ///
    /// The item carries no target, so the responder chain decides: it is enabled only while the demo
    /// on screen answers the action, and inert otherwise.
    private func installNewTabMenuItem() {
        guard let mainMenu = NSApp.mainMenu, let (fileMenu, closeItemIndex) = windowCloseMenuLocation() else { return }
        releaseKeyEquivalent("t", in: mainMenu)
        let newTabItem = NSMenuItem(title: "New Tab", action: #selector(TabBarDemoViewController.newTab(_:)), keyEquivalent: "t")
        newTabItem.keyEquivalentModifierMask = [.command]
        fileMenu.insertItem(newTabItem, at: closeItemIndex)
    }

    /// Clears `key` from whatever already claims it, so a newly inserted item can keep it.
    private func releaseKeyEquivalent(_ key: String, in menu: NSMenu) {
        for item in menu.items {
            if item.keyEquivalent == key, item.keyEquivalentModifierMask == [.command] {
                item.keyEquivalent = ""
            }
            if let submenu = item.submenu {
                releaseKeyEquivalent(key, in: submenu)
            }
        }
    }

    /// Where the stock Close item sits — found by what it does rather than by its menu's title, which
    /// is localized.
    private func windowCloseMenuLocation() -> (menu: NSMenu, index: Int)? {
        for topLevelItem in NSApp.mainMenu?.items ?? [] {
            guard let submenu = topLevelItem.submenu,
                  let index = submenu.items.firstIndex(where: { $0.action == #selector(NSWindow.performClose(_:)) })
            else { continue }
            return (submenu, index)
        }
        return nil
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        true
    }
}
