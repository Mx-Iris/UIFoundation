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

    let mainWindowController = MainWindowController.create()
    

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        mainWindowController.showWindow(nil)
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }


}

