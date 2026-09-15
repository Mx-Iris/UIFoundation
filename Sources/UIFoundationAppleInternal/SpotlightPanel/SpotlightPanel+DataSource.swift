//
//  Replicated from macOS 26's Spotlight.app (26.6.2).
//  Decision record: Documentations/Evolutions/0021-spotlight-panel-replica.md
//

#if SpotlightPanel && os(macOS)

import AppKit

/// Supplies the panel's results.
///
/// The panel never knows what an item is — it holds `AnyHashable` identifiers and asks for a
/// view per row, the same shape a table view uses. Searching itself is entirely the host's:
/// this replica reproduces Spotlight's shell, not its index.
@MainActor
public protocol SpotlightPanelDataSource: AnyObject {
    /// Called whenever the search term settles.
    ///
    /// Complete the task synchronously for a cheap search, or hold on to it and complete it
    /// later for an asynchronous one. A task the panel has moved past reports `isCancelled`.
    func spotlightPanel(_ spotlightPanel: SpotlightPanel, itemsForSearchTask searchTask: SpotlightPanel.SearchTask)

    /// The row view for an item. Returning `nil` leaves the row blank.
    func spotlightPanel(
        _ spotlightPanel: SpotlightPanel,
        viewForItem item: AnyHashable,
        searchTerm: String
    ) -> NSView?

    /// How tall the panel should be for this response.
    ///
    /// The default grows with the content between the panel's expanded floor and a ceiling set
    /// by the screen, which is what Spotlight does for an ordinary result list.
    func spotlightPanel(
        _ spotlightPanel: SpotlightPanel,
        platterBehaviorForItems items: [AnyHashable],
        searchTerm: String
    ) -> SpotlightPanel.PlatterBehavior
}

public extension SpotlightPanelDataSource {
    func spotlightPanel(
        _ spotlightPanel: SpotlightPanel,
        platterBehaviorForItems items: [AnyHashable],
        searchTerm: String
    ) -> SpotlightPanel.PlatterBehavior {
        spotlightPanel.defaultPlatterBehavior(forItemCount: items.count)
    }
}

/// Receives the panel's selection, activation and keyboard events.
///
/// Every method has a default implementation, so a host adopts only the ones it needs.
@MainActor
public protocol SpotlightPanelDelegate: AnyObject {
    /// Return `false` to make a row unselectable — section headers, separators.
    func spotlightPanel(_ spotlightPanel: SpotlightPanel, canSelectItem item: AnyHashable) -> Bool

    /// The selection moved onto `item`.
    func spotlightPanel(_ spotlightPanel: SpotlightPanel, didSelectItem item: AnyHashable)

    /// Return or a click activated `item`. The panel dismisses itself afterwards unless this
    /// returns `false`.
    @discardableResult
    func spotlightPanel(_ spotlightPanel: SpotlightPanel, didActivateItem item: AnyHashable) -> Bool

    /// Space was pressed on `item`.
    ///
    /// Spotlight opens a Quick Look preview here. This replica has no preview pane — see the
    /// decision record's non-goals — so the event is handed over instead.
    func spotlightPanel(_ spotlightPanel: SpotlightPanel, didRequestQuickLookForItem item: AnyHashable)

    /// ⌘C was pressed while `item` was selected and the search field had no selected text.
    func spotlightPanel(_ spotlightPanel: SpotlightPanel, didRequestCopyForItem item: AnyHashable)

    /// Tab / Shift-Tab was pressed.
    ///
    /// Spotlight moves between top-level filters here. With no filter bar in this phase the
    /// event is forwarded; returning `true` marks it handled.
    func spotlightPanel(_ spotlightPanel: SpotlightPanel, didPressTabForward isForward: Bool) -> Bool

    /// → was pressed on `item`, which in Spotlight drills into it.
    func spotlightPanel(_ spotlightPanel: SpotlightPanel, didRequestDrillDownForItem item: AnyHashable) -> Bool

    /// The search term changed, after debouncing.
    func spotlightPanel(_ spotlightPanel: SpotlightPanel, searchTermDidChange searchTerm: String)

    /// The panel closed without anything being activated.
    func spotlightPanelDidCancel(_ spotlightPanel: SpotlightPanel)

    /// The panel finished dismissing, for any reason.
    func spotlightPanelDidDismiss(_ spotlightPanel: SpotlightPanel)
}

public extension SpotlightPanelDelegate {
    func spotlightPanel(_ spotlightPanel: SpotlightPanel, canSelectItem item: AnyHashable) -> Bool { true }
    func spotlightPanel(_ spotlightPanel: SpotlightPanel, didSelectItem item: AnyHashable) {}

    @discardableResult
    func spotlightPanel(_ spotlightPanel: SpotlightPanel, didActivateItem item: AnyHashable) -> Bool { true }

    func spotlightPanel(_ spotlightPanel: SpotlightPanel, didRequestQuickLookForItem item: AnyHashable) {}
    func spotlightPanel(_ spotlightPanel: SpotlightPanel, didRequestCopyForItem item: AnyHashable) {}
    func spotlightPanel(_ spotlightPanel: SpotlightPanel, didPressTabForward isForward: Bool) -> Bool { false }
    func spotlightPanel(_ spotlightPanel: SpotlightPanel, didRequestDrillDownForItem item: AnyHashable) -> Bool { false }
    func spotlightPanel(_ spotlightPanel: SpotlightPanel, searchTermDidChange searchTerm: String) {}
    func spotlightPanelDidCancel(_ spotlightPanel: SpotlightPanel) {}
    func spotlightPanelDidDismiss(_ spotlightPanel: SpotlightPanel) {}
}

#endif
