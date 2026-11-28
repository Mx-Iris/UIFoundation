#if QuickActionBar && os(macOS)

import AppKit
import Testing
@testable import UIFoundationAppKit

/// `QuickActionBar.Configuration` on its own, without presenting a bar.
@Suite("QuickActionBar Configuration")
@MainActor
struct QuickActionBarConfigurationTests {
    @Test("The default configuration keeps what present(…) used to default to")
    func defaultConfigurationKeepsPresentDefaults() {
        let configuration = QuickActionBar.Configuration()

        #expect(configuration.placeholderText == "Quick Actions")
        #expect(configuration.searchImage === QuickActionBar.DefaultImage)
        #expect(configuration.width == nil)
        #expect(configuration.resultsHeight == nil)
        #expect(configuration.showsKeyboardShortcuts == false)
        #expect(configuration.canBecomeMainWindow == true)
        #expect(configuration.requiredClickCount == .double)
    }

    @Test("The default corner radius is half of the 56-point collapsed bar on macOS 26 and later")
    func defaultCornerRadiusIs28PointsOnMacOS26() {
        guard #available(macOS 26.0, *) else { return }

        #expect(QuickActionBar.Configuration.defaultCornerRadius == 28)
        #expect(QuickActionBar.Configuration().cornerRadius == 28)
    }

    @Test("A bar keeps the configuration it was created with")
    func initializerStoresTheGivenConfiguration() {
        let actionBar = QuickActionBar(configuration: QuickActionBar.Configuration(
            placeholderText: "Open Quickly",
            width: 512,
            resultsHeight: 200,
            cornerRadius: 12,
            showsKeyboardShortcuts: true,
            canBecomeMainWindow: false,
            requiredClickCount: .single
        ))

        #expect(actionBar.configuration.placeholderText == "Open Quickly")
        #expect(actionBar.configuration.width == 512)
        #expect(actionBar.configuration.resultsHeight == 200)
        #expect(actionBar.configuration.cornerRadius == 12)
        #expect(actionBar.configuration.showsKeyboardShortcuts == true)
        #expect(actionBar.configuration.canBecomeMainWindow == false)
        #expect(actionBar.configuration.requiredClickCount == .single)
    }

    @Test("The deprecated requiredClickCount reads and writes the configuration")
    @available(*, deprecated, message: "Exercises the deprecated requiredClickCount.")
    func deprecatedRequiredClickCountForwardsToConfiguration() {
        let actionBar = QuickActionBar()

        actionBar.requiredClickCount = .single
        #expect(actionBar.configuration.requiredClickCount == .single)

        actionBar.configuration.requiredClickCount = .double
        #expect(actionBar.requiredClickCount == .double)
    }
}

#endif
