#if SpotlightPanel && os(macOS)

import AppKit
import Testing
@testable import UIFoundationAppleInternal

/// The expand / collapse resize.
///
/// The resize is driven frame by frame rather than through `window.animator().setFrame(_:display:)`
/// so that the model frame and the visual frame stay equal — Auto Layout resolves against the
/// model, and a window whose model frame runs ahead of its visual one lays its contents out where
/// they will end up rather than where they are. `QuickActionBar` reached the same conclusion
/// independently.
///
/// **What these tests do and do not cover.** They pin this implementation's own behaviour: the
/// state machine, the zero-duration path, cancellation, replacement, the curve. They do **not**
/// distinguish it from the `animator()` spelling — that was checked by putting the old shape back,
/// and the suite stayed green, because in a test process with no display the two behave alike.
/// Anyone tempted to switch back should know these tests will not stop them.
@Suite("SpotlightPanel window frame animator")
@MainActor
struct SpotlightPanelWindowFrameAnimatorTests {
    private func makeWindow() -> NSWindow {
        NSWindow(
            contentRect: CGRect(x: 100, y: 500, width: 760, height: 136),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
    }

    // MARK: The regression

    /// Right after the call the window has not jumped to the target — it is still at, or barely
    /// past, where it started. This catches a resize that forgot to animate at all; it does not
    /// catch the `animator()` spelling (see the note on the suite).
    @Test("An animated resize does not set the model frame straight away")
    func animatedResizeDoesNotJumpTheModelFrame() {
        let window = makeWindow()
        let startingFrame = window.frame
        let targetFrame = CGRect(x: 100, y: 200, width: 760, height: 436)

        let animator = SpotlightPanel.WindowFrameAnimator()
        animator.animate(window, to: targetFrame, duration: 0.2) {}

        #expect(window.frame != targetFrame)
        #expect(window.frame.height < targetFrame.height)
        #expect(window.frame.height >= startingFrame.height)
        #expect(animator.isAnimating)
        #expect(animator.frameBeingAnimatedTo == targetFrame)

        animator.cancel()
    }

    /// A zero duration is the "don't animate this response" path and has to land exactly, with the
    /// completion still called.
    @Test("A zero-duration resize lands immediately and still completes")
    func zeroDurationLandsImmediately() {
        let window = makeWindow()
        let targetFrame = CGRect(x: 100, y: 200, width: 760, height: 436)

        var didComplete = false
        let animator = SpotlightPanel.WindowFrameAnimator()
        animator.animate(window, to: targetFrame, duration: 0) { didComplete = true }

        #expect(window.frame == targetFrame)
        #expect(didComplete)
        #expect(!animator.isAnimating)
    }

    @Test("Cancelling stops the animation and drops the completion")
    func cancellingStopsTheAnimation() {
        let window = makeWindow()
        var didComplete = false

        let animator = SpotlightPanel.WindowFrameAnimator()
        animator.animate(
            window,
            to: CGRect(x: 100, y: 200, width: 760, height: 436),
            duration: 0.2
        ) { didComplete = true }
        animator.cancel()

        #expect(!animator.isAnimating)
        #expect(animator.frameBeingAnimatedTo == nil)
        #expect(!didComplete)
    }

    /// Starting a second resize mid-flight replaces the first rather than racing it.
    @Test("A second resize replaces the one in flight")
    func secondResizeReplacesTheFirst() {
        let window = makeWindow()
        let firstTarget = CGRect(x: 100, y: 200, width: 760, height: 436)
        let secondTarget = CGRect(x: 100, y: 300, width: 760, height: 336)

        let animator = SpotlightPanel.WindowFrameAnimator()
        animator.animate(window, to: firstTarget, duration: 0.2) {}
        animator.animate(window, to: secondTarget, duration: 0.2) {}

        #expect(animator.frameBeingAnimatedTo == secondTarget)

        animator.cancel()
    }

    // MARK: The curve

    @Test("The easing curve is symmetric and pinned at both ends")
    func easingCurveIsSymmetric() {
        #expect(SpotlightPanel.WindowFrameAnimator.easeInEaseOut(0) == 0)
        #expect(SpotlightPanel.WindowFrameAnimator.easeInEaseOut(1) == 1)
        #expect(SpotlightPanel.WindowFrameAnimator.easeInEaseOut(0.5) == 0.5)

        // Slow at the start, slow at the end, fast in the middle.
        #expect(SpotlightPanel.WindowFrameAnimator.easeInEaseOut(0.25) < 0.25)
        #expect(SpotlightPanel.WindowFrameAnimator.easeInEaseOut(0.75) > 0.75)
    }

    @Test("Interpolation moves every edge and lands exactly at both ends")
    func interpolationCoversEveryEdge() {
        let startingFrame = CGRect(x: 0, y: 0, width: 100, height: 100)
        let endingFrame = CGRect(x: 40, y: 80, width: 300, height: 500)

        #expect(
            SpotlightPanel.WindowFrameAnimator.interpolate(
                from: startingFrame, to: endingFrame, progress: 0
            ) == startingFrame
        )
        #expect(
            SpotlightPanel.WindowFrameAnimator.interpolate(
                from: startingFrame, to: endingFrame, progress: 1
            ) == endingFrame
        )

        let halfway = SpotlightPanel.WindowFrameAnimator.interpolate(
            from: startingFrame, to: endingFrame, progress: 0.5
        )
        #expect(halfway == CGRect(x: 20, y: 40, width: 200, height: 300))
    }
}

#endif
