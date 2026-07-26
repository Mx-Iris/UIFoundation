import AppKit
import UIFoundation

@main
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let windowController = DemoBrowserWindowController()

    func applicationDidFinishLaunching(_ notification: Notification) {
        CustomToolTipManager.install()

        windowController.showWindow(nil)

        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        true
    }
}
