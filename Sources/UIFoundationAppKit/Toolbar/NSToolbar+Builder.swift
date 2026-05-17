#if canImport(AppKit) && !targetEnvironment(macCatalyst)

import AppKit
import AssociatedObject
import UIFoundationToolbox

// MARK: - Direct extensions (init, nested types, associated storage)

extension NSToolbar {

    /// Creates a toolbar configured with the specified items.
    ///
    /// - Parameters:
    ///   - identifier: A string identifying the toolbar (used for autosaving). Pass
    ///     `nil` for an automatically generated identifier.
    ///   - allowsUserCustomization: Whether the user can modify the contents.
    ///   - items: The toolbar items.
    public convenience init(_ identifier: NSToolbar.Identifier? = nil, allowsUserCustomization: Bool = true, items: [ToolbarItem]) {
        self.init(identifier: identifier ?? NSToolbar.box.makeAutomaticIdentifier(for: "Toolbar"))
        _installManagedItems(items, allowsUserCustomization: allowsUserCustomization)
    }

    /// Creates a toolbar configured with the items produced by the builder.
    public convenience init(_ identifier: NSToolbar.Identifier? = nil, allowsUserCustomization: Bool = true, @NSToolbar.Builder _ items: () -> [ToolbarItem]) {
        self.init(identifier, allowsUserCustomization: allowsUserCustomization, items: items())
    }

    fileprivate func _installManagedItems(_ items: [ToolbarItem], allowsUserCustomization: Bool) {
        let manager = ManagedDelegate(items: items)
        managedDelegate = manager
        delegate = manager
        self.allowsUserCustomization = allowsUserCustomization
        autosavesConfiguration = allowsUserCustomization
        if #available(macOS 13.0, *) {
            centeredItemIdentifiers = Set(items.filter(\.isCentered).map(\.identifier))
        }
    }

    // MARK: - Style

    /// The appearance and location of a toolbar in relation to the attached window's title bar.
    public enum Style: Int, Hashable, Codable {
        /// The system determines the toolbar's appearance and location.
        case automatic
        /// The toolbar appears below the window title.
        case expanded
        /// The toolbar appears below the window title with items centered.
        case preference
        /// The toolbar appears next to the window title.
        case unified
        /// The toolbar appears next to the window title with reduced margins.
        case unifiedCompact
        /// The style specified by the attached window's `toolbarStyle`.
        case window = -100

        @available(macOS 11.0, *)
        var nsStyle: NSWindow.ToolbarStyle? {
            NSWindow.ToolbarStyle(rawValue: rawValue)
        }
    }

    // MARK: - Result builder

    /// A result builder that produces an array of ``ToolbarItem`` values.
    @resultBuilder
    public enum Builder {
        public static func buildBlock(_ blocks: [ToolbarItem]...) -> [ToolbarItem] {
            blocks.flatMap { $0 }
        }

        public static func buildOptional(_ items: [ToolbarItem]?) -> [ToolbarItem] {
            items ?? []
        }

        public static func buildEither(first: [ToolbarItem]) -> [ToolbarItem] {
            first
        }

        public static func buildEither(second: [ToolbarItem]) -> [ToolbarItem] {
            second
        }

        public static func buildArray(_ components: [[ToolbarItem]]) -> [ToolbarItem] {
            components.flatMap { $0 }
        }

        public static func buildLimitedAvailability(_ component: [ToolbarItem]) -> [ToolbarItem] {
            component
        }

        public static func buildExpression(_ expression: ToolbarItem?) -> [ToolbarItem] {
            expression.map { [$0] } ?? []
        }

        public static func buildExpression(_ expression: [ToolbarItem]?) -> [ToolbarItem] {
            expression ?? []
        }
    }

    // MARK: - Delegate proxy

    /// Internal delegate that maintains the managed item list and the attached window.
    final class ManagedDelegate: NSObject, NSToolbarDelegate {
        var items: [ToolbarItem]
        weak var attachedWindow: NSWindow?
        var style: NSToolbar.Style = .window

        init(items: [ToolbarItem]) {
            self.items = items
        }

        func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
            items.filter(\.isDefault).identifiers
        }

        func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
            items.identifiers
        }

        func toolbarSelectableItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
            items.filter(\.isSelectable).identifiers
        }

        func toolbarImmovableItemIdentifiers(_ toolbar: NSToolbar) -> Set<NSToolbarItem.Identifier> {
            Set(items.filter(\.isImmovable).identifiers)
        }

        func toolbar(_ toolbar: NSToolbar, itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier, willBeInsertedIntoToolbar flag: Bool) -> NSToolbarItem? {
            items[id: itemIdentifier]?.item
        }
    }

    // MARK: - Associated storage

    @AssociatedObject(.retain(.nonatomic))
    var managedDelegate: ManagedDelegate?
}

