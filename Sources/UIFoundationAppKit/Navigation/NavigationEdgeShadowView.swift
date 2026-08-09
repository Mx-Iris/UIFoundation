//
//  Ported from UIKit's `_UIVerticalEdgeShadowView`, by way of AppKitPlus's
//  `_NSVerticalEdgeShadowView`.
//

#if Navigation && os(macOS)

import AppKit

/// The soft vertical falloff that trails the incoming page's leading edge.
///
/// Without it two flat pages sliding past each other read as one flat thing moving; the shadow is
/// what makes the arriving page look like a layer travelling *over* the one it covers. UIKit has
/// it, the macOS App Store does not — see ``NavigationConfiguration/edgeShadowWidth``.
///
/// **The falloff is a blur spill, not a gradient.** An opaque block is filled entirely *outside*
/// the clip and discarded; only the part of its shadow that reaches back inside survives, which
/// gives a Gaussian profile. A linear `NSGradient` in its place reads noticeably harder.
final class NavigationEdgeShadowView: NSView {
    let shadowWidth: CGFloat

    /// Which side of the strip is darkest — the side the incoming page sits against.
    let darkEdge: NSRectEdge

    init(shadowWidth: CGFloat, darkEdge: NSRectEdge) {
        self.shadowWidth = max(0, shadowWidth)
        self.darkEdge = darkEdge == .minX ? .minX : .maxX
        super.init(frame: .zero)
        wantsLayer = true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func draw(_ dirtyRect: NSRect) {
        guard shadowWidth > 0, !bounds.isEmpty,
              let context = NSGraphicsContext.current?.cgContext
        else { return }

        context.saveGState()
        // Clipping is what turns the block into a falloff: the block lands entirely outside and is
        // thrown away, and only its shadow spills back in.
        context.clip(to: bounds)

        let shadowColor = NSColor.black.cgColor
        context.setFillColor(shadowColor)
        context.setShadow(offset: .zero, blur: shadowWidth, color: shadowColor)

        // Overhang both ends so the falloff stays even along the full height instead of tapering
        // at the corners.
        let blockRect = CGRect(
            x: darkEdge == .maxX ? bounds.maxX : bounds.minX - shadowWidth,
            y: bounds.minY - shadowWidth,
            width: shadowWidth,
            height: bounds.height + shadowWidth * 2
        )
        context.fill(blockRect)

        context.restoreGState()
    }

    override func hitTest(_ point: NSPoint) -> NSView? { nil }
}

#endif
