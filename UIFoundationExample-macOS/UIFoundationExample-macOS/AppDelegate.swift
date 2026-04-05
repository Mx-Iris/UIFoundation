//
//  AppDelegate.swift
//  UIFoundationExample-macOS
//
//  Created by JH on 2023/11/5.
//

import Cocoa
import UIFoundation

@main
class AppDelegate: NSObject, NSApplicationDelegate {

    var textFinderDemoWindow: NSWindow?

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        if #available(macOS 12.0, *) {
            showTextFinderDemo()
        }
    }

    @available(macOS 12.0, *)
    private func showTextFinderDemo() {
        let viewController = TextFinderDemoViewController()
        let window = NSWindow(contentViewController: viewController)
        window.title = "TextFinder Demo — Cmd+F to search"
        window.setContentSize(NSSize(width: 600, height: 450))
        window.center()
        window.makeKeyAndOrderFront(nil)
        textFinderDemoWindow = window
    }

    func applicationWillTerminate(_ aNotification: Notification) {}

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }
}
