#if Settings && os(macOS)

import Testing

@testable import UIFoundationSettingsUI

/// The history semantics on their own — no window, no SwiftUI. Everything the
/// back / forward buttons depend on is decided here.
@MainActor
@Suite("Settings navigator")
struct SettingsNavigatorTests {

    @Test("an initial page counts as the first visit")
    func initialPageIsRecorded() {
        guard #available(macOS 14.0, *) else { return }
        let navigator = SettingsNavigator(initialPageID: "general")

        #expect(navigator.currentPageID == "general")
        #expect(navigator.visitedPageIDs == ["general"])
        #expect(navigator.currentHistoryIndex == 0)
        #expect(!navigator.canGoBack)
        #expect(!navigator.canGoForward)
    }

    @Test("without an initial page the history starts empty")
    func emptyStart() {
        guard #available(macOS 14.0, *) else { return }
        let navigator = SettingsNavigator()

        #expect(navigator.currentPageID == nil)
        #expect(navigator.visitedPageIDs.isEmpty)
        #expect(navigator.currentHistoryIndex == -1)
        #expect(!navigator.canGoBack)
        #expect(!navigator.canGoForward)
    }

    @Test("navigating to a page records it; navigating to the same one again does not")
    func recordingAndDeduplication() {
        guard #available(macOS 14.0, *) else { return }
        let navigator = SettingsNavigator(initialPageID: "general")

        navigator.navigate(to: "appearance")
        #expect(navigator.visitedPageIDs == ["general", "appearance"])

        navigator.navigate(to: "appearance")
        #expect(navigator.visitedPageIDs == ["general", "appearance"])
        #expect(navigator.currentHistoryIndex == 1)
    }

    @Test("going back and forward moves through the history without adding to it")
    func backAndForwardDoNotRecord() {
        guard #available(macOS 14.0, *) else { return }
        let navigator = SettingsNavigator(initialPageID: "general")
        navigator.navigate(to: "appearance")
        navigator.navigate(to: "editor")

        #expect(navigator.goBack() == "appearance")
        #expect(navigator.currentPageID == "appearance")
        #expect(navigator.visitedPageIDs == ["general", "appearance", "editor"])
        #expect(navigator.canGoBack)
        #expect(navigator.canGoForward)

        #expect(navigator.goForward() == "editor")
        #expect(navigator.currentPageID == "editor")
        #expect(navigator.visitedPageIDs == ["general", "appearance", "editor"])
        #expect(!navigator.canGoForward)
    }

    @Test("at either end the move is refused and nothing changes")
    func boundariesAreRefused() {
        guard #available(macOS 14.0, *) else { return }
        let navigator = SettingsNavigator(initialPageID: "general")

        #expect(navigator.goBack() == nil)
        #expect(navigator.currentHistoryIndex == 0)
        #expect(navigator.goForward() == nil)
        #expect(navigator.currentHistoryIndex == 0)

        let empty = SettingsNavigator()
        #expect(empty.goBack() == nil)
        #expect(empty.goForward() == nil)
        #expect(empty.currentHistoryIndex == -1)
    }

    @Test("picking a new page after going back drops what was ahead")
    func selectingAfterGoingBackTruncates() {
        guard #available(macOS 14.0, *) else { return }
        let navigator = SettingsNavigator(initialPageID: "general")
        navigator.navigate(to: "appearance")
        navigator.navigate(to: "editor")
        navigator.goBack()

        navigator.navigate(to: "updates")

        #expect(navigator.visitedPageIDs == ["general", "appearance", "updates"])
        #expect(navigator.currentHistoryIndex == 2)
        #expect(!navigator.canGoForward)
    }

    @Test("an internal nil selection update is ignored so the sidebar keeps its selection")
    func nilAssignmentIsIgnored() {
        guard #available(macOS 14.0, *) else { return }
        let navigator = SettingsNavigator(initialPageID: "general")

        navigator.currentPageID = nil

        #expect(navigator.currentPageID == "general")
        #expect(navigator.visitedPageIDs == ["general"])
    }

