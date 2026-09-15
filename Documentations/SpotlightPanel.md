# SpotlightPanel

> A replica of macOS 26's Spotlight panel — the floating translucent platter with a query field
> that grows downwards into a result list. Placement, springs, scale, content blur and sizing
> rules are all reproduced from measurements of Spotlight's own binary, not eyeballed.
>
> **It does not search anything.** The host supplies results; this is the shell.
>
> Ships behind the opt-in SPM trait `SpotlightPanel`, which enables `AppleInternal` and
> `Navigation` with it. macOS only.

---

## Table of Contents

- [1. Getting started](#1-getting-started)
- [2. Data source and delegate](#2-data-source-and-delegate)
- [3. Contracts a host has to know](#3-contracts-a-host-has-to-know)
- [4. Geometry](#4-geometry)
- [5. Sizing](#5-sizing)
- [6. The animation](#6-the-animation)
- [7. The keyboard table](#7-the-keyboard-table)
- [8. Known divergences from Spotlight](#8-known-divergences-from-spotlight)

---

## 1. Getting started

```swift
.package(url: "…/UIFoundation", traits: ["SpotlightPanel"])
```

```bash
swift build --traits SpotlightPanel
```

```swift
import UIFoundation

final class CommandPaletteController: NSObject {
    private let spotlightPanel = SpotlightPanel(
        configuration: .init(placeholderText: "Search commands")
    )

    override init() {
        super.init()
        spotlightPanel.dataSource = self
        spotlightPanel.delegate = self
    }

    func show() {
        spotlightPanel.present()
    }
}
```

`present(on:initialSearchTerm:)` builds the window, places it, animates it in and issues the first
search. `dismiss()` animates it out and tears it down. There is no window object to reach — the
panel owns it.

The trait pulls in `AppleInternal` because the dismissal blur is private API, and `Navigation`
because later phases host sub-pages in this library's navigation stack. Enabling
`SpotlightPanel` alone is enough; the other two come with it.

---

## 2. Data source and delegate

`SpotlightPanelDataSource` has three methods, one of which has a default:

```swift
func spotlightPanel(_ panel: SpotlightPanel, itemsForSearchTask task: SpotlightPanel.SearchTask)
func spotlightPanel(_ panel: SpotlightPanel, viewForItem item: AnyHashable, searchTerm: String) -> NSView?
func spotlightPanel(_ panel: SpotlightPanel, platterBehaviorForItems items: [AnyHashable], searchTerm: String)
    -> SpotlightPanel.PlatterBehavior   // defaulted
```

Items are `AnyHashable` identifiers; the panel never inspects them. Complete a `SearchTask`
synchronously for a cheap search:

```swift
func spotlightPanel(_ panel: SpotlightPanel, itemsForSearchTask task: SpotlightPanel.SearchTask) {
    task.complete(with: commands.filter { $0.matches(task.searchTerm) })
}
```

or hold it and complete it later, from any thread:

```swift
func spotlightPanel(_ panel: SpotlightPanel, itemsForSearchTask task: SpotlightPanel.SearchTask) {
    searchQueue.async {
        let results = expensiveSearch(task.searchTerm)
        task.completeFromBackgroundThread(with: results)
    }
}
```

A task the panel has moved past reports `isCancelled`, and completing it is a no-op — out-of-order
answers sort themselves out, so a host does not track staleness.

`SpotlightPanelDelegate` is entirely defaulted. The ones most hosts want:

```swift
func spotlightPanel(_ panel: SpotlightPanel, didActivateItem item: AnyHashable) -> Bool
func spotlightPanel(_ panel: SpotlightPanel, didSelectItem item: AnyHashable)
func spotlightPanelDidCancel(_ panel: SpotlightPanel)
```

`didActivateItem` returns whether the panel should dismiss afterwards — return `false` to keep it
open for a command that refines the query.

---

## 3. Contracts a host has to know

All five fail quietly rather than loudly.

1. **The panel closes when it stops being key, by default.** Spotlight does the opposite: it
   leaves `hidesOnDeactivate` off and relies on ⌘Space to come back. A library panel usually has
   no such hotkey, so `Configuration.dismissesWhenResigningKey` defaults to `true`. Set it to
   `false` if the host drives dismissal itself — and then remember that clicking away leaves the
   panel up.

2. **Result views are built on demand and not reused.** `viewForItem:` is called from
   `NSTableView`'s delegate without a reuse identifier, so returning a freshly built view per call
   is correct. Do not cache views keyed by row: rows move.

3. **Panel width and standard expanded height are choices, not measurements.** Both of
   Spotlight's own values resolve through `SpotlightUIShared`, which the reverse engineering did
   not cover (see the research note's §9). The defaults — 680 wide, 430 tall — place the panel
   close to the original but are not it. Everything else in `Metrics` *is* measured.

4. **The content blur degrades silently.** `NSWindow._setContentBlurRadius:` is private. If a
   future AppKit drops it, `SpotlightPanel.isContentBlurSupported` goes false and the
   dismissal animates scale and opacity only. Nothing throws and nothing logs at error level.

5. **Reduce Motion skips both animations entirely**, writing the end state directly. A host that
   times anything off the presentation should use the completion, not a duration.

---

## 4. Geometry

Every default in `SpotlightPanel.Metrics` except `standardWidth` and `standardExpandedHeight` came
out of Spotlight's `SearchConstants`:

| Property | Default | Spotlight |
|---|---|---|
| `collapsedHeight` | 56 | measured |
| `minimumExpandedHeight` | 430 | measured |
| `cornerRadius` | 28 | measured |
| `animationPadding` | 40 | measured |
| `horizontalContentInset` | 20 | measured |
| `separatorHeight` | 1 | measured |
| `standardWidth` | 680 | **chosen** |
| `standardExpandedHeight` | 430 | **chosen** |
| `resultSelectionCornerRadius` | 10 | **chosen** |
| `resultSelectionHorizontalInset` | 8 | **chosen** |

**The selected row is drawn by this library, not by AppKit.** The system's emphasised selection
paints `selectedContentBackgroundColor` — the user's accent colour — edge to edge and square,
which on a glass platter reads as a coloured bar stamped across the panel and changes colour as
focus moves. Spotlight's is a neutral rounded band, inset from the edges, that looks the same
whether or not the panel is key. `ResultRowView` reproduces that and forces `isEmphasized` to
`false`, which is also what keeps a row's text colour usable against a light-grey band in the
light appearance. The two numbers above are the band's geometry; both are chosen rather than
measured, because Spotlight draws its rows from `SearchUI`, a private framework the reverse
engineering did not cover.

The rule under the query field stops short of the panel's edges by
`horizontalContentInset`, matching Spotlight; it does not run the full width.

**Placement is the part worth understanding**, because it is not what it looks like:

```swift
y = screen.minY + (screen.height + standardExpandedHeight) / 2 − windowHeight
```

The panel's **top edge** is pinned to where a `standardExpandedHeight`-tall window's top edge
would be if that window were centred — and it stays there no matter how tall the panel currently
is. So the panel sits high while collapsed and arrives at dead centre once expanded. Centring the
window instead, or keeping the collapsed position and growing downwards, both look wrong beside
the original.

`Configuration.searchFieldLeadingSymbolName` puts an SF Symbol at the leading edge of the query
field — `"magnifyingglass"` by default, as Spotlight has. Set it to `nil` for a bare field.

`animationPadding` is a transparent margin on all four sides of the window, not part of the
platter. The present and dismiss animations scale the platter up to 1.12, and without that margin
the growth would be clipped by the window edge.

**That margin is also why the window has to be borderless.** Anything the window draws at its own
bounds appears as a second rounded rectangle 40 points outside the platter, and the panel reads as
two stacked platters. `.titled` draws exactly that: a titled window is a real framed window, so
the window server strokes its own rounded frame at the window rect and shapes the shadow to it
rather than to the content. It is a tempting flag — it does give a heavier drop shadow, which is
why it shipped for one round — and it is measurable: with `.titled` the panel's
`contentLayoutRect` came back 32 points shorter than its content rect, because the window also
reserves a titlebar. Borderless gets the shadow the right way instead, derived from the
composited alpha, so it hugs the platter and follows the present / dismiss scale.

One consequence to keep in mind before touching `Panel`: a borderless `NSWindow` returns `false`
from `canBecomeKey`, so the override on `SpotlightPanel.Panel` is the only thing that lets the
query field take focus. Under `.titled` that override merely restated the default; now it is
load-bearing. `SpotlightPanelWindowChromeTests` guards all of this.

---

## 5. Sizing

`PlatterBehavior` is this library's form of Spotlight's `ResultPlatterBehavior`: the data source
returns one per response, and the panel resolves it into a height.

```swift
func spotlightPanel(
    _ panel: SpotlightPanel,
    platterBehaviorForItems items: [AnyHashable],
    searchTerm: String
) -> SpotlightPanel.PlatterBehavior {
    guard !items.isEmpty else { return .collapsed }
    return .list(minimumHeight: 120, maximumHeight: 520, heightCanPersist: true)
}
```

The fields that change behaviour rather than numbers:

- **`heightCanPersist`** keeps the height the panel settled on when the next response is shorter.
  This is what stops a list that arrives in several passes from jumping short and tall again.
- **`collapsesForEmptyResponse`** — turn it off when the host shows its own "no results" row,
  which still needs the panel open.
- **`isAnimated`** — a response that only reorders existing rows can set this to `false` and skip
  the resize settle.

`includesFilterBarHeight` is reserved for the filter bar, which is not in this phase, and is
always `false`.

Resize requests are debounced separately from the search itself
(`Configuration.sizingDebounceDelay`, default 0.05 s, against `searchDebounceDelay`'s 0.2 s).
Spotlight keeps the same two timers apart for the same reason.

`expansionState` reports `uninitialized` / `collapsed` / `expanding` / `expanded`. The two
transitional cases exist because a second resize arriving mid-animation has to be coalesced rather
than acted on.

---

## 6. The animation

Three curves, and the relationships between them are the effect:

| | layer scale | window `alphaValue` | window content blur |
|---|---|---|---|
| **Present** | 1.12 / 0.95 → 1.0, spring(0.28, bounce 0.41 / 0.32) | 0 → 1, spring(0.28, 0.41) | not animated |
| **Dismiss** | 1.0 → 1.12 / 0.95, spring(0.45, 0.05) | 1 → 0, spring(0.28, 0.41) | 0 → 25, spring(0.51, 0.05) |

Three things are deliberate and are asserted by `SpotlightPanelAnimationTests`:

- **The scale is not uniform.** 1.12 wide against 0.95 tall, so the panel spreads sideways as it
  leaves rather than swelling. The two axes also carry different `bounce` values on the way in.
- **The blur curve is nearly twice as slow as the opacity curve.** That gap is why the panel goes
  soft before it goes away; matching the durations collapses it into an ordinary fade.
- **Only dismissal blurs.** Presenting starts at zero blur and never animates it.

`present()` called during a dismissal **reverses it in place**, picking the starting state off the
presentation layer, rather than building a second panel. That is what makes a double-tap of a
host's hotkey feel continuous.

Before macOS 14 there is no `CASpringAnimation(perceptualDuration:bounce:)`; the fallback is the
documented conversion to a mass/stiffness/damping triple, not an approximation.

---

## 7. The keyboard table

The query field never gives up first responder — typing has to keep working while the arrow keys
drive the list — so the commands arrive through the field editor.

| Key | Behaviour |
|---|---|
| ↑ / ↓ | Move the selection, skipping unselectable rows |
| Return | Activate the selection |
| Escape | Dismiss |
| Tab / Shift-Tab | Forwarded to `didPressTabForward:`; return `true` to consume |
| → | Drill in, but **only when the caret is already at the end of the query**, so it keeps working as a cursor key |
| ← | Left to the field editor |
| ⌘C | `didRequestCopyForItem:`, but **only when the field has no selected text** — with text selected the user means the text |
| ⌘Y | `didRequestQuickLookForItem:` |
| Delete, ⌘A, ⌘V | Left to the field editor |

---

## 8. Known divergences from Spotlight

- **Quick Look is ⌘Y, not Space.** Spotlight has a results pane that can take focus away from its
  query field; this panel does not, so Space has to stay a space.
- **No filter bar, no search history, no navigation stack yet.** Phases two and three of the
  decision record.
- **No preview pane, ever.** An explicit non-goal.
- **No system hotkey takeover.** Spotlight claims ⌘Space through a second window-server
  connection and `CGSSetSymbolicHotKeyWithExclusion`. That is a process-wide effect and does not
  belong in a UI component; a host wanting a global hotkey should register one itself.
- **The expand / collapse resize curve is this library's**, not Spotlight's — that one curve was
  not recovered. It is `Configuration.resizeAnimationDuration` on an ease-in-ease-out.

---

**Decision record:** [`Evolutions/0021-spotlight-panel-replica.md`](Evolutions/0021-spotlight-panel-replica.md)
**Reverse engineering:** [`Researchs/Spotlight-Panel-Internals.md`](../Researchs/Spotlight-Panel-Internals.md)
