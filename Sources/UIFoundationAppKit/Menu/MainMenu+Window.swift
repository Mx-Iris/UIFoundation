#if canImport(AppKit) && !targetEnvironment(macCatalyst)

import AppKit
import FoundationToolbox

extension MainMenu.ItemIdentifier {
    public static let windowMinimize = standard("windowMinimize")
    public static let windowZoom = standard("windowZoom")
    public static let windowBringAllToFront = standard("windowBringAllToFront")
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

    /// Standard items of the Window menu.
    @MainActor
    public enum Window {
        public static func minimize() -> NSMenuItem {
            NSMenuItem("Minimize", action: #Selector("performMiniaturize:"), keyEquivalent: "m")
                .identifier(ItemIdentifier.windowMinimize)
        }

        public static func zoom() -> NSMenuItem {
            NSMenuItem("Zoom", action: #Selector("performZoom:"))
                .identifier(ItemIdentifier.windowZoom)
        }

        public static func bringAllToFront() -> NSMenuItem {
            NSMenuItem("Bring All to Front", action: #Selector("arrangeInFront:"))
                .identifier(ItemIdentifier.windowBringAllToFront)
        }
    }
}

#endif
