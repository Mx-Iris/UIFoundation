# AppKit NSToolbar Centered Item Width Ratio Internals

> Selectors and addresses: macOS 26.6 AppKit, cache `d64a142b85333e09968a6ad3e176e3f6`, read in the IDA database
> `/Volumes/DyldSharedCaches/macOS/26.6/AppKit.i64` (through an APFS copy) by the RuntimeViewer team on 2026-11-03.
> Every address is an unslid address in that cache and moves between releases. Section 2 was corrected on
> 2026-11-05 from macOS 27.0 (26A428) and 27.2 (26B123) AppKit, whose addresses are marked as such.
>
> Behaviour: measured on macOS 27.2 with `Tests/UIFoundationTests/ToolbarCenteredItemWidthTests.swift` and a
> throwaway probe of the same shape. macOS 15.8's dyld cache contains the selector name; its AppKit was not
> decompiled.
>
> How Xcode uses it comes from the RuntimeViewer team's reverse engineering of Xcode 26.6 (17F113), in
> `/Volumes/RE/Xcode/26.6/README.md`, section "Toolbar activity view (2026-11-03)".
>
> **Why this report exists.** Xcode 26's toolbar Activity View, the capsule in the middle of the toolbar, is 40 % of
> the toolbar wide and follows the window as it resizes. Nothing public sizes a toolbar item relative to the
> toolbar: an item's width comes from its view's constraints, which cannot reach the toolbar view. Xcode gets it
> from one private `NSToolbar` property. The API built on it is in
> `Sources/UIFoundationAppleInternal/Toolbar/NSToolbar+CenteredItemWidth.swift`.

---

## 1. The property

| Selector | Address (26.6) | What it does |
|---|---|---|
| `-[NSToolbar setPreferredPrincipalItemWidthRatio:]` | 0x184B68F88 | Stores the `double` at offset 0x48 of the toolbar's auxiliary storage (`_toolbarAuxCreatingIfNeeded:`). Lays nothing out |
| `-[NSToolbar preferredPrincipalItemWidthRatio]` | 0x184ABB36C | Reads it back |
| `-[NSToolbar setCenteredItemIdentifier:]` | 0x184B68E5C | Stores a one-element `centeredItemIdentifiers` and calls `_noteCenteredItemChanged`; the older single-item spelling of the public property |

No SDK header declares the property. A new toolbar answers **−1** (measured on 27.2).

## 2. Where the toolbar reads it

- The only reader is `-[NSToolbarView _layoutDirtyItemViewersAndTileToolbarAndRecalculateKeyViewLoop:]`
  (0x1856E3920, the read at 0x1856E4244). For the last layout section — the centre one — it calls
  `setStandardCenterWidth:` with `ceil(ratio × toolbarView.frame.width)` when the ratio is above 0, and −1 otherwise.
- `-[NSBarLayout _centerRectGivenItems:leadingItems:trailingItems:inRect:]` (27.0 0x1855365C8, 27.2 0x18AA36F90,
  identical) turns that into the item's rect:
  - The standard width is paid out first when it lies within the item's minimum and maximum width; otherwise the item
    aims at its maximum. So a standard width below the minimum is dropped, as section 4 measures.
  - The room left after every item's minimum is shared equally among the items before the centered item, the item and
    the items after it, each group up to its widest. Flexible spaces, and items whose view measures 10,000 points wide
    or more, count at their minimum there.
  - The rect is centred midway between the sidebar and inspector dividers (`-[NSToolbarView
    layout:visualCenterXForCenterItems:]`, 27.0 0x1858FA8DC). It slides only when the group before or after it grew
    past it.
- **Corrected 2026-11-05.** An earlier version of this report said that
  `-[NSBarLayout _principleRectGivenItems:remainingLeadingWidth:remainingTrailingWidth:totalWidth:…]` (26.6 0x185445BF4)
  places the item, and read it as raising a standard width below the minimum to the minimum, which contradicted the
  27.2 measurement. That function belongs to the Touch Bar. `+[NSToolbar newToolbarLayout]` (26.6.2 0x1856A1DF0, 27.0
  0x1858AC484, 27.2 0x18ACC3CA0) builds every toolbar layout with `centerIsPrincipal = NO`, and only Touch Bar code sets
  it YES, so a toolbar never reaches that function or its `requiresTrueCenterLayout` branch. Read by the RuntimeViewer
  team; the pseudo-code is in RuntimeViewer's
  `Documentations/ResolvedIssues/2026-11-05-long-toolbar-title-pushed-the-centered-item-aside.md`.

Because the setter lays nothing out, a ratio assigned to a toolbar already in a window shows at the toolbar's next
layout — a window resize, an item change. Xcode assigns it while building the item, before the toolbar is shown.

## 3. How Xcode 26 uses it

`ActivityView.updateProportionalWidth()` (IDEKit 26.6, 0x559E60) assigns
`IDEActivityViewProportionalWidthPercentage / 100`, a user default that starts at 40 and is clipped to 20…90. The
item is the toolbar's `centeredItemIdentifier`, and its view is constrained to at least 160 points (required) and at
most 2000 (priority 450, above the 200 at which the toolbar pulls an item wide when it measures the maximum).

## 4. Measured on macOS 27.2

A window 1200 points wide with a unified toolbar holding a flexible space, the centered item and another flexible
space; the item's view constrained as Xcode's. The enclosing `NSToolbarView` is 1200 points wide.

| Ratio | `ceil(ratio × 1200)` | Item width |
|---|---|---|
| none (−1) | — | 928 (the room left) |
| 0.05 … 0.13 | 60 … 156, below the minimum 160 | 928 |
| 0.14 | 169 (0.14 × 1200 is 168.00000000000003) | 169 |
| 0.15 | 180 | 180 |
| 0.2 | 240 | 240 |
| 0.4 | 480 | 480 |
| 0.9, 1.0 | 1080, 1200 | 928 |

Assigning 0.4 after the toolbar was laid out without a ratio takes effect at the next layout (a 20-point resize
triggered it).

## 5. Not worked out

- macOS 26.6 has not been measured, and its `_centerRectGivenItems:…` was not read; that 26.6 raises a width below the
  minimum to it was a reading of the Touch Bar's function (section 2).
- The content clipping width was not exercised.
