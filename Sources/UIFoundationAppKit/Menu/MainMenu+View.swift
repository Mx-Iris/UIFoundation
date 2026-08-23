#if canImport(AppKit) && !targetEnvironment(macCatalyst)

import AppKit
import FoundationToolbox

extension MainMenu.ItemIdentifier {
    /// Standard items of the View menu, addressed as `.View.showToolbar` etc.
    public enum View {
        public static let showToolbar = standard("View.showToolbar")
        public static let customizeToolbar = standard("View.customizeToolbar")
        public static let showSidebar = standard("View.showSidebar")
        public static let enterFullScreen = standard("View.enterFullScreen")
    }
}

extension MainMenu {
    /// The View menu with the template's standard content.
    public static func view(title: String = "View") -> NSMenuItem {
        view(title: title) {
            View.showToolbar()
            View.customizeToolbar()
            NSMenuItem.separator()
            View.showSidebar()
            View.enterFullScreen()
        }
    }

    /// The View menu with custom content.
    public static func view(title: String = "View", @MenuBuilder _ items: () -> [NSMenuItem]) -> NSMenuItem {
        NSMenuItem(title, submenu: items)
            .identifier(ItemIdentifier.view)
    }

    /// Standard items of the View menu. AppKit's validation retitles the
    /// toggling items (Show/Hide Toolbar, Show/Hide Sidebar) on its own.
    @MainActor
    public enum View {
        public static func showToolbar() -> NSMenuItem {
            NSMenuItem("Show Toolbar", action: #Selector("toggleToolbarShown:"), keyEquivalent: "t", modifiers: [.option, .command])
                .identifier(ItemIdentifier.View.showToolbar)
        }

        public static func customizeToolbar() -> NSMenuItem {
            NSMenuItem("Customize Toolbar…", action: #Selector("runToolbarCustomizationPalette:"))
                .identifier(ItemIdentifier.View.customizeToolbar)
        }

        public static func showSidebar() -> NSMenuItem {
            NSMenuItem("Show Sidebar", action: #Selector("toggleSidebar:"), keyEquivalent: "s", modifiers: [.control, .command])
                .identifier(ItemIdentifier.View.showSidebar)
        }

        public static func enterFullScreen() -> NSMenuItem {
            NSMenuItem("Enter Full Screen", action: #Selector("toggleFullScreen:"), keyEquivalent: "f", modifiers: [.control, .command])
                .identifier(ItemIdentifier.View.enterFullScreen)
        }
    }
}

#endif
