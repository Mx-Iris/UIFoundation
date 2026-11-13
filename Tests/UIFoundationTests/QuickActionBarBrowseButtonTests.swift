#if QuickActionBar && os(macOS)

import AppKit
import Testing
@testable import UIFoundationAppKit

/// The browse buttons beside the search field, and the glass they bud out of (macOS 26 and later).
///
/// The buttons move on a display link, which a test cannot wait on reliably, so tests read where
/// the buttons are heading (`isShowingBrowseButtons`) and then end the animation with
/// `finishBrowseButtonAnimations()` before measuring frames. The motion itself is covered by
/// `QuickActionBarMitosisTests`.
///
/// These live in the presentation suite so that they never run beside another bar: a bar closes
/// itself when it resigns key or main, and serializing keeps one bar on screen at a time.
@MainActor
extension QuickActionBarPresentationTests {
    @Test("Without browse items the platter's glass spans the whole bar")
    func platterSpansTheBarWithoutBrowseItems() throws {
        guard #available(macOS 26.0, *), NSScreen.main != nil else { return }

        let actionBar = makeBrowseButtonActionBar(browseItems: [])
        defer { actionBar.cancel() }
        let window = try #require(actionBar.quickActionBarWindow)
        window.contentView?.layoutSubtreeIfNeeded()

        let glassPlatterView = try #require(window.primaryView?.glassPlatterView)
        #expect(glassPlatterView.platterGlass.frame.width == 640)
        #expect(glassPlatterView.platterGlass.frame.height == glassPlatterView.bounds.height)
        #expect(glassPlatterView.platterGlass.enclosingGlassEffectContainer != nil)
    }

    @Test("A click on the search field still reaches it through the glass container")
    func searchFieldReceivesClicks() throws {
        guard #available(macOS 26.0, *), NSScreen.main != nil else { return }

        let actionBar = makeBrowseButtonActionBar(browseItems: [])
        defer { actionBar.cancel() }
        let window = try #require(actionBar.quickActionBarWindow)
        window.contentView?.layoutSubtreeIfNeeded()

        let searchField = window.editLabel
        let pointInWindow = searchField.convert(NSPoint(x: searchField.bounds.midX, y: searchField.bounds.midY), to: nil)
        let hitView = try #require(window.contentView?.superview?.hitTest(pointInWindow))

        #expect(hitView === searchField || hitView.isDescendant(of: searchField))
    }

    @Test("No browse items, no buttons — even after Spotlight's delay")
    func noBrowseItemsNoButtons() async throws {
        guard #available(macOS 26.0, *), NSScreen.main != nil else { return }

        let actionBar = makeBrowseButtonActionBar(browseItems: [])
        defer { actionBar.cancel() }
        let glassPlatterView = try #require(actionBar.quickActionBarWindow?.primaryView?.glassPlatterView)

        try await ContinuousClock().sleep(for: .milliseconds(600))

        #expect(!glassPlatterView.hasBrowseButtons)
        #expect(glassPlatterView.glassSmoothness == 0)
    }

    @Test("The buttons bud out after Spotlight's delay and settle where Spotlight puts them")
    func buttonsBudOutAfterTheDelay() async throws {
        guard #available(macOS 26.0, *), NSScreen.main != nil else { return }

        let actionBar = makeBrowseButtonActionBar(browseItems: Self.spotlightBrowseItems())
        defer { actionBar.cancel() }
        let window = try #require(actionBar.quickActionBarWindow)
        let glassPlatterView = try #require(window.primaryView?.glassPlatterView)

        #expect(!glassPlatterView.hasBrowseButtons)
        try await ContinuousClock().sleep(for: .milliseconds(600))
        #expect(glassPlatterView.isShowingBrowseButtons)

        glassPlatterView.finishBrowseButtonAnimations()

        #expect(abs(glassPlatterView.platterGlass.frame.width - 384) < 0.01)
        #expect(glassPlatterView.browseButtonGlasses.map { (($0.frame.midX * 100).rounded() / 100) } == [421, 485, 549, 613])
        #expect(glassPlatterView.browseButtonGlasses.allSatisfy { abs($0.frame.width - 54) < 0.01 && abs($0.cornerRadius - 27) < 0.01 })
        #expect(glassPlatterView.browseButtonGlasses.allSatisfy { $0.enclosingGlassEffectContainer != nil })
        #expect(glassPlatterView.browseButtonControls.map(\.toolTip) == ["Applications", "Files", "Actions", "Clipboard"])
        let everyButtonIsEnabled = glassPlatterView.browseButtonControls.allSatisfy { $0.isEnabled }
        #expect(everyButtonIsEnabled)
    }

