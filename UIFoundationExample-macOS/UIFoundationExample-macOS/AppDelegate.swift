import AppKit
import UIFoundation

@main
@MainActor
enum App {
    static func main() {
        // Mirrors NSApplicationMain, which drains a pool over everything before run().
        let app = autoreleasepool {
            let app = NSApplication.shared
            app.delegate = AppDelegate.shared
            app.setActivationPolicy(.regular)
            app.mainMenu = MainMenu.standard()
            return app
        }
        app.run()
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    static let shared = AppDelegate()
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
