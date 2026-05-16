//
//  QuickActionBar+Delegate.swift
//  UIFoundation
//
//  Ported into UIFoundation from DSFQuickActionBar by Darren Ford
//  (https://github.com/dagronf/DSFQuickActionBar).
//
//  MIT License — Copyright (c) 2022 Darren Ford
//

#if QuickActionBar

import AppKit

/// Delegate / content source for a ``QuickActionBar`` instance.
public protocol QuickActionBarContentSource: NSObjectProtocol {
    /// Called to retrieve the items that match the search term.
    ///
    /// The task object can be stored and completed later, for example when the item search is asynchronous.
    /// If your search matching is simple, complete the task synchronously by calling `task.complete(with:)`.
    func quickActionBar(_ quickActionBar: QuickActionBar, itemsForSearchTermTask task: QuickActionBar.SearchTask)

    /// Return a configured view to display for the specified item and search term.
    func quickActionBar(_ quickActionBar: QuickActionBar, viewForItem item: AnyHashable, searchTerm: String) -> NSView?

    /// Called when an item is about to be selected (e.g. by keyboard navigation or clicking).
    /// Return `false` to make the row unselectable (for example, separator rows).
    func quickActionBar(_ quickActionBar: QuickActionBar, canSelectItem item: AnyHashable) -> Bool

    /// Called when an item is selected.
    func quickActionBar(_ quickActionBar: QuickActionBar, didSelectItem item: AnyHashable)

    /// Called when the specified item is activated (double clicked, return key pressed while selected, etc).
    func quickActionBar(_ quickActionBar: QuickActionBar, didActivateItem item: AnyHashable)

    /// Called when the quick action bar was dismissed without selecting an item.
    func quickActionBarDidCancel(_ quickActionBar: QuickActionBar)
}

public extension QuickActionBarContentSource {
    /// Default implementation. Rows are _always_ selectable.
    func quickActionBar(_ quickActionBar: QuickActionBar, canSelectItem item: AnyHashable) -> Bool {
        return true
    }

    /// Default implementation.
    func quickActionBar(_ quickActionBar: QuickActionBar, didSelectItem item: AnyHashable) {}

    /// Default implementation.
    func quickActionBarDidCancel(_ quickActionBar: QuickActionBar) {}
}

#endif
