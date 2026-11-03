# AppKit NSToolbar Centered Item Width Ratio Internals

> Selectors and addresses: macOS 26.6 AppKit, cache `d64a142b85333e09968a6ad3e176e3f6`, read in the IDA database
> `/Volumes/DyldSharedCaches/macOS/26.6/AppKit.i64` (through an APFS copy) by the RuntimeViewer team on 2026-11-03.
> Every address is an unslid address in that cache and moves between releases.
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
- `-[NSBarLayout _principleRectGivenItems:remainingLeadingWidth:remainingTrailingWidth:totalWidth:…]` (0x185445BF4,
  when `requiresTrueCenterLayout` is NO) turns that into the item's rect: the standard width against the item's
  minimum and maximum width, at least the item's content clipping width, at most the room the leading and trailing
  items leave plus the minimum; then the rect is centred on the visual centre and slid sideways only when one side
  lacks room. Hex-Rays fails on this function ("local variable allocation failed"); it was read from the disassembly.
- The 26.6 reading of the minimum was "a standard width below the minimum becomes the minimum". **macOS 27.2 does not
  behave that way** (section 4): the preference is dropped and the item takes its maximum width, as with no ratio.
  Either the rule changed in 27 or the disassembly was misread; macOS 26.6 has not been measured.

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

- Whether macOS 26.6 raises a width below the minimum to it, as its disassembly was read to say.
- `requiresTrueCenterLayout` and the content clipping width were not exercised.
