#if canImport(AppKit) && !targetEnvironment(macCatalyst)

import AppKit

extension MainMenu {
    /// Amends an assembled main menu by identifier, in the shape of UIKit's
    /// `UIMenuBuilder`: query an item, insert around it, replace it, or remove
    /// it — without rewriting the menu it sits in.
    ///
    /// UIKit's three element kinds (menu group, action, command) collapse to
    /// one in AppKit — everything is an `NSMenuItem` — so its three addressing
    /// schemes collapse to ``MainMenu/ItemIdentifier`` and one set of verbs.
    /// Mutations apply immediately; later queries see the transformed tree.
    /// Addressing an identifier that is not in the menu is a silent no-op
    /// (matching `UIMenuBuilder`), so customization code can run
    /// unconditionally; use ``item(for:)`` to check explicitly.
    ///
    /// Separators are not addressable. Removals can orphan them instead —
    /// UIKit never has this problem because its group model draws separators
    /// implicitly — so after the transformation runs, every menu it touched is
    /// normalized: consecutive separators collapse into one and leading /
    /// trailing separators are dropped. Untouched menus are left exactly as
    /// built.
    @MainActor
    public final class Builder {
        private let rootMenu: NSMenu
        private var touchedMenus: [NSMenu] = []

        init(rootMenu: NSMenu) {
            self.rootMenu = rootMenu
        }

        // MARK: Querying

        /// The identified item, for direct property mutation.
        public func item(for identifier: ItemIdentifier) -> NSMenuItem? {
            locate(identifier)?.item
        }

        // MARK: Inserting

        /// Inserts items immediately before the identified item.
        public func insertItems(_ items: [NSMenuItem], before identifier: ItemIdentifier) {
            guard let located = locate(identifier) else { return }
            insert(items, into: located.menu, at: located.index)
        }

        /// Inserts items immediately after the identified item.
        public func insertItems(_ items: [NSMenuItem], after identifier: ItemIdentifier) {
            guard let located = locate(identifier) else { return }
            insert(items, into: located.menu, at: located.index + 1)
        }

        /// Inserts items at the start of the identified item's submenu.
        public func insertItems(_ items: [NSMenuItem], atStartOf identifier: ItemIdentifier) {
            guard let submenu = locate(identifier)?.item.submenu else { return }
            insert(items, into: submenu, at: 0)
        }

        /// Inserts items at the end of the identified item's submenu.
        public func insertItems(_ items: [NSMenuItem], atEndOf identifier: ItemIdentifier) {
            guard let submenu = locate(identifier)?.item.submenu else { return }
            insert(items, into: submenu, at: submenu.items.count)
        }

        public func insertItems(before identifier: ItemIdentifier, @MenuBuilder _ items: () -> [NSMenuItem]) {
            insertItems(items(), before: identifier)
        }

        public func insertItems(after identifier: ItemIdentifier, @MenuBuilder _ items: () -> [NSMenuItem]) {
            insertItems(items(), after: identifier)
        }

        public func insertItems(atStartOf identifier: ItemIdentifier, @MenuBuilder _ items: () -> [NSMenuItem]) {
            insertItems(items(), atStartOf: identifier)
        }

        public func insertItems(atEndOf identifier: ItemIdentifier, @MenuBuilder _ items: () -> [NSMenuItem]) {
            insertItems(items(), atEndOf: identifier)
        }

        // MARK: Replacing

        /// Replaces the identified item with the given items.
        public func replace(_ identifier: ItemIdentifier, with items: [NSMenuItem]) {
            guard let located = locate(identifier) else { return }
            located.menu.removeItem(at: located.index)
            insert(items, into: located.menu, at: located.index)
        }

        public func replace(_ identifier: ItemIdentifier, @MenuBuilder with items: () -> [NSMenuItem]) {
            replace(identifier, with: items())
        }

        /// Replaces the items of the identified item's submenu with the array
        /// the transform returns; the transform receives the current items,
        /// already detached, so they can be filtered or reordered freely.
        public func replaceItems(of identifier: ItemIdentifier, from transform: ([NSMenuItem]) -> [NSMenuItem]) {
            guard let submenu = locate(identifier)?.item.submenu else { return }
            let currentItems = submenu.items
            submenu.items = []
            submenu.items = transform(currentItems)
            markTouched(submenu)
        }

        // MARK: Removing

        /// Removes the identified item.
        public func remove(_ identifier: ItemIdentifier) {
            guard let located = locate(identifier) else { return }
            located.menu.removeItem(at: located.index)
            markTouched(located.menu)
        }

        // MARK: Internals

        private func locate(_ identifier: ItemIdentifier) -> (menu: NSMenu, item: NSMenuItem, index: Int)? {
            locate(identifier.userInterfaceItemIdentifier, in: rootMenu)
        }

        private func locate(
            _ identifier: NSUserInterfaceItemIdentifier,
            in menu: NSMenu
        ) -> (menu: NSMenu, item: NSMenuItem, index: Int)? {
            for (index, menuItem) in menu.items.enumerated() {
                if menuItem.identifier == identifier {
                    return (menu, menuItem, index)
                }
                if let submenu = menuItem.submenu,
                   let located = locate(identifier, in: submenu) {
                    return located
                }
            }
            return nil
        }

        private func insert(_ items: [NSMenuItem], into menu: NSMenu, at index: Int) {
            for (offset, menuItem) in items.enumerated() {
                menu.insertItem(menuItem, at: index + offset)
            }
            markTouched(menu)
        }

        private func markTouched(_ menu: NSMenu) {
            if !touchedMenus.contains(where: { $0 === menu }) {
                touchedMenus.append(menu)
            }
        }

        func normalizeTouchedMenus() {
            for menu in touchedMenus {
                var normalizedItems: [NSMenuItem] = []
                for menuItem in menu.items {
                    if menuItem.isSeparatorItem,
                       normalizedItems.last?.isSeparatorItem != false {
                        continue
                    }
                    normalizedItems.append(menuItem)
                }
                if normalizedItems.last?.isSeparatorItem == true {
                    normalizedItems.removeLast()
                }
                if normalizedItems.count != menu.items.count {
                    menu.items = []
                    menu.items = normalizedItems
                }
            }
        }
    }
}

#endif
