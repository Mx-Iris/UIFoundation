//
//  Ported from the macOS App Store's own navigation stack.
//  Reverse-engineering notes: Researchs/AppStore-Custom-Navigation-Internals.md
//

#if Navigation && os(macOS)

import AppKit

/// Every rectangle a parallax transition needs, as pure functions.
///
/// Kept free of views deliberately: the numbers are the part worth pinning down in tests, and a
/// test that has to stand up a window to check an offset is a test nobody runs.
enum NavigationTransitionGeometry {
    /// The rectangle child views are laid out in — the container's bounds, inset.
    ///
    /// The App Store computes this from the container's **`frame`**, which only agrees with
    /// `bounds` while the container's origin is `(0, 0)`. That holds for a view controller's root
    /// view in the usual setup, so it never bit them, but it is the wrong rectangle: a child's
    /// frame lives in the container's own coordinate space. This port uses `bounds`.
    static func referenceRect(
        containerBounds: CGRect,
        contentInsets: NSEdgeInsets,
        isFlipped: Bool
    ) -> CGRect {
        let leadingInset = contentInsets.left
        let trailingInset = contentInsets.right
        // `top` names the edge as it appears on screen, so which of minY / maxY it eats depends
        // on which way the container's y axis runs.
        let lowerInset = isFlipped ? contentInsets.top : contentInsets.bottom
        let upperInset = isFlipped ? contentInsets.bottom : contentInsets.top
        return CGRect(
            x: containerBounds.minX + leadingInset,
            y: containerBounds.minY + lowerInset,
            width: max(0, containerBounds.width - leadingInset - trailingInset),
            height: max(0, containerBounds.height - lowerInset - upperInset)
        )
    }

    /// How far the outgoing view slides against the incoming one.
    ///
    /// Floored, not rounded — matching the App Store, which would otherwise land a half point off
    /// at odd widths.
    static func parallaxShift(referenceRect: CGRect, parallaxFactor: CGFloat) -> CGFloat {
        floor(referenceRect.width * parallaxFactor)
    }

    /// Where a view sits once it is entirely past the trailing edge, i.e. where an incoming view
    /// starts from and an outgoing view ends up.
    static func offscreenRect(
        referenceRect: CGRect,
        layoutDirection: NSUserInterfaceLayoutDirection
    ) -> CGRect {
        var rect = referenceRect
        rect.origin.x = layoutDirection == .rightToLeft
            ? referenceRect.minX - referenceRect.width
            : referenceRect.maxX
        return rect
    }

    /// Where the edge shadow sits for a given position of the page it trails: a strip
    /// `edgeShadowWidth` wide, hugging that page's leading edge from outside.
    static func edgeShadowRect(
        alongsideTopViewRect topViewRect: CGRect,
        edgeShadowWidth: CGFloat,
        layoutDirection: NSUserInterfaceLayoutDirection
    ) -> CGRect {
        guard edgeShadowWidth > 0 else { return .zero }
        return CGRect(
            x: layoutDirection == .rightToLeft ? topViewRect.maxX : topViewRect.minX - edgeShadowWidth,
            y: topViewRect.minY,
            width: edgeShadowWidth,
            height: topViewRect.height
        )
    }

    /// Which side of the shadow strip is darkest.
    ///
    /// The strip sits just outside the leading edge of the page it trails, so the darkest side is
    /// the one touching that page — the far side of the strip from the direction of travel.
    static func edgeShadowDarkEdge(
        for layoutDirection: NSUserInterfaceLayoutDirection
    ) -> NSRectEdge {
        layoutDirection == .rightToLeft ? .minX : .maxX
    }

    /// The reference rectangle displaced by the parallax amount, away from the trailing edge —
    /// where the underlying view rests while another one covers it.
    static func parallaxRect(
        referenceRect: CGRect,
        parallaxFactor: CGFloat,
        layoutDirection: NSUserInterfaceLayoutDirection
    ) -> CGRect {
        let shift = parallaxShift(referenceRect: referenceRect, parallaxFactor: parallaxFactor)
        var rect = referenceRect
        rect.origin.x = layoutDirection == .rightToLeft
            ? referenceRect.minX + shift
            : referenceRect.minX - shift
        return rect
    }
}

#endif