    @Test("clearing keeps only the page on screen")
    func clearingKeepsTheCurrentPage() {
        guard #available(macOS 14.0, *) else { return }
        let navigator = SettingsNavigator(initialPageID: "general")
        navigator.navigate(to: "appearance")
        navigator.navigate(to: "editor")

        navigator.clearHistory()

        #expect(navigator.visitedPageIDs == ["editor"])
        #expect(navigator.currentPageID == "editor")
        #expect(!navigator.canGoBack)
        #expect(!navigator.canGoForward)
    }

    @Test("pruning keeps the position when the page on screen survives")
    func pruningKeepsTheSurvivingPosition() {
        guard #available(macOS 14.0, *) else { return }
        let navigator = SettingsNavigator(initialPageID: "general")
        navigator.navigate(to: "workspace-a")
        navigator.navigate(to: "editor")
        navigator.goBack()  // on "workspace-a"

        navigator.pruneHistory(keeping: ["general", "workspace-a", "editor"])

        #expect(navigator.visitedPageIDs == ["general", "workspace-a", "editor"])
        #expect(navigator.currentPageID == "workspace-a")
    }

    @Test("pruning a vanished current page falls back to the nearest one behind it")
    func pruningFallsBackward() {
        guard #available(macOS 14.0, *) else { return }
        let navigator = SettingsNavigator(initialPageID: "general")
        navigator.navigate(to: "workspace-a")
        navigator.navigate(to: "editor")
        navigator.goBack()  // on "workspace-a"

        navigator.pruneHistory(keeping: ["general", "editor"])

        #expect(navigator.visitedPageIDs == ["general", "editor"])
        #expect(navigator.currentPageID == "general")
        #expect(navigator.canGoForward)
    }

    @Test("pruning falls forward when nothing behind survives")
    func pruningFallsForward() {
        guard #available(macOS 14.0, *) else { return }
        let navigator = SettingsNavigator(initialPageID: "workspace-a")
        navigator.navigate(to: "workspace-b")
        navigator.navigate(to: "editor")
        navigator.goBack()
        navigator.goBack()  // on "workspace-a"

        navigator.pruneHistory(keeping: ["editor"])

        #expect(navigator.visitedPageIDs == ["editor"])
        #expect(navigator.currentPageID == "editor")
    }

    @Test("pruning collapses the repeats it creates")
    func pruningCollapsesRepeats() {
        guard #available(macOS 14.0, *) else { return }
        let navigator = SettingsNavigator(initialPageID: "general")
        navigator.navigate(to: "workspace-a")
        navigator.navigate(to: "general")

        navigator.pruneHistory(keeping: ["general"])

        // "general, workspace-a, general" minus the workspace would read
        // "general, general" — two entries that navigate nowhere.
        #expect(navigator.visitedPageIDs == ["general"])
        #expect(navigator.currentPageID == "general")
        #expect(!navigator.canGoBack)
        #expect(!navigator.canGoForward)
    }

    @Test("pruning everything away empties the history")
    func pruningEverything() {
        guard #available(macOS 14.0, *) else { return }
        let navigator = SettingsNavigator(initialPageID: "workspace-a")
        navigator.navigate(to: "workspace-b")

        navigator.pruneHistory(keeping: [])

        #expect(navigator.visitedPageIDs.isEmpty)
        #expect(navigator.currentHistoryIndex == -1)
        #expect(navigator.currentPageID == nil)
    }

    @Test("the history stops growing at its cap, keeping the newest entries")
    func historyIsCapped() {
        guard #available(macOS 14.0, *) else { return }
        let navigator = SettingsNavigator(initialPageID: "page-0")
        let visitCount = SettingsNavigator.maximumHistoryLength + 20
        for pageNumber in 1 ..< visitCount {
            navigator.navigate(to: "page-\(pageNumber)")
        }

        #expect(navigator.visitedPageIDs.count == SettingsNavigator.maximumHistoryLength)
        #expect(navigator.currentPageID == "page-\(visitCount - 1)")
        #expect(navigator.currentHistoryIndex == SettingsNavigator.maximumHistoryLength - 1)
        #expect(navigator.visitedPageIDs.first == "page-\(visitCount - SettingsNavigator.maximumHistoryLength)")
    }
}

#endif
