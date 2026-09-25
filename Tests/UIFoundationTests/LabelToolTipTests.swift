#if canImport(AppKit) && !targetEnvironment(macCatalyst)

import Testing
import AppKit
@testable import UIFoundationAppKit

/// `Label` mirrors its text into its tooltip while `syncStringValueToolTip` is on (the default).
/// Text reaches it through two setters — `stringValue` for plain strings, `attributedStringValue`
/// for styled ones — and AppKit's `attributedStringValue` setter does not go through
/// `stringValue`, so each setter has to mirror on its own.
@Suite("Label tooltip")
@MainActor
struct LabelToolTipTests {
    @Test("a plain string value becomes the tooltip")
    func stringValueBecomesToolTip() {
        let label = Label()

        label.stringValue = "NSGlassEffectView"

        #expect(label.toolTip == "NSGlassEffectView")
    }

    @Test("an attributed string value becomes the tooltip")
    func attributedStringValueBecomesToolTip() {
        let label = Label()

        label.attributedStringValue = NSAttributedString(string: "NSGlassEffectView")

        #expect(label.toolTip == "NSGlassEffectView")
    }

    @Test("with the sync turned off an attributed string value leaves the tooltip alone")
    func syncOffLeavesToolTipAlone() {
        let label = Label()
        label.syncStringValueToolTip = false

        label.attributedStringValue = NSAttributedString(string: "NSGlassEffectView")

        #expect(label.toolTip == nil)
    }
}

#endif
