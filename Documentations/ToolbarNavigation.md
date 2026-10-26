# ToolbarNavigation

> `NSToolbar.Navigation` — a Safari-style back / forward pair, as a single toolbar item.
>
> AppKit ships no navigation item of its own, so every app that wants one assembles a two-segment
> `NSSegmentedControl` by hand. This type does the assembly and holds two invisible AppKit
> behaviours in place along the way.
>
> Part of `UIFoundationAppKit`'s toolbar DSL. macOS only, no trait, no private API.
> Design record: [Evolution 0004](Evolutions/0004-appkit-navigation-toolbar-item.md).

---

## Contents

- [1. Getting started](#1-getting-started)
- [2. The data source is pulled, not pushed](#2-the-data-source-is-pulled-not-pushed)
- [3. Contracts a host has to know](#3-contracts-a-host-has-to-know)
  - [3.1 Index 0 is the nearest entry](#31-index-0-is-the-nearest-entry)
  - [3.2 The two cheap questions run on the event loop](#32-the-two-cheap-questions-run-on-the-event-loop)
  - [3.3 Refresh is not immediate while the window is not key](#33-refresh-is-not-immediate-while-the-window-is-not-key)
- [4. What the item handles so a host does not](#4-what-the-item-handles-so-a-host-does-not)
- [5. The appearance is fixed](#5-the-appearance-is-fixed)
- [6. Keyboard shortcuts](#6-keyboard-shortcuts)
- [7. Known limits](#7-known-limits)
- [8. How this is verified](#8-how-this-is-verified)
- [9. The toolbar item base classes](#9-the-toolbar-item-base-classes)

---

## 1. Getting started

No trait and no import beyond the umbrella:

```swift
import UIFoundation

let navigationItem = NSToolbar.Navigation()
navigationItem.dataSource = self
navigationItem.delegate = self

window.toolbar = NSToolbar {
    navigationItem
    NSToolbar.box.flexibleSpace
}
```

The smallest useful host implements two methods and gets working chevrons:

```swift
extension BrowserWindowController: NSToolbar.Navigation.DataSource,
                                   NSToolbar.Navigation.Delegate {

    func navigationToolbarItem(
        _ item: NSToolbar.Navigation,
        canNavigateIn direction: NSToolbar.Navigation.Direction
    ) -> Bool {
        switch direction {
        case .backward: currentIndex > 0
        case .forward:  currentIndex < visitedPages.count - 1
        }
    }

    func navigationToolbarItem(
        _ item: NSToolbar.Navigation,
        didNavigateIn direction: NSToolbar.Navigation.Direction
    ) {
        currentIndex += (direction == .backward ? -1 : 1)
        showCurrentPage()
    }
}
```

Everything else on the data source has a default that means *no history menu*. Adding
`numberOfHistoryEntriesIn` and `historyEntryAt:in:` turns on the long-press menus; adding
`didSelectHistoryEntryAt:in:` on the delegate receives a choice from one.

A complete worked example — a pretend documentation site with a visit list, a cursor and per-row
icons — is the **Toolbar Navigation** demo in `UIFoundationExample-macOS`. It opens a window of its
own, since the demo browser's detail pane has no toolbar, and lists the four checks only a human can
perform — the long press being the main one.

---

## 2. The data source is pulled, not pushed

There is no `reloadHistory()`, and its absence is the point.

`NSToolbarItem` already validates itself on the toolbar's validation cycle. `NSToolbar.Navigation`
uses that cycle to re-ask the data source whether each direction is live and how deep its history
is, then updates the segments and attaches or detaches each menu. A host that changes its own
history therefore has nothing to remember to call — and cannot forget.

The row *contents* are pulled later still, in `menuNeedsUpdate(_:)`, only while a menu is actually
opening. That split is deliberate: resolving an icon per row is common and must not land on the
event loop, while whether a menu exists at all has to be settled *before* the press, because
attaching `nil` is what makes a direction have nothing to open.

```
validation cycle   →  canNavigateIn        →  segment enabled / disabled
                   →  numberOfHistoryEntriesIn →  menu attached / detached
long press         →  historyEntryAt:in:   →  the rows
```

---

## 3. Contracts a host has to know

### 3.1 Index 0 is the nearest entry

Both `historyEntryAt:in:` and `didSelectHistoryEntryAt:in:` count outward from the current
position, in the direction being asked about. Index 0 is the entry a *single click* of that segment
would land on — Safari's ordering, most recent at the top of the back menu.

Getting this backwards does not fail, it just produces a menu that reads plausibly and jumps to the
wrong page. The usual shape:

```swift
private func historyIndex(forEntryAt entryIndex: Int, in direction: NSToolbar.Navigation.Direction) -> Int {
    switch direction {
    case .backward: currentIndex - 1 - entryIndex
    case .forward:  currentIndex + 1 + entryIndex
    }
}
```

### 3.2 The two cheap questions run on the event loop

`canNavigateIn` and `numberOfHistoryEntriesIn` are asked on every validation pass, which is
frequent. Answer both from state you already have — an index compared against an array's count,
typically. Anything that touches the file system, decodes an image or walks a document tree belongs
in `historyEntryAt:in:`, which is only reached while a menu opens.

Violating this produces no error, only a toolbar that makes the whole window feel heavy.

### 3.3 Refresh is not immediate while the window is not key

The validation cycle only runs for a visible item in an active toolbar. A history change made while
the window is not key reaches the control when it becomes key again, which is soon enough for
anything a user can see. A host that needs an exact moment — a screenshot, a test — can call
`validate()` directly; it is `open` and public.

---

## 4. What the item handles so a host does not

Two AppKit behaviours are held in place structurally rather than by a comment:

| Behaviour | How it is held |
|---|---|
| A segment menu opens on a *click* rather than a long press when the control's action is `nil` — single-step navigation silently disappears. | The control is internal and nothing forwards to it, so `target` / `action` are wired once in `init` and there is no typed door to reach them through. |
| An empty `NSMenu` still pops, as a blank box. | An empty direction gets `setMenu(nil, forSegment:)`, never a menu with no rows. |

A third, often repeated alongside them, **did not reproduce**: attaching a menu does not raise a
pull-down indicator on the segment. Measured on macOS 26 — `showsMenuIndicator(forSegment:)` reads
`false` on a fresh control and stays `false` across `setMenu(_:forSegment:)`. The item still turns it
off once, as a statement of the intended look, but it is not repaired per attachment.
`ToolbarNavigationItemTests` keeps a canary on this so a future release changing it shows up as a
failure rather than as a stray arrow.

---

## 5. The appearance is fixed

There is no styling API, and the `NSSegmentedControl` behind the item is internal. A navigation pair
has one correct look, and the door a host would reach through is the same one that holds the first
contract in place — hand the control out "for styling" and its `target` / `action` go with it. So
don't add a `segmentStyle` / `controlSize` passthrough "for flexibility": the control it would
forward to is the one carrying the action.

One caveat, stated rather than glossed: AppKit needs the view on the toolbar item, so
`navigationItem.item.view` still leads to the control for anyone who casts it. No design can close
that; what is closed is the typed, inviting door nobody opens by accident. Reaching through it and
assigning an action is unsupported and breaks the long-press menus.

What is settled, and not negotiable:

- Two segments, `.momentary` tracking, `.separated` bezel — what the system's own navigation
  controls wear on macOS 11 and later.
- `chevron.backward` / `chevron.forward` on macOS 11+, which mirror themselves under a
  right-to-left layout. `chevron.left` / `.right` do not, and are deliberately not used. On macOS
  10.15 the item falls back to `NSImage.goBackTemplateName` / `goForwardTemplateName`.
- No menu indicator on either segment.
- `isNavigational` on macOS 11+, which is what lets the toolbar place the pair where the system
  expects navigation controls.

The one host-facing exception is text, which exists for localization rather than for looks:

```swift
navigationItem.backwardTitle = String(localized: "Back")
navigationItem.forwardTitle  = String(localized: "Forward")
```

Each becomes that segment's tooltip and its chevron's accessibility description. The defaults are
the English `"Back"` / `"Forward"` — the item ships no string catalog, so an app that localizes sets
them.

---

## 6. Keyboard shortcuts

`NSToolbarItem` has no key equivalents, so ⌘[ / ⌘] belong to the main menu. Wire those menu items to
`performNavigation(in:)` and the same delegate call and refresh happen as for a click:

```swift
@objc func goBack(_ sender: Any?) { navigationItem.performNavigation(in: .backward) }
```

`performNavigation(in:)` is also the only supported way to cause a click from code: the control's
`target` / `action` are out of reach by design (see [4](#4-what-the-item-handles-so-a-host-does-not)).

---

## 7. Known limits

- **No history model.** What a row shows and where choosing it goes are the host's domain data. The
  item asks for rows and reports an index; it never stores a history of its own.
- **Long press is the only history affordance.** No dropdown button, no hover preview.
- **Two directions.** `Direction` has `backward` and `forward` and no room reserved for a third.
- **No reactive bindings.** The library has no reactive dependency; a host using one adapts at the
  delegate.

---

## 8. How this is verified

`Tests/UIFoundationTests/ToolbarNavigationItemTests.swift` — 18 tests covering the control's shape,
enablement tracking the data source, the empty-history detachment, the never-`nil` action across
menus being attached and detached, nearest-first row order, on-demand row resolution, disabled rows
surviving AppKit's automatic enabling, and dispatch to the delegate. Every assertion was checked by
sabotaging the implementation and confirming it went red. The suite reaches the control through
`@testable`, which is why it is internal rather than `private`.

Three things the suite cannot reach, and what covers them instead:

- **The long press itself** needs real mouse tracking. Checked by hand in the example app's
  **Toolbar Navigation** demo, which lists exactly what to look for.
- **`selectedSegment` during a momentary click.** Measured: assigning it on a `.momentary`
  `NSSegmentedControl` reads back as `-1`, AppKit's "nothing is being tracked", so a click cannot be
  faked. The dispatch that follows the read is tested through `performNavigation(in:)`, and that the
  action resolves at all is tested by sending it.
- **AppKit's own validation cycle** needs a key window. What is tested is the half that is ours —
  that the native `NSToolbarItem` forwards its validation to the managed item.

---

## 9. The toolbar item base classes

`NSToolbar.Navigation` is one item of a larger builder-style `NSToolbar` API in
`Sources/UIFoundationAppKit/Toolbar/`: a `ToolbarItem` base class with chained modifiers, and the
subclasses `NSToolbar.Button` / `.Item` / `.Group` / `.Menu` / `.PopUpButton` / `.Search` /
`.SegmentedControl` / `.View` / `.TrackingSeparator` / `.Navigation`. Like `Navigation`, it has no
trait and ships unconditionally on macOS. `Navigation` is the reason its base is split in two. Design
record: [Evolution 0019](Evolutions/0019-toolbar-item-action-and-bordered.md).

**The base is two classes, and which one an item derives from is the whole design.** `ToolbarItem`
carries what every item has — the `NSToolbarItem` forwarding properties, `isBordered` and
`isNavigational` among them. `ActionableToolbarItem` adds `target` / `action`, their three chained
modifiers (`target(_:)` / `action(_:)` / `target(_:action:)`) and the trampoline behind each
subclass's typed `actionBlock`, all resolved against one overridable `actionHost`: the item itself by
default, the hosted control for `Button`, `PopUpButton` and `SegmentedControl`.

**`Search`, `TrackingSeparator` and `Navigation` deliberately derive from `ToolbarItem` directly**,
and they are the only reason the middle class exists rather than these members living on the common
base. Measured on macOS 26: `NSToolbarItem` forwards `target`, `action` *and* `isBordered` to its
custom view — AppKit's header scopes `isBordered` to items *without* a custom view, but the setter
forwards anyway. `Navigation`'s custom view *is* the segmented control whose `target` / `action` are
wired once in `init` and must stay unreachable (see
[4](#4-what-the-item-handles-so-a-host-does-not)), so putting the pair on `ToolbarItem` would hand out
exactly the door that item's design closes. `ToolbarItemActionTests` keeps a canary on both the
forwarding and the three classes staying outside `ActionableToolbarItem`.

**Do not turn a typed `actionBlock` back into a stored property with a `didSet`.** A property
observer does not fire for an assignment made inside an initializer (measured), so that shape made
every `init(…, action:)` store the closure and wire nothing. `Item` and `Button` shipped broken that
way; `SegmentedControl` only escaped because its `commonInit()` called the installer a second time.
The computed-property-over-private-storage shape is what makes the initializer parameter work at all.

**Two chained modifiers are deprecated in favour of the base-class spelling.** `NSToolbar.Item`'s and
`NSToolbar.Button`'s `bordered(_:)` both point at `isBordered(_:)`, which matches the existing
`isDefault(_:)` / `isSelectable(_:)` / `isEnabled(_:)` naming. Both spellings reach the same place: the
button's wrote `NSButton.isBordered`, and the item property forwards there.

---

## Further reading

- [Evolution 0004](Evolutions/0004-appkit-navigation-toolbar-item.md) — why this exists, and the four
  designs that were rejected (including the push-based one this replaced).
- [SettingsWindow](SettingsWindow.md) — the SwiftUI answer to the same problem, which needs no
  hand-assembly at all.
