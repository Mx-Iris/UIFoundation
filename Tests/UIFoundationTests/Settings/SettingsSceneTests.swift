#if Settings && os(macOS)

import SwiftUI
import Testing

@testable import UIFoundationSettingsUI

@MainActor
@Suite("Settings scene")
struct SettingsSceneTests {
    @Test("defaults select the first page and retain configuration")
    func defaultsSelectFirstPageAndRetainConfiguration() {
        let configuration = SettingsConfiguration(
            sidebarIconSize: 15,
            showsNavigationControls: false
        )
        let settingsScene = SettingsScene(configuration: configuration) {
            SettingsPage("General", id: "general", symbol: "gearshape") { Text("general") }
            SettingsPage("Updates", id: "updates", symbol: "arrow.down.circle") { Text("updates") }
        }

        #expect(settingsScene.configuration.sidebarIconSize == 15)
        #expect(!settingsScene.configuration.showsNavigationControls)
        #expect(settingsScene.navigator.currentPageID == "general")
    }

    @Test("a provided navigator remains the scene's single navigation state")
    func providedNavigatorRemainsSingleNavigationState() {
        let navigator = SettingsNavigator(initialPageID: "updates")
        let settingsScene = SettingsScene(navigator: navigator) {
            SettingsPage("General", id: "general", symbol: "gearshape") { Text("general") }
            SettingsPage("Updates", id: "updates", symbol: "arrow.down.circle") { Text("updates") }
        }

        #expect(settingsScene.navigator === navigator)
        #expect(settingsScene.navigator.currentPageID == "updates")
    }

    @Test("macOS 26 AppKit can host the public scene directly")
    func macOS26AppKitCanHostPublicSceneDirectly() {
        guard #available(macOS 26.0, *) else { return }

        let settingsScene = SettingsScene {
            SettingsPage("General", id: "general", symbol: "gearshape") { Text("general") }
        }
        let representation = NSHostingSceneRepresentation {
            settingsScene
        }

        _ = representation.environment.openSettings
    }

    @Test("the native settings scene keeps the title and toolbar inline")
    func nativeSettingsSceneUsesUnifiedToolbarStyle() async {
        guard #available(macOS 26.0, *) else { return }

        let existingWindowIdentifiers = Set(NSApplication.shared.windows.map(ObjectIdentifier.init))
        let settingsScene = SettingsScene {
            SettingsPage("General", id: "general", symbol: "gearshape") { Text("general") }
            SettingsPage("Updates", id: "updates", symbol: "arrow.down.circle") { Text("updates") }
        }
        let representation = NSHostingSceneRepresentation {
            settingsScene
        }

        NSApplication.shared.addSceneRepresentation(representation)
        representation.environment.openSettings()

        var presentedWindow: NSWindow?
        for _ in 0 ..< 50 {
            presentedWindow = NSApplication.shared.windows.first {
                !existingWindowIdentifiers.contains(ObjectIdentifier($0))
            }
            if presentedWindow?.toolbarStyle == .unified { break }
            try? await Task.sleep(for: .milliseconds(20))
        }
        try? await Task.sleep(for: .milliseconds(200))
        defer { presentedWindow?.close() }

        #expect(presentedWindow != nil, "the Settings scene did not present a window")
        #expect(
            presentedWindow?.toolbarStyle == .unified,
            "expected an inline title and toolbar, got raw style \(String(describing: presentedWindow?.toolbarStyle.rawValue))"
        )
    }
}

#endif
