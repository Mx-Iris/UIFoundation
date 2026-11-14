# QuickActionBar

> A Spotlight-style floating action bar for macOS: a search field that grows into a result list,
> driven by a content source the host supplies, with optional round browse buttons beside the
> field that bud out of it the way macOS 26 Spotlight's do.
>
> Ported from [dagronf/DSFQuickActionBar](https://github.com/dagronf/DSFQuickActionBar).
> Lives in `UIFoundationAppKit` and ships behind the opt-in SPM trait `QuickActionBar` (default:
> off). macOS only.

---

## Contents

- [1. Getting started](#1-getting-started)
- [2. Public API](#2-public-api)
- [3. Escape: clear first, then close](#3-escape-clear-first-then-close)
- [4. Interrupting a dismissal](#4-interrupting-a-dismissal)
- [5. Browse buttons](#5-browse-buttons)
- [6. Testing the bar from a test process](#6-testing-the-bar-from-a-test-process)
- [7. Demo](#7-demo)
- [8. Implementation notes](#8-implementation-notes)
  - [8.1 Changes from upstream](#81-changes-from-upstream)
  - [8.2 Why Escape lives only in `cancelOperation(_:)`](#82-why-escape-lives-only-in-canceloperation_)
  - [8.3 The springs](#83-the-springs)
  - [8.4 Reversible show / dismiss animations](#84-reversible-show--dismiss-animations)
  - [8.5 How the browse buttons move](#85-how-the-browse-buttons-move)

---

## 1. Getting started

Turn the trait on, the same way as the other opt-in features (`FilterUI`, `IDEIcons`,
`NSAttributedStringBuilder`):

```swift
.package(url: "…/UIFoundation", traits: ["QuickActionBar"])     // SPM dependency
```

```bash
swift build --traits QuickActionBar
swift test  --traits QuickActionBar
```

Every source file under `Sources/UIFoundationAppKit/QuickActionBar/` is wrapped in
`#if QuickActionBar && os(macOS)`, so the trait compiles to nothing on UIKit, Mac Catalyst, tvOS,
visionOS and watchOS even if it is accidentally enabled there.

Then present a bar and answer its searches:

```swift
let bar = QuickActionBar()
bar.contentSource = self
bar.present(placeholderText: "Search…")
```

There is no SwiftUI bridge. Upstream shipped an `NSViewRepresentable`; it was intentionally not
ported, and only the AppKit controller is provided.

## 2. Public API

| Symbol | Notes |
| --- | --- |
| `QuickActionBar` | The controller (upstream's `DSFQuickActionBar`). |
| `QuickActionBar.resumePresentation()` | Reverses a dismissal that is still animating. See [§4](#4-interrupting-a-dismissal). |
| `QuickActionBar.browseItems` | Round buttons beside the search field; none by default. See [§5](#5-browse-buttons). |
| `QuickActionBar.BrowseItem` | One browse button: `title`, `image` and an `action` called with the bar. |
| `QuickActionBarContentSource` | The delegate protocol (upstream's `DSFQuickActionBarContentSource`). `canSelectItem`, `didSelectItem` and `quickActionBarDidCancel` have default no-op implementations. |
| `QuickActionBar.SearchTask` | An async-capable search task, finished with `complete(with:)` or abandoned with `cancel()`. |
| `QuickActionBar.RequiredClickCount` | `.single` / `.double`. |
| `QuickActionBar.createARGB32Image(width:height:drawBlock:)` | Static helper; was upstream's free function `CreateARGB32`. |
| `QuickActionBar.scaleImageProportionally(_:to:)` | Static helper; was upstream's free function `scaleImageProportionally`. |
| `QuickActionBar.usingEffectiveAppearance(of:_:)` | Static helper; replaces upstream's `UsingEffectiveAppearance(ofWindow:)`. |

## 3. Escape: clear first, then close

Escape clears a non-empty query before it closes the bar, as Spotlight does on macOS 27.2. Clearing
searches again for the empty term at once — the pending debounce is cancelled — and the results
collapse unless the content source returns some for the empty term. A second Escape, on an empty
query, dismisses the bar.

Decision record and evidence: Evolution
[`0032`](Evolutions/0032-escape-clears-query-before-dismissing.md). Why the handling sits where it
does is in [§8.2](#82-why-escape-lives-only-in-canceloperation_).

## 4. Interrupting a dismissal

`resumePresentation()` restores the same window, and only does so while the current panel is in the
middle of its dismiss animation. Its return value tells you whether it actually interrupted a
dismissal.

A host's own shortcut for opening the bar should take the shape of the demo's open button: reverse a
dismissal still in flight with `resumePresentation()` before presenting a new bar.

## 5. Browse buttons

Round buttons beside the search field, the way macOS 26 Spotlight shows Applications, Files, Actions
and Clipboard. There are none by default, and the bar is then exactly as it was before they existed.

```swift
let quickActionBar = QuickActionBar()
quickActionBar.browseItems = [
    QuickActionBar.BrowseItem(title: "Applications", image: applicationsSymbol) { quickActionBar in
        quickActionBar.cancel()
        showApplications()
    },
    // …
]
quickActionBar.present(placeholderText: "Search")
```

- **When they are out.** They bud out of the search field 0.47 seconds after the bar's first frame
  on screen, while the query is empty and no results are showing. Results arriving draw them back into
  the field — for a non-empty query even an empty answer does, so the query gets the whole field —
  and an empty query's results collapsing brings them out again; Escape on a query does both in
  turn. Like Spotlight's, they follow the results as they arrive, not each keystroke.
- **A click** calls the item's `action` with the bar and leaves the bar open; call `cancel()` there
  to close it. The search field keeps the keyboard focus. There is no keyboard access to the
  buttons and no selected state: Spotlight's browse modes are not reproduced.
- **Size.** A button is a circle 2 points smaller than the collapsed search row — 54 points at the
  default 56 — and takes its diameter plus a 10-point gap from the search field. Four take 256
  points, so a 640-point bar keeps a 384-point field. Nothing caps the count; give the bar the width.
- **Icons.** `title` is the tooltip and the accessibility label. A symbol image is drawn at the
  `.title1` text style, the size Spotlight uses; any other image at its own size. Spotlight's own
  symbols are `appstore`, `folder`, `app.2.stack.3d` and `document.on.document`.
- **Changing `browseItems` while the bar is open** draws the current buttons back in and lets the
  new ones bud out.
- **macOS 26 and later only.** Earlier systems ignore the list: they have no glass for the buttons
  to merge with, and Spotlight had no such buttons before 26.
- **Reduce Motion** puts the buttons out or in at once.

Decision record: Evolution
[`0039`](Evolutions/0039-quick-action-bar-browse-items.md). How they
move is in [§8.5](#85-how-the-browse-buttons-move); Spotlight's numbers, and where in its binary they
were read, are in [`Spotlight-Panel-Internals.md`](../Researchs/Spotlight-Panel-Internals.md) §11.

## 6. Testing the bar from a test process

Traps that fail confusingly rather than loudly:

- **A key-down Escape does nothing in a test process.** The window never becomes key there, and the
  window derives `cancelOperation:` from a key-down only in its keyboard-UI step, so an Escape
  key-down sent to a non-text first responder is dropped. Send the `cancelOperation:` command itself
  instead, as `QuickActionBarEscapeTests` does.
- **Keep the content source alive past the end of its test.** Results arrive on a later main-queue
  turn, and `ResultsView.buildShortcuts()` traps when the content source is gone by then. This is a
  known, unfixed trap. Without a content source at all, `provideResultIdentifiers(_:)` traps the
  same way.
- **Never `performClick(_:)` a browse button.** It runs AppKit's press highlight through the event
  loop, and on macOS 27.2 the system ends a `swift test` runner a moment after it starts handling
  window events: exit status 0, and every later test silently never runs. Send the button's action
  with `sendAction(_:to:)`, and check that the run ends with its `Test run with … tests` summary
  line, not only its exit status (the same trap as in [PlaybackSlider](PlaybackSlider.md)).
- **The browse buttons move on a display link,** which a test cannot wait on reliably. Read where
  they are heading (`GlassPlatterView.isShowingBrowseButtons`), then end the motion with
  `finishBrowseButtonAnimations()` before measuring frames, as `QuickActionBarBrowseButtonTests`
  does. The motion itself is tested on `QuickActionBar.MitosisAnimation`, against SwiftUI's own
  springs (`QuickActionBarMitosisTests`).
- **Don't sit out the 0.47-second start delay; end it with `finishBrowseButtonsPresentationDelay()`.**
  Only one test waits it out for real. The presentation suite is serialized and the longest in the
  run, and with seven such waits in it the full `swift test` run was ended early by the system in
  both of two runs (inside PlaybackSlider's event tests, exit status 0); with the waits cut it
  completed.
- **Glass does not look like glass in a test run** (a `swift test` binary carries an old SDK
  version, and AppKit gates the macOS 26 look on it). Assert on frames, corner radii and the
  container's `spacing`; judge the look in the demo.

## 7. Demo

**Quick Action Bar** in the example app (`QuickActionBarDemoViewController`) exercises every option
`present(…)` takes, zero to four of Spotlight's browse buttons, headings the list cannot select, the
↩ / ⌘1–⌘9 shortcuts, and a search slowed down to show stale answers being dropped. It also lists
the checks only a human can make — among them the browse buttons' animation beside Spotlight's own.
Its open button reverses a dismissal still in flight with `resumePresentation()` before presenting a
new bar (see [§4](#4-interrupting-a-dismissal)).

---

## 8. Implementation notes

### 8.1 Changes from upstream

- **The `DSF` prefix is stripped from every type and filename.**
- **Every internal helper type is nested under the `QuickActionBar` namespace**, so none of them
  pollutes `UIFoundationAppKit`'s module-internal scope: `QuickActionBar.TextField`,
  `QuickActionBar.EphemeralWindow`, `QuickActionBar.Debounce`, `QuickActionBar.SingleShotTimer`,
  `QuickActionBar.FlippedClipView`, `QuickActionBar.FlippedContainerView`,
  `QuickActionBar.PrimaryRoundedView`, `QuickActionBar.DelayedIndeterminiteRadialProgressIndicator`
  and `QuickActionBar.TransparentBackgroundScroller`. The types added since follow the same rule.
- **Upstream's free functions became static methods on `QuickActionBar`** — `CreateARGB32`,
  `scaleImageProportionally` and `usingEffectiveAppearance(ofWindow:)` are now the three helpers in
  the [§2](#2-public-api) table.
- **The `DSFAppearanceManager` dependency is gone.** Accent colour, dark mode, increased contrast
  and reduced transparency are read directly from `NSColor.controlAccentColor`,
  `effectiveAppearance.bestMatch(from:)` and `NSWorkspace.shared.accessibilityDisplay*`. Upstream's
  `UsingEffectiveAppearance(ofWindow:)` is replaced by the in-tree `usingEffectiveAppearance(of:_:)`,
  which uses `NSAppearance.performAsCurrentDrawingAppearance(_:)` on macOS 11+ and falls back to
  `NSAppearance.current` on 10.15.
- **The SwiftUI `NSViewRepresentable` bridge is not ported** (see [§1](#1-getting-started)).
- **`PrivacyInfo.xcprivacy` is not bundled** — UIFoundation has no privacy manifest of its own.
- **Licensing:** the original MIT license and every per-file copyright notice are preserved, and the
  port has a top-level entry in [`THIRD_PARTY_LICENSES.md`](../THIRD_PARTY_LICENSES.md).
- **Show and dismiss can be reversed mid-flight on the original window** — see
  [§8.4](#84-reversible-show--dismiss-animations).
- **Escape clears the query before dismissing** — see [§3](#3-escape-clear-first-then-close) and
  [§8.2](#82-why-escape-lives-only-in-canceloperation_).
- **The resize uses Spotlight's spring** — see [§8.3](#83-the-springs).
- **Browse buttons** — not in upstream; see [§5](#5-browse-buttons) and
  [§8.5](#85-how-the-browse-buttons-move).

### 8.2 Why Escape lives only in `cancelOperation(_:)`

The two-step Escape lives in the window's `cancelOperation(_:)` override and nowhere else, and that
is enough to catch Escape from both places focus can be:

- From the search field, nothing between the field editor and the window implements
  `cancelOperation:`, so the command reaches the window.
- From the results table, `NSTableView` hands the command to every responder above it that
  implements it, so it reaches the window too.

Both facts were read off macOS 27.2 AppKit, so no second handler lower in the chain is needed.

### 8.3 The springs

Every spring in the bar is `QuickActionBar.Spring`: SwiftUI's `Spring(duration:bounce:)`, evaluated
in closed form the way SwiftUI evaluates it, with an initial velocity. Spotlight states all of its
animations in that form, so the bar quotes its numbers directly.

The expand / collapse resize is `QuickActionBar.ResizeSpring`, `Spring(duration: 0.3, bounce: 0.2)` —
the default resize animation of Spotlight's results platter on 27.2. Upstream stepped a numerical
spring with hand-tuned constants (300 / 28), which ran about a fifth slow.

**Don't go back to tuning constants.** `QuickActionBarResizeSpringTests` and
`QuickActionBarSpringTests` compare the curves with SwiftUI's own `Spring`, so a change has to keep
matching that reference. One measured quirk of the reference: for a negative bounce SwiftUI's
`velocity(target:initialVelocity:time:)` returns the slope plus the target, while its `value(…)` is
right, so the velocity tests compare with the slope of `value(…)`.

### 8.4 Reversible show / dismiss animations

Show and dismiss can be reversed on the original window rather than by creating a new one. Each
animation carries an identifier, and a completion whose identifier is stale is discarded. Without
that, triggering the bar rapidly could leave a brief moment with no window at all, or let an old
completion close the state that replaced it.

`resumePresentation()` depends on this, and its implementation must keep two contracts:

- It must continue from the presentation layer's **current** transform and the window's current
  `NSWindow.alphaValue`, not from the start or end values, or the reversal jumps.
- The interrupted dismissal's completion must not close the window that was resumed.

### 8.5 How the browse buttons move

**What Spotlight does** (macOS 27.2, `SpotlightUIInternal`; the full account with addresses is
[`Spotlight-Panel-Internals.md`](../Researchs/Spotlight-Panel-Internals.md) §11). Each button has
three switches: *translated* (a dot on the collapsed field's edge moves out to its place), *scaled*
(the circle and its icon grow from 0.1 to full size) and *visible* (the icon's blur goes from 10 to
0 and its opacity from 0 to 1). The search field and the buttons are one glass material over a
smooth union of their shapes; the union's smoothing distance starts at 100 points, so the dots are
joined to the field and to each other, and falls to 0 while they move out. Every part is a SwiftUI
`Spring(duration:bounce:)`, and all of them start together:

| What moves | Out | Back in |
|---|---|---|
| Union smoothing, 100 ↔ 0 | 0.71 / 0.01 (jumps to 100 first) | 0.41 / 0.12 (jumps to 0 first) |
| Search field width | 0.39 / 0.39 | 0.41 / 0.12 |
| Button 0–3 position | 0.35/0.43, 0.45/0.39, 0.55/0.35, 0.60/0.31 | 0.41 / 0.12 |
| Button 0–3 size | 0.41/0.394, 0.55/0.35, 0.65/0.32, 0.71/0.274 | 0.41 / 0.12 |
| Icon blur and opacity | 0.49 / 0.15, 0.17 s late | 0.20 / 0.05 |

A fifth button and beyond take Spotlight's fallbacks: position 0.45 + 0.1i / max(0.39 − 0.04i, 0),
size 0.41 + 0.1i / max(0.394 − 0.04i, 0). `QuickActionBar.Mitosis` holds all of it;
`QuickActionBar.MitosisAnimation` keeps each part as a 0…1 progress whose springs retarget from the
current value and velocity, as SwiftUI's do, and turns them into geometry.

**The 0.47-second start delay was measured, not read.** On a 60 fps recording the field starts to
narrow 28–29 frames after the bar's first visible frame. In the binary the buttons start as the
window enters its invoking state, with no delay of its own on that path. The bar counts the delay
from its own first frame too, which the first tick of a display link marks, falling back to a fifth
of a second after `present(…)`. Counting from `present(…)` itself put the buttons about six frames
early: a new bar's first commit, where the glass is built, lands about a tenth of a second after the
call returns.

**Judge the motion in a Release build.** Recorded at 60 fps from the demo app's Release build, the
bud-out runs at full rate but for one two-frame drop as the buttons pull apart — Spotlight's own
recording drops single frames too. The Debug build falls to about 28 fps there. Sampling the
Release build, the bar's own per-frame work is about a millisecond; the rest of the frame is
SwiftUI rendering the glass and the search field relaying out as it narrows, which Spotlight pays
as well.

**How the bar draws it** (`QuickActionBar.GlassPlatterView`, macOS 26 and later):

```
PrimaryRoundedView                       the layer the present / dismiss transform animates
└── GlassPlatterView
    ├── NSGlassEffectContainerView       spacing = the union's smoothing distance
    │   └── FlippedContainerView         the container's content view
    │       ├── NSGlassEffectView × n    the buttons' circles, by frame
    │       └── NSGlassEffectView        the search platter, by constraints
    │           └── contentView          the search row and the results
    └── BrowseButtonOverlayView          answers hit tests only over its buttons
        └── BrowseButton × n             NSButton: the icons, above the glass
```

A display link drives it, setting every frame, corner radius and the container's `spacing` once a
frame. These look simplifiable and are not:

- **`spacing` is the union's smoothing distance, the very value Spotlight animates.** Read off
  AppKit and SwiftUICore in macOS 27.2 build 26B123: `setSpacing:` stores it and marks the container
  for layout, and `layout()` hands it synchronously to SwiftUI's `_GlassEffectContainer(smoothness:)`,
  whose `PathSet.smoothness` is what Spotlight sets through `_ShapeSet(smoothness:)`. Which glass
  views merge at all is decided by identity, not distance, so the platter and the circles must keep
  identical glass settings.
- **Shapes come from frames, never from layer transforms.** The container rebuilds every member's
  shape from its frame and corner radius on each layout pass, so a circle grows by its frame and
  its corner radius. A new corner radius alone does not mark the container for layout; each frame
  marks it.
- **Nothing is set inside an implicit-animation context.** There AppKit animates frames by itself,
  and `setSpacing:` forwards to `animator()`; either fights the display link.
- **The platter is laid out by constraints, pinned to `GlassPlatterView`.** By frame it is zero wide
  before the first layout pass, and its content's minimum widths break the search row's constraints —
  three logged conflicts per presentation. Pinned to the container's content view it gets
  stretched: the container holds that view with constraints below required.
- **The results' width constraint sits at `dragThatCannotResizeWindow` (490).** Results that arrive
  while the buttons are still out want the bar's full width inside a narrowed platter. Above the
  window's own size constraint (500) that request grows the whole window — measured: 896 points for
  a 640-point bar with four buttons — and at required it breaks the stack's edge constraints. So for
  the 0.4 seconds the buttons take to draw in, the results follow the platter's width, where
  Spotlight keeps them at full width and lets the platter clip them.
- **The icons are not glass.** They are borderless `NSButton`s in an overlay above the container,
  the same split as Spotlight's, whose glass is a background behind its buttons. Outside the glass
  a layer transform (around the centre: AppKit keeps the layer's anchor at its origin) and a
  `CIGaussianBlur` content filter work as anywhere else, and the button keeps AppKit's press
  highlight and accessibility. The overlay answers hit tests only over its buttons, so clicks
  elsewhere reach the search field — under the macOS 27 SDK a view that answers over a control takes
  its clicks.
- **`PrimaryRoundedView` sets no corner radius of its own on macOS 26.** On 27.2 a layer corner
  radius turns `clipsToBounds` on (see [LayerBackground](LayerBackground.md)), and the clip would
  trim the buttons as they overshoot the bar's trailing edge.
- **A button is usable from the moment it starts out** and not once it starts back in, as
  Spotlight enables its buttons with the translation. Buttons drawn back in are removed once they
  settle, and the container's `spacing` returns to 0, leaving the plain platter.
