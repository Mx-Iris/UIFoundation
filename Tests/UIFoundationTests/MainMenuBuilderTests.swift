#if canImport(AppKit) && !targetEnvironment(macCatalyst)

import Testing
import AppKit
@testable import UIFoundationAppKit

/// Exercises `MainMenu.Builder` against an unwired standard tree, built
/// directly from the factories so no `NSApplication` state is touched and the
/// suite can run in parallel. Wiring interplay lives in `MainMenuTests`.
@Suite("MainMenu.Builder")
@MainActor
struct MainMenuBuilderTests {
    private func makeStandardTree() -> (rootMenu: NSMenu, builder: MainMenu.Builder) {
        let rootMenu = NSMenu(title: "Main Menu", items: [
            MainMenu.application(applicationName: "Example"),
            MainMenu.file(),
            MainMenu.edit(),
            MainMenu.format(),
            MainMenu.view(),
            MainMenu.window(),
            MainMenu.help(applicationName: "Example"),
        ])
        return (rootMenu, MainMenu.Builder(rootMenu: rootMenu))
    }

    private func fileMenu(of rootMenu: NSMenu) -> NSMenu {
        rootMenu.items[1].submenu!
    }

    // MARK: Addressability

    @Test("every standard item carries an identifier, and no identifier repeats")
    func everyStandardItemIsAddressable() throws {
        let (rootMenu, _) = makeStandardTree()
        var seenIdentifiers: Set<NSUserInterfaceItemIdentifier> = []

        func walk(_ menu: NSMenu) {
            for menuItem in menu.items {
                if !menuItem.isSeparatorItem {
                    let identifier = menuItem.identifier
                    #expect(identifier != nil, "\(menuItem.title) has no identifier")
                    if let identifier {
                        #expect(seenIdentifiers.insert(identifier).inserted, "\(identifier.rawValue) repeats")
                    }
                }
                if let submenu = menuItem.submenu {
                    walk(submenu)
                }
            }
        }
        walk(rootMenu)
    }

    @Test("item(for:) reaches top-level menus, direct items, and nested leaves")
    func addressingReachesEveryDepth() throws {
        let (_, builder) = makeStandardTree()
        #expect(builder.item(for: .file)?.title == "File")
        #expect(builder.item(for: .applicationSettings)?.keyEquivalent == ",")
        #expect(builder.item(for: .editFindNext)?.tag == 2)
        #expect(builder.item(for: .formatFontKernTighten) != nil)
        #expect(builder.item(for: .formatTextWritingDirectionSelectionRightToLeft) != nil)
    }

    @Test("item(for:) hands out the live item for direct mutation")
    func directMutationThroughQuery() throws {
        let (rootMenu, builder) = makeStandardTree()
        let action = #selector(NSApplication.orderFrontStandardAboutPanel(_:))
        builder.item(for: .applicationSettings)?.action = action

        let settingsItem = rootMenu.items[0].submenu!.items[2]
        #expect(settingsItem.action == action)
    }

    // MARK: Inserting

    @Test("sibling insertion lands immediately around the identified item")
    func siblingInsertion() throws {
        let (rootMenu, builder) = makeStandardTree()
        builder.insertItems(after: .fileOpen) {
            NSMenuItem("Open Workspace…")
        }
        builder.insertItems([NSMenuItem("Prelude")], before: .fileNew)

        let titles = fileMenu(of: rootMenu).items.prefix(4).map(\.title)
        #expect(titles == ["Prelude", "New", "Open…", "Open Workspace…"])
    }

    @Test("child insertion lands at the ends of the identified submenu")
    func childInsertion() throws {
        let (rootMenu, builder) = makeStandardTree()
        builder.insertItems(atStartOf: .window) {
            NSMenuItem("First")
        }
        builder.insertItems(atEndOf: .window) {
            NSMenuItem("Last")
        }

        let windowMenu = rootMenu.items[5].submenu!
        #expect(windowMenu.items.first?.title == "First")
        #expect(windowMenu.items.last?.title == "Last")
    }

    @Test("child insertion into a submenu-less item is a no-op")
    func childInsertionNeedsSubmenu() throws {
        let (rootMenu, builder) = makeStandardTree()
        let itemCountBefore = fileMenu(of: rootMenu).items.count
        builder.insertItems([NSMenuItem("Nowhere")], atEndOf: .fileClose)
        #expect(fileMenu(of: rootMenu).items.count == itemCountBefore)
    }

