//
//  Replicated from macOS 26's Spotlight.app (26.6.2).
//  Reverse-engineering notes: Researchs/Spotlight-Panel-Internals.md
//  Decision record: Documentations/Evolutions/0021-spotlight-panel-replica.md
//

#if SpotlightPanel && os(macOS)

import AppKit
import QuartzCore

extension SpotlightPanel {
    /// Every number in the present / dismiss animation, read out of Spotlight's binary.
    ///
    /// Three things here are easy to "tidy up" and must not be:
    ///
    /// - **The scale is not uniform.** 1.12 horizontally against 0.95 vertically, so the panel
    ///   spreads sideways as it leaves rather than swelling. The two axes also carry different
    ///   `bounce` values while presenting.
    /// - **The blur is its own curve, and a slower one** (0.51 against the opacity's 0.28).
    ///   That gap is the whole effect: the panel goes soft before it goes away. Matching the
    ///   two durations collapses it into an ordinary fade.
    /// - **Only dismissal blurs.** Presenting starts at a blur of zero and never animates it.
    public enum AnimationRecipe {
        /// `CASpringAnimation(perceptualDuration:)` for the scale while presenting.
        public static let presentPerceptualDuration: CGFloat = 0.28
        /// `bounce` for `transform.scale.x` while presenting.
        public static let presentHorizontalBounce: CGFloat = 0.41
        /// `bounce` for `transform.scale.y` while presenting.
        public static let presentVerticalBounce: CGFloat = 0.32

        /// `CASpringAnimation(perceptualDuration:)` for the scale while dismissing. Both axes
        /// share it, and share ``dismissBounce``.
        public static let dismissPerceptualDuration: CGFloat = 0.45
        /// `bounce` for both scale axes while dismissing.
        public static let dismissBounce: CGFloat = 0.05

        /// The window's `alphaValue` curve. Identical in both directions.
        public static let opacityPerceptualDuration: CGFloat = 0.28
        /// `bounce` for the `alphaValue` curve.
        public static let opacityBounce: CGFloat = 0.41

        /// The window's content-blur curve, used on dismissal only.
        public static let blurPerceptualDuration: CGFloat = 0.51
        /// `bounce` for the content-blur curve.
        public static let blurBounce: CGFloat = 0.05

        /// `transform.scale.x` at the dismissed end of the animation.
        public static let dismissedHorizontalScale: CGFloat = 1.12
        /// `transform.scale.y` at the dismissed end of the animation.
        public static let dismissedVerticalScale: CGFloat = 0.95
        /// The window's content blur radius at the dismissed end.
        public static let dismissedBlurRadius: CGFloat = 25

        /// `transform.scale.x` / `.y` while presented.
        public static let presentedScale: CGFloat = 1
    }
}

// MARK: - Spring construction

extension SpotlightPanel.AnimationRecipe {
    /// A spring in the same terms SwiftUI states them, falling back for systems without
    /// `CASpringAnimation(perceptualDuration:bounce:)` (macOS 14).
    ///
    /// The fallback is not an eyeballed approximation — it is the documented conversion from
    /// `Spring(duration:bounce:)` to the mass/stiffness/damping triple, with unit mass:
    ///
    ///     stiffness = (2π / duration)²
    ///     damping   = 4π (1 − bounce) / duration          for bounce ≥ 0
    ///     damping   = 4π / (duration + duration · bounce)  for bounce < 0
    static func makeSpringAnimation(perceptualDuration: CGFloat, bounce: CGFloat) -> CASpringAnimation {
        if #available(macOS 14.0, *) {
            return CASpringAnimation(perceptualDuration: perceptualDuration, bounce: bounce)
        }

        let springAnimation = CASpringAnimation()
        springAnimation.mass = 1
        springAnimation.stiffness = pow(2 * .pi / perceptualDuration, 2)
        springAnimation.damping = if bounce >= 0 {
            4 * .pi * (1 - bounce) / perceptualDuration
        } else {
            4 * .pi / (perceptualDuration + perceptualDuration * bounce)
        }
        return springAnimation
    }

    /// Whether the panel should skip its animations entirely.
    ///
    /// Spotlight gates on `SUIUtilities.isInvocationAnimationEnabled` plus
    /// `NSAccessibilityEnhancedUserInterfaceEnabled()`. The first is its own defaults switch and
    /// has no equivalent here; the second is not exposed to Swift, so the reduce-motion
    /// preference — which is the one a user actually sets — stands in for both.
    @MainActor
    static var prefersReducedMotion: Bool {
        NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
    }
}

#endif
