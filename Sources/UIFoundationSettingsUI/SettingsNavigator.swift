#if Settings && os(macOS)

import Foundation
import Observation

/// Which settings page is on screen, and how the user got there.
///
/// Two jobs in one object: it is the single source of truth for the selected
/// page, and it keeps the visit history behind the back / forward buttons.
/// Hosts hold one to drive the settings window from code:
///
/// ```swift
/// let navigator = SettingsNavigator(initialPageID: "general")
/// let settingsWindowController = SettingsWindowController(navigator: navigator) {
///     SettingsPage("General", id: "general", symbol: "gearshape") {
///         GeneralSettingsView()
///     }
///     SettingsPage("Updates", id: "updates", symbol: "arrow.down.circle") {
///         UpdatesSettingsView()
///     }
/// }
///
/// navigator.navigate(to: "updates")
/// settingsWindowController.showWindow(nil)
///
/// navigator.navigate(to: "general")
/// navigator.goBack()
/// ```
///
/// ``SettingsRootView`` and ``SettingsWindowController`` create one for
/// themselves when none is passed in, so this works without any extra wiring.
///
/// The sidebar's selection is *derived* from this object rather than kept
/// alongside it. That is deliberate: the usual "selection plus an
/// `isNavigatingThroughHistory` flag" arrangement depends on when SwiftUI
/// writes the selection back, and there is no guarantee about that — clear the
/// flag too early and a visit goes unrecorded, too late and the user's next
/// click is mistaken for a programmatic one. Here both paths feed the same
/// history operation, so there is nothing to keep in sync.
///
/// ### Why the derived values are stored rather than computed
///
/// ``currentPageID``, ``canGoBack`` and ``canGoForward`` are all trivially
/// derivable from ``visitedPageIDs`` and ``currentHistoryIndex``, and were
/// computed properties at first. Observation tracks reads at the level of the
/// *stored* property, and a computed property establishes its dependencies
/// transitively — so a view reading `canGoBack` was really depending on the
/// whole history array, and every history change invalidated it even when the
/// answer had not moved. They are cached in ``refreshDerivedState()`` instead,
/// so a view depends only on the one value it read. Being `Equatable`, they also
/// let the `@Observable` setter skip the notification entirely when a refresh
/// recomputes the same answer.
@available(macOS 14.0, *)
@MainActor
@Observable
public final class SettingsNavigator {

    /// The cap on how many entries the history keeps.
    ///
    /// Hosts are told to keep one settings window controller for the lifetime
    /// of the app, so an uncapped history would grow with every click for as
    /// long as the app runs. Dropping the oldest entries past this many costs
    /// nothing a user would notice — nobody goes back a hundred pages.
    public static let maximumHistoryLength = 100

    /// - Parameter initialPageID: The page to start on, recorded as the first
    ///   visit. Pass `nil` to let ``SettingsRootView`` seed it with its first
    ///   page.
    public init(initialPageID: SettingsPage.ID? = nil) {
        if let initialPageID {
            visitedPageIDs = [initialPageID]
            currentHistoryIndex = 0
            storedCurrentPageID = initialPageID
        } else {
            visitedPageIDs = []
            currentHistoryIndex = -1
            storedCurrentPageID = nil
        }
        canGoBack = false
        canGoForward = false
    }

    /// Navigates to a page and records the visit.
    ///
    /// Anything ahead in the history is dropped the way a browser does when
    /// you go back and then follow a new link. Navigating to the page already
    /// on screen changes nothing.
    public func navigate(to pageID: SettingsPage.ID) {
        record(pageID)
    }

    /// The page on screen. Use ``navigate(to:)`` to change it.
    ///
    /// The setter remains internal so ``SettingsRootView`` can give SwiftUI's
    /// `List` a key-path selection binding. `List` writes `nil` when a click
    /// lands on empty space; ignoring that keeps the detail pane selected.
    public internal(set) var currentPageID: SettingsPage.ID? {
        get { storedCurrentPageID }
        set {
            guard let newValue else { return }
            navigate(to: newValue)
        }
    }

    /// Backs ``currentPageID``. Private but observed: reading through the
    /// computed property establishes a dependency on this one value, not on
    /// the history array it was derived from.
    private var storedCurrentPageID: SettingsPage.ID?

