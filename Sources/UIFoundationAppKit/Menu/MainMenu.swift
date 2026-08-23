#if canImport(AppKit) && !targetEnvironment(macCatalyst)

import AppKit

/// Builds the standard macOS main menu in code — the menu bar Xcode's
/// application template ships as `MainMenu.xib` — with every layer open for
/// customization, so a fully programmatic app can write:
///
/// ```swift
/// @main
/// enum App {
///     static func main() {
///         let app = autoreleasepool {
///             let app = NSApplication.shared
///             app.delegate = AppDelegate.shared
///             app.setActivationPolicy(.regular)
///             app.mainMenu = MainMenu.standard()
///             return app
///         }
///         app.run()
///     }
/// }
/// ```
///
/// Four levels, from coarse to fine:
///
/// ```swift
/// // 1. The complete template-equivalent menu bar:
/// app.mainMenu = MainMenu.standard()
///
/// // 2. Amend single items in place — every standard item is addressable
/// //    by identifier through a UIMenuBuilder-style transformation:
/// app.mainMenu = MainMenu.standard { builder in
///     builder.remove(.File.pageSetup)
///     builder.item(for: .Application.settings)?.action = #selector(AppDelegate.openSettings(_:))
///     builder.insertItems(after: .File.open) {
///         NSMenuItem("Open Workspace…", action: #selector(AppDelegate.openWorkspace(_:)), keyEquivalent: "O")
///     }
/// }
///
/// // 3. Pick, reorder, and mix top-level menus:
/// app.mainMenu = MainMenu.menu {
///     MainMenu.application()
///     MainMenu.file()
///     MainMenu.edit()
///     NSMenuItem("Project") {
///         NSMenuItem("Build", action: #selector(AppDelegate.build(_:)), keyEquivalent: "b")
///     }
///     MainMenu.window()
///     MainMenu.help()
/// }
///
/// // 4. Rewrite one menu's content from standard single items:
/// MainMenu.file {
///     MainMenu.File.new()
///     MainMenu.File.open()
///     NSMenuItem.separator()
///     MainMenu.File.close()
/// }
/// ```
///
/// ``standard(applicationName:)`` and ``menu(_:)`` also perform the wiring
/// `MainMenu.xib` gets from Interface Builder's system-menu markers: the
/// Services, Window, and Help submenus are assigned to `NSApplication`, and the
/// Font submenu to `NSFontManager`. The wiring is identifier-driven, so it
/// survives rewriting a menu's content through the builder forms — and item
/// factories themselves never touch global state, so a menu item that is
/// created but never assembled wires nothing. In the customizing form the
/// transformation runs *before* the wiring, so a removed Window or Help menu
/// leaves no stale assignment behind.
///
/// Item content mirrors the template verbatim (titles, actions, key
/// equivalents, and tags). Titles default to English, like the template's
/// development language; override a title with the chained `.title(_:)`
/// modifier or the factories' parameters. Actions target the first responder
/// (except the Font menu items the template points at `NSFontManager`), and
/// enabling/validation is left entirely to the responder chain.
@MainActor
public enum MainMenu {
    // MARK: - Assembly

    /// The complete template-equivalent main menu, wired and ready for
    /// `NSApp.mainMenu`.
    public static func standard(applicationName: String? = nil) -> NSMenu {
        standard(applicationName: applicationName) { _ in }
    }

    /// The complete template-equivalent main menu with identifier-addressed
    /// amendments applied by `customize` before the special-menu wiring runs.
    public static func standard(applicationName: String? = nil, customizing customize: (Builder) -> Void) -> NSMenu {
        let mainMenu = NSMenu(title: "Main Menu", items: [
            application(applicationName: applicationName),
            file(),
            edit(),
            format(),
            view(),
            window(),
            help(applicationName: applicationName),
        ])
        let builder = Builder(rootMenu: mainMenu)
        customize(builder)
        builder.normalizeTouchedMenus()
        wireSpecialMenus(in: mainMenu)
        return mainMenu
    }

    /// Assembles a main menu from top-level items and wires any special
    /// submenus found in it (see ``ItemIdentifier``) to `NSApplication` /
    /// `NSFontManager`.
    public static func menu(@MenuBuilder _ items: () -> [NSMenuItem]) -> NSMenu {
        let mainMenu = NSMenu(title: "Main Menu", items: items())
        wireSpecialMenus(in: mainMenu)
        return mainMenu
    }

