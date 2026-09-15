//
//  Replicated from macOS 26's Spotlight.app (26.6.2).
//  Decision record: Documentations/Evolutions/0021-spotlight-panel-replica.md
//

#if SpotlightPanel && os(macOS)

import AppKit
import QuartzCore

extension SpotlightPanel {
    /// Resizes a window frame by frame, writing the real frame every tick.
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
            let linearProgress = min(max(elapsed / duration, 0), 1)
            let easedProgress = Self.easeInEaseOut(linearProgress)

            animatedWindow.setFrame(
                Self.interpolate(from: startingFrame, to: targetFrame, progress: easedProgress),
                display: true
            )

            guard linearProgress >= 1 else { return }

            animatedWindow.setFrame(targetFrame, display: true)
            let finishedCompletion = completion
            cancel()
            finishedCompletion?()
        }

        /// The curve `CAMediaTimingFunction(name: .easeInEaseOut)` describes, in closed form.
        static func easeInEaseOut(_ progress: Double) -> Double {
            progress < 0.5
                ? 2 * progress * progress
                : 1 - pow(-2 * progress + 2, 2) / 2
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
