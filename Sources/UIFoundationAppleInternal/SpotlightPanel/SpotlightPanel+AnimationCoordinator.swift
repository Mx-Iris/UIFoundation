//
//  Replicated from macOS 26's Spotlight.app (26.6.2).
//  Reverse-engineering notes: Researchs/Spotlight-Panel-Internals.md
//  Decision record: Documentations/Evolutions/0021-spotlight-panel-replica.md
//

#if SpotlightPanel && os(macOS)

import AppKit
import OSToolbox
import QuartzCore

extension SpotlightPanel {
    /// The four values the panel animates between, matching Spotlight's
    /// `WindowAnimationCoordinator.InvocationAnimationState`.
    ///
    /// The two constants below are the two literal pairs its binary carries; they are stated
    /// here as whole states rather than as loose numbers because that is the only way the
    /// non-uniform scale stays obviously deliberate.
    public struct AnimationState: Equatable, Sendable {
        public var horizontalScale: CGFloat
        public var verticalScale: CGFloat
        public var opacity: CGFloat
        public var blurRadius: CGFloat

        public init(horizontalScale: CGFloat, verticalScale: CGFloat, opacity: CGFloat, blurRadius: CGFloat) {
            self.horizontalScale = horizontalScale
            self.verticalScale = verticalScale
            self.opacity = opacity
            self.blurRadius = blurRadius
        }

        /// Fully on screen.
        public static let presented = AnimationState(
            horizontalScale: AnimationRecipe.presentedScale,
            verticalScale: AnimationRecipe.presentedScale,
            opacity: 1,
            blurRadius: 0
        )

        /// Spread, transparent and blurred — where a dismissal ends and a presentation starts.
        public static let dismissed = AnimationState(
            horizontalScale: AnimationRecipe.dismissedHorizontalScale,
            verticalScale: AnimationRecipe.dismissedVerticalScale,
            opacity: 0,
            blurRadius: AnimationRecipe.dismissedBlurRadius
        )

        /// The layer translation that keeps a scale looking centred.
        ///
        /// A layer-backed `NSView`'s backing layer anchors at its bottom-left corner, not its
        /// middle, so scaling it alone pins the corner and drags everything sideways. Shifting
        /// by half the size change puts the apparent origin back in the centre.
        func translation(forLayerBounds layerBounds: CGRect) -> CGPoint {
            CGPoint(
                x: layerBounds.width * (1 - horizontalScale) / 2,
                y: layerBounds.height * (1 - verticalScale) / 2
            )
        }
    }
}

extension SpotlightPanel {
    /// Runs the panel's present and dismiss animations and reports when they finish.
    ///
    /// Spotlight keeps a set of `AnimationAssertion`s so a late completion cannot act on a state
    /// that has since been replaced. A monotonic generation counter does the same job here: any
    /// completion whose generation is stale is dropped on arrival, which is what makes a
    /// dismissal interruptible.
    @MainActor
    @Loggable
    public final class AnimationCoordinator {
        /// Where the panel is in its present / dismiss cycle.
        public enum Phase: Equatable, Sendable {
            case idle
            case presenting
            case presented
            case dismissing
            case dismissed
        }

        public private(set) var phase: Phase = .idle

        /// Bumped on every animation start; a completion carrying an older value is ignored.
        private var currentGeneration: UInt = 0

        private static let layerAnimationKey = "spotlightPanelInvocation"

        public init() {}

        // MARK: Presenting

        /// Animate the panel in. Safe to call while a dismissal is running — the reversal picks
        /// up from wherever the dismissal had got to.
        public func present(
            window: NSWindow,
            layer: CALayer,
            completion: @escaping @MainActor () -> Void
        ) {
            let startingState = phase == .dismissing
                ? currentState(of: layer, window: window, fallback: .dismissed)
                : .dismissed

            #log(.debug, "Presenting")
            run(
                from: startingState,
                to: .presented,
                window: window,
                layer: layer,
                scalePerceptualDuration: AnimationRecipe.presentPerceptualDuration,
                horizontalBounce: AnimationRecipe.presentHorizontalBounce,
                verticalBounce: AnimationRecipe.presentVerticalBounce,
                animatesBlur: false,
                keepsFinalState: false,
                startingPhase: .presenting,
                endingPhase: .presented,
                completion: completion
            )
        }

        // MARK: Dismissing

