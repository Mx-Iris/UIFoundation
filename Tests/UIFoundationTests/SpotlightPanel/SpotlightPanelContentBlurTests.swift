#if SpotlightPanel && os(macOS)

import AppKit
import Testing
@testable import UIFoundationAppleInternal

/// The window content blur, which is the one piece of this component that reaches into private
/// AppKit and the one that went wrong first.
///
/// **The bug these guard against:** the starting blur was taken from `startingState.blurRadius`
/// rather than hard-coded to zero. Presenting starts from `.dismissed`, whose `blurRadius` is 25,
/// and presenting deliberately does not animate the blur — so the panel wrote 25 once and never
/// wrote anything again. Everything the window covered stayed smeared for as long as it was up.
/// Spotlight itself hard-codes the zero: its `_setContentBlurRadius:` call sits *outside* the
/// branch that picks the starting alpha.
@Suite("SpotlightPanel content blur")
@MainActor
struct SpotlightPanelContentBlurTests {
    private func makeWindow() -> NSWindow {
        NSWindow(
            contentRect: CGRect(x: 0, y: 0, width: 760, height: 136),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
    }

    private func makeLayer() -> CALayer {
        let layer = CALayer()
        layer.bounds = CGRect(x: 0, y: 0, width: 680, height: 136)
        return layer
    }

    /// Reads the blur back without assuming the private getter is still there.
    private func blurRadius(of window: NSWindow) -> Double? {
        guard window.responds(to: Selector(("_contentBlurRadius"))) else { return nil }
        return (window.value(forKey: NSWindow.spotlightPanelContentBlurRadiusKeyPath) as? NSNumber)?
            .doubleValue
    }

    // MARK: The private surface

    /// Measured on macOS 26: the setter is `_setContentBlurRadius:` and the getter is
    /// `_contentBlurRadius` — note that the getter is *not* `contentBlurRadius`, even though that
    /// is the key both KVC and `NSWindow.animations` use.
    @Test("The private setter and getter are both present")
    func privateAccessorsExist() {
        let window = makeWindow()

        #expect(window.responds(to: #selector(NSWindow._setContentBlurRadius(_:))))
        #expect(window.responds(to: Selector(("_contentBlurRadius"))))
        #expect(SpotlightPanel.isContentBlurSupported)

        // The unprefixed spellings do not exist as selectors; they only work through KVC.
        #expect(!window.responds(to: Selector(("contentBlurRadius"))))
        #expect(!window.responds(to: Selector(("setContentBlurRadius:"))))
    }

    /// The animation reaches the blur by putting a spring into `NSWindow.animations` under
    /// `contentBlurRadius` and letting the animator proxy do `setValue(_:forKey:)`. That only
    /// works because KVC's setter search includes the `_set<Key>:` form — so this asserts the
    /// mechanism the animation depends on, not just the setter.
    @Test("The blur round-trips through KVC under the key the animation uses")
    func kvcRoundTrips() {
        let window = makeWindow()

        window.setValue(17.0, forKey: NSWindow.spotlightPanelContentBlurRadiusKeyPath)
        #expect(blurRadius(of: window) == 17)

        window.setValue(0.0, forKey: NSWindow.spotlightPanelContentBlurRadiusKeyPath)
        #expect(blurRadius(of: window) == 0)
    }

    // MARK: The regression

    /// The failure that shipped: presenting left the window blurred forever.
    @Test("Presenting leaves the window unblurred")
    func presentingLeavesNoBlur() {
        let window = makeWindow()
        let coordinator = SpotlightPanel.AnimationCoordinator()

        coordinator.present(window: window, layer: makeLayer()) {}

        #expect(blurRadius(of: window) == 0)
    }

    /// The other half of the same contract: a dismissal *starts* sharp and is driven to 25 by its
    /// own spring, so the starting value must not come from the state either.
    @Test("A dismissal starts from an unblurred window")
    func dismissalStartsSharp() {
        let window = makeWindow()
        let coordinator = SpotlightPanel.AnimationCoordinator()

        coordinator.dismiss(window: window, layer: makeLayer()) {}

        #expect(blurRadius(of: window) == 0)
    }

    /// Presenting after a dismissal — the reversal path — must also clear the blur, since that is
    /// the case where a non-zero value is actually sitting on the window.
    @Test("Reversing a dismissal clears the blur the dismissal was building")
    func reversingADismissalClearsTheBlur() {
        let window = makeWindow()
        let layer = makeLayer()
        let coordinator = SpotlightPanel.AnimationCoordinator()

        coordinator.dismiss(window: window, layer: layer) {}
        // Stand in for the spring having advanced, which it does not do in a test process.
        window.setValue(25.0, forKey: NSWindow.spotlightPanelContentBlurRadiusKeyPath)

        coordinator.present(window: window, layer: layer) {}

        #expect(blurRadius(of: window) == 0)
    }

    /// Only the dismissal is supposed to blur; the recipe states it and the end states have to
    /// agree, or the direction-dependent behaviour above has nothing to stand on.
    @Test("Only the dismissed end state carries a blur")
    func onlyTheDismissedStateBlurs() {
        #expect(SpotlightPanel.AnimationState.presented.blurRadius == 0)
        #expect(SpotlightPanel.AnimationState.dismissed.blurRadius == 25)
    }
}

#endif
