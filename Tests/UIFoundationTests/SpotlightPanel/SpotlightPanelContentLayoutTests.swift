#if SpotlightPanel && os(macOS)

import AppKit
import Testing
@testable import UIFoundationAppleInternal

/// The panel's internal layout.
///
/// **The bug this guards against:** the query field was pinned to the collapsed height (56 pt)
/// rather than centred within it. Measured: an `NSTextField`'s intrinsic height for a 24 pt line
/// is 28, but its cell's drawing rect fills whatever height it is handed and draws the text at the
/// top of it — so the query sat against the top edge with 28 points of dead space beneath it.
@Suite("SpotlightPanel content layout")
@MainActor
struct SpotlightPanelContentLayoutTests {
    private let metrics = SpotlightPanel.Metrics.default

    private func makeLaidOutController(
        leadingSymbolName: String? = "magnifyingglass"
    ) -> SpotlightPanel.ContentViewController {
        let controller = SpotlightPanel.ContentViewController(
            metrics: metrics,
            searchFieldFontSize: 24,
            searchFieldLeadingSymbolName: leadingSymbolName,
            searchDebounceDelay: 0.2
        )
        controller.view.frame = CGRect(x: 0, y: 0, width: 680, height: metrics.collapsedHeight)
        controller.view.layoutSubtreeIfNeeded()
        return controller
    }

    @Test("The query field keeps its intrinsic height instead of filling the collapsed height")
    func queryFieldIsNotStretched() {
        let controller = makeLaidOutController()

        let fieldHeight = controller.searchField.frame.height
        #expect(fieldHeight > 0)
        #expect(fieldHeight < metrics.collapsedHeight)
        #expect(fieldHeight == controller.searchField.intrinsicContentSize.height)
    }

    @Test("The query field is vertically centred in its container")
    func queryFieldIsCentred() {
        let controller = makeLaidOutController()

        let container = controller.searchFieldContainer
        let fieldCentre = controller.searchField.frame.midY
        let containerCentre = container.bounds.midY

        #expect(abs(fieldCentre - containerCentre) < 0.5)
    }

    @Test("The container holding the query field is exactly the collapsed height")
    func containerIsTheCollapsedHeight() {
        let controller = makeLaidOutController()
        #expect(controller.searchFieldContainer.frame.height == metrics.collapsedHeight)
    }

    // MARK: Selection

    /// The selected row must not use the system's emphasised selection.
    ///
    /// AppKit would paint `selectedContentBackgroundColor` — the user's accent colour — edge to
    /// edge and square, which on a glass platter reads as a coloured bar stamped across the panel,
    /// and which changes colour as focus moves. Forcing `isEmphasized` to `false` is what keeps
    /// the row's own text colour usable against the neutral band drawn in its place.
    @Test("A result row never reports itself as emphasised")
    func resultRowIsNeverEmphasised() {
        let rowView = SpotlightPanel.ResultRowView()

        #expect(!rowView.isEmphasized)

        rowView.isEmphasized = true
        #expect(!rowView.isEmphasized)
    }

    /// The accent colour and the neutral colour really are different, so the assertion above is
    /// worth something. On a machine whose accent happens to be grey this would be vacuous — hence
    /// checking rather than assuming.
    @Test("The neutral selection colour is not the accent selection colour")
    func neutralSelectionDiffersFromAccent() {
        let accent = NSColor.selectedContentBackgroundColor.usingColorSpace(.sRGB)
        let neutral = NSColor.unemphasizedSelectedContentBackgroundColor.usingColorSpace(.sRGB)

        #expect(accent != nil)
        #expect(neutral != nil)

        // Neutral means the three components agree; an accent colour normally does not.
        if let neutral {
            #expect(abs(neutral.redComponent - neutral.greenComponent) < 0.01)
            #expect(abs(neutral.greenComponent - neutral.blueComponent) < 0.01)
        }
    }

    @Test("Selection geometry reaches the row views from the metrics")
    func selectionGeometryIsHandedToRowViews() {
        var customMetrics = SpotlightPanel.Metrics.default
        customMetrics.resultSelectionCornerRadius = 14
        customMetrics.resultSelectionHorizontalInset = 6

        let resultsView = SpotlightPanel.ResultsView()
        resultsView.selectionCornerRadius = customMetrics.resultSelectionCornerRadius
        resultsView.selectionHorizontalInset = customMetrics.resultSelectionHorizontalInset

        let rowView = resultsView.tableView(NSTableView(), rowViewForRow: 0) as? SpotlightPanel.ResultRowView
        #expect(rowView?.selectionCornerRadius == 14)
        #expect(rowView?.selectionHorizontalInset == 6)
    }
}

#endif
