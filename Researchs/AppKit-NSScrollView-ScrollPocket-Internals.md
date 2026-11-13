# AppKit NSScrollView Scroll Pocket Internals

> Selectors and addresses: macOS 27.0 (26A428) AppKit, from the RuntimeViewer export at
> `/Volumes/DyldSharedCaches/macOS/27.0/AppKit/ObjCHeaders/` and the IDA database
> `/Volumes/DyldSharedCaches/macOS/27.0/AppKit-20261014.i64`. Every address is a slid text address in that cache and
> moves between releases.
>
> Behaviour: measured on macOS 27.2 (26B5101f) with `Tests/UIFoundationTests/ScrollPocketTests.swift` and a throwaway
> probe of the same shape. No 27.2 AppKit export existed then, so 27.2's method list was read from the Objective-C
> runtime (`class_copyMethodList`). Section 5 has its own header: it was read off 27.2's AppKit.
>
> How Xcode uses all this comes from the RuntimeViewer team's reverse engineering of Xcode 27.2, in
> `/Volumes/RE/Xcode/27.2/README.md`, section "Navigator chooser and scroll pockets (2026-10-14)".
>
> **Why this report exists.** From macOS 26 AppKit fades content out where it scrolls under a bar: the scroll edge
> effect, drawn by an `NSScrollPocket` view the scroll view adds to itself along an edge. AppKit sets this up for the
> window's title bar and for split view item accessories, and the only public control over it is
> `preferredScrollEdgeEffectStyle` on those two accessory classes. A bar of your own that floats over a list — Xcode's
> navigator chooser and filter bar — gets nothing unless it is registered with the scroll view through private calls.
> The API built on them is in `Sources/UIFoundationAppleInternal/ScrollView/NSScrollView+ScrollPocket.swift`.

---

## 1. The calls

`NSScrollView`, macOS 27.0:

| Selector | IMP | Notes |
|---|---|---|
| `-registerPocketContainer:onEdge:` | `0x185A545EC` | adds a view to the edge's containers |
| `-unregisterPocketContainer:onEdge:` | `0x185A5475C` | |
| `-scrollPocketStyleOnEdge:` | `0x185A54278` | |
| `-setScrollPocketStyle:onEdge:` | `0x185A5420C` | |
| `alwaysShownPocketEdges` | getter `0x185A540F4`, setter `0x185A54108` | `NSInteger`, ivar at +1176 |
| `allowedPocketEdges` | getter `0x185A54130`, setter `0x185A541E4` | `NSInteger`, ivar at +1184 |
| `-_pocketForEdge:makeIfNeeded:` | `0x185A54894` | |
| `-_registeredPocketContainersOnEdge:` | `0x185A54844` | **absent from 27.2** |
| `-_updatePockets` | `0x185A51BDC` | |
| `-_updateTopPocketGeometry` | `0x185A52018` | |

The scroll view keeps `_topPocket` (+1152) and `_bottomPocket` (+1160), both `NSScrollPocket`, a
`_pocketContainerViews` dictionary (+1168), and a style per edge (`_topPocketStyle` +1192, `_bottomPocketStyle`
+1200).

An `edge` argument is 0 for the top edge and 1 for the bottom one. `alwaysShownPocketEdges` and `allowedPocketEdges`
take one bit per edge, `1 << edge`: Xcode passes 3 for both edges, and the tests pin `.bottom` to the value 2.

`NSView` adopts AppKit's `NSScrollPocketElement` protocol, whose `_scrollPocketElementStyle` (readonly `NSInteger`)
tells a pocket what a registered container is. `NSScrollPocket` is an `NSView` subclass written in Swift.

### macOS 27.2

`NSScrollView`'s pocket methods on 27.2, from the runtime: `_allowsPocketColorSchemeAdaptivityForEdge:`,
`_destroyPocketForEdge:`, `_invalidatePocketGeometry`, `_pocketColorForEdge:`, `_pocketForEdge:makeIfNeeded:`,
`_preferredScrollPocketAppearanceForEdge:`, `_setAllowsPocketColorSchemeAdaptivity:forEdge:`,
`_setPocketColor:forEdge:`, `_setPreferredScrollPocketAppearance:forEdge:`, `allowedPocketEdges`,
`alwaysShownPocketEdges`, `registerPocketContainer:onEdge:`, `scrollPocketStyleOnEdge:`, `setAllowedPocketEdges:`,
`setAlwaysShownPocketEdges:`, `setScrollPocketStyle:onEdge:`, `unregisterPocketContainer:onEdge:`.

**`_registeredPocketContainersOnEdge:` is gone**: calling it raises `unrecognized selector`. It is the reason every
call in the wrapper is checked with `instancesRespond(to:)` first.

