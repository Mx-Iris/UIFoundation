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
        #expect(builder.item(for: .Application.settings)?.keyEquivalent == ",")
        #expect(builder.item(for: .Edit.Find.next)?.tag == 2)
        #expect(builder.item(for: .Format.Font.Kern.tighten) != nil)
        #expect(builder.item(for: .Format.Text.WritingDirection.selectionRightToLeft) != nil)
    }

    @Test("item(for:) hands out the live item for direct mutation")
    func directMutationThroughQuery() throws {
        let (rootMenu, builder) = makeStandardTree()
        let action = #selector(NSApplication.orderFrontStandardAboutPanel(_:))
        builder.item(for: .Application.settings)?.action = action

        let settingsItem = rootMenu.items[0].submenu!.items[2]
        #expect(settingsItem.action == action)
    }

    // MARK: Inserting

    @Test("sibling insertion lands immediately around the identified item")
    func siblingInsertion() throws {
        let (rootMenu, builder) = makeStandardTree()
        builder.insertItems(after: .File.open) {
            NSMenuItem("Open Workspace…")
        }
        builder.insertItems([NSMenuItem("Prelude")], before: .File.new)

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
        builder.insertItems([NSMenuItem("Nowhere")], atEndOf: .File.close)
        #expect(fileMenu(of: rootMenu).items.count == itemCountBefore)
    }

    // MARK: Replacing

    @Test("replace swaps one identified item for many, in place")
    func replaceItem() throws {
        let (rootMenu, builder) = makeStandardTree()
        builder.replace(.File.new) {
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
            currentItems.filter { $0.identifier == MainMenu.ItemIdentifier.File.close.userInterfaceItemIdentifier }
        }

        #expect(fileMenu(of: rootMenu).items.map(\.title) == ["Close"])
    }

    // MARK: Removing and separator normalization

    @Test("removing a whole trailing section leaves no trailing separator")
    func removalNormalizesTrailingSeparator() throws {
        let (rootMenu, builder) = makeStandardTree()
        builder.remove(.File.pageSetup)
        builder.remove(.File.print)
        builder.normalizeTouchedMenus()

        let titles = fileMenu(of: rootMenu).items.map(\.title)
        #expect(titles.last == "Revert to Saved")
        #expect(fileMenu(of: rootMenu).items.last?.isSeparatorItem == false)
    }

    @Test("removing everything between two separators collapses them into one")
    func removalCollapsesAdjacentSeparators() throws {
        let (rootMenu, builder) = makeStandardTree()
        builder.remove(.File.close)
        builder.remove(.File.save)
        builder.remove(.File.saveAs)
        builder.remove(.File.revertToSaved)
        builder.normalizeTouchedMenus()

        let items = fileMenu(of: rootMenu).items
        #expect(items.filter(\.isSeparatorItem).count == 1)
        #expect(items.map(\.title) == ["New", "Open…", "", "Page Setup…", "Print…"])
    }

    @Test("removing the leading section leaves no leading separator")
    func removalNormalizesLeadingSeparator() throws {
        let (rootMenu, builder) = makeStandardTree()
        builder.remove(.File.new)
        builder.remove(.File.open)
        builder.normalizeTouchedMenus()

        #expect(fileMenu(of: rootMenu).items.first?.isSeparatorItem == false)
        #expect(fileMenu(of: rootMenu).items.first?.title == "Close")
    }

    @Test("untouched menus keep their separators exactly as built")
    func untouchedMenusAreLeftAlone() throws {
        let (rootMenu, builder) = makeStandardTree()
        let editTitlesBefore = rootMenu.items[2].submenu!.items.map(\.title)
        builder.remove(.File.print)
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
        builder.insertItems(after: .File.open) {
            NSMenuItem("Build").identifier(hostIdentifier)
        }

        #expect(builder.item(for: hostIdentifier)?.title == "Build")
        builder.remove(hostIdentifier)
        #expect(builder.item(for: hostIdentifier) == nil)
    }

    // MARK: Item-rooted builders

    @Test("an item-rooted builder addresses the root item itself, and its subtree")
    func itemRootReachesItselfAndItsSubtree() throws {
        let fileItem = MainMenu.file()
        let builder = MainMenu.Builder(rootItem: fileItem)

        #expect(builder.item(for: .file) === fileItem)
        #expect(builder.item(for: .File.print)?.title == "Print…")
    }

    @Test("an item-rooted builder sees nothing outside its subtree")
    func itemRootIsScoped() throws {
        let builder = MainMenu.Builder(rootItem: MainMenu.file())

        #expect(builder.item(for: .edit) == nil)
        #expect(builder.item(for: .Edit.undo) == nil)
    }

    @Test("an item-rooted builder on a submenu-less item reaches only that item")
    func itemRootWithoutSubmenu() throws {
        let closeItem = MainMenu.File.close()
        let builder = MainMenu.Builder(rootItem: closeItem)

        #expect(builder.item(for: .File.close) === closeItem)
        #expect(builder.item(for: .File.print) == nil)
    }

    @Test("the verbs needing a containing menu do nothing when aimed at the root item")
    func rootItemHasNoContainingMenu() throws {
        let fileItem = MainMenu.file()
        let builder = MainMenu.Builder(rootItem: fileItem)
        let titlesBefore = try #require(fileItem.submenu).items.map(\.title)

        builder.insertItems([NSMenuItem("Before")], before: .file)
        builder.insertItems([NSMenuItem("After")], after: .file)
        builder.replace(.file, with: [NSMenuItem("Replacement")])
        builder.remove(.file)
        builder.normalizeTouchedMenus()

        #expect(fileItem.title == "File")
        #expect(fileItem.submenu?.items.map(\.title) == titlesBefore)
    }

    @Test("the child-side verbs act on the root item's own submenu")
    func rootItemChildVerbs() throws {
        let fileItem = MainMenu.file()
        let builder = MainMenu.Builder(rootItem: fileItem)

        builder.insertItems(atStartOf: .file) {
            NSMenuItem("First")
        }
        builder.replaceItems(of: .file) { currentItems in
            currentItems.filter { !$0.isSeparatorItem }
        }

        #expect(fileItem.submenu?.items.first?.title == "First")
        #expect(fileItem.submenu?.items.contains(where: \.isSeparatorItem) == false)
    }

    // MARK: Factory customization

    @Test("a factory customization amends that menu, and normalizes it")
    func factoryCustomizationAmendsAndNormalizes() throws {
        let fileItem = MainMenu.file { builder in
            builder.remove(.File.pageSetup)
            builder.remove(.File.print)
        }

        let items = try #require(fileItem.submenu).items
        #expect(!items.map(\.title).contains("Page Setup…"))
        #expect(items.last?.title == "Revert to Saved")
        #expect(items.last?.isSeparatorItem == false)
    }

    @Test("a factory customization reaches the menu's own item")
    func factoryCustomizationReachesOwnItem() throws {
        let fileItem = MainMenu.file { builder in
            builder.item(for: .file)?.title = "Dossier"
        }

        #expect(fileItem.title == "Dossier")
        // Retitling through the builder touches the item, not the submenu it
        // owns — unlike the `title:` parameter, which names both. Harmless
        // (AppKit shows the item's title, never a submenu's), but pinned so a
        // future change to either path is a visible one.
        #expect(fileItem.submenu?.title == "File")
        #expect(MainMenu.file(title: "Dossier").submenu?.title == "Dossier")
    }

    @Test("an empty customization produces exactly the standard menu")
    func emptyCustomizationMatchesTheStandardFactory() throws {
        func outline(of menuItem: NSMenuItem) -> [String] {
            var lines = [menuItem.title]
            func walk(_ menu: NSMenu, depth: Int) {
                for item in menu.items {
                    lines.append(String(repeating: "\t", count: depth) + item.title)
                    if let submenu = item.submenu {
                        walk(submenu, depth: depth + 1)
                    }
                }
            }
            if let submenu = menuItem.submenu {
                walk(submenu, depth: 1)
            }
            return lines
        }

        #expect(outline(of: MainMenu.application(customizing: { _ in })) == outline(of: MainMenu.application()))
        #expect(outline(of: MainMenu.file(customizing: { _ in })) == outline(of: MainMenu.file()))
        #expect(outline(of: MainMenu.edit(customizing: { _ in })) == outline(of: MainMenu.edit()))
        #expect(outline(of: MainMenu.format(customizing: { _ in })) == outline(of: MainMenu.format()))
        #expect(outline(of: MainMenu.view(customizing: { _ in })) == outline(of: MainMenu.view()))
        #expect(outline(of: MainMenu.window(customizing: { _ in })) == outline(of: MainMenu.window()))
        #expect(outline(of: MainMenu.help(customizing: { _ in })) == outline(of: MainMenu.help()))
        #expect(outline(of: MainMenu.Edit.find(customizing: { _ in })) == outline(of: MainMenu.Edit.find()))
        #expect(outline(of: MainMenu.Edit.spellingAndGrammar(customizing: { _ in })) == outline(of: MainMenu.Edit.spellingAndGrammar()))
        #expect(outline(of: MainMenu.Edit.substitutions(customizing: { _ in })) == outline(of: MainMenu.Edit.substitutions()))
        #expect(outline(of: MainMenu.Edit.transformations(customizing: { _ in })) == outline(of: MainMenu.Edit.transformations()))
        #expect(outline(of: MainMenu.Edit.speech(customizing: { _ in })) == outline(of: MainMenu.Edit.speech()))
        #expect(outline(of: MainMenu.Format.font(customizing: { _ in })) == outline(of: MainMenu.Format.font()))
        #expect(outline(of: MainMenu.Format.text(customizing: { _ in })) == outline(of: MainMenu.Format.text()))
    }

    @Test("a group factory customizes its own item and its inline leaves")
    func groupFactoryCustomization() throws {
        let findItem = MainMenu.Edit.find { builder in
            builder.item(for: .Edit.find)?.title = "Search"
            builder.item(for: .Edit.Find.next)?.keyEquivalent = "n"
        }
        #expect(findItem.title == "Search")
        #expect(findItem.submenu?.items.first { $0.tag == 2 }?.keyEquivalent == "n")

        let fontItem = MainMenu.Format.font { builder in
            builder.remove(.Format.Font.Kern.tighten)
        }
        let kernMenu = try #require(
            fontItem.submenu?
                .items.first { $0.identifier == MainMenu.ItemIdentifier.Format.Font.kern.userInterfaceItemIdentifier }?
                .submenu
        )
        #expect(kernMenu.items.map(\.title) == ["Use Default", "Use None", "Loosen"])
    }

    @Test("a content closure still selects the content overload")
    func contentClosuresAreNotStolenByTheCustomizingOverload() throws {
        // A single-expression content closure is *also* a valid
        // `(Builder) -> Void` — the parameter may be omitted and the result
        // discarded — so this is the call shape the new overload could
        // silently take over.
        let windowItem = MainMenu.window {
            MainMenu.Window.minimize()
        }
        #expect(windowItem.submenu?.items.map(\.title) == ["Minimize"])

        let fileItem = MainMenu.file {
            MainMenu.File.new()
            MainMenu.File.open()
        }
        #expect(fileItem.submenu?.items.map(\.title) == ["New", "Open…"])
    }
}

#endif