// MARK: - Identifier counter storage (private, file-scoped)

private enum ToolbarIdentifierStore {
    static let lock = NSLock()
    nonisolated(unsafe) static var counters: [String: Int] = [:]
}

// MARK: - Instance API via .box

extension FrameworkToolbox where Base: NSToolbar {

    /// The toolbar items configured via the builder-style initializer.
    public var managedItems: [ToolbarItem] {
        base.managedDelegate?.items ?? []
    }

    /// `true` if this toolbar was configured via the builder API.
    public var isManaged: Bool {
        base.managedDelegate != nil
    }

    /// The currently selected managed item.
    public var managedSelectedItem: ToolbarItem? {
        get {
            guard let identifier = base.selectedItemIdentifier else { return nil }
            return managedItems.first(where: { $0.identifier == identifier })
        }
        nonmutating set {
            if let newValue = newValue, newValue.isSelectable, managedItems.contains(where: { $0 === newValue }) {
                base.selectedItemIdentifier = newValue.identifier
            } else {
                base.selectedItemIdentifier = nil
            }
        }
    }

    /// The managed items currently in the toolbar (excluding the overflow menu).
    public var managedDisplayingItems: [ToolbarItem] {
        let identifiers = base.items.map(\.itemIdentifier)
        return managedItems.filter { identifiers.contains($0.identifier) }
    }

    /// The managed items currently visible in the toolbar.
    public var managedVisibleItems: [ToolbarItem] {
        guard let visible = base.visibleItems else { return [] }
        return visible.compactMap { native in
            managedItems.first(where: { $0.item == native })
        }
    }

    /// The window currently hosting this toolbar.
    ///
    /// Setting this installs the toolbar on the new window (and removes it from
    /// any previous host). Only takes effect on toolbars created via the builder API.
    public var attachedWindow: NSWindow? {
        get { base.managedDelegate?.attachedWindow }
        nonmutating set {
            guard let manager = base.managedDelegate else { return }
            let previous = manager.attachedWindow
            if previous !== newValue, previous?.toolbar === base {
                previous?.toolbar = nil
            }
            manager.attachedWindow = newValue
            if #available(macOS 11.0, *), let window = newValue, let style = manager.style.nsStyle {
                window.toolbarStyle = style
            }
            newValue?.toolbar = base
        }
    }

    /// The style applied when an attached window is set.
    ///
    /// On macOS 11+, assigning this updates the attached window's `toolbarStyle`.
    public var managedStyle: NSToolbar.Style {
        get { base.managedDelegate?.style ?? .window }
        nonmutating set {
            base.managedDelegate?.style = newValue
            guard #available(macOS 11.0, *), let window = attachedWindow, let style = newValue.nsStyle else { return }
            window.toolbarStyle = style
        }
    }
}

// MARK: - Static API via .box

extension FrameworkToolbox where Base: NSToolbar {

    /// Returns an automatically generated identifier string of the form `"<name> <n>"`.
    public static func makeAutomaticIdentifier(for name: String) -> String {
        ToolbarIdentifierStore.lock.lock()
        defer { ToolbarIdentifierStore.lock.unlock() }
        let next = (ToolbarIdentifierStore.counters[name] ?? -1) + 1
        ToolbarIdentifierStore.counters[name] = next
        return "\(name) \(next)"
    }

    /// Returns an automatically generated `NSToolbarItem.Identifier`.
    public static func automaticIdentifier(for name: String) -> NSToolbarItem.Identifier {
        NSToolbarItem.Identifier(makeAutomaticIdentifier(for: name))
    }
}

// MARK: - NSWindow .box convenience

extension FrameworkToolbox where Base: NSWindow {
    /// Returns the window's toolbar if it was configured via the builder API.
    public var managedToolbar: NSToolbar? {
        guard let toolbar = base.toolbar, toolbar.box.isManaged else { return nil }
        return toolbar
    }
}

#endif
