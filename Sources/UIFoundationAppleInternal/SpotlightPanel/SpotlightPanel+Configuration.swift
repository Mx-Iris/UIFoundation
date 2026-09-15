//
//  Replicated from macOS 26's Spotlight.app (26.6.2).
//  Decision record: Documentations/Evolutions/0021-spotlight-panel-replica.md
//

#if SpotlightPanel && os(macOS)

import AppKit

extension SpotlightPanel {
    /// Everything a host can change about the panel.
    ///
    /// Split away from ``SpotlightPanel/Metrics``, which is geometry recovered from Spotlight;
    /// this is behaviour and text, none of which has an original to be faithful to.
    public struct Configuration: Equatable, Sendable {
        /// Panel geometry. Defaults are Spotlight's own.
        public var metrics: Metrics

        /// Placeholder shown in the empty query field.
        public var placeholderText: String

        /// SF Symbol shown at the leading edge of the query field, as Spotlight shows a
        /// magnifying glass. `nil` leaves the field flush against the panel's content inset.
        public var searchFieldLeadingSymbolName: String?

        /// Point size of the query field's text.
        ///
        /// Not a measurement — Spotlight's own `searchFieldPadding` resolves through a framework
        /// the dump did not cover, so this is sized to look right inside a 56 pt collapsed panel.
        public var searchFieldFontSize: CGFloat

        /// How long typing has to pause before a search is issued.
        public var searchDebounceDelay: TimeInterval

        /// How long result changes are coalesced before the window resizes.
        ///
        /// Separate from ``searchDebounceDelay`` on purpose, and this is the one that stops a
        /// response arriving in several passes from making the panel shudder — Spotlight keeps
        /// the same two timers apart for the same reason.
        public var sizingDebounceDelay: TimeInterval

        /// Duration of the expand / collapse resize.
        ///
        /// Spotlight's own curve for this was not recovered; the present and dismiss springs in
        /// ``SpotlightPanel/AnimationRecipe`` were.
        public var resizeAnimationDuration: TimeInterval

        /// Whether losing key status dismisses the panel.
        ///
        /// Spotlight's answer is no, because it has its own hotkey to come back through. A
        /// library panel usually wants yes.
        public var dismissesWhenResigningKey: Bool

        /// Whether presenting activates the application first.
        ///
        /// Needed for the query field to take focus when the panel is raised from a background
        /// application.
        public var activatesApplicationOnPresent: Bool

        /// The tallest the whole panel may get, as a fraction of the screen's visible height.
        public var maximumHeightFractionOfScreen: CGFloat

        public init(
            metrics: Metrics = .default,
            placeholderText: String = "",
            searchFieldLeadingSymbolName: String? = "magnifyingglass",
            searchFieldFontSize: CGFloat = 24,
            searchDebounceDelay: TimeInterval = 0.2,
            sizingDebounceDelay: TimeInterval = 0.05,
            resizeAnimationDuration: TimeInterval = 0.2,
            dismissesWhenResigningKey: Bool = true,
            activatesApplicationOnPresent: Bool = true,
            maximumHeightFractionOfScreen: CGFloat = 0.6
        ) {
            self.metrics = metrics
            self.placeholderText = placeholderText
            self.searchFieldLeadingSymbolName = searchFieldLeadingSymbolName
            self.searchFieldFontSize = searchFieldFontSize
            self.searchDebounceDelay = searchDebounceDelay
            self.sizingDebounceDelay = sizingDebounceDelay
            self.resizeAnimationDuration = resizeAnimationDuration
            self.dismissesWhenResigningKey = dismissesWhenResigningKey
            self.activatesApplicationOnPresent = activatesApplicationOnPresent
            self.maximumHeightFractionOfScreen = maximumHeightFractionOfScreen
        }

        public static let `default` = Configuration()
    }
}

#endif
