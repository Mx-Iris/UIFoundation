//
//  Ported from the macOS App Store's own navigation stack.
//  Reverse-engineering notes: Researchs/AppStore-Custom-Navigation-Internals.md
//

#if Navigation && os(macOS)

import AppKit

/// One two-finger pop, from the moment the gesture is recognised until it commits or is abandoned.
final class InteractivePopSession {
    let transition: any InteractiveViewTransition
    let poppedViewController: NSViewController
    let revealedViewController: NSViewController

    init(
        transition: any InteractiveViewTransition,
        poppedViewController: NSViewController,
        revealedViewController: NSViewController
    ) {
        self.transition = transition
        self.poppedViewController = poppedViewController
        self.revealedViewController = revealedViewController
    }
}

extension NavigationController {

    /// The swipe-tracking options the App Store passes.
    ///
    /// `NSEvent.SwipeTrackingOptions` publicly declares `.lockDirection` (1) and
    /// `.clampGestureAmount` (2); the App Store passes **7**, so bit 2 is something AppKit does
    /// not name. Reproduced verbatim because matching the shipped feel is the point — the
    /// documented pair alone is `[.lockDirection, .clampGestureAmount]`.
    private static let swipeTrackingOptions = NSEvent.SwipeTrackingOptions(rawValue: 7)

    /// Starts an interactive pop if this scroll event is the beginning of a rightward two-finger
    /// swipe and there is somewhere to go back to.
    ///
    /// - Returns: `true` when the event was taken over, in which case the caller must not pass it
    ///   to `super`.
    func beginInteractivePopIfPossible(with event: NSEvent) -> Bool {
        guard allowsInteractivePop,
              !isTransitioning,
              interactivePopSession == nil,
              canPop,
              // Only the very first event of a gesture opens a session; everything after it is
              // delivered through the tracking handler instead.
              event.phase == .began,
              // Horizontal-dominant, and rightward only: this gesture goes back, never forward.
              abs(event.scrollingDeltaY) < abs(event.scrollingDeltaX),
              event.scrollingDeltaX > 0
        else { return false }

        let poppedViewController = stack[stack.count - 1]
        let revealedViewController = stack[stack.count - 2]

        guard let transition = makeTransition(
            operation: .pop,
            from: poppedViewController,
            to: revealedViewController
        ) as? any InteractiveViewTransition else {
            // A transition delegate supplied something that cannot be driven by hand. Fall back to
            // letting the event travel on rather than half-starting a gesture.
            return false
        }

        let session = InteractivePopSession(
            transition: transition,
            poppedViewController: poppedViewController,
            revealedViewController: revealedViewController
        )
        interactivePopSession = session
        beginTransition()
        delegate?.navigationController(self, willShow: revealedViewController, animated: true)
        transition.beginInteractive()

        // AppKit keeps calling the handler after the fingers lift, animating `gestureAmount` to
        // whichever end it snapped to, and only then passes `isComplete`. So the settle is the
        // system's, not ours, and it stays in step with the gesture that preceded it.
        event.trackSwipeEvent(
            options: Self.swipeTrackingOptions,
            dampenAmountThresholdMin: 0,
            max: 1
        ) { [weak self] gestureAmount, _, isComplete, stop in
            guard let self, interactivePopSession === session else {
                stop.pointee = true
                return
            }
            let fraction = min(max(gestureAmount, 0), 1)
            session.transition.apply(fraction)
            guard isComplete else { return }
            endInteractivePop(session, didPop: fraction >= 0.5)
        }

        return true
    }

    private func endInteractivePop(_ session: InteractivePopSession, didPop: Bool) {
        interactivePopSession = nil

        // The stack can only be committed if it still looks the way it did when the gesture
        // started; anything else means something reached in behind the gesture.
        let isStackUnchanged = stack.last === session.poppedViewController
        let shouldCommit = didPop && isStackUnchanged

        session.transition.cleanUp(isFinished: shouldCommit)

        if shouldCommit {
            session.poppedViewController.removeFromParent()
            stack.removeLast()
        }

        endTransition()

        if shouldCommit {
            notifyDidShow(session.revealedViewController, animated: true)
        } else {
            // The gesture was abandoned, so the view controller that was on top is on top again.
            // Say so both ways round, or a host that swapped its chrome on `willShow` never
            // learns to swap it back.
            delegate?.navigationController(self, willShow: session.poppedViewController, animated: true)
            notifyDidShow(session.poppedViewController, animated: true)
        }
    }
}

#endif
