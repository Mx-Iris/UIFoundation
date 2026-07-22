# TabBar

> A multi-tab control for macOS, ported from [KPCTabsControl](https://github.com/onekiloparsec/KPCTabsControl)
> and rebuilt around `SystemStyle` — a replication of the macOS 26 (Liquid Glass) window tab bar,
> matched against a live `NSTabBar` rather than eyeballed.
>
> Ships behind the opt-in SPM trait `TabBar`. macOS only.

---

## Table of Contents

- [1. Getting started](#1-getting-started)
- [2. Data source and delegate](#2-data-source-and-delegate)
- [3. Contracts a host has to know](#3-contracts-a-host-has-to-know)
  - [3.1 Items are matched by identity, not position](#31-items-are-matched-by-identity-not-position)
  - [3.2 Who owns the selection](#32-who-owns-the-selection)
  - [3.3 What `reloadTabs(animated:)` animates](#33-what-reloadtabsanimated-animates)
- [4. Styles](#4-styles)
- [5. `SystemStyle` in depth](#5-systemstyle-in-depth)
  - [5.1 Geometry](#51-geometry)
  - [5.2 Stacking](#52-stacking)
  - [5.3 Scrolling](#53-scrolling)
  - [5.4 Closing a run of tabs](#54-closing-a-run-of-tabs)
- [6. Namespace convention](#6-namespace-convention)
- [7. How this is verified](#7-how-this-is-verified)
- [8. Known divergences](#8-known-divergences)

---

## 1. Getting started

```swift
.package(
    url: "https://github.com/Mx-Iris/UIFoundation",
    from: "0.13.0",
    traits: ["TabBar"]
)
```

```bash
swift build --traits TabBar
swift test  --traits TabBar
```

```swift
let tabBar = TabBar()
tabBar.dataSource = self          // TabBar.DataSource
tabBar.delegate = self            // TabBar.Delegate
tabBar.reloadTabs()
tabBar.selectItemAtIndex(0)
```

`SystemStyle.tabBarRecommendedHeight` is 30 pt. The control scrolls and folds internally, so it
only needs a width; give it the full width available and let it divide itself.

| Member | Notes |
| --- | --- |
| `style: Style` | Assigning re-lays out the tabs. |
| `reloadTabs()` / `reloadTabs(animated:)` | Rebuilds from the data source. The animated form opens and closes tabs rather than snapping. |
| `selectItemAtIndex(_:)` | Selects a tab and notifies the delegate. Out-of-range indices do nothing. |
| `selectedButtonIndex: Int?` | Read-only. |
| `editTabAtIndex(_:)` | Starts an inline rename, as a double-click would. |
| `isStacking: Bool` | Whether the overflow is currently folded into piles. |
| `currentTabWidth() -> CGFloat` | The width tabs are currently laid out at. |
| `TabBar.selectionDidChangeNotification` | Posted on every selection change, including programmatic ones. |

## 2. Data source and delegate

Both protocols are `@objc`, so the `item` passed around is `Any` — the same shape `NSOutlineView` uses.
Only the first three data-source methods are required.

**`TabBar.DataSource`**

| Method | Purpose |
| --- | --- |
| `tabBarNumberOfTabs(_:)` | Tab count. |
| `tabBar(_:itemAtIndex:)` | The item backing a tab — see [3.1](#31-items-are-matched-by-identity-not-position). |
| `tabBar(_:titleForItem:)` | Tab title. |
| `tabBar(_:iconForItem:)` | Leading icon. |
| `tabBar(_:menuForItem:)` | Contextual menu; configure its target and action before returning. |
| `tabBar(_:closeIconForItem:)` / `closePositionForItem:` | The close button's image and edge (`.left` matches the system bar). |
| `tabBar(_:titleAlternativeIconForItem:)` | Drawn in place of a title too narrow to fit. |

**`TabBar.Delegate`**

| Method | Purpose |
| --- | --- |
| `tabBar(_:canSelectItem:)` | Gates selection. |
| `tabBarDidChangeSelection(_:item:)` | Fires for user *and* programmatic selection — guard against your own writes. |
| `tabBar(_:canReorderItem:)` / `didReorderItems:` | Drag reorder. Store the new order, or the tabs snap back. |
| `tabBar(_:canEditTitleOfItem:)` / `setTitle:forItem:` | Inline rename. |
| `tabBar(_:canCloseItem:)` / `didCloseItem:` | Close. See [3.2](#32-who-owns-the-selection). |

## 3. Contracts a host has to know

Three things are not obvious from the signatures and will bite otherwise.

### 3.1 Items are matched by identity, not position

Across a reload, a tab is recognised by its *item*, so a surviving tab keeps the same `TabButton` — and
therefore its decoration, its glass, and its animation. Positional matching would hand button *k* to
an item inserted at *k*, and the new tab would slide in from wherever its neighbour used to be.

Identity is derived as:

1. `AnyHashable(item)` when the item is `Hashable` — which includes **Swift structs**, since a struct
   crossing the `@objc` boundary arrives boxed in a `__SwiftValue` that forwards `isEqual:` and `hash`.
2. `ObjectIdentifier` of the object otherwise — the case for a plain (non-`Hashable`) Swift class.

So a value-type model works, provided its equality actually identifies the *tab*:

```swift
struct TabItem: Hashable {
    let id: UUID        // <- carry one
    var title: String
    var kind: Kind?
}
```

Without a stable `id`, two empty tabs are equal on `title` and `kind` alone and the control cannot tell
them apart.

> **Row indices do not work as items.** Bridged through `@objc`, an `Int` becomes a tagged
> `__NSCFNumber`, so two `3`s are the same identity and closing a middle tab renumbers everything
> behind it — the identities then claim "tab 3 vanished and tab 5 is homeless" when tab 3 is the one
> that closed. The control detects this (an unmatched item *alongside* an unclaimed button) and falls
> back to position, which is exactly right for such a host, but it gives up the animation.

### 3.2 Who owns the selection

By default the **control** owns it: closing a tab moves the selection to the tab on its left.

A host that keeps the active tab in its own model — so that commands like ⌘W act on the model rather
than on whatever the bar highlights — takes over by calling `selectItemAtIndex(_:)` from inside
`tabBar(_:didCloseItem:)`. The control notices the hand-off and stands down instead of overruling
it:

```swift
func tabBar(_ control: TabBar, didCloseItem item: Any) {
    guard let index = index(of: item) else { return }
    tabs.remove(at: index)
    activeTabIndex = min(index, tabs.count - 1)   // right neighbour, like Safari
    control.reloadTabs(animated: true)
    control.selectItemAtIndex(activeTabIndex)     // <- takes the selection over
}
```

Without the hand-off the two disagree after **every** close, silently and permanently: the bar lights
up one tab while the host's shortcut closes another. On a stacked bar the same disagreement is loud
rather than silent, because the selection anchors the fold — re-selecting into a pile blows that
sliver up to full width, and the animation appears to happen at the far edge of the strip instead of
at the tab that closed.

### 3.3 What `reloadTabs(animated:)` animates

- A **new** tab opens out of nothing: zero width springing to full, never a fade. It unfurls from the
  trailing edge when appended and from its slot's midpoint when inserted between two others.
- A **closed** tab is gone at once. What reads as "the tab closed" is the survivors reflowing into the
  space, not the tab itself leaving; fading it where it stands leaves a motionless ghost for its
  neighbours to slide through.
- Surviving tabs move, they do not jump. Every frame change goes through one animation whose origin is
  the layer's *presented* position, so a reload landing mid-animation continues from where the tab
  looks rather than from where its model frame already is.

## 4. Styles

`SystemStyle` is the only style shipped, and the default — `TabBar()` is already wearing it.
The Numbers, Chrome and Safari styles inherited from KPCTabsControl are gone: macOS 26 gave Safari
the system tab bar, which left that style with nothing of its own to show, and Chrome's never had a
dark appearance.

A style renders in one of two ways, and the fork is `Style.controlDecoration`:

- **`nil`** — the classic path, where each tab button draws its own bezel. Nothing ships on it any
  more, but the whole `ThemedStyle` / `Theme` machinery is still there for anyone writing one.
- **non-`nil`** — control-level decoration, which `SystemStyle` uses: the control floats one
  `NSGlassEffectView` behind each tab and draws the hairline separators and the bar track, while the
  buttons draw only their content. Overflow stacking lives on this path too.

`ControlDecoration` is what a decorating style is configured through:

| Field | Default | Meaning |
| --- | ---: | --- |
| `cornerRadius` | 12 | Selection and hover pill radius. |
| `selectionInsets` | 3 top/bottom | Pill inset from the button. Horizontally zero — the glass fills its button, and `interTabSpacing` is what separates two pills. |
| `highlightsHover` | `true` | Hover pill on non-selected tabs. |
| `drawsSeparators` | `true` | Hairlines between adjacent tabs. |
| `separatorVerticalInset` | 3 | Shortens each separator. |
| `showsBarTrack` | `true` | Capsule track behind the whole bar. |
| `barContentInset` | 10 | Inset of the tabs from the control's edges. |
| `barTrackInset` | 8 | Inset of the track — deliberately *smaller*, so 2 pt of track stands proud of the end pills rather than a margin. |
| `interTabSpacing` | 1 | Gap between evenly divided tabs. Stacked tabs are laid out flush. |
| `allowsStacking` | `true` | Fold the overflow instead of shrinking past `minimumTabWidth`. |
| `minimumTabWidth` | 120 | Width a tab locks to once stacking begins. |

## 5. `SystemStyle` in depth

### 5.1 Geometry

Every number below is measured off a live `NSTabBar`, not chosen.

| | |
| --- | --- |
| Bar / button / glass height | 28 pt each — the glass fills its button exactly |
| Tabs inset from the bar | 10 pt per side |
| Track inset from the bar | 8 pt per side |
| Gap between two tabs | 1 pt |
| Minimum tab width | 120 pt |
| Maximum tab width | none — two tabs in a 1480 pt bar are 739 / 740 |
| Close-button fade | 0.16 s, on its own clock, distinct from the 0.15 s relayout |

### 5.2 Stacking

Once the tabs no longer fit at 120 pt the bar stops shrinking them and starts *folding*: the overflow
telescopes into a compressed pile at each end, thinning towards the edge. The selected tab is the
**frontmost** one — it keeps its full width and everything else piles around it, so moving the
selection re-anchors the fold.

A compressed tab does not truncate its title. It keeps a **full-width** title pinned to an edge —
leading for tabs before the frontmost, trailing for tabs after it — and lets the glass clip whatever no
longer fits. A tab squeezed to a sliver therefore shows nothing at all, rather than an ellipsis.

Separators do not care about the pile: they are hidden only when trailing-most, adjacent to the
selection, or adjacent to a hovered tab. There is no width test.

### 5.3 Scrolling

The strip lives in a scroll view whose document is the full un-stacked width, and it moves on its own
in exactly two situations:

- **A tab is inserted.** The bar scrolls so the new tab stands at full width instead of folded into a
  pile. The target is computed against the tab's *un-stacked* slot, because folding keeps every tab
  nominally inside the viewport and `scrollToVisible` would be a no-op.
- **The strip gets shorter.** A bar scrolled to its end that loses a tab has to give back a tab's worth
  of offset.

Selecting a tab never scrolls the bar, matching the system.

Both moves are absorbed into the animation's origin rather than applied on top of it. Tab frames live
in document coordinates, so a viewport that jumps just before they animate drags the whole strip
sideways and then hauls it back — loudest in a pile, where a tab's entire width is a few points.

### 5.4 Closing a run of tabs

While tabs are being closed by clicking, the layout is *pinned*: survivors keep their width and simply
shift into the slot the closed tab left, which parks the next tab's close button under a stationary
pointer. The bar divides itself afresh once the pointer leaves. Adding a tab ends the run, and the
trailing tab never pins — nothing would slide under the pointer to be clicked next.

## 6. Namespace convention

To keep generic names out of the umbrella module, the entire public API is nested inside the
`TabBar` class. Only `TabBar` and `TabButton` are top level.

| Upstream | Here |
| --- | --- |
| `TabBarDataSource` / `TabBarDelegate` | `TabBar.DataSource` / `.Delegate` |
| `Style` / `ThemedStyle` / `Theme` | `TabBar.Style` / `.ThemedStyle` / `.Theme` |
| `TabButtonTheme` / `TabBarTheme` | `TabBar.ButtonTheme` / `.ControlTheme` |
| `TabPosition` / `ClosePosition` / `TabWidth` / `TabSelectionState` | `TabBar.TabPosition` / `.ClosePosition` / `.TabWidth` / `.SelectionState` |
| `SystemStyle` | nested |
| `TabBarSelectionDidChangeNotification` (string) | `TabBar.selectionDidChangeNotification` (`Notification.Name`) |

Files whose content is a protocol default-implementation extension (`extension TabBar.ThemedStyle`)
are not lexically inside `TabBar`, so sibling nested types there need qualifying.

## 7. How this is verified

`SystemStyle` is checked against a real `NSTabBar` running in the same process, driven through
`NSWindow.tabbingMode = .preferred`. Standalone probes compile the real sources with
`swiftc -D TabBar` plus a small shim, put our control and the system's side by side, and compare
frames — augmented by IDA Pro decompilation of AppKit when a number needs explaining rather than just
matching. `Researchs/AppKit-NSTabBar-Insertion-Internals.md` records the reverse-engineered insertion
and reveal path, the ivar map, and the measurement method, including two traps that produce convincing
false results.

Two habits are worth copying when extending this:

- **Measure travel, not just endpoints.** Sampling `layer.presentation()` each frame and totalling the
  distance against the net displacement is what separates "moved 120 pt" from "swung 240 pt and came
  back" — a distinction invisible to the eye inside a 0.15 s animation, and invisible to any check that
  only compares before and after.
- **Sample in screen space.** Document-space frames hide every problem that involves the viewport moving.

The demo (`UIFoundationExample-macOS` → Tab Bar) is wired the host-owned way described in
[3.2](#32-who-owns-the-selection): it keeps its own active index, opens tabs next to it, activates the
right neighbour on close, takes ⌘T / ⌘W off the responder chain, and logs a warning whenever the bar
and the model name different tabs.

## 8. Known divergences

- **Compression ramp**: 1 pt of float difference against the system in the compressed band
  (ours `610(65) 675(28) 703(19)` against `610(64) 674(28) 702(19)`).
- **Title centre offset**: AppKit adds a further offset of up to ~20 pt to a compressed tab's title,
  from `-[NSTabBar _titleCenterOffsetForButtonAtIndex:frontmostButtonIndex:]`. The constant is known
  (52 × the bar-width scale, at ivar offset 808, alongside the transcribed 64 / 90 / 128) and the
  formula is the difference of two slowing-curve evaluations, but implementing it means
  parameterising the core horizontal-offset curve, which currently matches the system to 0.0 pt across
  45 sample points. Without it, a tab in the 40–60 pt band shows slightly more of its title than the
  system does.
- **Vertical pill inset**: `selectionInsets` is 3 pt top and bottom where the system's glass is full
  height. Deliberate.
