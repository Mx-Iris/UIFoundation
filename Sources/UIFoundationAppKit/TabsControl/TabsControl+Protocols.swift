//
//  TabsControl+Protocols.swift
//  UIFoundation
//
//  Ported into UIFoundation from KPCTabsControl
//  (https://github.com/onekiloparsec/KPCTabsControl) by Cédric Foellmi
//  and Christian Tietze.
//
//  MIT License — Copyright (c) 2014-2016 Cédric Foellmi
//

#if TabsControl && os(macOS)

import AppKit

extension TabsControl {
    /// Provides all the information the control needs to build its tabs.
    @objc public protocol DataSource: NSObjectProtocol {
        /// Returns the number of tabs to display.
        func tabsControlNumberOfTabs(_ control: TabsControl) -> Int

        /// Returns the item backing the tab at the given index (akin to a cell's `representedObject`).
        func tabsControl(_ control: TabsControl, itemAtIndex index: Int) -> Any

        /// Returns the title for the tab of the given item.
        func tabsControl(_ control: TabsControl, titleForItem item: Any) -> String

        /// If any, returns a menu for the tab, placed to its right side. Configure its targets and
        /// actions before returning it.
        @objc optional func tabsControl(_ control: TabsControl, menuForItem item: Any) -> NSMenu?

        /// If any, returns an icon for the tab, placed to its left side.
        @objc optional func tabsControl(_ control: TabsControl, iconForItem item: Any) -> NSImage?

        @objc optional func tabsControl(_ control: TabsControl, closeIconForItem item: Any) -> NSImage?

        @objc optional func tabsControl(_ control: TabsControl, closePositionForItem item: Any) -> ClosePosition

        /// If the tab is too narrow to draw the title, an alternative icon may be returned to replace it.
        /// The switch-over threshold is computed individually for each title.
        @objc optional func tabsControl(_ control: TabsControl, titleAlternativeIconForItem item: Any) -> NSImage?
    }

    /// Provides additional customization points and precise behavior.
    @objc public protocol Delegate: NSControlTextEditingDelegate {
        /// Returns whether the tab can be selected.
        @objc optional func tabsControl(_ control: TabsControl, canSelectItem item: Any) -> Bool

        /// Informs the delegate that the selected tab changed.
        /// See also ``TabsControl/selectionDidChangeNotification``.
        @objc optional func tabsControlDidChangeSelection(_ control: TabsControl, item: Any?)

        /// Returns `true` if the tab is allowed to be reordered by dragging.
        @objc optional func tabsControl(_ control: TabsControl, canReorderItem item: Any) -> Bool

        /// Informs the delegate that the tabs have been reordered. It is the delegate's responsibility
        /// to store the new order; otherwise the tabs recover their original order.
        @objc optional func tabsControl(_ control: TabsControl, didReorderItems items: [Any])

        /// Returns `true` if editing the tab title is allowed. Titles are not editable by default.
        @objc optional func tabsControl(_ control: TabsControl, canEditTitleOfItem item: Any) -> Bool

        /// Informs the delegate that the tab has been renamed to the given title. It is the delegate's
        /// responsibility to store the new title.
        @objc optional func tabsControl(_ control: TabsControl, setTitle newTitle: String, forItem item: Any)

        @objc optional func tabsControl(_ control: TabsControl, canCloseItem item: Any) -> Bool

        /// Informs the delegate that the tab has been closed. It is the delegate's responsibility to
        /// drop it from its own model.
        ///
        /// A delegate that keeps the selection in that model — so that commands like ⌘W act on it
        /// rather than on whatever the bar happens to highlight — may call
        /// ``TabsControl/selectItemAtIndex(_:)`` from here to say which tab is active now. Doing so
        /// takes the selection over: the control skips the neighbour it would otherwise have moved to
        /// on its own. A delegate that stays silent gets the default, which is the tab to the left of
        /// the one that closed.
        @objc optional func tabsControl(_ control: TabsControl, didCloseItem item: Any)
    }
}

#endif
