#if SpotlightPanel && os(macOS)

import AppKit
import Testing
@testable import UIFoundation

/// The sizing rules — Spotlight's `ResultPlatterBehavior` — resolved as a pure function, which is
/// the only reason they can be asserted at all.
@Suite("SpotlightPanel platter behavior")
struct SpotlightPanelSizingTests {
    private let collapsedHeight: CGFloat = 56
    private let separatorHeight: CGFloat = 1

    private func resolve(
        _ behavior: SpotlightPanel.PlatterBehavior,
        measuredResultsHeight: CGFloat,
        storedExpandedHeight: CGFloat? = nil,
        hasResults: Bool = true
    ) -> CGFloat {
        behavior.resolvedContentHeight(
            collapsedHeight: collapsedHeight,
            measuredResultsHeight: measuredResultsHeight,
            separatorHeight: separatorHeight,
            storedExpandedHeight: storedExpandedHeight,
            hasResults: hasResults
        )
    }

    @Test("An empty response collapses when the behavior says so")
    func emptyResponseCollapses() {
        let behavior = SpotlightPanel.PlatterBehavior(
            minimumHeight: 300,
            maximumHeight: 600,
            collapsesForEmptyResponse: true
        )
        #expect(resolve(behavior, measuredResultsHeight: 0, hasResults: false) == collapsedHeight)
    }

    /// The opposite setting exists for hosts that show a "no results" row, which still needs the
    /// panel open.
    @Test("An empty response stays open when the behavior says so")
    func emptyResponseCanStayOpen() {
        let behavior = SpotlightPanel.PlatterBehavior(
            minimumHeight: 300,
            maximumHeight: 600,
            collapsesForEmptyResponse: false
        )
        let resolvedHeight = resolve(behavior, measuredResultsHeight: 0, hasResults: false)
        #expect(resolvedHeight == collapsedHeight + separatorHeight + 300)
    }

    @Test("The measured height is clamped between the floor and the ceiling")
    func measuredHeightIsClamped() {
        let behavior = SpotlightPanel.PlatterBehavior(minimumHeight: 200, maximumHeight: 500)

        #expect(resolve(behavior, measuredResultsHeight: 40) == collapsedHeight + separatorHeight + 200)
        #expect(resolve(behavior, measuredResultsHeight: 350) == collapsedHeight + separatorHeight + 350)
        #expect(resolve(behavior, measuredResultsHeight: 900) == collapsedHeight + separatorHeight + 500)
    }

    @Test("A preferred height wins over the measured one, still clamped")
    func preferredHeightWins() {
        let behavior = SpotlightPanel.PlatterBehavior(
            minimumHeight: 100,
            preferredHeight: 320,
            maximumHeight: 500
        )
        #expect(resolve(behavior, measuredResultsHeight: 40) == collapsedHeight + separatorHeight + 320)

        let clampedBehavior = SpotlightPanel.PlatterBehavior(
            minimumHeight: 100,
            preferredHeight: 900,
            maximumHeight: 500
        )
        #expect(resolve(clampedBehavior, measuredResultsHeight: 40) == collapsedHeight + separatorHeight + 500)
    }

    /// This is the setting that stops a panel jumping short and tall again while results arrive
    /// in several passes.
    @Test("A persisted height holds when the new content is shorter")
    func persistedHeightHoldsAgainstShorterContent() {
        let behavior = SpotlightPanel.PlatterBehavior(
            minimumHeight: 0,
            maximumHeight: 600,
            heightCanPersist: true
        )
        let resolvedHeight = resolve(behavior, measuredResultsHeight: 90, storedExpandedHeight: 400)
        #expect(resolvedHeight == collapsedHeight + separatorHeight + 400)
    }

    @Test("A persisted height gives way to taller content")
    func persistedHeightGivesWayToTallerContent() {
        let behavior = SpotlightPanel.PlatterBehavior(
            minimumHeight: 0,
            maximumHeight: 600,
            heightCanPersist: true
        )
        let resolvedHeight = resolve(behavior, measuredResultsHeight: 520, storedExpandedHeight: 400)
        #expect(resolvedHeight == collapsedHeight + separatorHeight + 520)
    }

    @Test("Without heightCanPersist the stored height is ignored")
    func storedHeightIsIgnoredWithoutPersistence() {
        let behavior = SpotlightPanel.PlatterBehavior(
            minimumHeight: 0,
            maximumHeight: 600,
            heightCanPersist: false
        )
        let resolvedHeight = resolve(behavior, measuredResultsHeight: 90, storedExpandedHeight: 400)
        #expect(resolvedHeight == collapsedHeight + separatorHeight + 90)
    }

    @Test("The collapsed preset never expands, whatever the content measures")
    func collapsedPresetNeverExpands() {
        #expect(resolve(.collapsed, measuredResultsHeight: 800) == collapsedHeight)
    }

    @Test("Expansion state reports the two transitional cases as in-flight")
    func expansionStateTransitions() {
        #expect(SpotlightPanel.ExpansionState.expanding.isExpandedOrExpanding)
        #expect(SpotlightPanel.ExpansionState.expanded.isExpandedOrExpanding)
        #expect(!SpotlightPanel.ExpansionState.collapsed.isExpandedOrExpanding)
        #expect(!SpotlightPanel.ExpansionState.uninitialized.isExpandedOrExpanding)
    }
}

#endif