`NSView`'s: `_isTitlebarAssociatedScrollPocketElementContainer`, `_pocketGeometryListenerToggled:inPocket:`,
`_registerWithPocket:`, `_scrollPocketElementBehavioralVariance`, `_scrollPocketElementStyle`,
`_shouldDescendantsContributeToScrollPocket`, `_unregisterFromPocket:`, `computed_scrollPocketDescendantContributors`.

## 2. When a pocket exists and how tall it is

Static reading of 27.0 (`_updatePockets`, `_updateTopPocketGeometry`): the top pocket shows when its edge is always
shown, when there is a full-screen title bar overlay, or when a container is registered on it; the bottom pocket only
when its edge is always shown or a container is registered on it. The top pocket is a strip as tall as the scroll
view's top safe area inset, united with the header clip view and each registered top container. A scroll view whose
top reaches the title bar registers with the window (`_updateTitlebarAdjacencyState`, `0x185A52EA8`), which registers
its `_titlebarContainerView` as the top container; split view item accessories are registered top and bottom the same
way (`-[NSWindowSectionContentController _updateSplitViewAccessoryRegistration]`, `0x185CC0098`).

Measured on 27.2 — a 300 × 600 scroll view filling a window's content view, a flipped document 3,000 points tall, a
30-point view along the top edge and a 20-point view along the bottom one. Frames are in the scroll view's
coordinates, whose origin is its top-left corner.

| Insets | Registration | Top pocket | Bottom pocket |
|---|---|---|---|
| none | none | 0 tall | none |
| none | always shown, both edges | 0 tall | 0 tall |
| none | both bars registered | 30 tall (the bar) | 20 tall at y 580 (the bar) |
| scroll view `contentInsets` (80, 44), automatic off | none | 0 tall | none |
| scroll view `contentInsets` (80, 44), automatic off | always shown | 0 tall | 44 tall at y 556 |
| scroll view `contentInsets` (80, 44), automatic off | registered | 30 tall | 44 tall |
| clip view `contentInsets` (80, 44), clip automatic off | always shown | 0 tall | **0 tall** |
| clip view `contentInsets` (80, 44), clip automatic off | registered | 30 tall | 20 tall |
| `additionalSafeAreaInsets` (80, 44), automatic on | none | 80 tall | none |
| `additionalSafeAreaInsets` (80, 44), automatic on | always shown | 80 tall | 44 tall |
| `additionalSafeAreaInsets` (80, 44), automatic on | registered | 80 tall | 44 tall |

What follows from it:

- **The bottom pocket exists only while its edge is always shown or has a container**, and is as tall as the scroll
  view's own bottom content inset, united with the containers registered there.
- **It is the scroll view's own content inset, not the clip view's.** The two are separate values: in 27.0
  `-[NSScrollView setContentInsets:]` (`0x184F78FAC`) writes the scroll view's own `_contentInsets`, re-tiles and keeps
  the scroll position without touching the clip view, whose `contentInsets` is another ivar (getter `0x184F5FA5C`) —
  read by the RuntimeViewer session that reviewed `NavigatorScrollViewLayout`. A scroll view whose content is inset
  through its clip view alone gets a bottom pocket 0 points tall.
- **The top pocket follows the top safe area inset, not a content inset**: content insets of 80 with no safe area give
  a 0-point top pocket.
- **A list whose bars become its safe area gets both pockets at the right height** as long as the scroll view keeps
  adjusting its own content insets, because its automatic insets are its safe area. This is how a list can get the
  effect without registering anything.
- The top `NSScrollPocket` view exists in every case, 0 points tall when nothing sizes it.

Every pocket view measured had `isHidden == NO` and an alpha of 1, whatever the setup, so whether a pocket *draws*
cannot be read off the view from outside; the measurements above are of geometry only.

## 3. Styles

Both edges' `scrollPocketStyleOnEdge:` is 0 until set, and a value set reads back. What each value draws has not been
worked out. Xcode 27.2 sets `setScrollPocketStyle:(hasSecondLevel ? 2 : 0) onEdge:0` on macOS 27 and 2 on both edges
on macOS 26 (`-[IDENavigatorArea replacementView:didInstallViewController:]`, IDEKit `0x2924A0`).

`_scrollPocketElementStyle` on 27.2:

| View | Value |
|---|---|
| `NSView`, `NSStackView` | −1 |
| `NSControl` itself, `NSSlider` | 0 |
| `NSGlassEffectView` | 1 |
| `_NSSplitViewItemAccessoryViewWrapper` | 2 |
| `NSButton`, `NSTextField`, `NSSearchField`, `NSPopUpButton`, `NSSegmentedControl` | 3 |

