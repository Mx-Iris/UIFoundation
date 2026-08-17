//
//  Ported from the macOS App Store's own navigation stack.
//  Reverse-engineering notes: Researchs/AppStore-Custom-Navigation-Internals.md
//

#if Navigation && os(macOS)

import AppKit

/// What goes behind a page while it is moving, so a see-through page does not show the page it is
/// covering.
///
/// A navigation transition assumes pages are opaque: the arriving one covers the one it pushes
/// away. On macOS 26 that assumption breaks, because a page has to be **clear** for the window's
/// glass to show through it — and then both pages' content is visible at once for the length of
/// the transition, overlapping.
///
/// The fix is a background for the page running the full-width slide, for the duration only. It is a sibling, not something written onto the page itself: this package's own
/// ``LayerBackedView`` rewrites `layer.backgroundColor` in `updateLayer()`, so a page that redraws
/// mid-transition would clobber anything set there, and restoring it afterwards would write back a
/// stale value — a host doing this by hand has to force a redraw after restoring, and a sibling
/// view has nothing to restore at all.
public enum NavigationPageBackdrop {
    /// Add one only when the travelling page looks see-through — it reports `isOpaque == false`
    /// and carries no opaque layer background. Filled with `windowBackgroundColor`.
    ///
    /// A page that paints its own opaque background in `draw(_:)` also matches, and gets a
    /// backdrop it completely hides. That costs one view for the length of the transition and
    /// changes nothing on screen.
    case automatic

    /// Always add one, filled with this colour.
    case color(NSColor)

    /// Always add one, built by this closure — an `NSVisualEffectView` or `NSGlassEffectView` if
    /// the page should carry its own material while it travels rather than a flat fill.
    case view(() -> NSView)

    /// Never add one. Correct when every page is opaque, and the only way to keep the container's
    /// glass visible under a see-through page for the whole transition.
    case none
}

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

    /// What goes behind a see-through page so it does not show the page it covers.
    ///
    /// It applies to the page running the full-width slide — the arriving page on a push, the
    /// **leaving** page on a pop — and only that one. That is the page whose motion the eye
    /// follows, and the one that has to look solid so the page behind it does not read through.
    ///
    /// The two directions get there differently. A push slides a view in underneath the arriving
    /// page; a pop writes the colour onto the leaving page itself and puts it back afterwards,
    /// because that page already fills the container and anything slipped beneath it would appear
    /// there instantly instead of arriving with it.
    public var pageBackdrop: NavigationPageBackdrop

    /// How far pages are inset from the container's bounds. Honoured by the transition too.
    public var contentInsets: NSEdgeInsets

    public init(
        timing: AnimationTiming = .uiKitNavigation,
        parallaxFactor: CGFloat = 0.3,
        dimmingColor: NSColor = NSColor(srgbRed: 0, green: 0, blue: 0, alpha: 0.1),
        edgeShadowWidth: CGFloat = 9,
        pageBackdrop: NavigationPageBackdrop = .automatic,
        contentInsets: NSEdgeInsets = NSEdgeInsets()
    ) {
        self.timing = timing
        self.parallaxFactor = parallaxFactor
        self.dimmingColor = dimmingColor
        self.edgeShadowWidth = edgeShadowWidth
        self.pageBackdrop = pageBackdrop
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
