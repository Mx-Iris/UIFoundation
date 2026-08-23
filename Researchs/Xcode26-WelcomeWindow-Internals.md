# Xcode 26 Welcome Window Internals

> Based on two Xcode view-hierarchy captures of Xcode 26's welcome window — one dark, one light,
> same process, 2× backing — cross-checked against live `NSVisualEffectView` probes and CoreText
> text metrics run on macOS 26.
> Covers what the window actually is, the exact material recipe behind it, and every measurement
> needed to rebuild it in AppKit.
> Companion to the `.xcode26` style in `Sources/UIFoundationAppKit/WelcomePanel/` (Evolution 0012).

---

## Table of Contents

- [1. What it is](#1-what-it-is)
- [2. Method of measurement](#2-method-of-measurement)
- [3. The material is `.fullScreenUI`](#3-the-material-is-fullscreenui)
- [4. The window](#4-the-window)
- [5. Left pane geometry](#5-left-pane-geometry)
- [6. Typography, recovered by inversion](#6-typography-recovered-by-inversion)
- [7. Right pane and the project list](#7-right-pane-and-the-project-list)
- [8. What this capture cannot tell](#8-what-this-capture-cannot-tell)
- [9. The AppKit recipe](#9-the-appkit-recipe)

---

## 1. What it is

`IDEKit.WelcomeWindow` is a **borderless `NSWindow` whose entire content is one SwiftUI view**:

```
IDEKit.WelcomeWindow                    740 × 460, styleMask 0
└── NSNextStepFrame
    └── NSHostingView<IDEKit.WelcomeView<IDEWelcomeViewModel>>
        ├── SwiftUI._NSGraphicsView × 5          (SwiftUI's own drawing surfaces)
        │   ├── _FocusRingView × 3               (the three action rows, 460 × 44 each)
        │   └── SwiftUIAppKitButton              (the close button, 15 × 15)
        └── AppKitPlatformViewHost<OutlineListRepresentable<SelectionManagerBox<URL>>>
            └── SwiftUI.ListCoreScrollView       (a SwiftUI List → NSOutlineView)
```

There is **no `NSVisualEffectView` and no `NSGlassEffectView` anywhere in the view tree**. Every
surface — the two panes' translucency, the action pills, all text — is drawn by SwiftUI into
`CGDrawingLayer` / `RBDrawingLayer` layers, with the blur supplied by a bare `CABackdropLayer`.

That matters for a replica: nothing here can be copied structurally, but as §3 shows, everything can
be reproduced with public AppKit.

---

## 2. Method of measurement

Each capture is a directory of gzipped JSON. The dark one holds three responses; the light one holds
six — the same three plus a second round taken after switching appearance in the same Xcode process,
so responses 3–5 are the light data:

| File | Request | Carries |
|---|---|---|
| `Response_0` | Initial request | The object tree plus eager properties (`frame`, `bounds`, `hidden`, `masksToBounds`, …) |
| `Response_1` | Fetch encoded layers | One `encodedPresentationLayer` — a base64 `NSKeyedArchiver` plist of the whole render tree |
| `Response_2` | Fetch remaining lazy properties | 14 465 entries under `topLevelPropertyDescriptions`, keyed `"<objectID>.<propertyName>"` — colors, corner radii, shadows, `inspectedDebugDescription` |

Four passes produced the numbers below:

1. **Tree + geometry** — walk `topLevelGroups` in `Response_0`, merge the lazy properties from
   `Response_2` by object id. Numeric values are hex floats (`0x1.72p+9` = 740).
2. **Filter chain** — decode `encodedPresentationLayer`, resolve the `NSKeyedArchiver` graph, and read
   every `CAFilter` instance's `CAFilterName` plus its `CAFilterInputs` dictionary.
3. **Material identification** — instantiate all 14 `NSVisualEffectView.Material` cases live, force a
   display pass, and dump each one's backdrop filter chain and tint layers for comparison (§3).
4. **Type sizes** — the text is drawn into A8 backing stores, so no font survives in the capture.
   Instead, invert: lay out the known strings at every size from 9.0 to 42.0 pt in four weights and
   keep the ones reproducing the measured layer width **and** height (§6).
5. **Appearance diff** — run passes 1–2 over both captures and compare. Every frame is identical
   across the two; **only colours change, plus the icon glow, which exists in dark only**. Geometry is
   therefore appearance-independent and each measurement below is confirmed twice.

---

## 3. The material is `.fullScreenUI`

Both panes carry the same four-layer stack. Decoded from the capture:

```
<CALayer> mask=MaskLayer
  <CABackdropLayer> backgroundColor = rgba(0.1569, 0.1569, 0.1569, 0.5)
                    filters = colorSaturate(inputAmount 1.8),
                              gaussianBlur(inputRadius 60, inputNormalizeEdges true, inputDither true)
<CALayer> compositingFilter = lightenBlendMode, mask=MaskLayer
  <CALayer> backgroundColor = rgba(0.095, 0.095, 0.095, 1)
<CALayer> opacity = 0.05, mask=MaskLayer
  <CAChameleonLayer>
```

Probing every `NSVisualEffectView` material live under `NSAppearanceNameDarkAqua` gives exactly one
match:

| Material | backdrop tint | colorSaturate | lighten layer | chameleon |
|---|---|---|---|---|
| `.hudWindow` | 0.1569 @ **0.4** | **1.6** | 0.08 | 0.05 |
| `.popover` | 0.1569 @ **0.6** | **2.0** | 0.11 | 0.05 |
| `.menu` | 0.1569 @ **0.7** | **2.2** | 0.125 | 0.05 |
| `.sidebar` / `.underWindowBackground` / `.toolTip` | 0.1569 @ **0.8** | **2.4** | 0.14 | 0.05 |
| **`.fullScreenUI`** | **0.1569 @ 0.5** | **1.8** | **0.095** | **0.05** |

Every value of `.fullScreenUI` matches the capture. The one apparent discrepancy — blur radius 60 in
the capture against 30 live — is a **unit difference, not a recipe difference**: the capture reads the
*presentation* layer, whose radius is in device pixels, and that window reports
`backingScaleFactor = 2`. 60 device pixels = 30 pt.

So the translucency needs no private API. `NSVisualEffectView(material: .fullScreenUI, blendingMode:
.behindWindow)` reproduces it bit for bit.

The light capture confirms the same material from the other side. Probing `.fullScreenUI` live under
`NSAppearanceNameAqua` and reading the light capture give the same three values:

| | live `.fullScreenUI` (Aqua) | light capture |
|---|---|---|
| backdrop tint | rgba(0.9646, 0.9648, 0.9646, 0.48) | identical |
| blend layer | `darkenBlendMode`, rgba(0.96, 0.96, 0.96, 1) | identical |
| chameleon | opacity 0.05 | identical |

Note the blend mode flips with the appearance — `lightenBlendMode` in dark, `darkenBlendMode` in
light — which is `NSVisualEffectView`'s own doing, not something a replica has to arrange.

On top of the shared material each pane gets one flat overlay:

| Pane | Dark | Light | Identified as |
|---|---|---|---|
| Left (0, 0, 460, 460) | rgba(0.118, 0.118, 0.118, **0.75**) | rgba(1, 1, 1, **0.9**) | `windowBackgroundColor` in both appearances (0.1176 dark, white light) — but at a **different alpha per appearance**, so it is one dynamic colour, not one colour at one opacity |
| Right (460, 0, 280, 460) | rgba(0.1882, 0.1725, 0.1843, 0.5) | rgba(1, 1, 1, 0.6) | light is exactly neutral white; the dark value is 4/255 off neutral — see §8 |

The right pane is the lighter of the two in both appearances; there is **no divider line** between
them, only the tint difference.

---

## 4. The window

| Property | Value |
|---|---|
| `frame` | 740 × 460 |
| `styleMask` | **0** — borderless |
| `hasShadow` | `YES` |
| `collectionBehavior` | 2 = `.moveToActiveSpace` |
| `releasedWhenClosed` | `NO` |
| `title` | `Welcome to Xcode` (set even with no titlebar) |
| `contentViewController` | `NSHostingController<WelcomeView<IDEWelcomeViewModel>>` |
| `delegate` | `IDEKit.WelcomeWindowController` |
| `animationBehavior` | 0 (default) |
| `firstResponder` | the project list |

**Corners are rounded to 20 pt by the content, not by the window**: several SwiftUI layers spanning
the full 740 × 460 carry `cornerRadius = 20, masksToBounds = YES`. The window itself reports
`isOpaque = YES`, which cannot be literally true of a window with rounded corners and a shadow — take
it as a stale/default reading rather than a recipe, and give the replica a clear window background.

---

## 5. Left pane geometry

All coordinates are top-left origin within the 460 × 460 left pane.

| Element | Frame | Notes |
|---|---|---|
| App icon | (166, 52, 128, 128) | horizontally centred: (460 − 128) / 2 = 166 |
| Icon glow | — | `shadowColor` rgba(0.0902, 0.4157, 0.8784, **0.55**), `shadowRadius` **50**, `shadowOffset` (0, 2), `shadowOpacity` 1 |
| Title | (176.5, 180, 107, 43) | starts exactly at the icon's bottom edge — zero gap |
| Version | (192, 223, 76, 16) | starts exactly at the title's bottom edge — zero gap |
| Action pill 1 | (56, **287**, 348, 36) | `cornerRadius` **18** (capsule), background **white @ 0.032** in dark, **rgba(0.3725, 0.3725, 0.3725) @ 0.096** in light |
| Action pill 2 | (56, **331**, 348, 36) | 8 pt gap |
| Action pill 3 | (56, **375**, 348, 36) | last pill ends at 411, leaving a 49 pt bottom margin |
| Action hit area | (0, 287 / 331 / 375, **460**, 44) | `SwiftUI.KeyViewProxy` — the clickable band spans the **full pane width**, not just the pill |
| Row icon | ≈ (66, centre, 16–19, 16–22) | varies per symbol; all centred on x ≈ 75.5, i.e. 19.5 pt from the pill's leading edge |
| Row label | x = **94** | 38 pt from the pill's leading edge, vertically centred in the 36 pt pill |
| Close button | (13, 13, 15, 15) | holds a 13 × 13 monochrome image |

**The glow is dark-mode only.** The light capture contains no shadow-casting layer at all — the icon
is drawn flat. (This is also what the original WelcomeKit did, gating `appIconImageShadow` on
`NSAppearance.currentDrawing().isDark`; the capture says Xcode agrees.)

The icon's glow is built the way SwiftUI always builds `.shadow()`: an offscreen group holding the
image, a `sourceAtop` fill and a `sourceAtop` chameleon wash produce a tinted silhouette, which is
then blurred. The visible icon is drawn separately on top. For a replica the four shadow parameters
are all that matter — an `NSShadow` on the image view reproduces it.

The third row's icon is a `_ColorShapeLayer` wrapping a `CAShapeLayer` rather than a `CATintedImage`,
i.e. that one is a multicolour or vector glyph while the first two are template symbols.

---

## 6. Typography, recovered by inversion

No font survives the capture — SwiftUI rasterises text into A8 backing stores. But each drawing
layer's frame is the laid-out text's box, which is enough to invert: search every size × weight for
one reproducing both the width and the height.

**Title — "Xcode", measured 107 × 43.** Only one candidate matches both dimensions:

| Weight | Size reproducing width 107 | Resulting height | Verdict |
|---|---|---|---|
| regular | 39.0 pt | 46 | ✗ |
| medium | 37.9 pt | 45 | ✗ |
| semibold | 37.1 pt | 44 | ✗ |
| **bold** | **36.0 pt** (width 106.75) | **43** | ✓ |

→ `systemFont(ofSize: 36, weight: .bold)`.

**Action row labels.** Three strings under one font is a strong constraint. Measured widths 134 /
140.5 / 147.5 with a 16 pt line box; using the real ellipsis character:

| Candidate | "Create New Project…" | "Clone Git Repository…" | "Open Existing Project…" | Line box |
|---|---|---|---|---|
| regular 13.7 | 133.76 | 140.26 | 147.17 | 17 ✗ |
| **semibold 13.0** | **133.56** | **140.41** | **147.32** | **16 ✓** |
| medium 13.3 | 133.73 | 140.43 | 147.35 | 16 ✓ (non-round size) |

→ `systemFont(ofSize: 13, weight: .semibold)`, the round-numbered candidate that fits all three.

**Version label — 76 × 16.** The exact string is not recoverable, but "Version 26.0" at
`systemFont(ofSize: 13)` measures 75.62 × 16, consistent with the rest of the family. Treat 13 pt
regular as likely rather than proven.

---

## 7. Right pane and the project list

A SwiftUI `List` (`OutlineListRepresentable` → `SwiftUIOutlineListView`, an `NSOutlineView`) whose
subtree runs under `NSAppearanceNameVibrantDark`.

| Element | Value |
|---|---|
| Pane | (460, 0, 280, 460) |
| Scroll view | 280 wide; clip view **263** wide |
| Scroller | `NSScroller` (263, 0, **17**, 460), track rgba(0.0784, 0.0784, 0.0784, 1), knob 11 wide inset 3 — a *legacy* scroller occupying real width, so the capture machine had "Show scroll bars: Always" |
| Rows | 44 pt tall, contiguous (no intercell spacing), first row at y = **10** |
| Row content layer | inset 10 pt each side within the 263 pt clip |
| Cell | (16, 0, 231, 44) — 16 pt insets |
| Hover/selection pill | (0, 4, 231, 36) — 36 pt tall, 4 pt inset top and bottom |
| File icon | 32 × 32 at (0, 6) — vertically centred |
| Title | x = **40** (icon + 8 pt), y = 8, `compositingFilter = plusL` — vibrant text |
| Subtitle | x = 40, y = 23 |
| Content height | 1112 ≈ 25 rows plus the 10 pt top inset |

---

## 8. What this capture cannot tell

- **Why the dark right-pane overlay is 4/255 off neutral is unresolved.** Light gives exactly
  rgba(1, 1, 1, 0.6); dark gives rgba(0.1882, 0.1725, 0.1843, 0.5) — (48, 44, 47) rather than a flat
  (47, 47, 47) — matching no AppKit system colour and reading faintly purple, while the
  `CAChameleonLayer` in the same tree carries a purple placeholder and chameleon layers sample the
  desktop. Whether that cast is wallpaper-derived or simply a designed colour cannot be settled from
  two captures taken on one wallpaper. The deviation is under 2 %, so a replica can use either the
  measured value or a neutral grey without a visible difference.
- **Hover, pressed and selected states** are invisible in a static snapshot. The list cell's
  background layer sits at alpha 0.0001, i.e. an un-hovered hover highlight, which says such a state
  exists but not what it looks like.
- **The version string** is unknown, so its font size is inferred rather than measured.

---

## 9. The AppKit recipe

Everything measured above, expressed in public AppKit:

| Xcode 26 does | AppKit equivalent |
|---|---|
| SwiftUI Material behind both panes | `NSVisualEffectView`, `material = .fullScreenUI`, `blendingMode = .behindWindow` |
| Left pane overlay | a flat fill of `windowBackgroundColor` over the effect view — **75 % in dark, 90 % in light** |
| Right pane overlay | a flat fill — dark rgba(0.1882, 0.1725, 0.1843) @ 0.5, light white @ 0.6 |
| 20 pt rounded window | `cornerRadius = 20` + `clipsToBounds = true` on the root content view, clear window background, `hasShadow = true` |
| Borderless chrome | `styleMask = []`, `collectionBehavior = .moveToActiveSpace`, own close button at (13, 13, 15, 15) |
| Icon glow (**dark only**) | `NSShadow` — colour rgba(0.0902, 0.4157, 0.8784, 0.55), blur radius 50, offset (0, 2); no shadow at all in light |
| Title / version | `systemFont(ofSize: 36, weight: .bold)` / `systemFont(ofSize: 13)` |
| Action pill | 348 × 36 at x = 56, `cornerRadius` 18, fill white @ 0.032 (dark) / rgba(0.3725, 0.3725, 0.3725) @ 0.096 (light); icon centred 19.5 pt in, label at 38 pt, `systemFont(ofSize: 13, weight: .semibold)` |
| Action rows at y 287 / 331 / 375 | row height 36 + intercell spacing 8, table top at 287 |
| Project list | `NSTableView`, row height 44, no intercell spacing, 10 pt top inset, 16 pt cell insets, 32 pt icon, label at 40 pt |
