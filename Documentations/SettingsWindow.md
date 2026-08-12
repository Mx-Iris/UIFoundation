# Settings Window

> A System Settings-shaped window for AppKit apps: a sidebar of pages, grouped forms, and a settings
> model that persists itself. The host writes a `Codable` struct and a list of pages; saving,
> debouncing, loading and change notification come with the box.
>
> Ships behind the opt-in SPM trait `Settings`, in two modules — `UIFoundationSettings` (the model
> layer) and `UIFoundationSettingsUI` (the window). macOS 14+, macOS only.

---

## Contents

- [1. Getting started](#1-getting-started)
- [2. The settings model](#2-the-settings-model)
- [3. Reading and writing settings](#3-reading-and-writing-settings)
- [4. Building the window](#4-building-the-window)
- [5. Page navigation](#5-page-navigation)
- [6. Persistence](#6-persistence)
- [7. What redraws, and when](#7-what-redraws-and-when)
- [8. Contracts and limits](#8-contracts-and-limits)

---

## 1. Getting started

```swift
.package(url: "…/UIFoundation", traits: ["Settings"])   // SPM dependency
swift build --traits Settings                           // CLI
```

```swift
import UIFoundationSettings      // model layer
import UIFoundationSettingsUI    // window layer

struct Settings: PersistentSettings {
    var general = General()
    var appearance = Appearance()

    struct General: Codable, Sendable {
        var confirmsBeforeQuitting = true
        var recentDocumentCount = 10
    }

    struct Appearance: Codable, Sendable {
        var usesLargeText = false
    }

    @MainActor
    static let store = SettingsStore(
        defaultValue: Settings(),
        storage: FileSystemSettingsStorage(applicationDirectoryName: "MyApp")
    )
}

// Collapses the model parameter, so call sites read `@Setting(\.general)`.
typealias Setting<Value> = AppSettings<Settings, Value>
```

```swift
// At launch:
await Settings.store.load()

// Wherever the window is opened from:
let settingsWindowController = SettingsWindowController {
    SettingsPage("General", symbol: "gearshape") { GeneralPage() }
    SettingsPage("Appearance", symbol: "paintpalette", tint: .purple) { AppearancePage() }
}
settingsWindowController.showWindow(nil)
```

A full worked example lives in the demo browser — `UIFoundationExample-macOS`, the **Settings
Window** entry (`Demos/SettingsDemoViewController.swift`): a seven-page settings panel for an
imaginary workbench app in its own window, with a page list that changes with the settings
themselves, and a row of host-side controls that drive the window's navigation from outside it.

**Scoped to its own split view.** Embedding the panel inside an app that has its own sidebar leaves
that sidebar exactly as the host configured it — see [§8](#sidebar-collapsing).

Two modules rather than one because reading settings and *showing* the settings window are separate
jobs: services, coordinators and view models all read settings, while exactly one place opens the
window. A module that only reads settings depends on `UIFoundationSettings` and never pulls in
`NavigationSplitView` or a window controller.

---

## 2. The settings model

Conform a type to `PersistentSettings`; its only requirement is a static `store`.

**The model must be a value type.** Nothing in the type system enforces this and violating it fails
silently — see [§8](#8-contracts-and-limits).

Everything else is ordinary Swift. Use plain property defaults; `Codable` synthesis fills them in
when a stored file predates a newly added field, so adding settings over time needs no migration
plumbing.

```swift
struct Settings: PersistentSettings {
    var general = General()          // added in 1.0
    var indexing = Indexing()        // added in 1.4 — old files decode fine
    …
}
```

---

## 3. Reading and writing settings

**Inside SwiftUI**, use `AppSettings`. It takes a key path of any depth, so a page can bind a whole
section or a single leaf:

```swift
struct GeneralPage: View {
    @Setting(\.general)
    private var general

    @Setting(\.appearance.usesLargeText)
    private var usesLargeText

    var body: some View {
        SettingsForm {
            Section {
                Toggle("Confirm Before Quitting", isOn: $general.confirmsBeforeQuitting)
                Toggle("Use Large Text", isOn: $usesLargeText)
            }
        }
    }
}
```

**Everywhere else**, use `current`:

```swift
if Settings.current.general.confirmsBeforeQuitting { … }
Settings.current.appearance.usesLargeText = true
```

Both reach the same store; there is no environment to inject and no container to register.

> **Assign through `current` itself.** `var copy = Settings.current` followed by mutating `copy`
> changes a copy: nothing is saved, nothing is notified, nothing reports an error.

**Observing changes** outside SwiftUI works through the Observation framework as usual — the read
has to happen *inside* the tracking closure:

```swift
withObservationTracking {
    _ = Settings.current.updates       // must be read in here
} onChange: {
    Task { @MainActor in reapply(); rearm() }
}
```

---

## 4. Building the window

`SettingsWindowController` takes a title, a fixed content width, a minimum height, and the pages:

```swift
SettingsWindowController(title: "Settings", contentWidth: 715, minimumContentHeight: 400) {
    SettingsPage("General", symbol: "gearshape") { GeneralPage() }
    if isDeveloperBuild {
        SettingsPage("Debug", symbol: "ladybug", tint: .red) { DebugPage() }
    }
}
```

The builder supports `if` / `if-else` / `for`, so pages can be conditional.

Each page's `id` defaults to its title. **Pass an explicit `id` whenever the title is localized** —
otherwise the selected page identity changes with the app's language.

`SettingsPage.Icon` has four shapes. Three draw the System Settings badge — `.symbol(_:tint:)`,
`.text("β", tint:)`, `.image(someImage)` — and `.plainSymbol(_:tint:)` draws the glyph on its own,
for a sidebar meant to read as an icon list rather than a grid of coloured tiles:

```swift
SettingsPage("General", id: "general", plainSymbol: "gearshape") { GeneralPage() }
```

`.plainSymbol` is not the same as `.symbol(name, tint: .clear)`: clearing the tint removes the badge
but keeps its shadow, which then lands on the glyph itself.

A symbol name that the running system does not know falls back to an asset catalog image of the same
name, so a host can ship a glyph for a symbol introduced in a newer OS.

The library ships **no singleton**. Hold the controller yourself if the app should reuse one window.

---

## 5. Page navigation

The window carries a back / forward control at the leading edge of the detail pane, in the same place
Xcode and System Settings put theirs, bound to ⌘[ and ⌘]. It walks the history of visited pages.

It is the same control Xcode's settings window uses, produced the same way — one toolbar item holding
a `ControlGroup` in the `.navigation` style:

```swift
ToolbarItem(placement: .navigation) {
    ControlGroup {
        Button(action: goBack) { Label("Back", systemImage: "chevron.backward") }
        Button(action: goForward) { Label("Forward", systemImage: "chevron.forward") }
    }
    .controlGroupStyle(.navigation)
}
```

That spelling is load-bearing: SwiftUI turns it into a momentary, `.separated` `NSSegmentedControl`,
which is where the joined capsule with a divider comes from. A `ControlGroup` *without*
`.navigation` resolves to a native toolbar item with no such control, and two adjacent `ToolbarItem`s
draw as two separate buttons.

Behind them is `SettingsNavigator`, which is also **the single source of truth for which page is on
screen** — so the same object opens the window on a chosen page:

```swift
settingsWindowController.navigator.currentPageID = "updates"
settingsWindowController.showWindow(nil)
```

It is created for you and published as `SettingsWindowController.navigator`. Pass your own to
`SettingsWindowController(navigator:)` / `SettingsRootView(navigator:)` when it should outlive the
window — worth doing if the window is rebuilt on each open, since a fresh navigator means a fresh,
empty history each time.

| Member | Does |
|---|---|
| `currentPageID` | The page on screen. Assigning records a visit. |
| `visitedPageIDs` / `currentHistoryIndex` | The history and the position in it. |
| `canGoBack` / `canGoForward` | What the buttons key their enabled state off. |
| `goBack()` / `goForward()` | Move; return the page moved to, or `nil` at either end. |
| `clearHistory()` | Forget everything but the page on screen. |
| `pruneHistory(keeping:)` | Drop entries for pages that no longer exist. `SettingsRootView` calls this whenever its page list changes; hosts rarely need to. |

Behaviour, matching Xcode and System Settings:

- Picking a page in the sidebar records a visit; picking the one already on screen does not.
- Going back and then picking a new page drops what was ahead, as a browser does.
- Back and forward move the sidebar's highlight and add nothing to the history.
- `currentPageID = nil` is **ignored**. A settings sidebar always has a selection, and `List` writes
  `nil` back when a click lands on empty space.
- The history caps at `SettingsNavigator.maximumHistoryLength` (100) entries, dropping the oldest.

`showsNavigationControls: false` hides the control. **The navigator keeps working** — hiding the
chevrons is a chrome decision, not a way to turn navigation off. An embedded panel is in the same
position for a different reason (see [§8](#sidebar-collapsing)): drive `navigator` from the host's
own controls.

### Sub-pages

Drill-down needs nothing from this library: put a `NavigationStack` in a page's own content and
SwiftUI installs its own back button in the toolbar.

```swift
SettingsPage("General", id: "general", symbol: "gearshape") {
    NavigationStack {
        SettingsForm {
            NavigationLink("Storage…", value: StorageRoute.storage)
        }
        .navigationDestination(for: StorageRoute.self) { _ in StoragePage() }
    }
}
```

That back button is SwiftUI's and is **separate** from `SettingsNavigator` — the navigator tracks
pages, not positions within a page. One pair of chevrons doing both, the way System Settings does it,
would mean hoisting every page's stack path into the root view; see
[Evolution 0003](Evolutions/0003-settings-navigation-history.md#替代方案考量) for why that was left
out.

---

## 6. Persistence

`SettingsStore` owns the value and writes it back a short while after it changes, coalescing a burst
of edits into a single write. Hosts never call save.

| Concern | Behaviour |
|---|---|
| Where | `FileSystemSettingsStorage(applicationDirectoryName:)` → `~/Library/Application Support/<name>/Settings.json`. `init(fileURL:)` writes anywhere else; conform `SettingsStorage` to persist somewhere other than a file. |
| When | `autoSaveDelay` after the last change (default 1 s). `save()` writes immediately and cancels the pending write — call it when terminating. |
| Loading | `await store.load()` once at launch. It replaces the value **without** triggering a save. |
| Missing file | Not an error: `load()` returns `.noStoredData` and the default value stays in effect. |
| Corrupt file | `load()` returns `.failed(error)`, keeps the defaults, and **leaves the stored bytes alone** so a later build can still recover them. |

`load()`'s result is `@discardableResult`; take it when you want to log which of the three happened.

**Migrations need no API.** Run them after `load()` returns — mutating the value there takes the
normal path, so the migrated result saves itself:

```swift
await Settings.store.load()
migrateLegacyFontSizeIfNeeded()   // writes through Settings.current
```

---

## 7. What redraws, and when

Redraws come from Observation, not from this library: SwiftUI evaluates `body` inside an
observation-tracking scope, so reading the store there registers the dependency. Consequently:

- `AppSettings` **does not conform to `DynamicProperty`**, on purpose. Measured three ways — a
  conforming wrapper, a non-conforming one, and a view reading the store directly — all redraw
  identically. The conformance would only suggest it is load-bearing when it is not.
- A view that reads settings outside the settings window updates too, with no wiring. The demo's
  live mirror panel is exactly this.

**Invalidation is coarse, by design of the value-type model.** Tracking lands on the store's `value`
property as a whole, so **any** settings change invalidates **every** view that reads settings —
including views reading an unrelated field. Measured with three panels side by side:

| Panel | Edit to `appearance` | Edit to `general` |
|---|---|---|
| reads `\.general` | re-evaluates | re-evaluates |
| reads `\.appearance` | re-evaluates | re-evaluates |
| reads no settings | untouched | untouched |

So the blast radius is "every view that reads settings", **not** the whole view tree — a view that
never touches the store is unaffected. The **Settings Window** demo shows this live with counters.

In a settings window this costs nothing: one page is on screen, edits happen at human speed. It can
matter if a hot path in the main UI reads settings directly. If that comes up, in increasing order
of effort: hoist the value into the view's own `@State`, cache a snapshot outside the view, or
revisit the trade-off recorded in
[Evolution 0002](Evolutions/0002-reusable-settings-window.md#替代方案考量).

---

## 8. Contracts and limits

**The settings model must be a value type.** Auto-saving hangs off `value`'s `didSet`, which only
fires when the property is assigned. With a struct, `store.value.general.x = 1` reads-modifies-writes
the whole property and saves. With a class it mutates the object in place, `didSet` never fires, and
**settings are silently never written to disk**. There is no compiler diagnostic for this.

**macOS 14+.** `@Observable` sets the floor. The package still deploys to macOS 10.15, so every
symbol here is `@available(macOS 14, *)`; a host on an older target gates the settings window behind
`if #available`.

**Do not name the host's model `AppSettings`.** That name belongs to the property wrapper this module
exports. Naming the model `Settings` (and aliasing the wrapper) avoids the collision.

**One store per model type.** The store is reached through the type, so a model type has exactly one
store per process. For settings that is the point; a second, independent set of settings means a
second model type.

**iOS is not supported.** Both modules are macOS-only. The model layer happens not to import AppKit,
but it is not conditionally compiled or tested for other platforms, and it is not exported there.

### Sidebar collapsing

The sidebar cannot be collapsed, and the toolbar toggle that would collapse it is hidden. Both are
applied to SwiftUI's own split view controller, which is reachable **only as the `NSSplitView`'s
delegate** — it is not a child of the hosting controller. `canCollapse = false` sticks: verified on
macOS 26 across a run-loop pass, a SwiftUI update and a window resize. No swizzling is involved, and
none should be added.

**The chrome is scoped to the settings UI's own split view**, which matters as soon as the panel is
embedded: a host with its own sidebar keeps it collapsible. Getting that scope right is fiddlier than
it looks, because SwiftUI puts a `.background()` view *outside* the `NavigationSplitView`'s own
`NSSplitView` — so looking upward finds the **host's** split view, and searching the window downward
finds both. The implementation walks outward one ancestor at a time, searches each subtree, stops at
the first level that yields a split view, and excludes any split view that is an ancestor of itself
(containing the settings UI is what makes a split view the host's rather than ours).

SwiftUI does install a toolbar for the settings window, and hiding the toggle in it works — measured
on macOS 26.5.2. The one case with nothing to find is the panel **embedded** in a host window: not
being the window's `contentViewController`, SwiftUI owns no toolbar there, and `window.toolbar` is
`nil`. That is also why an embedded panel shows no back / forward buttons even with
`showsNavigationControls` on — `navigator` still works, so drive it from the host's own controls.

`SettingsWindowChromeTests` guards the collapsing behaviour against future SwiftUI changes, and
`SettingsNavigationControlsTests` guards that the navigation control reaches the toolbar at all, and
that it is still the control Xcode uses.
