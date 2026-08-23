# WelcomePanel

> The Xcode-style welcome window for macOS: the app icon, its name and version above a short action
> list on the left, a recent-project list on the right. Three styles imitate three Xcode generations.
>
> Ported from [Mx-Iris/WelcomeKit](https://github.com/Mx-Iris/WelcomeKit).
> Ships behind the opt-in SPM trait `WelcomePanel`. macOS 11+ only.

---

## Contents

- [1. Getting started](#1-getting-started)
- [2. Styles](#2-styles)
- [3. The project list is pulled, not pushed](#3-the-project-list-is-pulled-not-pushed)
- [4. Contracts a host has to know](#4-contracts-a-host-has-to-know)
- [5. Known issues](#5-known-issues)
- [6. Changes from the original package](#6-changes-from-the-original-package)
- [7. How this is verified](#7-how-this-is-verified)

---

## 1. Getting started

```swift
.package(
    url: "https://github.com/Mx-Iris/UIFoundation",
    from: "0.13.0",
    traits: ["WelcomePanel"]
)
```

```swift
import UIFoundation

final class AppDelegate: NSObject, NSApplicationDelegate {
    private lazy var welcomePanel: WelcomePanelController = {
        var configuration = WelcomePanelController.Configuration(style: .xcode15)
        configuration.primaryAction = .init(
            image: NSImage(systemSymbolName: "plus.square", accessibilityDescription: nil),
            title: "Create New File…",
            action: { _ in NSDocumentController.shared.newDocument(nil) }
        )
        configuration.secondaryAction = .init(
            image: NSImage(systemSymbolName: "folder", accessibilityDescription: nil),
            title: "Open File or Folder…",
            action: { _ in NSDocumentController.shared.openDocument(nil) }
        )

        let controller = WelcomePanelController(configuration: configuration)
        controller.dataSource = self
        controller.delegate = self
        return controller
    }()

    func applicationDidFinishLaunching(_ notification: Notification) {
        welcomePanel.showWindow(nil)
    }
}

extension AppDelegate: WelcomePanelController.DataSource {
    // `true` takes the list straight from NSDocumentController — the two methods
    // below are then never called.
    func welcomePanelUsesRecentDocumentURLs(_ welcomePanel: WelcomePanelController) -> Bool { true }
    func numberOfProjects(in welcomePanel: WelcomePanelController) -> Int { 0 }
    func welcomePanel(_ welcomePanel: WelcomePanelController, urlForProjectAtIndex index: Int) -> URL {
        fatalError("unreachable while the recent-documents path is on")
    }
}

extension AppDelegate: WelcomePanelController.Delegate {
    func welcomePanel(_ welcomePanel: WelcomePanelController, didCheckShowPanelWhenLaunch isCheck: Bool) {}
    func welcomePanel(_ welcomePanel: WelcomePanelController, didSelectProjectAtIndex index: Int) {}
    func welcomePanel(_ welcomePanel: WelcomePanelController, didDoubleClickProjectAtIndex index: Int) {
        // open the project at that index
    }
}
```

Everything is nested under one top-level symbol: `WelcomePanelController.Configuration` / `.Style` /
`.Action` / `.DataSource` / `.Delegate`.

`Configuration` is all optionals plus a style. A `nil` text, font or color falls back to that
style's own default — which for the two labels means the host bundle's `CFBundleName` and
`CFBundleShortVersionString`, and for the icon means `NSApplication.shared.applicationIconImage`.
There are exactly three action slots: `primaryAction`, `secondaryAction`, `tertiaryAction`; the nil
ones are dropped and the rest keep that order.

---

## 2. Styles

| | `.xcode14` | `.xcode15` | `.xcode26` |
|---|---|---|---|
| Window | titled, full-size content | borderless, 8 pt radius | borderless, 8 pt radius |
| Size | 800 × 460 | 740 × 460 | 740 × 460 |
| Backdrop | opaque | `NSVisualEffectView` behind the content | none — plain background |
| Project pane | 307 pt | 280 pt | 280 pt |
| Action rows | 46 pt, icon + title + subtitle | 36 pt rounded pills, title only | 36 pt rounded pills, title only |
| "Show on launch" checkbox | yes | no | no |
| Close button | fades in on hover, asset image | always visible, SF Symbol | **none — see [known issues](#5-known-issues)** |

`.xcode15` and `.xcode26` share every measurement; the only difference is the vibrancy backdrop,
which `.xcode26` drops.

---

## 3. The project list is pulled, not pushed

There is no "the list changed" call to make in the common case. The panel re-asks the data source:

- when `dataSource` is assigned,
- on every `showWindow(_:)`,
- whenever the window's occlusion state turns visible (switching spaces, un-minimising, coming back
  from another app).

`reloadData()` exists for the case those moments do not cover — a list that changes while the panel
is already on screen and in front.

---

## 4. Contracts a host has to know

Each of these fails quietly rather than loudly.

**4.1 The window is not reachable.** `window` and `contentViewController` are marked
`@available(*, unavailable)`, so `panel.window?.center()` does not compile. Use `showWindow(_:)` and
`close()`. This is inherited from the original library and kept deliberately — the panel owns its
own chrome, geometry and position.

**4.2 A negative project count is clamped to zero.** `numberOfProjects(in:)` returning a negative
number yields an empty list instead of trapping. Nothing is logged.

**4.3 The recent-documents path skips the other two methods entirely.** Returning `true` from
`welcomePanelUsesRecentDocumentURLs(_:)` means `numberOfProjects(in:)` and
`welcomePanel(_:urlForProjectAtIndex:)` are never called; the list is
`NSDocumentController.shared.recentDocumentURLs`, which is empty in a non-document app.

**4.4 The "show this window on launch" checkbox only exists under `.xcode14`.** Under the other two
styles `welcomePanel(_:didCheckShowPanelWhenLaunch:)` never fires. A host that wants the setting
under those styles has to put the control somewhere else.

**4.5 Persisting the checkbox is the host's job.** `Configuration.checkShowOnLaunch` is only the
initial state; the panel reports changes through the delegate and stores nothing.

**4.6 Actions fire on mouse-up over the row, not through the table's selection.** The action list
has `selectionHighlightStyle = .none` and no target/action of its own — each cell calls back
directly. A row therefore never looks selected, by design.

**4.7 Row indices are indices into whichever list is in force.** `didSelectProjectAtIndex` /
`didDoubleClickProjectAtIndex` carry the row index, and a double click on empty space reports
`-1` (AppKit's `clickedRow` for "no row"). Guard for it.

---

## 5. Known issues

Two gaps were carried over verbatim from the original library (see Evolution
[`0011`](Evolutions/0011-welcome-panel.md) — porting and bug-fixing were kept apart on purpose so
that "is the port faithful?" stayed answerable). Both are specific to `.xcode26`, which was added
upstream by appending `, .xcode26` to every `case .xcode15:` — two equality checks were missed:

1. **The close button has no icon under `.xcode26`.** It is still there and still works; it is just
   invisible. `.xcode15` sets `xmark.circle.fill`, `.xcode14` uses the bundled asset, `.xcode26`
   sets neither.
2. **Pressing an action row gives no highlight under `.xcode26`.** The click still fires; only the
   pressed-state background is missing.

Both are pinned by canary tests in `WelcomePanelTests` (named `KNOWN GAP: …`). Fixing either one
means updating those tests and this section in the same batch.

Smaller oddities kept as they were, listed so nobody "fixes" them by accident:

- `windowNibName` returns `""` — the window is built in `loadWindow()`, so no nib is ever looked up.
- The window is constructed with an empty style mask and gets its real one in `windowDidLoad()`.
- The action cell's `mouseDown` / `mouseUp` do not call `super`.
- Two tracking areas are created with `rect: .zero` plus `.inVisibleRect`; AppKit ignores the rect in
  that mode, so this works — it just reads as a mistake.

One environment-dependent gap that is **not** a bug in the panel: the `.xcode14` close button's two
images come from the package's asset catalog, and command-line `swift build` / `swift test` do not
run `actool`. In a pure CLI build the images resolve to `nil` and the button draws empty. Apps built
through Xcode are unaffected. This is the same trade-off the Filter resources already carry.

---

## 6. Changes from the original package

The port is behaviour-for-behaviour identical. What changed is shape and plumbing:

- **Namespace.** The six top-level names became one: `WelcomeConfiguration` →
  `WelcomePanelController.Configuration`, `WelcomeStyle` → `.Style`, `WelcomeAction` → `.Action`,
  `WelcomePanelDataSource` / `WelcomePanelDelegate` → `.DataSource` / `.Delegate`. Internal helpers
  (`HoverButton`, the two side view controllers, the two cell views, the scroll view, the window)
  are nested too, so they do not crowd `UIFoundationAppKit`'s module scope. No `typealias` is
  provided for the old names — they never existed in this library.
- **Base classes.** The library's own `LayerBackedView`, `LayerBackedTableCellView`,
  `XiblessViewController`, `ScrollView`, `Then`, `makeConstraints`, `.box.addSubview(_:fill:)`,
  `.box.makeView(ofClass:)` and `.box.isDark` replaced the duplicates the original shipped —
  about 500 of its 1444 lines, four of which collided outright with this library's top-level names.
- **Corner clipping is now explicit.** The original clipped whenever `cornerRadius != 0`; this
  library's `LayerBackgroundRenderer` clips on `clipsToBounds`, whose default is `false` for
  anything linked against macOS 14 or later. The rounded container and the pill cells therefore set
  `clipsToBounds = true` themselves. Removing those lines gives square corners on a borderless
  window.
- **The scroll view keeps painting through its layer.** `NSScrollView` already owns a
  `backgroundColor` property, so this one cannot ride `LayerBackgroundProviding` — a
  protocol-extension property of the same name is shadowed by the class one at every call site.
  `BackgroundScrollView` overrides the class property instead, exactly as the original did.
- **Dead code dropped**: `TrackView`, `NSLayoutEdgesAnchor` / `NSView.edgesAnchor`,
  `[NSLayoutConstraint].active()`, `NSEdgeInsets.zero`, and the original's own unused
  `NSTableView.makeView(ofClass:owner:)` — all were defined and referenced nowhere.
- **Assets renamed.** `close` / `close_hover` became `WelcomePanelCloseButton` /
  `WelcomePanelCloseButtonHovered`, since they now live in a catalog shared with the rest of
  `UIFoundationAppKit`.
- **Deployment floor.** The original package declared macOS 12 without using any macOS 12 API; the
  ported types are annotated `@available(macOS 11.0, *)`, which is what `NSTableView.style`,
  `NSAppearance.currentDrawing()` and the SF Symbol initialisers actually require.

---

## 7. How this is verified

`Tests/UIFoundationTests/WelcomePanelTests.swift` (13 tests, gated on the trait) pins the style
geometry table, the window chrome per style, `allActions` ordering, the three data-source contracts
from [§4](#4-contracts-a-host-has-to-know), the cells' reuse identifiers, fonts and pill geometry,
and the two known gaps.

What a test cannot judge is the look. The example app's **Welcome Panel** demo opens each style in a
real window and lists the four things only a human can check — corner clipping, the `.xcode14` hover
fade, the two `.xcode26` gaps, and the double-click / context-menu paths.

---

## Further reading

- Evolution [`0011`](Evolutions/0011-welcome-panel.md) — why the port looks like this, and what it
  deliberately did not fix.
