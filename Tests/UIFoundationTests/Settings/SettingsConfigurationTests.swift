#if Settings && os(macOS)

import SwiftUI
import Testing

@testable import UIFoundationSettingsUI

@MainActor
@Suite("Settings configuration")
struct SettingsConfigurationTests {
    @Test("defaults preserve the existing settings window")
    func defaultsPreserveExistingWindow() {
        let configuration = SettingsConfiguration()

        #expect(configuration.title == "Settings")
        #expect(configuration.contentWidth == 715)
        #expect(configuration.minimumContentHeight == 400)
        #expect(configuration.sidebarWidth == 185)
        #expect(configuration.sidebarIconSize == 20)
        #expect(configuration.showsNavigationControls)
    }

    @Test("one configuration value configures both public entry points")
    func customizedValueConfiguresBothEntryPoints() {
        let configuration = SettingsConfiguration(
            title: "Workbench Settings",
            contentWidth: 760,
            minimumContentHeight: 460,
            sidebarWidth: 210,
            sidebarIconSize: 15,
            showsNavigationControls: false
        )

        let rootView = SettingsRootView(configuration: configuration) {
            SettingsPage("General", symbol: "gearshape") { Text("general") }
        }
        let controller = SettingsWindowController(configuration: configuration) {
            SettingsPage("General", symbol: "gearshape") { Text("general") }
        }

        _ = rootView
        #expect(controller.configuration.title == "Workbench Settings")
        #expect(controller.configuration.contentWidth == 760)
        #expect(controller.configuration.minimumContentHeight == 460)
        #expect(controller.configuration.sidebarWidth == 210)
        #expect(controller.configuration.sidebarIconSize == 15)
        #expect(!controller.configuration.showsNavigationControls)
    }
}

#endif
