#if Settings && os(macOS)

import Testing

@testable import UIFoundationSettingsUI

/// The icon draws an SF Symbol when the system has one of that name and falls
/// back to an asset image of the same name otherwise. The check is the one
/// part that differs per platform; the UIKit branch only builds, so it is
/// exercised here through the AppKit one.
@Suite("SettingsPageIcon")
struct SettingsPageIconTests {
    @Test("a name the system has as an SF Symbol is drawn as one")
    func knownSymbolIsSystemSymbol() {
        #expect(SettingsPageIcon.isSystemSymbol(named: "gearshape"))
    }

    @Test("an unknown name falls back to an asset image")
    func unknownNameIsNotSystemSymbol() {
        #expect(!SettingsPageIcon.isSystemSymbol(named: "uifoundation.settings.tests.no-such-symbol"))
    }
}

#endif