    /// Every page visited, oldest first.
    ///
    /// No two neighbouring entries are ever equal — that invariant is what
    /// makes back and forward always land somewhere different.
    ///
    /// - Note: Reading this from a SwiftUI view means depending on the whole
    ///   array, so the view re-runs on every visit. Views that only need to
    ///   know where they are should read ``currentPageID``.
    public private(set) var visitedPageIDs: [SettingsPage.ID]

    /// Where in ``visitedPageIDs`` the user currently stands; `-1` when the
    /// history is empty.
    public private(set) var currentHistoryIndex: Int

    public private(set) var canGoBack: Bool

    public private(set) var canGoForward: Bool

    /// - Returns: The page moved to, or `nil` at the oldest entry — in which
    ///   case nothing changed.
    @discardableResult
    public func goBack() -> SettingsPage.ID? {
        guard canGoBack else { return nil }
        currentHistoryIndex -= 1
        refreshDerivedState()
        return storedCurrentPageID
    }

    /// - Returns: The page moved to, or `nil` at the newest entry — in which
    ///   case nothing changed.
    @discardableResult
    public func goForward() -> SettingsPage.ID? {
        guard canGoForward else { return nil }
        currentHistoryIndex += 1
        refreshDerivedState()
        return storedCurrentPageID
    }

    /// Forgets every visit but the current one.
    public func clearHistory() {
        if let storedCurrentPageID {
            visitedPageIDs = [storedCurrentPageID]
            currentHistoryIndex = 0
        } else {
            visitedPageIDs = []
            currentHistoryIndex = -1
        }
        refreshDerivedState()
    }

    /// Drops history entries for pages that no longer exist.
    ///
    /// The page list is allowed to change — ``SettingsPageBuilder`` supports
    /// `if` and `for`, so a page can come and go with the settings themselves.
    /// Once it goes, history entries naming it would send the user nowhere.
    /// ``SettingsRootView`` calls this whenever its page list changes.
    ///
    /// The current position survives if its page does. Otherwise it falls back
    /// to the nearest surviving entry behind it, then to the oldest one.
    public func pruneHistory(keeping availablePageIDs: Set<SettingsPage.ID>) {
        guard !visitedPageIDs.isEmpty else { return }

        var survivingPageIDs: [SettingsPage.ID] = []
        var survivingIndex = -1

        for (index, pageID) in visitedPageIDs.enumerated() {
            guard availablePageIDs.contains(pageID) else { continue }
            // Removing an entry can leave its neighbours equal (A, B, A minus B
            // is A, A); collapsing them here keeps the no-repeat invariant.
            if survivingPageIDs.last != pageID {
                survivingPageIDs.append(pageID)
            }
            if index <= currentHistoryIndex {
                survivingIndex = survivingPageIDs.count - 1
            }
        }

        visitedPageIDs = survivingPageIDs
        if survivingPageIDs.isEmpty {
            currentHistoryIndex = -1
        } else {
            currentHistoryIndex = survivingIndex >= 0 ? survivingIndex : 0
        }
        refreshDerivedState()
    }

    private func record(_ pageID: SettingsPage.ID) {
        guard storedCurrentPageID != pageID else { return }

        if currentHistoryIndex < visitedPageIDs.count - 1 {
            visitedPageIDs.removeSubrange((currentHistoryIndex + 1)...)
        }
        visitedPageIDs.append(pageID)
        currentHistoryIndex = visitedPageIDs.count - 1

        let overflow = visitedPageIDs.count - Self.maximumHistoryLength
        if overflow > 0 {
            visitedPageIDs.removeFirst(overflow)
            currentHistoryIndex -= overflow
        }
        refreshDerivedState()
    }

    /// Recomputes everything derived from the history. Assignments that land on
    /// the value already there notify nobody, so calling this after a mutation
    /// that moved nothing is free.
    private func refreshDerivedState() {
        storedCurrentPageID = currentHistoryIndex >= 0 ? visitedPageIDs[currentHistoryIndex] : nil
        canGoBack = currentHistoryIndex > 0
        canGoForward = currentHistoryIndex >= 0 && currentHistoryIndex < visitedPageIDs.count - 1
    }
}

#endif
