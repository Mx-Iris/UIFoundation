#if canImport(AppKit) && !targetEnvironment(macCatalyst)

import AppKit

extension MainMenu {
    /// The File menu with the template's standard content.
    public static func file(title: String = "File") -> NSMenuItem {
        file(title: title) {
            File.new()
            File.open()
            File.openRecent()
            NSMenuItem.separator()
            File.close()
            File.save()
            File.saveAs()
            File.revertToSaved()
            NSMenuItem.separator()
            File.pageSetup()
            File.print()
        }
    }

    /// The File menu with custom content.
    public static func file(title: String = "File", @MenuBuilder _ items: () -> [NSMenuItem]) -> NSMenuItem {
        NSMenuItem(title, submenu: items)
    }

    /// Standard items of the File menu.
    @MainActor
    public enum File {
        public static func new() -> NSMenuItem {
            NSMenuItem("New", action: Selector(("newDocument:")), keyEquivalent: "n")
        }

        public static func open() -> NSMenuItem {
            NSMenuItem("Open…", action: Selector(("openDocument:")), keyEquivalent: "o")
        }

        /// The Open Recent submenu with its Clear Menu item. AppKit has no
        /// public counterpart to the xib's `recentDocuments` marker, so this
        /// menu is identifier-tagged but not auto-populated — see the usage
        /// guide for the current state of that limitation.
        public static func openRecent() -> NSMenuItem {
            NSMenuItem("Open Recent") {
                NSMenuItem("Clear Menu", action: Selector(("clearRecentDocuments:")))
            }
            .identifier(ItemIdentifier.openRecent)
        }

        public static func close() -> NSMenuItem {
            NSMenuItem("Close", action: Selector(("performClose:")), keyEquivalent: "w")
        }

        public static func save() -> NSMenuItem {
            NSMenuItem("Save…", action: Selector(("saveDocument:")), keyEquivalent: "s")
        }

        public static func saveAs() -> NSMenuItem {
            NSMenuItem("Save As…", action: Selector(("saveDocumentAs:")), keyEquivalent: "S")
        }

        public static func revertToSaved() -> NSMenuItem {
            NSMenuItem("Revert to Saved", action: Selector(("revertDocumentToSaved:")), keyEquivalent: "r")
        }

        public static func pageSetup() -> NSMenuItem {
            NSMenuItem("Page Setup…", action: Selector(("runPageLayout:")), keyEquivalent: "P", modifiers: [.shift, .command])
        }

        public static func print() -> NSMenuItem {
            NSMenuItem("Print…", action: Selector(("print:")), keyEquivalent: "p")
        }
    }
}

#endif
