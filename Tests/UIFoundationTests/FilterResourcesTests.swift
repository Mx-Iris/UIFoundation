#if canImport(AppKit) && !targetEnvironment(macCatalyst) && FilterUI

import Testing
import AppKit
@testable import UIFoundationAppKit

@Suite("Filter resources (xcassets + Localization)")
struct FilterResourcesTests {

    @Test("Color assets resolve from Bundle.module")
    func colorAssetsResolve() {
        let bundle = Bundle.module

        let colorNames = [
            "filterFieldHighContrastActiveBorderColor",
            "filterFieldHighContrastInactiveBorderColor",
            "filterFieldKeyFocusBackgroundColor",
            "filterFieldNonVibrantActiveBackgroundColor",
            "filterFieldNonVibrantInactiveBackgroundColor",
            "filterFieldNonVibrantPlaceholderTextColor",
            "filterFieldVibrantActiveBackgroundColor",
            "filterFieldVibrantInactiveBackgroundColor",
            "filterFieldVibrantPlaceholderTextColor",
            "tokenRegularKeyColor",
            "tokenRegularValueColor",
            "tokenSelectedColor",
        ]

        for name in colorNames {
            #expect(NSColor(named: name, bundle: bundle) != nil, "Missing color asset: \(name)")
        }
    }

    @Test("Filter SF-Symbol fallback image assets resolve from Bundle.module")
    func symbolImageAssetsResolve() {
        let bundle = Bundle.module

        let imageNames = [
            "filter.circle",
            "filter.circle.fill",
            "filter.menu",
            "filter.menu.fill",
        ]

        for name in imageNames {
            #expect(bundle.image(forResource: name) != nil, "Missing image asset: \(name)")
        }
    }

    @Test("MoreSymbols raster image assets resolve from Bundle.module")
    func rasterImageAssetsResolve() {
        let bundle = Bundle.module

        let imageNames = [
            "clock.raster",
            "clock.fill.raster",
            "doc.raster",
            "doc.fill.raster",
            "tag.raster",
            "tag.fill.raster",
            "errors.filter.raster",
            "scm.filter.raster",
        ]

        for name in imageNames {
            #expect(bundle.image(forResource: name) != nil, "Missing image asset: \(name)")
        }
    }

    @Test("Localization strings resolve from Bundle.module")
    func localizationResolves() {
        let bundle = Bundle.module

        // Confirm en.lproj is wired up — Bundle.localizations should include "en".
        #expect(bundle.localizations.contains("en"), "en.lproj not found in Bundle.module")
        #expect(bundle.localizations.contains("da"), "da.lproj not found in Bundle.module")
    }
}

#endif
