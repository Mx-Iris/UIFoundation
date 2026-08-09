//
//  Ported from the macOS App Store's own navigation stack.
//  Reverse-engineering notes: Researchs/AppStore-Custom-Navigation-Internals.md
//

#if Navigation && os(macOS)

import AppKit

/// A description of how one view gives way to another.
///
/// A transition is a **value**, not a running animation: it knows the three views involved and
/// the properties to drive between two states, and ``apply(_:)`` writes the state for any
/// fraction. That is what lets the same description be handed to CoreAnimation or stepped frame
/// by frame from a gesture.
///
/// Implement this to replace the built-in look; hand your type back from
/// ``NavigationControllerTransitionDelegate``.
@MainActor
public protocol ViewTransition {
    /// - Parameters:
    ///   - containerView: The navigation controller's own view. Both other views live inside it.
    ///   - sourceView: The view on screen now.
    ///   - destinationView: The view coming in. Not yet in the hierarchy — ``prepare()`` adds it.
    init(
        containerView: NSView,
        sourceView: NSView,
        destinationView: NSView,
        configuration: NavigationConfiguration
    )

    /// How long the automatic (non-interactive) run takes, and how it eases.
    var timing: AnimationTiming { get }

    /// Adds the incoming view and any decoration to the hierarchy, turns on layer backing, and
    /// seats everything at fraction zero.
    ///
    /// Layer backing is not optional: ``ViewPropertyAnimator`` animates by assigning end values
    /// under `allowsImplicitAnimation`, and a view with no backing layer has nothing to
    /// interpolate and jumps.
    func prepare()

    /// Writes the state for `fraction`, where 0 is "not started" and 1 is "finished".
    func apply(_ fraction: CGFloat)

    /// Removes whatever should no longer be on screen and restores the frames of what stays.
    ///
    /// - Parameter isFinished: `true` when the transition reached 1, `false` when it was
    ///   abandoned and the source view is staying.
    func cleanUp(isFinished: Bool)
}

/// A transition that a gesture can drive directly.
///
/// The extra three members exist so a released gesture can animate the *remainder* rather than
/// restarting: the transition is already sitting at some fraction, and finishing means travelling
/// what is left of the distance in a proportionally shorter time.
@MainActor
public protocol InteractiveViewTransition: ViewTransition {
    /// Called once when the gesture starts, before the first ``apply(_:)``.
    func beginInteractive()

    /// Runs from `fraction` to 1 and then cleans up as a completed transition.
    func finishInteractive(from fraction: CGFloat, completion: @escaping () -> Void)

    /// Runs from `fraction` back to 0 and then cleans up as an abandoned transition.
    func cancelInteractive(from fraction: CGFloat, completion: @escaping () -> Void)
}

extension InteractiveViewTransition {
    public func beginInteractive() {
        prepare()
    }

    public func finishInteractive(from fraction: CGFloat, completion: @escaping () -> Void) {
        animateRemainder(from: fraction, to: 1, isFinished: true, completion: completion)
    }

    public func cancelInteractive(from fraction: CGFloat, completion: @escaping () -> Void) {
        animateRemainder(from: fraction, to: 0, isFinished: false, completion: completion)
    }

    private func animateRemainder(
        from fraction: CGFloat,
        to targetFraction: CGFloat,
        isFinished: Bool,
        completion: @escaping () -> Void
    ) {
        var animator = ViewPropertyAnimator(
            timing: timing.scaled(toRemaining: abs(targetFraction - fraction))
        )
        animator.addAnimations { apply(targetFraction) }
        animator.addCompletion {
            cleanUp(isFinished: isFinished)
            completion()
        }
        animator.run()
    }
}

#endif
