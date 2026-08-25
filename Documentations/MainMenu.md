# MainMenu

> The standard macOS main menu built in code — the exact menu bar Xcode's application template
> ships as `MainMenu.xib`, with every layer open for customization. Pure public AppKit, no trait,
> macOS only. Decision record: Evolution
> [`0009`](Evolutions/0009-standard-main-menu.md).

---

## Table of Contents

- [Quick Start](#quick-start)
- [The Four Levels](#the-four-levels)
- [Customizing the Standard Menu](#customizing-the-standard-menu)
- [Where a Customization Attaches](#where-a-customization-attaches)
- [The Wiring Contract](#the-wiring-contract)
- [What AppKit Adds On Its Own](#what-appkit-adds-on-its-own)
- [Open Recent](#open-recent)
- [Titles, Names, and Localization](#titles-names-and-localization)
- [Fidelity Notes](#fidelity-notes)

---

## Quick Start

A fully programmatic app gets the complete template-equivalent menu bar in one line:

```swift
@main
enum App {
    static func main() {
        // Mirrors NSApplicationMain, which drains a pool over everything before run().
        let app = autoreleasepool {
            let app = NSApplication.shared
            app.delegate = AppDelegate.shared
            app.setActivationPolicy(.regular)
            app.mainMenu = MainMenu.standard()
            return app
        }
        app.run()
    }
}
```

**Going storyboard-free forfeits `@main` on the app delegate.** Putting `@main` on an
`NSApplicationDelegate` synthesizes an entry point that calls `NSApplicationMain`, and
`NSApplicationMain` instantiates and connects the delegate only through the principal
storyboard/nib — unlike UIKit's `UIApplicationMain`, it takes no delegate class name. Delete the
storyboard and nothing ever creates the delegate: the process runs, `applicationDidFinishLaunching`
never fires, and no window appears (verified in the example app, 2026-08-22). An app that adopts
this API as its only menu source must own its entry point the way the snippet above does — create
the delegate, assign it (and hold it strongly: `NSApplication.delegate` is weak, which is why the
snippet keeps it in a `static let`), set the activation policy and the menu, then `run()`. The
`autoreleasepool` mirrors `NSApplicationMain`, which pushes a pool before loading and pops it right
before `run()` — without it, objects autoreleased during setup live until the process exits
(`run()`'s own pools start too late to cover it).

Nothing else needs replicating: `-[NSApplication run]` performs the rest of the launch-time
initialization itself (update-cycle setup, sudden/automatic termination, memory-pressure sources,
and a fresh autorelease pool per event), so a hand-rolled entry point is equivalent to
`NSApplicationMain` once delegate, menu, and window are yours. The decompile-level walkthrough —
including why `NSDelegateClass` is consumed only on the storyboard path, and that
`NSApplicationMain` keeps the delegate alive by never releasing it — is in
[`Researchs/AppKit-NSApplicationMain-Internals.md`](../Researchs/AppKit-NSApplicationMain-Internals.md).

`standard()` produces the seven template menus — the application menu, File, Edit, Format, View,
Window, Help — item for item, and performs all the system wiring the xib would (see
[The Wiring Contract](#the-wiring-contract)).

## The Four Levels

**Level 1 — the whole bar.** `MainMenu.standard(applicationName:)`. Done.

**Level 2 — amend single items in place.** `MainMenu.standard(customizing:)` hands the assembled
tree to a `MainMenu.Builder` for identifier-addressed amendments — the subject of
[Customizing the Standard Menu](#customizing-the-standard-menu):

```swift
app.mainMenu = MainMenu.standard { builder in
    builder.remove(.File.pageSetup)
    builder.item(for: .Application.settings)?.action = #selector(AppDelegate.openSettings(_:))
    builder.insertItems(after: .File.open) {
        NSMenuItem("Open Workspace…", action: #selector(AppDelegate.openWorkspace(_:)), keyEquivalent: "O")
    }
}
```

**Level 3 — pick, reorder, and mix top-level menus.** `MainMenu.menu { … }` takes the existing
`@MenuBuilder`, so standard menus and fully custom ones interleave freely, and it takes the same
transformation as a second trailing closure:

```swift
app.mainMenu = MainMenu.menu {
    MainMenu.application()
    MainMenu.file()
    MainMenu.edit()
    NSMenuItem("Project") {
        NSMenuItem("Build", action: #selector(AppDelegate.build(_:)), keyEquivalent: "b")
    }
    MainMenu.window()
    MainMenu.help()
} customizing: { builder in
    builder.remove(.File.pageSetup)
}
```

Each top-level factory has a builder overload that **replaces** that menu's content while keeping
its system role (see the wiring contract):

```swift
MainMenu.window {
    MainMenu.Window.minimize()
    MainMenu.Window.zoom()
    NSMenuItem.separator()
    NSMenuItem("Always on Top", action: #selector(AppDelegate.toggleFloating(_:)))
    NSMenuItem.separator()
    MainMenu.Window.bringAllToFront()
}
```

— and a `customizing:` overload that **keeps** the standard content and amends it, so the common
case of "the template's File menu, minus one item" costs one line instead of nine:

```swift
MainMenu.file { builder in
    builder.remove(.File.pageSetup)
}
```

**Level 4 — standard single items.** Every standard item is a factory on the menu's nested
namespace (`MainMenu.File.close()`, `MainMenu.Edit.find()`, `MainMenu.Application.quit()`, …), so a
rewritten menu never re-types a selector, key equivalent, or tag. The `Settings…` item is the one
item the template leaves unconnected; pass the host's action:

```swift
MainMenu.Application.settings(action: #selector(AppDelegate.openSettings(_:)))
```

The seven factories that produce a *group* — a submenu with several rows — take `customizing:`
too, which is the only way to reach into one without re-listing it:

```swift
MainMenu.Edit.find { builder in
    builder.item(for: .Edit.Find.next)?.keyEquivalent = "n"
}
```

## Customizing the Standard Menu

`MainMenu.Builder` is `UIMenuBuilder` translated to AppKit (decision record: Evolution
[`0010`](Evolutions/0010-main-menu-builder.md)). UIKit's three element kinds — menu group,
action, command — are all `NSMenuItem` here, so its three addressing schemes collapse into
`MainMenu.ItemIdentifier` and one set of verbs:

| `MainMenu.Builder` | `UIMenuBuilder` counterpart |
|---|---|
| `item(for:)` | `menu(for:)` + `action(for:)` |
| `insertItems(_:before:)` / `insertItems(_:after:)` | `insertSibling`, `insertElements(_:before/afterMenu:/Action:)` |
| `insertItems(_:atStartOf:)` / `insertItems(_:atEndOf:)` | `insertChild`, `insertElements(_:atStart/atEndOfMenu:)` |
| `replace(_:with:)` | `replace(menu:with:)`, `replace(action:with:)` |
| `replaceItems(of:from:)` | `replaceChildren(ofMenu:from:)` |
| `remove(_:)` | `remove(menu:)`, `remove(action:)` |

Every item `standard()` produces is addressable — the seven top-level menus, each menu's direct
items, and the nested groups' leaves, down to the Writing Direction section headers. The constants
mirror the factory namespaces: top-level menus sit on the identifier itself (`.file`), a menu's
content sits in a nested namespace named after it (`.File.new`, `.Application.settings`), and a
group's own items nest one level further (`.Edit.Find.next`, `.Format.Font.Kern.tighten`).
Inserting and replacing methods all have `@MenuBuilder` trailing-closure overloads. The contracts:

- **Mutations apply immediately** — later queries see the transformed tree, like `UIMenuBuilder`.
- **An absent identifier is a silent no-op** (also like `UIMenuBuilder`), so customization code can
  run unconditionally. Use `item(for:)` when you need to know.
- **The transformation runs before the wiring.** Removing or replacing the Window / Help /
  Services / Font menus inside `customizing:` leaves no stale `NSApplication` / `NSFontManager`
  assignment behind.
- **Orphaned separators are cleaned up afterwards.** UIKit never shows this problem because its
  group model draws separators implicitly; here a removal can strand one, so every menu the builder
  touched is normalized when the closure returns — consecutive separators collapse, leading and
  trailing ones are dropped. Untouched menus keep their exact built form. Separators themselves are
  not addressable.
- **Host items join the addressing scheme** by carrying their own identifier:

  ```swift
  builder.insertItems(after: .File.open) {
      NSMenuItem("Build").identifier(MainMenu.ItemIdentifier("com.example.build"))
  }
  ```

- **AppKit's auto-inserted items are out of reach** — Start Dictation… / Emoji & Symbols and the
  Window menu's tab items are injected after launch and do not exist at build time.

`MainMenu.ItemIdentifier` is a `RawRepresentable` struct (the same shape as `UIMenu.Identifier`);
`userInterfaceItemIdentifier` bridges it to the `NSUserInterfaceItemIdentifier` that actually sits
on the `NSMenuItem`, and the chained `.identifier(_:)` modifier accepts it directly.

## Where a Customization Attaches

The `customizing:` parameter is not special to `standard()` (decision record: Evolution
[`0013`](Evolutions/0013-main-menu-factory-customizing.md)). **Every factory that produces a
submenu with more than one row takes it**, and the transformation is scoped to whatever that call
produces — nothing more:

| Level | Entry points |
|---|---|
| Whole bar | `standard(applicationName:customizing:)`, `menu(_:customizing:)` |
| One top-level menu | `application` · `file` · `edit` · `format` · `view` · `window` · `help`, each `(…, customizing:)` |
| One group | `Edit.find` · `Edit.spellingAndGrammar` · `Edit.substitutions` · `Edit.transformations` · `Edit.speech` · `Format.font` · `Format.text`, each `(customizing:)` |

Scope is the point. A transformation written on `MainMenu.file` reads as "the File menu, amended",
and cannot silently reach the Edit menu; the same amendment written on `standard()` is a statement
about the whole bar. Both are available — pick the one that says what you mean:

```swift
app.mainMenu = MainMenu.menu {
    MainMenu.application()
    MainMenu.file { builder in                  // scoped: only the File menu
        builder.remove(.File.pageSetup)
    }
    MainMenu.edit()
    MainMenu.help()
} customizing: { builder in                     // scoped: the whole bar
    builder.remove(.Edit.speech)
}
```

Three contracts:

- **The layers do not leak into each other.** `standard()` builds its seven menus from the *plain*
  factories, so a customization you wrote on `MainMenu.file { … }` elsewhere in your code does not
  appear in `standard()`'s File menu — that is a different File menu object.

- **The menu's own item is addressable.** In a factory-level customization the builder's reach
  includes the item the factory returns, so `builder.item(for: .file)` / `.item(for: .Edit.find)`
  hands it to you. For the seven group factories, which take no `title` parameter, this is the only
  way to retitle them:

  ```swift
  MainMenu.Edit.substitutions { builder in
      builder.item(for: .Edit.substitutions)?.title = "Text Replacement"
  }
  ```

  Note that this retitles the *item*, not the `NSMenu` hanging off it — the `title:` parameter on
  the top-level factories names both. AppKit shows the item's title, so the difference is invisible;
  it is pinned by a test only so a change to either path is a visible one.

- **Four verbs have nowhere to act on that root item**, since nothing within the builder's reach
  contains it. They do nothing, the same silence as addressing an identifier that is not there:

  | Verb | Aimed at the factory's own item |
  |---|---|
  | `item(for:)` | ✅ returns it |
  | `insertItems(_:atStartOf:)` / `insertItems(_:atEndOf:)` | ✅ acts on its submenu |
  | `replaceItems(of:from:)` | ✅ acts on its submenu |
  | `insertItems(_:before:)` / `insertItems(_:after:)` | no-op |
  | `replace(_:with:)` / `remove(_:)` | no-op |

  Everything *inside* the subtree behaves exactly as it does at bar level, orphan-separator
  normalization included.

Three factories deliberately have **no** `customizing:` overload: `Application.services()` (its
submenu is empty — AppKit fills it after wiring, so there would be nothing to address),
`File.openRecent()` (one row), and the ~70 single-item factories (`Edit.undo()` and friends — they
return the item itself, so the chained modifiers already reach everything).

## The Wiring Contract

`MainMenu.xib` marks five submenus with Interface Builder's `systemMenu` attribute. In code that
role assignment has to be done through `NSApplication` / `NSFontManager`, and **it happens at
assembly time** — inside `MainMenu.standard()` and `MainMenu.menu { … }`, which scan the finished
menu for the identifiers in `MainMenu.ItemIdentifier` and wire what they find:

| Menu | Identifier | Wired to |
|------|-----------|----------|
| Services | `.Application.services` | `NSApplication.servicesMenu` |
| Format ▸ Font | `.Format.font` | `NSFontManager.setFontMenu(_:)` |
| Window | `.window` | `NSApplication.windowsMenu` |
| Help | `.help` | `NSApplication.helpMenu` |
| File ▸ Open Recent | `.File.openRecent` | *nothing — see [Open Recent](#open-recent)* |

Consequences worth knowing:

- **Item factories never touch global state.** Creating `MainMenu.window()` without assembling it
  wires nothing. Only the two assembly entry points mutate `NSApplication` / `NSFontManager`.
- **The builder overloads keep the role.** `MainMenu.window { … }` re-attaches the identifier, so a
  rewritten Window menu is still the windows menu.
- **A hand-built menu can opt in.** Attach the matching identifier to your own item and assemble
  through `MainMenu.menu { … }`:

  ```swift
  NSMenuItem("Windows", submenu: myWindowsMenu).identifier(MainMenu.ItemIdentifier.window)
  ```

- **Assembling twice re-wires.** The last assembled menu wins, which is what you want when swapping
  `NSApp.mainMenu` wholesale.
- **The application menu needs no wiring.** AppKit treats the first top-level item of the main menu
  as the application menu.

## What AppKit Adds On Its Own

The standard content deliberately **omits** everything AppKit inserts or maintains by itself.
Don't add these manually — you would get duplicates:

- **Edit menu**: "Start Dictation…" and "Emoji & Symbols" are appended by AppKit (suppress with the
  `NSDisabledDictationMenuItem` / `NSDisabledCharacterPaletteMenuItem` defaults).
- **File menu, in a document-based app**: `NSDocumentController` inserts Open Recent after the
  Open… item, and for autosaving document classes injects Duplicate / Rename… / Move To… /
  Revert To and the Share item around the standard save items — located **by their actions**,
  which is why this library's verbatim selectors matter. See [Open Recent](#open-recent).
- **Window menu**: the open-window list, and on systems that have them, the tab items
  (Show Tab Bar / Show All Tabs) and full-screen tiling items — all driven off
  `NSApplication.windowsMenu`.
- **Help menu**: the help search field comes from `NSApplication.helpMenu`.
- **Services menu**: content is entirely AppKit's once `servicesMenu` is set; the factory ships it
  empty on purpose.
- **Retitling toggles**: Show/Hide Toolbar, Show/Hide Sidebar, Enter/Exit Full Screen retitle
  themselves through validation.
- **Settings naming**: the factory picks "Settings…" on macOS 13+ and "Preferences…" before that,
  matching the system-wide rename.

## Open Recent

The one piece of the template with no public counterpart — and the reason the standard File menu
**does not include it**. The mechanism, pinned down by decompiling macOS 26.6 AppKit
([`Researchs/AppKit-OpenRecentMenu-Internals.md`](../Researchs/AppKit-OpenRecentMenu-Internals.md)):

- The xib's `recentDocuments` marker becomes a private menu *name* (`NSRecentDocumentsMenu`)
  when the nib finishes loading. `NSDocumentController` looks that name up first and, when it
  finds a registered menu, **adopts it** — empties it, rebuilds Clear Menu, and fills the rows
  through its own delegate. That is why a xib's Open Recent never duplicates.
- A code-built menu has no name, so the lookup fails and — in a document-based app —
  `NSDocumentController` inserts **its own** Open Recent right after the item with the
  `openDocument:` action. Shipping one in the standard content produced two Open Recent menus
  side by side (the system's working one with the clock icon, ours a dead duplicate).
- In a non-document app the insertion is skipped entirely (the check requires
  `documentClassNames` to be non-empty), and nothing would ever populate ours.

So: document-based apps get the real Open Recent automatically; non-document apps aren't supposed
to have one. `MainMenu.File.openRecent()` remains available for the one genuine use — a host that
fills the submenu itself from `NSDocumentController.shared.recentDocumentURLs` (e.g. in a
`menuNeedsUpdate(_:)` delegate) — and stays tagged with `ItemIdentifier.File.openRecent`.

## Titles, Names, and Localization

- **Titles default to English**, exactly like the template xib, which also ships only its
  development language. Nothing is localized by the library.
- **Every title is overridable.** Top-level factories take a `title:` parameter (which also renames
  the submenu); single items are renamed with the chained `.title(_:)` modifier from the existing
  menu DSL.
- **The application name** used by the application menu, Hide/Quit items, and "\<App\> Help"
  resolves as: explicit `applicationName:` parameter → localized/base `CFBundleDisplayName` →
  `CFBundleName` → `ProcessInfo.processInfo.processName`.

## Fidelity Notes

Content was taken from a verbatim dump of Xcode's template `MainMenu.xib` (the dump and its
corrections live in Evolution [`0009`](Evolutions/0009-standard-main-menu.md)); `MainMenuTests`
asserts the assembled menus against it. Details that are easy to get wrong by memory:

- File ▸ Print… fires **`print:`**, not `printDocument:`.
- The Find group uses **`performFindPanelAction:`** with the template's hardcoded tags
  (Find… = 1, Find and Replace… = 12, Next = 2, Previous = 3, Use Selection = 7); Jump to
  Selection is `centerSelectionInVisibleArea:`.
- In Format ▸ Font, exactly five items target **`NSFontManager.shared`** directly (Show Fonts,
  Bold = tag 2, Italic = tag 1, Bigger = tag 3, Smaller = tag 4); everything else, including
  Underline and Show Colors, goes to the first responder.
- Text ▸ Writing Direction reproduces the template's two **disabled header items**
  (Paragraph / Selection) and the **tab-prefixed** direction titles (`"\tDefault"`, …).
- Items that carry a submenu report `submenuAction:` as their action — that is AppKit's
  `setSubmenu(_:)` doing it, on the xib path too.