        /// Animate the panel out.
        public func dismiss(
            window: NSWindow,
            layer: CALayer,
            completion: @escaping @MainActor () -> Void
        ) {
            let startingState = phase == .presenting
                ? currentState(of: layer, window: window, fallback: .presented)
                : .presented

            #log(.debug, "Dismissing")
            run(
                from: startingState,
                to: .dismissed,
                window: window,
                layer: layer,
                scalePerceptualDuration: AnimationRecipe.dismissPerceptualDuration,
                horizontalBounce: AnimationRecipe.dismissBounce,
                verticalBounce: AnimationRecipe.dismissBounce,
                animatesBlur: true,
                keepsFinalState: true,
                startingPhase: .dismissing,
                endingPhase: .dismissed,
                completion: completion
            )
        }

        // MARK: The animation itself

        private func run(
            from startingState: AnimationState,
            to endingState: AnimationState,
            window: NSWindow,
            layer: CALayer,
            scalePerceptualDuration: CGFloat,
            horizontalBounce: CGFloat,
            verticalBounce: CGFloat,
            animatesBlur: Bool,
            keepsFinalState: Bool,
            startingPhase: Phase,
            endingPhase: Phase,
            completion: @escaping @MainActor () -> Void
        ) {
            currentGeneration &+= 1
            let generation = currentGeneration
            phase = startingPhase

            let finish = { [weak self] in
                guard let self, self.currentGeneration == generation else { return }
                self.phase = endingPhase
                completion()
            }

            guard !AnimationRecipe.prefersReducedMotion else {
                #log(.debug, "Reduced motion — applying the end state directly")
                layer.removeAnimation(forKey: Self.layerAnimationKey)
                apply(endingState, to: window)
                finish()
                return
            }

            // Both halves have to land before the caller is told the animation is over, and they
            // finish on different clocks: the layer group through CATransaction, the window's
            // properties through NSAnimationContext.
            let pendingHalves = PendingHalves(count: 2, completion: finish)

            CATransaction.begin()
            CATransaction.setCompletionBlock {
                MainActor.assumeIsolated { pendingHalves.completeOne() }
            }

            layer.removeAnimation(forKey: Self.layerAnimationKey)
            layer.add(
                makeTransformAnimation(
                    from: startingState,
                    to: endingState,
                    layerBounds: layer.bounds,
                    perceptualDuration: scalePerceptualDuration,
                    horizontalBounce: horizontalBounce,
                    verticalBounce: verticalBounce,
                    keepsFinalState: keepsFinalState
                ),
                forKey: Self.layerAnimationKey
            )

            animateWindowProperties(
                of: window,
                from: startingState,
                to: endingState,
                animatesBlur: animatesBlur,
                completion: {
                    MainActor.assumeIsolated { pendingHalves.completeOne() }
                }
            )

            CATransaction.commit()
        }

        private func makeTransformAnimation(
            from startingState: AnimationState,
            to endingState: AnimationState,
            layerBounds: CGRect,
            perceptualDuration: CGFloat,
            horizontalBounce: CGFloat,
            verticalBounce: CGFloat,
            keepsFinalState: Bool
        ) -> CAAnimationGroup {
            let startingTranslation = startingState.translation(forLayerBounds: layerBounds)
            let endingTranslation = endingState.translation(forLayerBounds: layerBounds)

            let animations = [
                makeSpringAnimation(
                    keyPath: "transform.scale.x",
                    from: startingState.horizontalScale,
                    to: endingState.horizontalScale,
                    perceptualDuration: perceptualDuration,
                    bounce: horizontalBounce
                ),
                makeSpringAnimation(
                    keyPath: "transform.translation.x",
                    from: startingTranslation.x,
                    to: endingTranslation.x,
                    perceptualDuration: perceptualDuration,
                    bounce: horizontalBounce
                ),
                makeSpringAnimation(
                    keyPath: "transform.scale.y",
                    from: startingState.verticalScale,
                    to: endingState.verticalScale,
                    perceptualDuration: perceptualDuration,
                    bounce: verticalBounce
                ),
                makeSpringAnimation(
                    keyPath: "transform.translation.y",
                    from: startingTranslation.y,
                    to: endingTranslation.y,
                    perceptualDuration: perceptualDuration,
                    bounce: verticalBounce
                ),
            ]

            let animationGroup = CAAnimationGroup()
            animationGroup.animations = animations
            animationGroup.duration = animations.map(\.duration).max() ?? perceptualDuration
            if keepsFinalState {
                animationGroup.fillMode = .forwards
                animationGroup.isRemovedOnCompletion = false
            }
            return animationGroup
        }