    // MARK: Replacing

    @Test("replace swaps one identified item for many, in place")
    func replaceItem() throws {
        let (rootMenu, builder) = makeStandardTree()
        builder.replace(.fileNew) {
            NSMenuItem("New Project")
            NSMenuItem("New File")
        }

        let titles = fileMenu(of: rootMenu).items.prefix(3).map(\.title)
        #expect(titles == ["New Project", "New File", "Open…"])
    }

    @Test("replaceItems(of:) transforms a submenu's detached items")
    func replaceItemsOfSubmenu() throws {
        let (rootMenu, builder) = makeStandardTree()
        builder.replaceItems(of: .file) { currentItems in
            currentItems.filter { $0.identifier == MainMenu.ItemIdentifier.fileClose.userInterfaceItemIdentifier }
        }

        #expect(fileMenu(of: rootMenu).items.map(\.title) == ["Close"])
    }

    // MARK: Removing and separator normalization

    @Test("removing a whole trailing section leaves no trailing separator")
    func removalNormalizesTrailingSeparator() throws {
        let (rootMenu, builder) = makeStandardTree()
        builder.remove(.filePageSetup)
        builder.remove(.filePrint)
        builder.normalizeTouchedMenus()

        let titles = fileMenu(of: rootMenu).items.map(\.title)
        #expect(titles.last == "Revert to Saved")
        #expect(fileMenu(of: rootMenu).items.last?.isSeparatorItem == false)
    }

    @Test("removing everything between two separators collapses them into one")
    func removalCollapsesAdjacentSeparators() throws {
        let (rootMenu, builder) = makeStandardTree()
        builder.remove(.fileClose)
        builder.remove(.fileSave)
        builder.remove(.fileSaveAs)
        builder.remove(.fileRevertToSaved)
        builder.normalizeTouchedMenus()

        let items = fileMenu(of: rootMenu).items
        #expect(items.filter(\.isSeparatorItem).count == 1)
        #expect(items.map(\.title) == ["New", "Open…", "Open Recent", "", "Page Setup…", "Print…"])
    }

    @Test("removing the leading section leaves no leading separator")
    func removalNormalizesLeadingSeparator() throws {
        let (rootMenu, builder) = makeStandardTree()
        builder.remove(.fileNew)
        builder.remove(.fileOpen)
        builder.remove(.openRecent)
        builder.normalizeTouchedMenus()

        #expect(fileMenu(of: rootMenu).items.first?.isSeparatorItem == false)
        #expect(fileMenu(of: rootMenu).items.first?.title == "Close")
    }

    @Test("untouched menus keep their separators exactly as built")
    func untouchedMenusAreLeftAlone() throws {
        let (rootMenu, builder) = makeStandardTree()
        let editTitlesBefore = rootMenu.items[2].submenu!.items.map(\.title)
        builder.remove(.filePrint)
        builder.normalizeTouchedMenus()

        #expect(rootMenu.items[2].submenu!.items.map(\.title) == editTitlesBefore)
    }

    // MARK: No-op semantics

    @Test("addressing an absent identifier is a silent no-op")
    func absentIdentifierIsSilentNoOp() throws {
        let (rootMenu, builder) = makeStandardTree()
        let absent = MainMenu.ItemIdentifier("test.absent")
        let fileTitlesBefore = fileMenu(of: rootMenu).items.map(\.title)

        #expect(builder.item(for: absent) == nil)
        builder.remove(absent)
        builder.replace(absent, with: [NSMenuItem("Ghost")])
        builder.insertItems([NSMenuItem("Ghost")], after: absent)
        builder.replaceItems(of: absent) { _ in [] }
        builder.normalizeTouchedMenus()

        #expect(fileMenu(of: rootMenu).items.map(\.title) == fileTitlesBefore)
    }

    @Test("host items become addressable through their own identifier")
    func hostItemsAreAddressable() throws {
        let (_, builder) = makeStandardTree()
        let hostIdentifier = MainMenu.ItemIdentifier("com.example.build")
        builder.insertItems(after: .fileOpen) {
            NSMenuItem("Build").identifier(hostIdentifier)
        }

        #expect(builder.item(for: hostIdentifier)?.title == "Build")
        builder.remove(hostIdentifier)
        #expect(builder.item(for: hostIdentifier) == nil)
    }
}

#endif
