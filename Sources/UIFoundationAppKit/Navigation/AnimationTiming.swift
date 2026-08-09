//
//  Ported from the macOS App Store's own navigation stack.
//  Reverse-engineering notes: Researchs/AppStore-Custom-Navigation-Internals.md
//

#if Navigation && os(macOS)

import AppKit

/// How long an animation runs and how it eases.
public struct AnimationTiming: Hashable, Sendable {
    public var duration: TimeInterval
    public var curve: TimingCurve

    public init(duration: TimeInterval, curve: TimingCurve) {
        self.duration = duration
        self.curve = curve
    }

    /// `UINavigationController`'s push timing: 0.35 seconds, ease-in-ease-out.
    public static let uiKitNavigation = AnimationTiming(duration: 0.35, curve: .easeInOut)

    /// What the macOS App Store uses for both directions of its navigation transition:
    /// 0.35 seconds on ``TimingCurve/appStoreNavigation``.
    public static let appStoreNavigation = AnimationTiming(duration: 0.35, curve: .appStoreNavigation)

    /// The same timing with the duration scaled to the distance still to travel.
    ///
    /// Used when a gesture is released partway: finishing from 70 % should take 30 % of the time,
    /// not the full 0.35 s.
    public func scaled(toRemaining remainingFraction: CGFloat) -> AnimationTiming {
        AnimationTiming(
            duration: duration * TimeInterval(min(max(remainingFraction, 0), 1)),
            curve: curve
        )
    }
}

#endif
