#if canImport(AppKit) && !targetEnvironment(macCatalyst)

import Testing
import AppKit
@testable import UIFoundationAppKit

/// Asserts the assembled menus against a verbatim dump of Xcode's
/// `MainMenu.xib` template (see Evolution 0009) — titles, actions,
/// key equivalents, modifier masks, and tags.
@Suite("MainMenu", .serialized)
@MainActor
struct MainMenuTests {
    private func selectorName(_ menuItem: NSMenuItem) -> String {
        menuItem.action.map(NSStringFromSelector) ?? ""
    }

    // MARK: Structure

    @Test("the standard menu carries the template's seven top-level menus")
    func standardTopLevelMenus() throws {
        let mainMenu = MainMenu.standard(applicationName: "Example")
        #expect(mainMenu.items.map(\.title) == ["Example", "File", "Edit", "Format", "View", "Window", "Help"])
        for topLevelItem in mainMenu.items {
            #expect(topLevelItem.submenu != nil)
        }
    }

    @Test("the application menu matches the template item by item")
    func applicationMenuContent() throws {
        let applicationMenu = try #require(MainMenu.application(applicationName: "Example").submenu)
        let expectedTitles = [
            "About Example", "", "Settings…", "", "Services", "",
            "Hide Example", "Hide Others", "Show All", "", "Quit Example",
        ]
        #expect(applicationMenu.items.map(\.title) == expectedTitles)

        let aboutItem = applicationMenu.items[0]
        #expect(selectorName(aboutItem) == "orderFrontStandardAboutPanel:")

        let settingsItem = applicationMenu.items[2]
        #expect(settingsItem.action == nil)
        #expect(settingsItem.keyEquivalent == ",")

        let servicesItem = applicationMenu.items[4]
        #expect(servicesItem.submenu != nil)
        #expect(servicesItem.identifier == MainMenu.ItemIdentifier.Application.services.userInterfaceItemIdentifier)

        let hideItem = applicationMenu.items[6]
        #expect(selectorName(hideItem) == "hide:")
        #expect(hideItem.keyEquivalent == "h")
        #expect(hideItem.keyEquivalentModifierMask == .command)

        let hideOthersItem = applicationMenu.items[7]
        #expect(selectorName(hideOthersItem) == "hideOtherApplications:")
        #expect(hideOthersItem.keyEquivalent == "h")
        #expect(hideOthersItem.keyEquivalentModifierMask == [.option, .command])

        #expect(selectorName(applicationMenu.items[8]) == "unhideAllApplications:")

        let quitItem = applicationMenu.items[10]
        #expect(selectorName(quitItem) == "terminate:")
        #expect(quitItem.keyEquivalent == "q")
    }

    @Test("the File menu matches the template, including the print: action")
    func fileMenuContent() throws {
        let fileMenu = try #require(MainMenu.file().submenu)
        let expected: [(title: String, action: String, keyEquivalent: String)] = [
            ("New", "newDocument:", "n"),
            ("Open…", "openDocument:", "o"),
            ("", "", ""),
            ("Close", "performClose:", "w"),
            ("Save…", "saveDocument:", "s"),
            ("Save As…", "saveDocumentAs:", "S"),
            ("Revert to Saved", "revertDocumentToSaved:", "r"),
            ("", "", ""),
            ("Page Setup…", "runPageLayout:", "P"),
            ("Print…", "print:", "p"),
        ]
        #expect(fileMenu.items.count == expected.count)
        for (menuItem, expectation) in zip(fileMenu.items, expected) {
            #expect(menuItem.title == expectation.title)
            #expect(selectorName(menuItem) == expectation.action)
            #expect(menuItem.keyEquivalent == expectation.keyEquivalent)
        }
        #expect(fileMenu.items[8].keyEquivalentModifierMask == [.shift, .command])
    }

