#if canImport(AppKit) && !targetEnvironment(macCatalyst)

import AppKit
import FoundationToolbox

extension MainMenu.ItemIdentifier {
    /// Standard items of the Window menu, addressed as `.Window.minimize` etc.
    public enum Window {
        public static let minimize = standard("Window.minimize")
        public static let zoom = standard("Window.zoom")
        public static let bringAllToFront = standard("Window.bringAllToFront")
    }
}

extension MainMenu {
    /// The Window menu with the template's standard content. The assembly step
    /// wires it to `NSApplication.windowsMenu`; AppKit then maintains the
    /// window list (and, where applicable, the tab and tiling items) on its
    /// own.
    public static func window(title: String = "Window") -> NSMenuItem {
        window(title: title) {
            Window.minimize()
            Window.zoom()
            NSMenuItem.separator()
            Window.bringAllToFront()
        }
    }

    /// The Window menu with custom content. Stays wired as the application's
    /// windows menu.
    public static func window(title: String = "Window", @MenuBuilder _ items: () -> [NSMenuItem]) -> NSMenuItem {
        NSMenuItem(title, submenu: items)
            .identifier(ItemIdentifier.window)
    }

    /// The Window menu with the template's standard content, amended by
    /// `customize`. The transformation reaches the menu's own item (`.window`)
    /// as well as everything under it, and the menu stays wired as the
    /// application's windows menu.
    public static func window(title: String = "Window", customizing customize: (Builder) -> Void) -> NSMenuItem {
        customized(window(title: title), by: customize)
    }

    /// Standard items of the Window menu.
    @MainActor
    public enum Window {
        public static func minimize() -> NSMenuItem {
            NSMenuItem("Minimize", action: #Selector("performMiniaturize:"), keyEquivalent: "m")
                .identifier(ItemIdentifier.Window.minimize)
        }

        public static func zoom() -> NSMenuItem {
            NSMenuItem("Zoom", action: #Selector("performZoom:"))
                .identifier(ItemIdentifier.Window.zoom)
        }

        public static func bringAllToFront() -> NSMenuItem {
            NSMenuItem("Bring All to Front", action: #Selector("arrangeInFront:"))
                .identifier(ItemIdentifier.Window.bringAllToFront)
        }
    }
}

#endif