So 3 is not specific to segmented controls, and "a control answers 0" holds for `NSControl` itself only.

Xcode's bars answer 2, the value of the wrapper a split view item puts around an accessory, and DVTUserInterfaceKit
names it: `NSViewWithScrollPocketElementStyleBar` (`0xD5F68`), `DVTStackViewWithScrollPocketElementStyleBar`
(`0xD34FC`) and `DVTScopeBarViewWithScrollPocketElementStyleBar` (`0xCB928`) all return 2, as do the filter bar,
`-[DVTFilterExpressionControlBar _scrollPocketElementStyle]` (DVTUserInterfaceKit 27.2, `0xA3A38`), and the navigator
chooser, `-[IDETwoLevelChooserView _scrollPocketElementStyle]` (IDEKit 27.2, `0x2A3268`). The disassembly was read by
the RuntimeViewer session working on the navigator chooser; the database is in `/Volumes/RE/Xcode/27.2/DVTUserInterfaceKit/`.
UIFoundation calls it `NSView.barScrollPocketElementStyle`.

## 4. What Xcode does with it

From `/Volumes/RE/Xcode/27.2/README.md`:

- When the navigator area installs a navigator (`-[IDENavigatorArea replacementView:didInstallViewController:]`,
  `0x2924A0`), from macOS 26 on: `setAlwaysShownPocketEdges:3`, `registerPocketContainer:<chooser> onEdge:0`,
  `registerPocketContainer:<filter bar> onEdge:1`, and the style above. `-[NSScrollView dvt_registerPocketContainer:onEdge:]`
  (DVTCocoaAdditionsKit `0x11694`) forwards to AppKit's call only when the scroll view responds to it.
- `IDEExplorableNavigatorView` registers its own filter bar on the bottom edge (`viewDidMoveToWindow`, `0x76344C`) and
  its auxiliary view on the top one.
- `-[IDEFindNavigator viewDidLoad]` (`0x1B42C0`) registers the query parameters view, the summary row and the
  load-more summary row on the results' top edge.
- The navigator's scroll view runs the full height, the bars float over it, and they reach it as safe area: the
  navigator area sets `additionalSafeAreaInsets.top` to the chooser's height, `IDEExplorableNavigatorView` sets the
  scroll view's own `additionalSafeAreaInsets.bottom` to the filter bar's. The clip view's automatic insets are off
  and its `contentInsets` are `(safeAreaInsets.top + 8, 0, safeAreaInsets.bottom, 0)`; the scroll view's own automatic
  insets stay on.

## 5. Backdrop groups under the title bar

> Read off macOS 27.2 (cache UUID `b411828b…`, AppKit UUID `77E3ADB8…`) in the IDA database
> `/Volumes/DyldSharedCaches/macOS/27.2/AppKit+UIKitCore+UIKitMacHelper+UpdateCycle.i64`, opened through a copy;
> addresses are that cache's. Measured on macOS 27.2 with the `TitlebarFixture` tests in `ScrollPocketTests.swift`
> and in RuntimeViewer, whose editor area puts two scroll views side by side under the toolbar (2026-11-13).

**The symptom.** Two scroll views side by side under a toolbar, both reaching the title bar: the title bar over the
first shows its content blurred, and from the first one's last subview drawn over its pocket (RuntimeViewer's
minimap) to the window's trailing edge — the whole second scroll view included — the title bar is a flat fill of the
window's background, as if nothing scrolled under it.

**Why.** On 27.2 a pocket draws through its v8 model (feature flag `MPV8`, `NSIsMagicPocketV8Enabled`,
`0x18B468D78`); `NSScrollPocket.layout()` (`0x18B479FA0`) hides the older views, `NSHardPocketView` among them. Its
layers name the recipe: the soft one is `ThinFilmBackgroundReplay` (a 16-point Gaussian blur of what lies behind the
scroll view, at opacity 0.6) under `ThinFilmContentBlurFill`, a `CABackdropLayer` that blurs the content. Each entry's
`groupName` is set in `sub_18B466A38`: a replay joins the pocket's own `backgroundGroup-…` group, the content blur
joins the model's `backdropGroupName` unless the pocket sits over glass (`!isOverGlass`, `sub_18B45E6D8`) — a
sidebar's pocket is, and gets `nil`. The model's name (`sub_18B478CF0`), first match wins:

1. the pocket's own `backdropGroupName` (`-[NSScrollPocket setBackdropGroupName:]`, `0x18B47D69C`), when not empty;
2. with the title bar among its containers (`titlebarElementContainerCount ≥ 1`), its `_effectiveTitlebarGroupName`;
3. `NSScrollPocket-0x…`, one per pocket (`sub_18B480B0C`).