        private func makeSpringAnimation(
            keyPath: String,
            from fromValue: CGFloat,
            to toValue: CGFloat,
            perceptualDuration: CGFloat,
            bounce: CGFloat
        ) -> CASpringAnimation {
            let springAnimation = AnimationRecipe.makeSpringAnimation(
                perceptualDuration: perceptualDuration,
                bounce: bounce
            )
            springAnimation.keyPath = keyPath
            springAnimation.fromValue = fromValue
            springAnimation.toValue = toValue
            // A CASpringAnimation's inherited `duration` is 0.25 regardless of the spring, so
            // without this the curve is cut off partway through.
            springAnimation.duration = springAnimation.settlingDuration
            return springAnimation
        }

        private func animateWindowProperties(
            of window: NSWindow,
            from startingState: AnimationState,
            to endingState: AnimationState,
            animatesBlur: Bool,
            completion: @escaping @MainActor () -> Void
        ) {
            window.animations[NSAnimatablePropertyKey("alphaValue")] =
                AnimationRecipe.makeSpringAnimation(
                    perceptualDuration: AnimationRecipe.opacityPerceptualDuration,
                    bounce: AnimationRecipe.opacityBounce
                )

            // Assigning without animation first makes these the *starting* values; the animator
            // proxy inside the group then drives them to the end state.
            window.alphaValue = startingState.opacity

            // The starting blur is **always zero**, in both directions, and not
            // `startingState.blurRadius`. Spotlight hard-codes it — the `_setContentBlurRadius:`
            // call sits outside the if/else that picks the starting alpha. Taking it from the
            // starting state instead means presenting writes 25 and then, because presenting does
            // not animate the blur, never writes anything else: the blur sticks at 25 for the
            // whole life of the panel and everything the window covers stays smeared.
            window.setSpotlightPanelContentBlurRadius(0)

            let animatesContentBlur = animatesBlur && SpotlightPanel.isContentBlurSupported
            if animatesContentBlur {
                window.animations[NSWindow.spotlightPanelContentBlurRadiusKeyPath] =
                    AnimationRecipe.makeSpringAnimation(
                        perceptualDuration: AnimationRecipe.blurPerceptualDuration,
                        bounce: AnimationRecipe.blurBounce
                    )
            }

            NSAnimationContext.runAnimationGroup({ context in
                context.allowsImplicitAnimation = true
                window.animator().alphaValue = endingState.opacity
                if animatesContentBlur {
                    window.animator().setValue(
                        endingState.blurRadius,
                        forKey: NSWindow.spotlightPanelContentBlurRadiusKeyPath
                    )
                }
            }, completionHandler: {
                // `runAnimationGroup` types its handler `@Sendable`, but AppKit calls it on the
                // main thread; asserting that is what keeps `completion` main-actor-isolated.
                MainActor.assumeIsolated { completion() }
            })
        }

        private func apply(_ state: AnimationState, to window: NSWindow) {
            window.alphaValue = state.opacity
            window.setSpotlightPanelContentBlurRadius(state.blurRadius)
        }

        /// Read back where an in-flight animation currently is, so reversing it does not snap.
        private func currentState(
            of layer: CALayer,
            window: NSWindow,
            fallback: AnimationState
        ) -> AnimationState {
            guard let presentationLayer = layer.presentation() else { return fallback }

            func value(forKeyPath keyPath: String, fallback fallbackValue: CGFloat) -> CGFloat {
                guard let number = presentationLayer.value(forKeyPath: keyPath) as? NSNumber else {
                    return fallbackValue
                }
                return CGFloat(number.doubleValue)
            }

            return AnimationState(
                horizontalScale: value(forKeyPath: "transform.scale.x", fallback: fallback.horizontalScale),
                verticalScale: value(forKeyPath: "transform.scale.y", fallback: fallback.verticalScale),
                opacity: window.alphaValue,
                blurRadius: fallback.blurRadius
            )
        }
    }
}

// MARK: - Completion join

/// Calls `completion` once the expected number of halves have reported in.
///
/// A reference type on purpose: both halves capture the same instance from different escaping
/// closures, and on the main actor there is nothing to synchronise.
@MainActor
private final class PendingHalves {
    private var remainingCount: Int
    private let completion: @MainActor () -> Void

    init(count: Int, completion: @escaping @MainActor () -> Void) {
        self.remainingCount = count
        self.completion = completion
    }

    func completeOne() {
        remainingCount -= 1
        guard remainingCount <= 0 else { return }
        completion()
    }
}

#endif
