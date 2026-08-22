#if canImport(AppKit) && !targetEnvironment(macCatalyst)

import AppKit

extension MainMenu {
    /// The application menu (the bold menu beside the Apple menu) with the
    /// template's standard content. AppKit treats the first top-level item of
    /// the main menu as the application menu; no extra wiring is required.
    public static func application(applicationName: String? = nil) -> NSMenuItem {
        let resolvedName = resolvedApplicationName(applicationName)
        return application(applicationName: resolvedName) {
            Application.about(applicationName: resolvedName)
            NSMenuItem.separator()
            Application.settings()
            NSMenuItem.separator()
            Application.services()
            NSMenuItem.separator()
            Application.hide(applicationName: resolvedName)
            Application.hideOthers()
            Application.showAll()
            NSMenuItem.separator()
            Application.quit(applicationName: resolvedName)
        }
    }

    /// The application menu with custom content.
    public static func application(applicationName: String? = nil, @MenuBuilder _ items: () -> [NSMenuItem]) -> NSMenuItem {
        NSMenuItem(resolvedApplicationName(applicationName), submenu: items)
    }

    /// Standard items of the application menu.
    @MainActor
    public enum Application {
        public static func about(applicationName: String? = nil) -> NSMenuItem {
            NSMenuItem("About \(resolvedApplicationName(applicationName))", action: Selector(("orderFrontStandardAboutPanel:")))
        }

        /// The Settings… (macOS 12 and earlier: Preferences…) item, ⌘,.
        /// The template leaves it unconnected; pass the host's action here or
        /// attach one with the chained `.action(_:)` modifier.
        public static func settings(action: Selector? = nil, target: AnyObject? = nil) -> NSMenuItem {
            let title = if #available(macOS 13.0, *) { "Settings…" } else { "Preferences…" }
            return NSMenuItem(title, action: action, keyEquivalent: ",").target(target)
        }

        /// The Services submenu. Its content is populated by AppKit once the
        /// assembly step wires it to `NSApplication.servicesMenu`.
        public static func services() -> NSMenuItem {
            NSMenuItem("Services", submenu: NSMenu(title: "Services"))
                .identifier(ItemIdentifier.services)
        }

        public static func hide(applicationName: String? = nil) -> NSMenuItem {
            NSMenuItem("Hide \(resolvedApplicationName(applicationName))", action: Selector(("hide:")), keyEquivalent: "h")
        }

        public static func hideOthers() -> NSMenuItem {
            NSMenuItem("Hide Others", action: Selector(("hideOtherApplications:")), keyEquivalent: "h", modifiers: [.option, .command])
        }

        public static func showAll() -> NSMenuItem {
            NSMenuItem("Show All", action: Selector(("unhideAllApplications:")))
        }

        public static func quit(applicationName: String? = nil) -> NSMenuItem {
            NSMenuItem("Quit \(resolvedApplicationName(applicationName))", action: Selector(("terminate:")), keyEquivalent: "q")
        }
    }
}

#endif