`-[NSView computed_effectiveTitlebarGroupName]` (`0x18B1D672C`) is the view's own `_titlebarGroupName` when not empty,
else its superview's, up to `-[NSWindow _titlebarBackdropGroupName]` (`0x18A41D130`), `TitlebarGroup-<window>`. The
default of `_titlebarGroupName` is an empty string (`+[NSView default_titlebarGroupName]`, `0x18B1D6720`), and it reads
back empty after being given `nil`. A title bar section names its own group, `TitlebarGroup-<NSTitlebarBackgroundView>`
(`-[NSTitlebarView _updateSectionBackgroundViews:]`, `0x18AF1595C`), and `_updateSectionGroupNames` (`0x18AF153F4`)
hands it to the section's background material and, through `-[NSWindowSectionContentController setGroupName:]`
(`0x18B1D7ADC`), to the split view item's adapter or else the section's primary scroll view.

So every pocket under the title bar in one section or window blurs in one group. Core Animation captures a group's
backdrop once per frame in the render server (`CA::OGL::capture_backdrop`, QuartzCore `0x18DD92CB8`; a group keeps a
master capture its members take sub-rectangles of, `BackdropGroup::subrect_to_master`, `0x18DF31D30`). That the
capture is taken when the group's first member is drawn was not read line by line; it is what the symptom shows —
everything drawn after the first pocket, its own overlays and the second scroll view, is missing from the capture.
Measured in RuntimeViewer: both editor pockets' `ThinFilmContentBlurFill` had the group `TitlebarGroup-0x…`, the
same name, and the flat strip began exactly where the first pane's minimap does.

**What separates them.** A non-empty `_titlebarGroupName` on a view around each scroll view
(`NSView.box.titlebarBackdropGroupName`): each pocket inside takes its own view's name, including a pocket AppKit makes
later for a scroll view swapped in, and a name set on a hierarchy on screen reaches the pockets already there. Setting
the pocket's own `backdropGroupName` works too and wins over everything, but a pocket made later starts without it.
The cost: each group captures only what lies behind its own pockets, so the blur of two neighbours meets at their
shared edge rather than running across it.

**A stand-alone pocket.** Xcode 27.2 sidesteps the question in its editor area: one `NSScrollPocket` of its own, in a
`DVTEdgeOcclusionView`, lies over all editor panes under the toolbar with a backdrop group name of its own
(`WindowTop`), and one lies behind each editor bar (the RuntimeViewer team's notes on IDEKit and DVTUserInterfaceKit
27.2: `-[IDEEditorAreaContainer initWithFrame:]` `0x10AF50`, `dvt_configureSubviewsBeforeSubviewLayout` `0x10B4FC`,
`-[DVTEdgeOcclusionView layout]` `0x287FC`). Style 2, `allowsSeparator` NO on 27, and the container keeps the
occlusion views' capture views at its back. Measured on 27.2, in RuntimeViewer's process and with `ScrollPocketView`:

- `NSScrollPocket` is exported (AppKit's `.tbd` lists it under `objc-classes`) and `init(frame:)` makes a working one
  outside any scroll view; `_isEnabled` is already true.
- Style 2 draws the hard recipe whatever the pocket's elements: `HardPocketContentBlur`, in the pocket's
  `backdropGroupName`, under `HardPocketBackgroundReplay` at opacity 0.85 in a window that was not key.
- Style 0 or 1 with no element containers draws nothing: the v8 root layer's opacity is 0. Given the title bar
  container with `addElementContainer:`, style 0 draws the soft recipe (`ThinFilm…`).
- The background replay comes from the pocket's `captureView`, a capture-only `CABackdropLayer` in the pocket's
  `backgroundGroup-…` group. A scroll view puts its own pocket's first among its subviews, behind the clip view; a
  stand-alone pocket's must be put behind the content it covers by whoever hosts it.
- Drawn after every pane, the pocket's one capture holds them all, and whatever is drawn over their own pockets.
  Those pockets still lie beneath it; `-[NSScrollView setAllowedPocketEdges:0]` removes them altogether (and with them
  any container registered on them), but Xcode leaves them, and so does RuntimeViewer.

## 6. Open questions

- What each `scrollPocketStyle` value draws, and what the element styles other than 2 change.
- What `allowedPocketEdges` restricts. Of `_scrollPocketElementBehavioralVariance` only one bit is known: an element
  answering it with bit 2 — `NSBannerView`, `NSRulerView` — makes the pocket hard, a near-opaque fill (27.2, the v8
  model build `sub_18B47C0C4`).
- Whether a group's backdrop is captured when its first member is drawn — the account in section 5 rests on the
  symptom, not on QuartzCore's code.
- Whether the containers a scroll view keeps are held strongly — 27.2 offers no way to read them back.
