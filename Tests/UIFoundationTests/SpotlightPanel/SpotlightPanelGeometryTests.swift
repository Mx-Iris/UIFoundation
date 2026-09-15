#if SpotlightPanel && os(macOS)

import AppKit
import Testing
@testable import UIFoundation

/// Geometry is the part of the replica that can be checked without a display, and the part most
/// likely to drift, so it carries the bulk of the suite.
///
/// Note on `#expect` and `CGFloat`: every expectation here types both sides the same. A `CGFloat`
/// compared against a `Double` **variable** inside the macro reports false even when the values
/// match — see the Swift Testing note in `CLAUDE.md`.
@Suite("SpotlightPanel geometry")
struct SpotlightPanelGeometryTests {
    private let metrics = SpotlightPanel.Metrics.default

    // MARK: Measured constants

    /// A canary on the numbers taken out of Spotlight's `SearchConstants`. If one of these
    /// changes, the replica has stopped being a replica.
    @Test("Metrics defaults match what was measured in Spotlight 26.6.2")
    func measuredDefaults() {
        #expect(metrics.collapsedHeight == 56)
        #expect(metrics.minimumExpandedHeight == 430)
        #expect(metrics.cornerRadius == 28)
        #expect(metrics.animationPadding == 40)
        #expect(metrics.horizontalContentInset == 20)
        #expect(metrics.separatorHeight == 1)
    }

    // MARK: Placement

    /// The whole point of Spotlight's placement: the top edge does not depend on how tall the
    /// panel currently is.
    @Test("The top edge is pinned regardless of the panel's height")
    func topEdgeIsPinnedAcrossHeights() {
        let screenFrame = CGRect(x: 0, y: 0, width: 1920, height: 1080)

        let collapsedSize = metrics.windowSize(forContentHeight: metrics.collapsedHeight)
        let expandedSize = metrics.windowSize(forContentHeight: 600)

        let collapsedOrigin = metrics.defaultOrigin(forWindowSize: collapsedSize, inScreenFrame: screenFrame)
        let expandedOrigin = metrics.defaultOrigin(forWindowSize: expandedSize, inScreenFrame: screenFrame)

        let collapsedTopEdge = collapsedOrigin.y + collapsedSize.height
        let expandedTopEdge = expandedOrigin.y + expandedSize.height

        #expect(collapsedTopEdge == expandedTopEdge)
    }

    /// And the pin itself: that top edge is where a `standardExpandedHeight`-tall window's top
    /// edge would be if it were centred.
    @Test("The pinned top edge is the centred standard-height window's top edge")
    func pinnedTopEdgeMatchesCentredStandardHeight() {
        let screenFrame = CGRect(x: 0, y: 0, width: 1920, height: 1080)
        let windowSize = metrics.windowSize(forContentHeight: metrics.collapsedHeight)
        let origin = metrics.defaultOrigin(forWindowSize: windowSize, inScreenFrame: screenFrame)

        let expectedTopEdge = screenFrame.minY
            + (screenFrame.height - metrics.standardExpandedHeight) / 2
            + metrics.standardExpandedHeight

        #expect(origin.y + windowSize.height == expectedTopEdge)
    }

    @Test("Placement is horizontally centred and honours the screen's origin")
    func placementIsHorizontallyCentred() {
        // A second display hanging off to the right, so a formula that forgot `minX` fails.
        let screenFrame = CGRect(x: 1920, y: 0, width: 1440, height: 900)
        let windowSize = metrics.windowSize(forContentHeight: metrics.collapsedHeight)
        let origin = metrics.defaultOrigin(forWindowSize: windowSize, inScreenFrame: screenFrame)

        #expect(origin.x == screenFrame.minX + (screenFrame.width - windowSize.width) / 2)
        #expect(origin.x > screenFrame.minX)
    }

    @Test("The window is the panel plus a padding margin on every side")
    func windowSizeIncludesPaddingOnBothSides() {
        let windowSize = metrics.windowSize(forContentHeight: 200)

        #expect(windowSize.width == metrics.standardWidth + metrics.animationPadding * 2)
        #expect(windowSize.height == CGFloat(200) + metrics.animationPadding * 2)
    }

    // MARK: Resizing

    /// Expanding must not move the search field, which sits at the top of the panel.
    @Test("Resizing keeps the top edge where it was")
    func resizingKeepsTheTopEdge() {
        let startingFrame = CGRect(x: 100, y: 500, width: 760, height: 136)
        let resizedFrame = metrics.frame(startingFrame, resizedToContentHeight: 400)

        #expect(resizedFrame.maxY == startingFrame.maxY)
        #expect(resizedFrame.minX == startingFrame.minX)
        #expect(resizedFrame.height == CGFloat(400) + metrics.animationPadding * 2)
    }

    @Test("Collapsing also keeps the top edge, moving the bottom up")
    func collapsingKeepsTheTopEdge() {
        let expandedFrame = CGRect(x: 100, y: 200, width: 760, height: 480)
        let collapsedFrame = metrics.frame(expandedFrame, resizedToContentHeight: metrics.collapsedHeight)

        #expect(collapsedFrame.maxY == expandedFrame.maxY)
        #expect(collapsedFrame.minY > expandedFrame.minY)
    }
}

#endif
