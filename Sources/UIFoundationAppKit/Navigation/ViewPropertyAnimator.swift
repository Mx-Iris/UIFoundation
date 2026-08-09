//
//  Ported from the macOS App Store's own navigation stack.
//  Reverse-engineering notes: Researchs/AppStore-Custom-Navigation-Internals.md
//

#if Navigation && os(macOS)

import AppKit

/// A thin wrapper over `NSAnimationContext.runAnimationGroup(_:completionHandler:)`.
///
/// The animation blocks assign **final** values; `allowsImplicitAnimation` is what turns those
/// assignments into animations. That is the whole trick behind the App Store's navigation
/// transition, and the reason ``ViewTransition/prepare()`` forces `wantsLayer` on every
/// participating view first — without a backing layer there is nothing for CoreAnimation to
/// interpolate and the views jump straight to their end state.
///
/// Do **not** replace this with explicit `CABasicAnimation`s. Building animations up front would
/// mean the same transition could no longer be stepped frame by frame from a gesture, which is
/// the entire point of ``InteractiveViewTransition``.
public struct ViewPropertyAnimator {
    /// Bodies run inside the animation group. Each assigns end values.
    public var animations: [() -> Void] = []

    /// Bodies run once the group finishes.
    public var completions: [() -> Void] = []

    public var duration: TimeInterval
    public var curve: TimingCurve

    /// Seconds to wait before starting. Zero starts synchronously.
    public var delay: TimeInterval = 0

    public init(duration: TimeInterval, curve: TimingCurve, delay: TimeInterval = 0) {
        self.duration = duration
        self.curve = curve
        self.delay = delay
    }

    public init(timing: AnimationTiming, delay: TimeInterval = 0) {
        self.init(duration: timing.duration, curve: timing.curve, delay: delay)
    }

    public mutating func addAnimations(_ body: @escaping () -> Void) {
        animations.append(body)
    }

    public mutating func addCompletion(_ body: @escaping () -> Void) {
        completions.append(body)
    }

    @MainActor
    public func run() {
        guard delay > 0 else { return runImmediately() }
        let hop = MainQueueHop(animator: self)
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            MainActor.assumeIsolated { hop.animator.runImmediately() }
        }
    }

    /// Carries the animator across the single main-queue → main-queue hop that ``delay`` needs.
    ///
    /// The animation bodies are plain `() -> Void`, so the animator itself can never be Sendable.
    /// Nothing but ``run()`` ever constructs this, the value is read back on the main queue, and
    /// `assumeIsolated` re-establishes the isolation the far side already has.
    private struct MainQueueHop: @unchecked Sendable {
        let animator: ViewPropertyAnimator
    }

    @MainActor
    private func runImmediately() {
        // The completion goes on the context rather than through the two-argument
        // `runAnimationGroup(_:completionHandler:)`, whose handler imports as `@Sendable` and so
        // cannot capture the plain `() -> Void` bodies held here. Same effect, no escape hatch.
        NSAnimationContext.runAnimationGroup { context in
            context.duration = duration
            context.timingFunction = curve.caMediaTimingFunction
            context.allowsImplicitAnimation = true
            let pendingCompletions = completions
            context.completionHandler = {
                for completion in pendingCompletions {
                    completion()
                }
            }
            for animation in animations {
                animation()
            }
        }
    }
}

#endif