    @Test("Open Recent stays out of the standard File menu but keeps its shape")
    func openRecentIsOptIn() throws {
        let fileMenu = try #require(MainMenu.file().submenu)
        #expect(!fileMenu.items.contains { $0.title == "Open Recent" })

        let openRecentItem = MainMenu.File.openRecent()
        #expect(openRecentItem.identifier == MainMenu.ItemIdentifier.File.openRecent.userInterfaceItemIdentifier)
        let openRecentMenu = try #require(openRecentItem.submenu)
        #expect(openRecentMenu.items.map(\.title) == ["Clear Menu"])
        #expect(selectorName(openRecentMenu.items[0]) == "clearRecentDocuments:")
    }

    @Test("the Find group keeps the template's performFindPanelAction: tags")
    func findGroupTags() throws {
        let findMenu = try #require(MainMenu.Edit.find().submenu)
        let panelActionItems = findMenu.items.filter { selectorName($0) == "performFindPanelAction:" }
        #expect(panelActionItems.map(\.tag) == [1, 12, 2, 3, 7])
        #expect(panelActionItems.map(\.keyEquivalent) == ["f", "f", "g", "G", "e"])
        #expect(panelActionItems[1].keyEquivalentModifierMask == [.option, .command])

        let jumpItem = try #require(findMenu.items.last)
        #expect(selectorName(jumpItem) == "centerSelectionInVisibleArea:")
        #expect(jumpItem.keyEquivalent == "j")
    }

    @Test("the Edit menu leaves AppKit's auto-inserted items out")
    func editMenuLeavesAutomaticItemsOut() throws {
        let editMenu = try #require(MainMenu.edit().submenu)
        #expect(!editMenu.items.contains { $0.title.contains("Dictation") })
        #expect(!editMenu.items.contains { $0.title.contains("Emoji") })
    }