    @Test("Clicking a browse button calls its action with the bar, which stays open")
    func clickingCallsTheAction() async throws {
        guard #available(macOS 26.0, *), NSScreen.main != nil else { return }

        var activatedTitles: [String] = []
        var receivedBar: QuickActionBar?
        let items = ["Applications", "Files"].map { title in
            QuickActionBar.BrowseItem(title: title, image: Self.symbolImage("folder")) { quickActionBar in
                activatedTitles.append(title)
                receivedBar = quickActionBar
            }
        }
        let actionBar = makeBrowseButtonActionBar(browseItems: items)
        defer { actionBar.cancel() }
        let window = try #require(actionBar.quickActionBarWindow)
        let glassPlatterView = try #require(window.primaryView?.glassPlatterView)
        try await ContinuousClock().sleep(for: .milliseconds(600))
        glassPlatterView.finishBrowseButtonAnimations()

        let filesButton = try #require(glassPlatterView.browseButtonControls.last)
        let pointInWindow = filesButton.convert(NSPoint(x: filesButton.bounds.midX, y: filesButton.bounds.midY), to: nil)
        #expect(window.contentView?.superview?.hitTest(pointInWindow) === filesButton)

        // The button's own action, not `performClick(_:)`: that one runs AppKit's highlight through
        // the event loop, and on macOS 27.2 the system ends a `swift test` runner a moment after it
        // starts handling window events (exit status 0, the rest of the run never printed — the
        // trap PlaybackSlider's guide records).
        filesButton.sendAction(filesButton.action, to: filesButton.target)

        #expect(activatedTitles == ["Files"])
        #expect(receivedBar === actionBar)
        #expect(actionBar.isPresenting)
        #expect(!actionBar.resumePresentation())
    }

