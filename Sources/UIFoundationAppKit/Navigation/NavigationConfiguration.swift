//
//  Ported from the macOS App Store's own navigation stack.
//  Reverse-engineering notes: Researchs/AppStore-Custom-Navigation-Internals.md
//

#if Navigation && os(macOS)

import AppKit

/// The knobs a ``NavigationController`` and its transitions share.
///
/// Two presets ship: ``uiKit`` — the default — reproduces `UINavigationController`'s push, and
/// ``appStore`` reproduces the macOS App Store's. They differ in more than taste, so read
/// ``appStore`` before switching.
public struct NavigationConfiguration {
    /// How long a transition runs and how it eases.
    public var timing: AnimationTiming

    /// How far the outgoing page slides, as a fraction of the container's width.
    ///
    /// The incoming page always travels the full width; this is only the counter-movement behind
    /// it, and the difference between the two speeds is the parallax.
    public var parallaxFactor: CGFloat

    /// The colour laid over the page being covered. Only ever the outgoing side.
    public var dimmingColor: NSColor

    /// Width of the soft shadow trailing the incoming page's leading edge, in points.
    ///
    /// Zero removes it. This is the single biggest difference between the two presets: without a
    /// shadow the arriving page has no visible edge, and the whole transition reads as content
    /// sliding sideways rather than one page moving over another.
    public var edgeShadowWidth: CGFloat

    /// How far pages are inset from the container's bounds. Honoured by the transition too.
    public var contentInsets: NSEdgeInsets

    public init(
        timing: AnimationTiming = .uiKitNavigation,
        parallaxFactor: CGFloat = 0.3,
        dimmingColor: NSColor = NSColor(srgbRed: 0, green: 0, blue: 0, alpha: 0.1),
        edgeShadowWidth: CGFloat = 9,
        contentInsets: NSEdgeInsets = NSEdgeInsets()
    ) {
        self.timing = timing
        self.parallaxFactor = parallaxFactor
        self.dimmingColor = dimmingColor
        self.edgeShadowWidth = edgeShadowWidth
        self.contentInsets = contentInsets
    }

    /// `UINavigationController`'s push, reproduced: 0.35 s ease-in-ease-out, the outgoing page
    /// counter-sliding 30 % of the width under a 10 % black dim, and a 9 pt edge shadow.
    ///
    /// This is the default. It is the livelier of the two — the shadow gives the arriving page a
    /// visible edge, and the symmetric curve keeps the motion readable end to end.
    public static let uiKit = NavigationConfiguration()

    /// The macOS App Store's own push, reproduced: 0.35 s on
    /// `cubic-bezier(0.1878, 0.0023, 0.5399, 0.9629)`, 25.27 % counter-slide, 22 % black dim, and
    /// **no edge shadow**.
    ///
    /// Flatter than ``uiKit`` on purpose — that is what the App Store ships. The curve is heavily
    /// front-loaded, so most of the travel happens in the first third and the tail crawls; with no
    /// shadow to mark the arriving page's edge, what stays visible longest is the outgoing page
    /// drifting. Pick it to match the App Store, not because it looks better.
    public static let appStore = NavigationConfiguration(
        timing: .appStoreNavigation,
        parallaxFactor: 0.2527,
        dimmingColor: NSColor(srgbRed: 0, green: 0, blue: 0, alpha: 0.22),
        edgeShadowWidth: 0
    )

    /// ``uiKit``.
    public static let `default` = uiKit
}

#endif
