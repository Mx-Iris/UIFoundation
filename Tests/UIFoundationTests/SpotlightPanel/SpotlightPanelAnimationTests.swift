#if SpotlightPanel && os(macOS)

import AppKit
import QuartzCore
import Testing
@testable import UIFoundationAppleInternal

/// The animation cannot be seen in a test process, so what is asserted is the **recipe**: the
/// spring parameters, the from/to pairs and the key paths. That is enough to catch the failure
/// this suite exists for — someone "simplifying" the two curves into one, or making the
/// non-uniform scale uniform.
@Suite("SpotlightPanel animation recipe")
@MainActor
struct SpotlightPanelAnimationTests {
    // MARK: Measured constants

    @Test("Present and dismiss springs match Spotlight 26.6.2")
    func springParametersAreTheMeasuredOnes() {
        #expect(SpotlightPanel.AnimationRecipe.presentPerceptualDuration == 0.28)
        #expect(SpotlightPanel.AnimationRecipe.presentHorizontalBounce == 0.41)
        #expect(SpotlightPanel.AnimationRecipe.presentVerticalBounce == 0.32)
        #expect(SpotlightPanel.AnimationRecipe.dismissPerceptualDuration == 0.45)
        #expect(SpotlightPanel.AnimationRecipe.dismissBounce == 0.05)
        #expect(SpotlightPanel.AnimationRecipe.opacityPerceptualDuration == 0.28)
        #expect(SpotlightPanel.AnimationRecipe.opacityBounce == 0.41)
        #expect(SpotlightPanel.AnimationRecipe.blurPerceptualDuration == 0.51)
        #expect(SpotlightPanel.AnimationRecipe.blurBounce == 0.05)
    }

    /// The single most tempting thing to "fix", and the one that would change the feel most.
    @Test("The dismissed scale is not uniform")
    func dismissedScaleIsNotUniform() {
        let dismissedState = SpotlightPanel.AnimationState.dismissed

        #expect(dismissedState.horizontalScale == 1.12)
        #expect(dismissedState.verticalScale == 0.95)
        #expect(dismissedState.horizontalScale != dismissedState.verticalScale)
    }

    /// Losing this gap turns "blurs out" into "fades out".
    @Test("The blur curve is slower than the opacity curve")
    func blurIsSlowerThanOpacity() {
        #expect(
            SpotlightPanel.AnimationRecipe.blurPerceptualDuration
                > SpotlightPanel.AnimationRecipe.opacityPerceptualDuration
        )
    }

    @Test("The two end states carry the measured values")
    func endStatesAreTheMeasuredOnes() {
        let presentedState = SpotlightPanel.AnimationState.presented
        #expect(presentedState.horizontalScale == 1)
        #expect(presentedState.verticalScale == 1)
        #expect(presentedState.opacity == 1)
        #expect(presentedState.blurRadius == 0)

        let dismissedState = SpotlightPanel.AnimationState.dismissed
        #expect(dismissedState.opacity == 0)
        #expect(dismissedState.blurRadius == 25)
    }

    // MARK: Centre compensation

    /// A backing layer anchors bottom-left, so a bare scale drags the panel sideways. The
    /// translation is what puts the apparent origin back in the middle.
    @Test("The translation recentres a non-uniform scale")
    func translationRecentresTheScale() {
        let layerBounds = CGRect(x: 0, y: 0, width: 680, height: 400)
        let translation = SpotlightPanel.AnimationState.dismissed.translation(forLayerBounds: layerBounds)

        // Growing 12% wider pulls left by half the growth.
        #expect(translation.x == layerBounds.width * (1 - 1.12) / 2)
        #expect(translation.x < 0)

        // Shrinking 5% shorter pushes up by half the shrink.
        #expect(translation.y == layerBounds.height * (1 - 0.95) / 2)
        #expect(translation.y > 0)
    }

    @Test("A presented state needs no translation")
    func presentedStateNeedsNoTranslation() {
        let layerBounds = CGRect(x: 0, y: 0, width: 680, height: 400)
        let translation = SpotlightPanel.AnimationState.presented.translation(forLayerBounds: layerBounds)

        #expect(translation.x == 0)
        #expect(translation.y == 0)
    }

    // MARK: Spring construction

    /// The pre-macOS 14 path is a documented conversion, not an approximation, so it is worth
    /// asserting that it lands where the formula says.
    @Test("The spring fallback converts duration and bounce to a damped oscillator")
    func springFallbackMatchesTheDocumentedConversion() {
        let springAnimation = SpotlightPanel.AnimationRecipe.makeSpringAnimation(
            perceptualDuration: 0.28,
            bounce: 0.41
        )

        if #available(macOS 14.0, *) {
            // On a system with the real initialiser the values come from CoreAnimation; all this
            // asserts is that a usable spring came back.
            #expect(springAnimation.settlingDuration > 0)
        } else {
            #expect(springAnimation.mass == 1)
            #expect(springAnimation.stiffness == pow(2 * .pi / 0.28, 2))
            #expect(springAnimation.damping == 4 * .pi * (1 - 0.41) / 0.28)
        }
    }

    /// `CASpringAnimation` inherits a 0.25 second `duration` that has nothing to do with its
    /// spring, so a group built from one is cut off unless the duration is corrected.
    @Test("A settling duration longer than the inherited default is not silently truncated")
    func settlingDurationExceedsTheInheritedDefault() {
        let springAnimation = SpotlightPanel.AnimationRecipe.makeSpringAnimation(
            perceptualDuration: 0.51,
            bounce: 0.05
        )
        #expect(springAnimation.settlingDuration > 0.25)
    }

    // MARK: Coordinator

    @Test("A fresh coordinator is idle")
    func freshCoordinatorIsIdle() {
        let coordinator = SpotlightPanel.AnimationCoordinator()
        #expect(coordinator.phase == .idle)
    }
}

#endif
