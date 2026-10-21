//
//  Replicated from macOS 26's Spotlight.app (26.6.2).
//  Decision record: Documentations/Evolutions/0021-spotlight-panel-replica.md
//

#if SpotlightPanel && os(macOS)

import AppKit
import QuartzCore

extension SpotlightPanel {
    /// Resizes a window frame by frame, writing the real frame every tick, along Spotlight's own
    /// resize curve.
    ///
    /// **The curve.** On macOS 27.2 the default resize animation of `SpotlightUIShared`'s results
    /// platter (`WindowSizingAnimation.AxisAnimation.default`) is
    /// `Animation.spring(Spring(duration: 0.3, bounce: 0.2))`, for expanding and collapsing alike.
    /// The duration is the caller's (``Configuration/resizeAnimationDuration``, 0.3 by default);
    /// the bounce is Spotlight's. The spring is evaluated in closed form, as SwiftUI evaluates it,
    /// and a resize ends once it has come to rest — a little after its duration.
    ///
    /// **Why not `window.animator().setFrame(_:display:)`.** The animator proxy moves the
    /// *visual* frame over time while setting the **model** frame to its final value immediately.
    /// Auto Layout resolves against the model, so everything inside the panel jumps to where it
    /// will end up and the window's edge then crawls out from behind it — the search field stays
    /// put but the result list appears fully laid out in a window that has not grown yet. Driving
    /// `setFrame` directly keeps model and visual frame equal at every step, which is the only
    /// shape in which Auto Layout and a growing window agree.
    @MainActor
    final class WindowFrameAnimator {
        private weak var animatedWindow: NSWindow?
        private var displayTimer: Timer?
        private var startingFrame: CGRect = .zero
        private var targetFrame: CGRect = .zero
        private var startedAt: CFTimeInterval = 0
        private var duration: TimeInterval = 0
        private var completion: (@MainActor () -> Void)?

        /// `true` while a resize is in flight.
        var isAnimating: Bool { displayTimer != nil }

        /// The frame the running animation is heading for, or `nil` when idle.
        private(set) var frameBeingAnimatedTo: CGRect?

        func animate(
            _ window: NSWindow,
            to newFrame: CGRect,
            duration newDuration: TimeInterval,
            completion newCompletion: @escaping @MainActor () -> Void
        ) {
            cancel()

            guard newDuration > 0 else {
                window.setFrame(newFrame, display: true)
                newCompletion()
                return
            }

            animatedWindow = window
            startingFrame = window.frame
            targetFrame = newFrame
            frameBeingAnimatedTo = newFrame
            startedAt = CACurrentMediaTime()
            duration = newDuration
            completion = newCompletion

            let timer = Timer(timeInterval: 1.0 / 120.0, repeats: true) { _ in
                MainActor.assumeIsolated { self.step() }
            }
            RunLoop.main.add(timer, forMode: .common)
            displayTimer = timer
        }

        /// Stop where it is, leaving the window at whatever frame it reached.
        func cancel() {
            displayTimer?.invalidate()
            displayTimer = nil
            frameBeingAnimatedTo = nil
            completion = nil
            animatedWindow = nil
        }

        private func step() {
            guard let animatedWindow else {
                cancel()
                return
            }

            let elapsed = CACurrentMediaTime() - startedAt
            let progress = Self.springProgress(at: elapsed, duration: duration)

            animatedWindow.setFrame(
                Self.interpolate(from: startingFrame, to: targetFrame, progress: progress),
                display: true
            )

            guard Self.springHasSettled(at: elapsed, duration: duration) else { return }

            animatedWindow.setFrame(targetFrame, display: true)
            let finishedCompletion = completion
            cancel()
            finishedCompletion?()
        }

        /// Spotlight's bounce. The duration varies; this does not.
        static let springBounce: Double = 0.2

        /// How far a resize has come `elapsed` seconds in, 0 being where it started and 1 the
        /// target: `Spring(duration: duration, bounce: 0.2)` from rest, which passes 1 by about
        /// 1.5 % before it settles.
        static func springProgress(at elapsed: TimeInterval, duration: TimeInterval) -> Double {
            let spring = SpringCoefficients(duration: duration)
            let envelope = exp(-spring.decayRate * elapsed)
            let oscillation = cos(spring.dampedFrequency * elapsed)
                + spring.decayRate / spring.dampedFrequency * sin(spring.dampedFrequency * elapsed)
            return 1 - envelope * oscillation
        }

        /// Whether that spring has come to rest on the target.
        static func springHasSettled(at elapsed: TimeInterval, duration: TimeInterval) -> Bool {
            let spring = SpringCoefficients(duration: duration)
            let velocity = exp(-spring.decayRate * elapsed)
                * spring.naturalFrequency * spring.naturalFrequency / spring.dampedFrequency
                * sin(spring.dampedFrequency * elapsed)
            return abs(springProgress(at: elapsed, duration: duration) - 1) < 0.0005 && abs(velocity) < 0.01
        }

        /// `Spring(duration:bounce:)` for a unit mass: SwiftUI's natural frequency is 2π / duration
        /// and its damping ratio 1 − bounce.
        private struct SpringCoefficients {
            let naturalFrequency: Double
            let decayRate: Double
            let dampedFrequency: Double

            init(duration: TimeInterval) {
                let dampingRatio = 1 - WindowFrameAnimator.springBounce
                naturalFrequency = 2 * .pi / duration
                decayRate = dampingRatio * naturalFrequency
                dampedFrequency = naturalFrequency * (1 - dampingRatio * dampingRatio).squareRoot()
            }
        }

        static func interpolate(from startingFrame: CGRect, to endingFrame: CGRect, progress: Double) -> CGRect {
            func interpolate(_ start: CGFloat, _ end: CGFloat) -> CGFloat {
                start + (end - start) * CGFloat(progress)
            }
            return CGRect(
                x: interpolate(startingFrame.minX, endingFrame.minX),
                y: interpolate(startingFrame.minY, endingFrame.minY),
                width: interpolate(startingFrame.width, endingFrame.width),
                height: interpolate(startingFrame.height, endingFrame.height)
            )
        }
    }
}

#endif
