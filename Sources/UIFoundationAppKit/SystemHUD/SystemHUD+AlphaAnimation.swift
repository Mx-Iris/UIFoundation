//
//  Ported from Mx-Iris/SystemHUD
//  https://github.com/Mx-Iris/SystemHUD
//

#if SystemHUD && os(macOS)

import AppKit

extension SystemHUD {
    /// Drives the panel's opacity by hand: `NSAnimation` reports progress, and each step is mapped
    /// onto the interval between ``startAlpha`` and ``endAlpha``.
    ///
    /// `stop()` is what makes an in-flight fade interruptible — it halts the animation outright,
    /// leaving the panel's current opacity for the caller to reset.
    final class AlphaAnimation: NSAnimation {
        var alphaDidChange: (CGFloat) -> Void = { _ in }

        var startAlpha: CGFloat = 1.0

        var endAlpha: CGFloat = 0.0

        override var currentProgress: NSAnimation.Progress {
            didSet {
                let alphaValue = startAlpha + (endAlpha - startAlpha) * CGFloat(currentProgress)
                alphaDidChange(alphaValue)
            }
        }
    }
}

#endif
