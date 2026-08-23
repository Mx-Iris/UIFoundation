#if canImport(AppKit) && !targetEnvironment(macCatalyst)

import AppKit
import FoundationToolbox

extension MainMenu.ItemIdentifier {
    /// Standard items of the Help menu, addressed as `.Help.applicationHelp`.
    public enum Help {
        public static let applicationHelp = standard("Help.applicationHelp")
    }
}

extension MainMenu {
    /// The Help menu with the template's standard content. The assembly step
    /// wires it to `NSApplication.helpMenu`, which is what gives it the
    /// built-in help search field.
    public static func help(applicationName: String? = nil, title: String = "Help") -> NSMenuItem {
        help(title: title) {
            Help.applicationHelp(applicationName: applicationName)
        }
    }

    /// The Help menu with custom content. Stays wired as the application's
    /// help menu.
    public static func help(title: String = "Help", @MenuBuilder _ items: () -> [NSMenuItem]) -> NSMenuItem {
        NSMenuItem(title, submenu: items)
            .identifier(ItemIdentifier.help)
    }

    /// Standard items of the Help menu.
    @MainActor
    public enum Help {
        public static func applicationHelp(applicationName: String? = nil) -> NSMenuItem {
            NSMenuItem("\(resolvedApplicationName(applicationName)) Help", action: #Selector("showHelp:"), keyEquivalent: "?")
                .identifier(ItemIdentifier.Help.applicationHelp)
        }
    }
}

#endif
