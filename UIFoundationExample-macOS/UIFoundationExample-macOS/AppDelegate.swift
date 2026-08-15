import AppKit
import UIFoundation

@main
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let windowController = DemoBrowserWindowController()
    private var settingsSceneRepresentationExample: (any SettingsSceneRepresentationPresenting)?

    func applicationWillFinishLaunching(_ notification: Notification) {
        if #available(macOS 26.0, *) {
            let settingsSceneRepresentationExample = SettingsSceneRepresentationExample()
            settingsSceneRepresentationExample.register(with: NSApplication.shared)
            self.settingsSceneRepresentationExample = settingsSceneRepresentationExample
        }
    }

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

    @discardableResult
    func openSettingsSceneRepresentationExample(page: SettingsSceneRepresentationExamplePage) -> Bool {
        guard let settingsSceneRepresentationExample else { return false }
        settingsSceneRepresentationExample.open(page: page)
        return true
    }
}
