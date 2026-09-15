//
//  Replicated from macOS 26's Spotlight.app (26.6.2).
//  Reverse-engineering notes: Researchs/Spotlight-Panel-Internals.md
//  Decision record: Documentations/Evolutions/0021-spotlight-panel-replica.md
//

#if SpotlightPanel && os(macOS)

import AppKit

extension SpotlightPanel {
    /// How tall the results platter wants to be, and what the panel is allowed to do about it.
    ///
    /// This is Spotlight's `ResultPlatterBehavior`, and it exists because "how tall is the
    /// content" and "how tall should the window be" are different questions. A data source
    /// returns one of these per response; the panel resolves it into an actual height through
    /// ``resolvedContentHeight(collapsedHeight:searchFieldHeight:separatorHeight:storedExpandedHeight:hasResults:)``.
    public struct PlatterBehavior: Equatable, Sendable {
        /// The floor for the results area. Never applied when the panel collapses.
        public var minimumHeight: CGFloat

        /// The height to use when it fits between ``minimumHeight`` and ``maximumHeight``.
        /// `nil` means "as tall as allowed".
        public var preferredHeight: CGFloat?

        /// The ceiling for the results area. Content beyond this scrolls.
        public var maximumHeight: CGFloat

        /// Whether the height the panel settles on survives into the next response.
        ///
        /// With this on, a list that briefly returns two rows does not make the panel jump short
        /// and then tall again — it keeps the height it had. Spotlight uses this for results
        /// that arrive incrementally.
        public var heightCanPersist: Bool

        /// Whether an empty response collapses the panel back to the search field alone.
        public var collapsesForEmptyResponse: Bool

        /// Whether the resize is animated. A response that only reorders existing rows can set
        /// this to `false` to avoid a visible settle.
        public var isAnimated: Bool

        /// Reserved for the filter bar, which is not part of this phase — see the decision
        /// record's phase table. Always `false` for now; kept so adding the filter bar later
        /// does not change this type's shape.
        public var includesFilterBarHeight: Bool

        /// Panel width for this response. `nil` keeps ``Metrics/standardWidth``.
        public var width: CGFloat?

        public init(
            minimumHeight: CGFloat = 0,
            preferredHeight: CGFloat? = nil,
            maximumHeight: CGFloat = .greatestFiniteMagnitude,
            heightCanPersist: Bool = false,
            collapsesForEmptyResponse: Bool = true,
            isAnimated: Bool = true,
            includesFilterBarHeight: Bool = false,
            width: CGFloat? = nil
        ) {
            self.minimumHeight = minimumHeight
            self.preferredHeight = preferredHeight
            self.maximumHeight = maximumHeight
            self.heightCanPersist = heightCanPersist
            self.collapsesForEmptyResponse = collapsesForEmptyResponse
            self.isAnimated = isAnimated
            self.includesFilterBarHeight = includesFilterBarHeight
            self.width = width
        }

        /// Stay collapsed regardless of what the results say.
        public static let collapsed = PlatterBehavior(
            minimumHeight: 0,
            preferredHeight: 0,
            maximumHeight: 0,
            collapsesForEmptyResponse: true
        )

        /// The default a list of results gets: grow with the content, between the panel's
        /// expanded floor and a ceiling derived from the screen.
        public static func list(
            minimumHeight: CGFloat,
            maximumHeight: CGFloat,
            heightCanPersist: Bool = true
        ) -> PlatterBehavior {
            PlatterBehavior(
                minimumHeight: minimumHeight,
                maximumHeight: maximumHeight,
                heightCanPersist: heightCanPersist
            )
        }
    }
}

// MARK: - Height resolution

extension SpotlightPanel.PlatterBehavior {
    /// Turn this behavior plus the measured content into the panel's total content height.
    ///
    /// Kept a pure function of its arguments so the sizing rules can be asserted without a
    /// window: it is the piece most likely to be wrong and the piece hardest to see going wrong.
    ///
    /// - Parameters:
    ///   - collapsedHeight: ``SpotlightPanel/Metrics/collapsedHeight``.
    ///   - measuredResultsHeight: how tall the results actually are, unclamped.
    ///   - separatorHeight: ``SpotlightPanel/Metrics/separatorHeight``, counted only when the
    ///     panel ends up expanded.
    ///   - storedExpandedHeight: the height the panel settled on for the previous response, or
    ///     `nil` if there was none. Only consulted when ``heightCanPersist`` is on.
    ///   - hasResults: whether the response carried anything at all.
    public func resolvedContentHeight(
        collapsedHeight: CGFloat,
        measuredResultsHeight: CGFloat,
        separatorHeight: CGFloat,
        storedExpandedHeight: CGFloat?,
        hasResults: Bool
    ) -> CGFloat {
        guard hasResults || !collapsesForEmptyResponse else { return collapsedHeight }
        guard maximumHeight > 0 else { return collapsedHeight }

        let requestedHeight: CGFloat = if let preferredHeight {
            preferredHeight
        } else if heightCanPersist, let storedExpandedHeight, storedExpandedHeight > measuredResultsHeight {
            storedExpandedHeight
        } else {
            measuredResultsHeight
        }

        let clampedHeight = min(max(requestedHeight, minimumHeight), maximumHeight)
        guard clampedHeight > 0 else { return collapsedHeight }

        return collapsedHeight + separatorHeight + clampedHeight
    }
}

// MARK: - Expansion state

extension SpotlightPanel {
    /// Where the panel is in the collapse / expand cycle.
    ///
    /// Spotlight tracks the same four (its spelling of the first one has a typo, fixed here).
    /// A plain `isExpanded` flag is not enough: the two transitional cases are exactly when a
    /// second resize request has to be coalesced rather than acted on.
    public enum ExpansionState: String, Hashable, Sendable, CaseIterable {
        /// No response has arrived yet, so the panel has never had a height.
        case uninitialized
        /// Search field only.
        case collapsed
        /// A resize towards expanded is in flight.
        case expanding
        /// Search field plus results.
        case expanded

        public var isExpandedOrExpanding: Bool {
            self == .expanded || self == .expanding
        }
    }
}

#endif