    @Test("the Font menu targets NSFontManager exactly where the template does")
    func fontMenuTargets() throws {
        let fontMenu = try #require(MainMenu.Format.font().submenu)
        let fontManagerTargetedItems = fontMenu.items.filter { $0.target === NSFontManager.shared }
        #expect(fontManagerTargetedItems.map(\.title) == ["Show Fonts", "Bold", "Italic", "Bigger", "Smaller"])
        #expect(fontManagerTargetedItems.map(\.tag) == [0, 2, 1, 3, 4])
        #expect(fontManagerTargetedItems.map { selectorName($0) } == [
            "orderFrontFontPanel:", "addFontTrait:", "addFontTrait:", "modifyFont:", "modifyFont:",
        ])
        let underlineItem = try #require(fontMenu.items.first { $0.title == "Underline" })
        #expect(underlineItem.target == nil)
    }

    @Test("Writing Direction keeps the disabled headers and tab-prefixed titles")
    func writingDirectionStructure() throws {
        let textMenu = try #require(MainMenu.Format.text().submenu)
        let writingDirectionItem = try #require(textMenu.items.first { $0.title == "Writing Direction" })
        let writingDirectionMenu = try #require(writingDirectionItem.submenu)

        let headerItems = writingDirectionMenu.items.filter { !$0.isEnabled && !$0.isSeparatorItem }
        #expect(headerItems.map(\.title) == ["Paragraph", "Selection"])
        for headerItem in headerItems {
            #expect(headerItem.action == nil)
        }

        let directionItems = writingDirectionMenu.items.filter { $0.title.hasPrefix("\t") }
        #expect(directionItems.map { selectorName($0) } == [
            "makeBaseWritingDirectionNatural:",
            "makeBaseWritingDirectionLeftToRight:",
            "makeBaseWritingDirectionRightToLeft:",
            "makeTextWritingDirectionNatural:",
            "makeTextWritingDirectionLeftToRight:",
            "makeTextWritingDirectionRightToLeft:",
        ])
    }

    // MARK: Wiring

    @Test("factories alone touch no global state")
    func factoriesHaveNoSideEffects() throws {
        let sentinelMenu = NSMenu(title: "Sentinel")
        NSApplication.shared.windowsMenu = sentinelMenu

        _ = MainMenu.window()
        _ = MainMenu.help()
        _ = MainMenu.application()

        #expect(NSApplication.shared.windowsMenu === sentinelMenu)
    }

    @Test("assembly wires services, windows, help, and the font menu")
    func assemblyWiresSpecialMenus() throws {
        let mainMenu = MainMenu.standard(applicationName: "Example")

        let servicesMenu = try #require(
            mainMenu.items[0].submenu?.items.first { $0.identifier == MainMenu.ItemIdentifier.Application.services.userInterfaceItemIdentifier }?.submenu
        )
        let fontMenu = try #require(
            mainMenu.items[3].submenu?.items.first { $0.identifier == MainMenu.ItemIdentifier.Format.font.userInterfaceItemIdentifier }?.submenu
        )
        let windowsMenu = try #require(mainMenu.items[5].submenu)
        let helpMenu = try #require(mainMenu.items[6].submenu)

        #expect(NSApplication.shared.servicesMenu === servicesMenu)
        #expect(NSApplication.shared.windowsMenu === windowsMenu)
        #expect(NSApplication.shared.helpMenu === helpMenu)
        #expect(NSFontManager.shared.fontMenu(false) === fontMenu)
    }

    @Test("rewriting a special menu through the builder keeps it wired")
    func builderFormKeepsWiring() throws {
        let mainMenu = MainMenu.menu {
            MainMenu.application(applicationName: "Example")
            MainMenu.window {
                MainMenu.Window.minimize()
            }
        }

        let windowsMenu = try #require(mainMenu.items[1].submenu)
        #expect(windowsMenu.items.map(\.title) == ["Minimize"])
        #expect(NSApplication.shared.windowsMenu === windowsMenu)
    }

    @Test("a customization removing the Window menu runs before wiring")
    func customizationPrecedesWiring() throws {
        let sentinelMenu = NSMenu(title: "Sentinel")
        NSApplication.shared.windowsMenu = sentinelMenu

        let mainMenu = MainMenu.standard(applicationName: "Example") { builder in
            builder.remove(.window)
        }

        #expect(!mainMenu.items.contains { $0.title == "Window" })
        #expect(NSApplication.shared.windowsMenu === sentinelMenu)
        let helpMenu = try #require(mainMenu.items.last?.submenu)
        #expect(NSApplication.shared.helpMenu === helpMenu)
    }

    @Test("menu(_:customizing:) runs the transformation before wiring")
    func assemblyCustomizationPrecedesWiring() throws {
        let sentinelMenu = NSMenu(title: "Sentinel")
        NSApplication.shared.windowsMenu = sentinelMenu

        let mainMenu = MainMenu.menu {
            MainMenu.application(applicationName: "Example")
            MainMenu.file()
            MainMenu.window()
            MainMenu.help(applicationName: "Example")
        } customizing: { builder in
            builder.remove(.window)
            builder.remove(.File.pageSetup)
            builder.remove(.File.print)
        }

        #expect(!mainMenu.items.contains { $0.title == "Window" })
        #expect(NSApplication.shared.windowsMenu === sentinelMenu)

        let helpMenu = try #require(mainMenu.items.last?.submenu)
        #expect(NSApplication.shared.helpMenu === helpMenu)

        // The touched File menu is normalized, like it is under standard(customizing:).
        let fileMenu = try #require(mainMenu.items[1].submenu)
        #expect(fileMenu.items.last?.title == "Revert to Saved")
    }

    // MARK: Names and titles

    @Test("the application name override reaches every named item")
    func applicationNameOverride() throws {
        let mainMenu = MainMenu.standard(applicationName: "Renamed")
        let applicationMenu = try #require(mainMenu.items[0].submenu)
        #expect(mainMenu.items[0].title == "Renamed")
        #expect(applicationMenu.items[0].title == "About Renamed")
        #expect(applicationMenu.items.last?.title == "Quit Renamed")

        let helpMenu = try #require(mainMenu.items[6].submenu)
        #expect(helpMenu.items[0].title == "Renamed Help")
        #expect(selectorName(helpMenu.items[0]) == "showHelp:")
        #expect(helpMenu.items[0].keyEquivalent == "?")
    }

    @Test("top-level titles are overridable per factory")
    func topLevelTitleOverride() throws {
        let fileItem = MainMenu.file(title: "Dossier")
        #expect(fileItem.title == "Dossier")
        #expect(fileItem.submenu?.title == "Dossier")
    }
}

#endif
