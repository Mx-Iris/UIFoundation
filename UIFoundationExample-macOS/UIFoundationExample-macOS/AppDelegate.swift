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

        let windowController = DemoBrowserWindowController()
        windowController.showWindow(nil)
        windowController.window?.makeKeyAndOrderFront(nil)
        browserWindowController = windowController
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        true
    }
}
