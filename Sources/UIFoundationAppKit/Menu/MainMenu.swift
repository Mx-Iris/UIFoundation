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
///         let app = NSApplication.shared
///         app.delegate = AppDelegate.shared
///         app.setActivationPolicy(.regular)
///         app.mainMenu = MainMenu.standard()
///         app.run()
///     }
/// }
/// ```
///
/// Three levels, from coarse to fine:
///
/// ```swift
/// // 1. The complete template-equivalent menu bar:
/// app.mainMenu = MainMenu.standard()
///
/// // 2. Pick, reorder, and mix top-level menus:
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
/// // 3. Rewrite one menu's content from standard single items:
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
/// Font submenu to `NSFontManager`. The wiring is identifier-driven (see
/// ``ItemIdentifier``), so it survives rewriting a menu's content through the
/// builder forms — and item factories themselves never touch global state, so
/// a menu item that is created but never assembled wires nothing.
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
        menu {
            application(applicationName: applicationName)
            file()
            edit()
            format()
            view()
            window()
            help(applicationName: applicationName)
        }
    }

    /// Assembles a main menu from top-level items and wires any special
    /// submenus found in it (see ``ItemIdentifier``) to `NSApplication` /
    /// `NSFontManager`.
    public static func menu(@MenuBuilder _ items: () -> [NSMenuItem]) -> NSMenu {
        let mainMenu = NSMenu(title: "Main Menu", items: items())
        wireSpecialMenus(in: mainMenu)
        return mainMenu
    }

    // MARK: - Special-menu wiring

    /// Identifiers marking the menu items whose submenus play a system role.
    ///
    /// `MainMenu.xib` marks these menus with Interface Builder's `systemMenu`
    /// attribute; in code the assembly step (``menu(_:)`` /
    /// ``standard(applicationName:)``) recognizes them by item identifier
    /// instead and performs the equivalent wiring. A host that hand-builds one
    /// of these menus can attach the matching identifier to have it wired too.
    public enum ItemIdentifier {
        /// The Services submenu, wired to `NSApplication.servicesMenu`.
        public static let services = NSUserInterfaceItemIdentifier("UIFoundation.MainMenu.services")
        /// The File > Open Recent submenu. AppKit offers no public equivalent
        /// of the xib's `recentDocuments` marker, so this one is tagged but
        /// not wired — see the usage guide.
        public static let openRecent = NSUserInterfaceItemIdentifier("UIFoundation.MainMenu.openRecent")
        /// The Format > Font submenu, wired via `NSFontManager.setFontMenu(_:)`.
        public static let font = NSUserInterfaceItemIdentifier("UIFoundation.MainMenu.font")
        /// The Window menu, wired to `NSApplication.windowsMenu`.
        public static let windows = NSUserInterfaceItemIdentifier("UIFoundation.MainMenu.windows")
        /// The Help menu, wired to `NSApplication.helpMenu`.
        public static let help = NSUserInterfaceItemIdentifier("UIFoundation.MainMenu.help")
    }

    static func wireSpecialMenus(in menu: NSMenu) {
        let application = NSApplication.shared
        enumerateItems(in: menu) { menuItem in
            guard let submenu = menuItem.submenu, let identifier = menuItem.identifier else { return }
            switch identifier {
            case ItemIdentifier.services:
                application.servicesMenu = submenu
            case ItemIdentifier.font:
                NSFontManager.shared.setFontMenu(submenu)
            case ItemIdentifier.windows:
                application.windowsMenu = submenu
            case ItemIdentifier.help:
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

#endif