    // MARK: - Item identifiers

    /// Addresses one standard item of the main menu.
    ///
    /// Every item ``standard(applicationName:)`` produces carries an
    /// identifier — the top-level menus, each menu's direct items, and the
    /// nested groups' leaves — so a ``Builder`` transformation can query,
    /// insert around, replace, or remove any of them without rewriting the
    /// menu. The constants mirror the factory namespaces: top-level menus sit
    /// on the identifier itself (`.file`), a menu's content sits in a nested
    /// namespace named after it (`.File.new`), and a group's leaves nest one
    /// level further (`.Edit.Find.next`, `.Format.Font.Kern.tighten`). Hosts
    /// give their own items an identifier (via `NSMenuItem.identifier(_:)`)
    /// to make them addressable too.
    ///
    /// A handful of identifiers double as wiring markers, the code-side
    /// equivalent of the xib's `systemMenu` attribute: `Application.services` →
    /// `NSApplication.servicesMenu`, `Format.font` → `NSFontManager.setFontMenu(_:)`,
    /// ``window`` → `NSApplication.windowsMenu`, ``help`` →
    /// `NSApplication.helpMenu`. `File.openRecent` is tagged but wired to
    /// nothing — AppKit offers no public counterpart to the xib's
    /// `recentDocuments` marker (see the usage guide).
    public struct ItemIdentifier: Hashable, RawRepresentable, Sendable {
        public let rawValue: String

        public init(rawValue: String) {
            self.rawValue = rawValue
        }

        public init(_ rawValue: String) {
            self.rawValue = rawValue
        }

        /// The AppKit identifier written onto the `NSMenuItem`.
        public var userInterfaceItemIdentifier: NSUserInterfaceItemIdentifier {
            NSUserInterfaceItemIdentifier(rawValue)
        }

        static func standard(_ name: String) -> ItemIdentifier {
            ItemIdentifier("UIFoundation.MainMenu.\(name)")
        }

        // Top-level menus.
        public static let application = standard("application")
        public static let file = standard("file")
        public static let edit = standard("edit")
        public static let format = standard("format")
        public static let view = standard("view")
        public static let window = standard("window")
        public static let help = standard("help")
    }

    static func wireSpecialMenus(in menu: NSMenu) {
        let application = NSApplication.shared
        enumerateItems(in: menu) { menuItem in
            guard let submenu = menuItem.submenu, let identifier = menuItem.identifier else { return }
            switch identifier {
            case ItemIdentifier.Application.services.userInterfaceItemIdentifier:
                application.servicesMenu = submenu
            case ItemIdentifier.Format.font.userInterfaceItemIdentifier:
                NSFontManager.shared.setFontMenu(submenu)
            case ItemIdentifier.window.userInterfaceItemIdentifier:
                application.windowsMenu = submenu
            case ItemIdentifier.help.userInterfaceItemIdentifier:
                application.helpMenu = submenu
            default:
                break
            }
        }
    }

    private static func enumerateItems(in menu: NSMenu, _ body: (NSMenuItem) -> Void) {
        for menuItem in menu.items {
            body(menuItem)
            if let submenu = menuItem.submenu {
                enumerateItems(in: submenu, body)
            }
        }
    }

    // MARK: - Application name

    static func resolvedApplicationName(_ overrideName: String?) -> String {
        if let overrideName {
            return overrideName
        }
        let bundle = Bundle.main
        for key in ["CFBundleDisplayName", "CFBundleName"] {
            if let name = (bundle.localizedInfoDictionary?[key] ?? bundle.infoDictionary?[key]) as? String,
               !name.isEmpty {
                return name
            }
        }
        return ProcessInfo.processInfo.processName
    }
}

extension NSMenuItem {
    /// Sets the menu item's identifier from a main-menu item identifier,
    /// making the item addressable by ``MainMenu/Builder``.
    @discardableResult
    public func identifier(_ identifier: MainMenu.ItemIdentifier) -> Self {
        self.identifier = identifier.userInterfaceItemIdentifier
        return self
    }
}

#endif
