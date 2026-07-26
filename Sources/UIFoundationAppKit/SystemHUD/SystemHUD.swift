//
//  Ported from Mx-Iris/SystemHUD
//  https://github.com/Mx-Iris/SystemHUD
//

#if SystemHUD && os(macOS)

import AppKit

/// A borderless floating panel modelled on the system volume / brightness HUD: a vibrancy
/// backdrop hosting an optional glyph above a single-line title, shown below the centre of the
/// active screen and faded out after a delay.
///
/// ```swift
/// SystemHUD.default.configuration.image = NSImage(named: "Build")
/// SystemHUD.default.configuration.title = "Build Succeeded"
/// SystemHUD.default.show(delay: 1.0)
/// ```
///
/// The panel never takes focus and never receives clicks, so it is safe to show it over any
/// window, including a full-screen one.
@MainActor
public final class SystemHUD {
    /// A shared HUD, enough for hosts that only ever show one message at a time.
    public static let `default` = SystemHUD(configuration: .init(title: ""))

    /// How far below the screen's vertical centre the panel sits, as a fraction of the visible
    /// height. Matches where the system places its own volume HUD.
    private static let verticalOffsetRatio: CGFloat = 0.38

    /// The gap kept between the panel and the screen edges when a long title pushes the panel
    /// wider than ``Configuration/minimumSize``.
    private static let screenEdgeMargin: CGFloat = 20

    /// The panel's appearance. Assigning re-lays out the panel immediately; the change shows up
    /// on the next ``show(delay:)``.
    public var configuration: Configuration {
        didSet {
            window.hudContentView.configuration = configuration
            updateWindowGeometry()
        }
    }

    private let window: Window

    private var dismissTimer: Timer?

    private var fadeOutAnimation: AlphaAnimation?

    public init(configuration: Configuration) {
        self.configuration = configuration
        self.window = Window(configuration: configuration)
        updateWindowGeometry()
    }

    /// Shows the panel, then fades it out `delay` seconds later.
    ///
    /// Calling this while a previous panel is still fading out interrupts that fade, restores full
    /// opacity, and restarts the timer.
    public func show(delay: TimeInterval) {
        dismissTimer?.invalidate()
        dismissTimer = nil

        updateWindowGeometry()

        fadeOutAnimation?.stop()
        fadeOutAnimation = nil
        window.alphaValue = 1
        window.orderFront(nil)

        // `.common` rather than the default mode: a HUD raised from a menu-tracking or
        // window-resizing run loop must still dismiss itself.
        let dismissTimer = Timer(timeInterval: delay, repeats: false) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.dismissTimer = nil
                self.fadeOut(duration: self.configuration.dismissAnimationDuration)
            }
        }
        RunLoop.main.add(dismissTimer, forMode: .common)
        self.dismissTimer = dismissTimer
    }

    /// Sizes the panel to its content — clamped below by ``Configuration/minimumSize`` and above by
    /// the screen width — and re-centres it on the screen that is active *now*. Doing this on every
    /// `show` rather than once at init is what keeps the HUD on the right display after the user
    /// moves to another screen or changes resolution.
    private func updateWindowGeometry() {
        guard let screen = NSScreen.main else { return }

        let visibleFrame = screen.visibleFrame
        let contentInsets = configuration.contentInsets
        let horizontalInsets = contentInsets.left + contentInsets.right
        let verticalInsets = contentInsets.top + contentInsets.bottom
        let preferredContentSize = window.hudContentView.preferredContentSize

        let maximumWindowWidth = max(configuration.minimumSize.width, visibleFrame.width - Self.screenEdgeMargin * 2)
        let windowWidth = min(maximumWindowWidth, max(configuration.minimumSize.width, preferredContentSize.width + horizontalInsets))
        let windowHeight = max(configuration.minimumSize.height, preferredContentSize.height + verticalInsets)

        // Hand the clamped width back to the content so an over-long title truncates inside the
        // panel instead of dragging the panel off the screen.
        window.hudContentView.setContentSize(
            .init(width: windowWidth - horizontalInsets, height: preferredContentSize.height)
        )

        let windowOrigin = CGPoint(
            x: visibleFrame.midX - windowWidth / 2,
            y: visibleFrame.midY - visibleFrame.height * Self.verticalOffsetRatio - windowHeight / 2
        )
        window.setFrame(.init(origin: windowOrigin, size: .init(width: windowWidth, height: windowHeight)), display: false)
    }

    /// Fades the panel out from wherever its opacity currently sits, non-blocking so the run loop
    /// keeps servicing the host.
    private func fadeOut(duration: TimeInterval) {
        let fadeOutAnimation = AlphaAnimation(duration: duration, animationCurve: .easeIn)
        fadeOutAnimation.alphaDidChange = { [weak self] alphaValue in
            guard let self else { return }
            window.alphaValue = alphaValue
        }
        fadeOutAnimation.startAlpha = window.alphaValue
        fadeOutAnimation.endAlpha = 0
        fadeOutAnimation.animationBlockingMode = .nonblocking
        fadeOutAnimation.start()
        self.fadeOutAnimation = fadeOutAnimation
    }
}

#endif