    @Test("Results draw the buttons back in, and clearing the query brings them out again")
    func resultsDrawTheButtonsIn() async throws {
        guard #available(macOS 26.0, *), NSScreen.main != nil else { return }

        let actionBar = makeBrowseButtonActionBar(browseItems: Self.spotlightBrowseItems(), contentSource: BrowseButtonContentSource.make())
        defer { actionBar.cancel() }
        let window = try #require(actionBar.quickActionBarWindow)
        let glassPlatterView = try #require(window.primaryView?.glassPlatterView)
        try await ContinuousClock().sleep(for: .milliseconds(600))
        glassPlatterView.finishBrowseButtonAnimations()
        #expect(glassPlatterView.isShowingBrowseButtons)

        window.editLabel.stringValue = "xcode"
        actionBar.provideResultIdentifiers(["alpha", "beta"])

        #expect(!glassPlatterView.isShowingBrowseButtons)
        glassPlatterView.finishBrowseButtonAnimations()
        #expect(!glassPlatterView.hasBrowseButtons)
        #expect(glassPlatterView.platterGlass.frame.width == 640)

        // Escape clears the query and searches again at once; the content source answers an empty
        // query with nothing, so the results collapse and the buttons come back out.
        window.doCommand(by: #selector(NSResponder.cancelOperation(_:)))
        try await ContinuousClock().sleep(for: .milliseconds(50))

        #expect(actionBar.currentSearchText == "")
        #expect(glassPlatterView.isShowingBrowseButtons)
    }

    @Test("Results arriving while the buttons are out leave the platter narrow until the springs widen it")
    func resultsDoNotWidenThePlatterAtOnce() async throws {
        guard #available(macOS 26.0, *), NSScreen.main != nil else { return }

        let actionBar = makeBrowseButtonActionBar(browseItems: Self.spotlightBrowseItems(), contentSource: BrowseButtonContentSource.make())
        defer { actionBar.cancel() }
        let window = try #require(actionBar.quickActionBarWindow)
        let glassPlatterView = try #require(window.primaryView?.glassPlatterView)
        try await ContinuousClock().sleep(for: .milliseconds(600))
        glassPlatterView.finishBrowseButtonAnimations()

        window.editLabel.stringValue = "xcode"
        actionBar.provideResultIdentifiers(["alpha", "beta"])
        window.contentView?.layoutSubtreeIfNeeded()

        // The results ask for the bar's full 640 points. At any priority above the window's own
        // size (500) that request grew the whole window to 896 points here, platter included —
        // measured, before the results' width was lowered below it.
        #expect(glassPlatterView.bounds.width == 640)
        #expect(glassPlatterView.platterGlass.frame.width < 400)
        #expect(window.results.frame.width <= glassPlatterView.platterGlass.frame.width)
    }

    @Test("With no buttons out the results still span the whole bar")
    func resultsSpanTheBarWithoutButtons() throws {
        guard NSScreen.main != nil else { return }

        let actionBar = makeBrowseButtonActionBar(browseItems: [], contentSource: BrowseButtonContentSource.make())
        defer { actionBar.cancel() }
        let window = try #require(actionBar.quickActionBarWindow)

        window.editLabel.stringValue = "xcode"
        actionBar.provideResultIdentifiers(["alpha", "beta"])
        window.contentView?.layoutSubtreeIfNeeded()

        #expect(window.results.frame.width == 640)
    }

    @Test("A query with no results still draws the buttons in, to give the query the whole field")
    func queryWithoutResultsDrawsTheButtonsIn() async throws {
        guard #available(macOS 26.0, *), NSScreen.main != nil else { return }

        let actionBar = makeBrowseButtonActionBar(browseItems: Self.spotlightBrowseItems(), contentSource: BrowseButtonContentSource.make())
        defer { actionBar.cancel() }
        let window = try #require(actionBar.quickActionBarWindow)
        let glassPlatterView = try #require(window.primaryView?.glassPlatterView)
        try await ContinuousClock().sleep(for: .milliseconds(600))
        #expect(glassPlatterView.isShowingBrowseButtons)

        window.editLabel.stringValue = "nothing matches"
        actionBar.provideResultIdentifiers([])

        #expect(!glassPlatterView.isShowingBrowseButtons)
    }

    @Test("New browse items replace the buttons that are out: the old ones draw in, the new ones bud out")
    func newItemsReplaceTheButtons() async throws {
        guard #available(macOS 26.0, *), NSScreen.main != nil else { return }

        let actionBar = makeBrowseButtonActionBar(browseItems: Self.spotlightBrowseItems())
        defer { actionBar.cancel() }
        let window = try #require(actionBar.quickActionBarWindow)
        let glassPlatterView = try #require(window.primaryView?.glassPlatterView)
        try await ContinuousClock().sleep(for: .milliseconds(600))
        glassPlatterView.finishBrowseButtonAnimations()

        actionBar.browseItems = Array(Self.spotlightBrowseItems().prefix(2))

        #expect(!glassPlatterView.isShowingBrowseButtons)
        #expect(glassPlatterView.browseButtonControls.count == 4)

        glassPlatterView.finishBrowseButtonAnimations()

        #expect(glassPlatterView.isShowingBrowseButtons)
        #expect(glassPlatterView.browseButtonControls.map(\.toolTip) == ["Applications", "Files"])
        glassPlatterView.finishBrowseButtonAnimations()
        #expect(abs(glassPlatterView.platterGlass.frame.width - 512) < 0.01)
    }

    // MARK: - Helpers

    private func makeBrowseButtonActionBar(
        browseItems: [QuickActionBar.BrowseItem],
        contentSource: BrowseButtonContentSource? = nil
    ) -> QuickActionBar {
        _ = NSApplication.shared
        let actionBar = QuickActionBar()
        actionBar.contentSource = contentSource
        actionBar.browseItems = browseItems
        actionBar.present(width: 640, height: 240)
        return actionBar
    }

    /// Spotlight's four, with the symbols it uses.
    private static func spotlightBrowseItems() -> [QuickActionBar.BrowseItem] {
        [
            ("Applications", "appstore"),
            ("Files", "folder"),
            ("Actions", "app.2.stack.3d"),
            ("Clipboard", "document.on.document"),
        ].map { title, symbolName in
            QuickActionBar.BrowseItem(title: title, image: symbolImage(symbolName)) { _ in }
        }
    }

    private static func symbolImage(_ symbolName: String) -> NSImage {
        NSImage(systemSymbolName: symbolName, accessibilityDescription: nil) ?? NSImage(size: NSSize(width: 22, height: 22))
    }
}

/// Answers every non-empty query with two rows and an empty one with none.
///
/// Every instance is kept alive for the rest of the run: the bar holds its content source weakly
/// and delivers results on a later main-queue turn, and its results view traps if the source is
/// gone by then.
private final class BrowseButtonContentSource: NSObject, QuickActionBarContentSource {
    @MainActor private static var everyInstance: [BrowseButtonContentSource] = []

    @MainActor static func make() -> BrowseButtonContentSource {
        let contentSource = BrowseButtonContentSource()
        everyInstance.append(contentSource)
        return contentSource
    }

    func quickActionBar(_ quickActionBar: QuickActionBar, itemsForSearchTermTask task: QuickActionBar.SearchTask) {
        task.complete(with: task.searchTerm.isEmpty ? [] : ["alpha", "beta"])
    }

    func quickActionBar(_ quickActionBar: QuickActionBar, viewForItem item: AnyHashable, searchTerm: String) -> NSView? {
        NSTextField(labelWithString: "\(item)")
    }

    func quickActionBar(_ quickActionBar: QuickActionBar, didActivateItem item: AnyHashable) {}
}

@available(macOS 26.0, *)
private extension NSView {
    /// The nearest glass effect container above this view, the one that merges its glass.
    var enclosingGlassEffectContainer: NSGlassEffectContainerView? {
        var ancestor = superview
        while let currentAncestor = ancestor {
            if let container = currentAncestor as? NSGlassEffectContainerView {
                return container
            }
            ancestor = currentAncestor.superview
        }
        return nil
    }
}

#endif
