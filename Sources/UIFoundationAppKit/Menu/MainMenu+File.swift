#if canImport(AppKit) && !targetEnvironment(macCatalyst)

import AppKit
import FoundationToolbox

extension MainMenu.ItemIdentifier {
    public static let fileNew = standard("fileNew")
    public static let fileOpen = standard("fileOpen")
    /// Tagged but wired to nothing — AppKit has no public counterpart to the
    /// xib's `recentDocuments` marker (see the usage guide).
    public static let openRecent = standard("openRecent")
    public static let openRecentClearMenu = standard("openRecentClearMenu")
    public static let fileClose = standard("fileClose")
    public static let fileSave = standard("fileSave")
    public static let fileSaveAs = standard("fileSaveAs")
    public static let fileRevertToSaved = standard("fileRevertToSaved")
    public static let filePageSetup = standard("filePageSetup")
    public static let filePrint = standard("filePrint")
}

extension MainMenu {
    /// The File menu with the template's standard content — minus Open
    /// Recent, deliberately: in a document-based app `NSDocumentController`
    /// inserts and adopts its own next to the `openDocument:` item (providing
    /// one here too shows two of them), and in a non-document app nothing
    /// populates one. See ``File/openRecent()``.
    public static func file(title: String = "File") -> NSMenuItem {
        file(title: title) {
            File.new()
            File.open()
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
            .identifier(ItemIdentifier.file)
    }

    /// Standard items of the File menu.
    @MainActor
    public enum File {
        public static func new() -> NSMenuItem {
            NSMenuItem("New", action: #Selector("newDocument:"), keyEquivalent: "n")
                .identifier(ItemIdentifier.fileNew)
        }

        public static func open() -> NSMenuItem {
            NSMenuItem("Open…", action: #Selector("openDocument:"), keyEquivalent: "o")
                .identifier(ItemIdentifier.fileOpen)
        }

        /// The Open Recent submenu with its Clear Menu item — deliberately
        /// not part of the standard File menu content. `NSDocumentController`
        /// recognizes the xib's Open Recent by a private menu name AppKit
        /// offers no public way to set; a code-built one is invisible to it,
        /// so in a document-based app the system inserts its own next to the
        /// `openDocument:` item (and this one would sit beside it as a dead
        /// duplicate), while in a non-document app nothing populates one. Use
        /// this factory only when the host fills the submenu itself, e.g.
        /// from `NSDocumentController.shared.recentDocumentURLs` in a
        /// `menuNeedsUpdate(_:)` delegate — see the usage guide.
        public static func openRecent() -> NSMenuItem {
            NSMenuItem("Open Recent") {
                NSMenuItem("Clear Menu", action: #Selector("clearRecentDocuments:"))
                    .identifier(ItemIdentifier.openRecentClearMenu)
            }
            .identifier(ItemIdentifier.openRecent)
        }

        public static func close() -> NSMenuItem {
            NSMenuItem("Close", action: #Selector("performClose:"), keyEquivalent: "w")
                .identifier(ItemIdentifier.fileClose)
        }

        public static func save() -> NSMenuItem {
            NSMenuItem("Save…", action: #Selector("saveDocument:"), keyEquivalent: "s")
                .identifier(ItemIdentifier.fileSave)
        }

        public static func saveAs() -> NSMenuItem {
            NSMenuItem("Save As…", action: #Selector("saveDocumentAs:"), keyEquivalent: "S")
                .identifier(ItemIdentifier.fileSaveAs)
        }

        public static func revertToSaved() -> NSMenuItem {
            NSMenuItem("Revert to Saved", action: #Selector("revertDocumentToSaved:"), keyEquivalent: "r")
                .identifier(ItemIdentifier.fileRevertToSaved)
        }

        public static func pageSetup() -> NSMenuItem {
            NSMenuItem("Page Setup…", action: #Selector("runPageLayout:"), keyEquivalent: "P", modifiers: [.shift, .command])
                .identifier(ItemIdentifier.filePageSetup)
        }

        public static func print() -> NSMenuItem {
            NSMenuItem("Print…", action: #Selector("print:"), keyEquivalent: "p")
                .identifier(ItemIdentifier.filePrint)
        }
    }
}

#endif
