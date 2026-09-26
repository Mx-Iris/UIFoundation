#if AppleInternal && os(macOS)

import AppKit
import Testing
import UIFoundationAppleInternal

/// Canaries for the values `NSGlassEffectView_Private.h` declares for the glass's private settings.
///
/// Every table in that header was reverse-engineered, and only a few rows can be observed from
/// outside the view: the initial values, the variants the public `style` writes, and the names
/// AppKit prints for the adaptive appearance. The rest change nothing a test can read, so they rest
/// on the reverse engineering alone — which is why a failure here means the header needs re-reading
/// on this OS as a whole, not just the rows that failed.
@Suite("NSGlassEffectView private configuration")
@MainActor
struct GlassEffectViewPrivateConfigurationTests {
    @Test("A new glass holds the default variant")
    @available(macOS 26.0, *)
    func newGlassHoldsDefaultVariant() throws {
        try #require(NSGlassEffectView.isPrivateConfigurationSupported, "AppKit dropped the private setters")
        #expect(NSGlassEffectView()._variant == .default)
    }

    @Test("A new glass starts idle, unforced and adapting to its backdrop")
    @available(macOS 26.0, *)
    func newGlassStartsFromTheDocumentedDefaults() throws {
        try #require(NSGlassEffectView.isPrivateConfigurationSupported, "AppKit dropped the private setters")
        let glassEffectView = NSGlassEffectView()

        #expect(glassEffectView._subvariant == nil)
        #expect(glassEffectView._interactionState == .idle)
        #expect(glassEffectView._subduedState == .automatic)
        #expect(glassEffectView._scrimState == .automatic)
        #expect(glassEffectView._contentLensing == .automatic)
        #expect(glassEffectView._adaptiveAppearance == .on)
    }

    @Test("The public style writes the regular and clear variants")
    @available(macOS 26.0, *)
    func styleWritesVariant() throws {
        try #require(NSGlassEffectView.isPrivateConfigurationSupported, "AppKit dropped the private setters")
        let glassEffectView = NSGlassEffectView()

        glassEffectView.style = .clear
        #expect(glassEffectView._variant == .clear)

        glassEffectView.style = .regular
        #expect(glassEffectView._variant == .regular)
    }

    @Test("The public style reads clear for the clear variant only")
    @available(macOS 26.0, *)
    func styleIsDerivedFromVariant() throws {
        try #require(NSGlassEffectView.isPrivateConfigurationSupported, "AppKit dropped the private setters")
        let glassEffectView = NSGlassEffectView()

        glassEffectView._variant = .clear
        #expect(glassEffectView.style == .clear)

        glassEffectView._variant = .abuttedSidebar
        #expect(glassEffectView.style == .regular)
    }

    /// Unlike every other name in the header, the subvariant constants are not a reading of AppKit:
    /// AppKit has none and writes the literals, so the library defines its own. What has to hold is
    /// that each spells exactly a name DesignLibrary accepts. The expected strings are the
    /// `Subvariant.Kind` case names found in DesignLibrary's metadata on both macOS 26.6 and 27.0 —
    /// for `tab` and `menu`, also the literals AppKit itself writes.
    @Test(
        "Every subvariant constant spells a name DesignLibrary accepts on both releases",
        arguments: [
            (_NSGlassEffectViewSubvariant.tab, "tab"),
            (.menu, "menu"),
            (.lockscreenControls, "lockscreenControls"),
            (.lockscreenNotifications, "lockscreenNotifications"),
            (.homescreenClose, "homescreenClose"),
            (.camera, "camera"),
            (.posterSwitcher, "posterSwitcher"),
            (.homescreenResizeHandle, "homescreenResizeHandle"),
            (.cursorAccessory, "cursorAccessory"),
            (.homescreenFolder, "homescreenFolder"),
            (.focusedButtonFill, "focusedButtonFill"),
            (.entryField, "entryField"),
            (.volumeSlider, "volumeSlider"),
            (.customizeSheet, "customizeSheet"),
            (.watchFacePhotos, "watchFacePhotos"),
            (.watchFacePhotosMini, "watchFacePhotosMini"),
            (.watchFaceFlowStencil, "watchFaceFlowStencil"),
            (.watchFaceFlowSolid, "watchFaceFlowSolid"),
            (.watchPasscode, "watchPasscode"),
            (.homescreenAppLibraryPod, "homescreenAppLibraryPod"),
            (.watchSmartStack, "watchSmartStack"),
            (.watchSmartStackAnimatedContent, "watchSmartStackAnimatedContent"),
            (.siriSnippet, "siriSnippet"),
            (.alarmSlider, "alarmSlider"),
            (.mapsSign, "mapsSign"),
            (.sheet, "sheet"),
            (.messagesTapback, "messagesTapback"),
            (.cluster, "cluster"),
            (.secondaryCluster, "secondaryCluster"),
            (.watchDetuned, "watchDetuned"),
            (.tvPortraitClock, "tvPortraitClock"),
        ]
    )
    func subvariantConstantSpellsAcceptedName(subvariant: _NSGlassEffectViewSubvariant, acceptedName: String) {
        #expect(subvariant.rawValue == acceptedName)
    }

    /// The one enum whose names are AppKit's own rather than ours: its debug description spells
    /// each value out. The key is read only after `responds(to:)` says it exists, because
    /// key-value coding against a missing key raises an exception Swift cannot catch.
    @Test(
        "The adaptive appearance values carry the names AppKit prints for them",
        arguments: [
            (_NSGlassEffectViewAdaptiveAppearance.automatic, "automatic"),
            (.off, "off"),
            (.on, "on"),
        ]
    )
    @available(macOS 26.0, *)
    func adaptiveAppearanceNames(adaptiveAppearance: _NSGlassEffectViewAdaptiveAppearance, printedName: String) throws {
        try #require(NSGlassEffectView.isPrivateConfigurationSupported, "AppKit dropped the private setters")
        let glassEffectView = NSGlassEffectView()
        try #require(glassEffectView.responds(to: Selector(("_adaptationDebugDescription"))))

        glassEffectView._adaptiveAppearance = adaptiveAppearance
        let debugDescription = try #require(glassEffectView.value(forKey: "_adaptationDebugDescription") as? String)

        #expect(debugDescription.contains(" adaptiveAppearance=\(printedName) "), Comment(rawValue: debugDescription))
    }
}

#endif
