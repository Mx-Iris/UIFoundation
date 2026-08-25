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
    ///
    /// A builder reaches either a whole menu — the form
    /// ``MainMenu/standard(applicationName:customizing:)`` and
    /// ``MainMenu/menu(_:customizing:)`` hand out — or a single menu item plus
    /// its submenu subtree, which is what the per-menu factories
    /// (``MainMenu/file(title:customizing:)``, ``MainMenu/Edit/find(customizing:)``, …)
    /// hand out. In the item-rooted form the root item is addressable *itself*,
    /// so its title, key equivalent, and image can be changed — the only way to
    /// retitle a group whose factory takes no `title` parameter. Nothing in the
    /// builder's reach holds that root item, though, so the verbs needing a
    /// containing menu — ``insertItems(_:before:)``, ``insertItems(_:after:)``,
    /// ``replace(_:with:)``, ``remove(_:)`` — do nothing when addressed at it,
    /// the same silence as addressing an identifier that is not there.
    @MainActor
    public final class Builder {
        /// What a builder can reach: a whole menu, or one item and its subtree.
        private enum Root {
            case menu(NSMenu)
            case item(NSMenuItem)
        }

        /// An addressed item together with the menu holding it. `container` is
        /// `nil` only for an item-rooted builder's root item.
        private struct LocatedItem {
            let item: NSMenuItem
            let container: Container?

            struct Container {
                let menu: NSMenu
                let index: Int
            }
        }

        private let root: Root
        private var touchedMenus: [NSMenu] = []

        init(rootMenu: NSMenu) {
            self.root = .menu(rootMenu)
        }

        init(rootItem: NSMenuItem) {
            self.root = .item(rootItem)
        }

        // MARK: Querying

        /// The identified item, for direct property mutation.
        public func item(for identifier: ItemIdentifier) -> NSMenuItem? {
            locate(identifier)?.item
        }

        // MARK: Inserting

        /// Inserts items immediately before the identified item.
        public func insertItems(_ items: [NSMenuItem], before identifier: ItemIdentifier) {
            guard let container = locate(identifier)?.container else { return }
            insert(items, into: container.menu, at: container.index)
        }

        /// Inserts items immediately after the identified item.
        public func insertItems(_ items: [NSMenuItem], after identifier: ItemIdentifier) {
            guard let container = locate(identifier)?.container else { return }
            insert(items, into: container.menu, at: container.index + 1)
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
            guard let container = locate(identifier)?.container else { return }
            container.menu.removeItem(at: container.index)
            insert(items, into: container.menu, at: container.index)
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
            guard let container = locate(identifier)?.container else { return }
            container.menu.removeItem(at: container.index)
            markTouched(container.menu)
        }

        // MARK: Internals

        private func locate(_ identifier: ItemIdentifier) -> LocatedItem? {
            let userInterfaceIdentifier = identifier.userInterfaceItemIdentifier
            switch root {
            case .menu(let rootMenu):
                return locate(userInterfaceIdentifier, in: rootMenu)
            case .item(let rootItem):
                if rootItem.identifier == userInterfaceIdentifier {
                    return LocatedItem(item: rootItem, container: nil)
                }
                guard let submenu = rootItem.submenu else { return nil }
                return locate(userInterfaceIdentifier, in: submenu)
            }
        }

        private func locate(
            _ identifier: NSUserInterfaceItemIdentifier,
            in menu: NSMenu
        ) -> LocatedItem? {
            for (index, menuItem) in menu.items.enumerated() {
                if menuItem.identifier == identifier {
                    return LocatedItem(item: menuItem, container: .init(menu: menu, index: index))
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
