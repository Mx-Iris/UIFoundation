//
//  Replicated from macOS 26's Spotlight.app (26.6.2).
//  Reverse-engineering notes: Researchs/Spotlight-Panel-Internals.md
//  Decision record: Documentations/Evolutions/0021-spotlight-panel-replica.md
//

#if SpotlightPanel && os(macOS)

import AppKit

extension SpotlightPanel {
    /// The panel's geometry.
    ///
    /// Every default here except ``standardWidth`` was read out of Spotlight's own
    /// `SearchConstants`, so changing one moves the replica away from the original rather than
    /// towards it. They are settable because a host's panel is not necessarily Spotlight-sized.
    public struct Metrics: Equatable, Sendable {
        /// Height of the panel when only the search field is showing. Spotlight: 56.
        public var collapsedHeight: CGFloat

        /// The floor an expanded panel is never allowed below. Spotlight: 430.
        public var minimumExpandedHeight: CGFloat

        /// The height whose centred position anchors the panel's top edge — see
        /// ``defaultOrigin(forWindowSize:on:)``, where it is the only thing the vertical
        /// placement depends on.
        ///
        /// In Spotlight this is `ResultPlatterBehavior.gridBrowse.minHeight + collapsedHeight`,
        /// and the left-hand term lives in `SpotlightUIShared` where it was not recoverable.
        /// **This default is therefore a choice, not a measurement** — it reuses
        /// ``minimumExpandedHeight``, which lands the panel close to where Spotlight puts it.
        public var standardExpandedHeight: CGFloat

        /// Panel width.
        ///
        /// **Also a choice rather than a measurement**: Spotlight's `standardWindowWidth`
        /// forwards into `SpotlightUIShared`, which the dump did not cover.
        public var standardWidth: CGFloat

        /// Corner radius of the rounded platter. Spotlight: 28 on macOS 26 (16 before it).
        public var cornerRadius: CGFloat

        /// Transparent margin kept on all four sides of the window so the present / dismiss
        /// scale-up has room to overflow without being clipped by the window edge.
        /// Spotlight's `animationWindowPadding`: 40 on every side.
        public var animationPadding: CGFloat

        /// Leading and trailing inset for the panel's content. Spotlight: 20 on macOS 26 (0
        /// before it).
        public var horizontalContentInset: CGFloat

        /// Thickness of the rule between the search field and the results. Spotlight: 1.
        public var separatorHeight: CGFloat

        /// Corner radius of the selected row's band. **Chosen, not measured** — Spotlight draws
        /// its rows from `SearchUI`, a private framework the reverse engineering did not cover.
        public var resultSelectionCornerRadius: CGFloat

        /// How far the selected row's band is inset from the panel's edges. Also chosen.
        public var resultSelectionHorizontalInset: CGFloat

        public static let `default` = Metrics()

        public init(
            collapsedHeight: CGFloat = 56,
            minimumExpandedHeight: CGFloat = 430,
            standardExpandedHeight: CGFloat = 430,
            standardWidth: CGFloat = 680,
            cornerRadius: CGFloat = 28,
            animationPadding: CGFloat = 40,
            horizontalContentInset: CGFloat = 20,
            separatorHeight: CGFloat = 1,
            resultSelectionCornerRadius: CGFloat = 10,
            resultSelectionHorizontalInset: CGFloat = 8
        ) {
            self.collapsedHeight = collapsedHeight
            self.minimumExpandedHeight = minimumExpandedHeight
            self.standardExpandedHeight = standardExpandedHeight
            self.standardWidth = standardWidth
            self.cornerRadius = cornerRadius
            self.animationPadding = animationPadding
            self.horizontalContentInset = horizontalContentInset
            self.separatorHeight = separatorHeight
            self.resultSelectionCornerRadius = resultSelectionCornerRadius
            self.resultSelectionHorizontalInset = resultSelectionHorizontalInset
        }
    }
}

// MARK: - Placement

extension SpotlightPanel.Metrics {
    /// Where a window of `windowSize` should sit on `screen`.
    ///
    /// This is `-[SPSpotlightPanel defaultPositionOriginForWindowSize:screen:]`, whose whole
    /// point is easy to miss: **the panel's top edge is pinned to where the top edge of a
    /// `standardExpandedHeight`-tall window would be if that window were centred**, and the
    /// current height only moves the bottom edge. So the panel sits high while collapsed and
    /// arrives at dead centre once expanded, instead of growing downwards from a fixed centre.
    ///
    /// The size passed in is the *padded* window size — the one that includes
    /// ``animationPadding`` — because that is what gets handed to `setFrame`.
    public func defaultOrigin(forWindowSize windowSize: CGSize, on screen: NSScreen) -> CGPoint {
        defaultOrigin(forWindowSize: windowSize, inScreenFrame: screen.frame)
    }

    /// The same placement against a bare rectangle.
    ///
    /// Split out from the `NSScreen` form because an `NSScreen` cannot be constructed, and this
    /// is the piece worth asserting.
    public func defaultOrigin(forWindowSize windowSize: CGSize, inScreenFrame screenFrame: CGRect) -> CGPoint {
        let horizontalOrigin = screenFrame.minX + (screenFrame.width - windowSize.width) / 2
        let anchoredTopEdge = screenFrame.minY + (screenFrame.height + standardExpandedHeight) / 2
        return CGPoint(x: horizontalOrigin, y: anchoredTopEdge - windowSize.height)
    }

    /// The window size that holds `contentHeight` points of panel, padding included.
    public func windowSize(forContentHeight contentHeight: CGFloat) -> CGSize {
        CGSize(
            width: standardWidth + animationPadding * 2,
            height: contentHeight + animationPadding * 2
        )
    }

    /// Grow a frame downwards (or shrink it upwards) while its top edge stays put.
    ///
    /// Expanding and collapsing must not move the search field, which is what the host's eye is
    /// on, so the frame is rebuilt from its top edge rather than its origin.
    public func frame(_ frame: CGRect, resizedToContentHeight contentHeight: CGFloat) -> CGRect {
        let newHeight = contentHeight + animationPadding * 2
        let topEdge = frame.maxY
        return CGRect(x: frame.minX, y: topEdge - newHeight, width: frame.width, height: newHeight)
    }
}

#endif
