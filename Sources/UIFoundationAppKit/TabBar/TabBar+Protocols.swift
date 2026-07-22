//
//  TabBar+Protocols.swift
//  UIFoundation
//
//  Ported into UIFoundation from KPCTabsControl
//  (https://github.com/onekiloparsec/KPCTabsControl) by Cédric Foellmi
//  and Christian Tietze.
//
//  MIT License — Copyright (c) 2014-2016 Cédric Foellmi
//

#if TabBar && os(macOS)

import AppKit

extension TabBar {
    /// Provides all the information the control needs to build its tabs.
    @objc public protocol DataSource: NSObjectProtocol {
        /// Returns the number of tabs to display.
        func tabBarNumberOfTabs(_ tabBar: TabBar) -> Int

        /// Returns the item backing the tab at the given index (akin to a cell's `representedObject`).
        func tabBar(_ tabBar: TabBar, itemAtIndex index: Int) -> Any

        /// Returns the title for the tab of the given item.
        func tabBar(_ tabBar: TabBar, titleForItem item: Any) -> String

        /// If any, returns a menu for the tab, placed to its right side. Configure its targets and
        /// actions before returning it.
        @objc optional func tabBar(_ tabBar: TabBar, menuForItem item: Any) -> NSMenu?

        /// If any, returns an icon for the tab, placed to its left side.
        @objc optional func tabBar(_ tabBar: TabBar, iconForItem item: Any) -> NSImage?

        @objc optional func tabBar(_ tabBar: TabBar, closeIconForItem item: Any) -> NSImage?

        @objc optional func tabBar(_ tabBar: TabBar, closePositionForItem item: Any) -> ClosePosition

        /// If the tab is too narrow to draw the title, an alternative icon may be returned to replace it.
        /// The switch-over threshold is computed individually for each title.
        @objc optional func tabBar(_ tabBar: TabBar, titleAlternativeIconForItem item: Any) -> NSImage?
    }

    /// Provides additional customization points and precise behavior.
    @objc public protocol Delegate: NSControlTextEditingDelegate {
        /// Returns whether the tab can be selected.
        @objc optional func tabBar(_ tabBar: TabBar, canSelectItem item: Any) -> Bool

        /// Informs the delegate that the selected tab changed.
        /// See also ``TabBar/selectionDidChangeNotification``.
        @objc optional func tabBarDidChangeSelection(_ tabBar: TabBar, item: Any?)

        /// Returns `true` if the tab is allowed to be reordered by dragging.
        @objc optional func tabBar(_ tabBar: TabBar, canReorderItem item: Any) -> Bool

        /// Informs the delegate that the tabs have been reordered. It is the delegate's responsibility
        /// to store the new order; otherwise the tabs recover their original order.
        @objc optional func tabBar(_ tabBar: TabBar, didReorderItems items: [Any])

        /// Returns `true` if editing the tab title is allowed. Titles are not editable by default.
        @objc optional func tabBar(_ tabBar: TabBar, canEditTitleOfItem item: Any) -> Bool

        /// Informs the delegate that the tab has been renamed to the given title. It is the delegate's
        /// responsibility to store the new title.
        @objc optional func tabBar(_ tabBar: TabBar, setTitle newTitle: String, forItem item: Any)

        @objc optional func tabBar(_ tabBar: TabBar, canCloseItem item: Any) -> Bool

        /// Informs the delegate that the tab has been closed. It is the delegate's responsibility to
        /// drop it from its own model.
        ///
        /// A delegate that keeps the selection in that model — so that commands like ⌘W act on it
        /// rather than on whatever the bar happens to highlight — may call
        /// ``TabBar/selectItemAtIndex(_:)`` from here to say which tab is active now. Doing so
        /// takes the selection over: the control skips the neighbour it would otherwise have moved to
        /// on its own. A delegate that stays silent gets the default, which is the tab to the left of
        /// the one that closed.
        @objc optional func tabBar(_ tabBar: TabBar, didCloseItem item: Any)
    }
}

#endif
