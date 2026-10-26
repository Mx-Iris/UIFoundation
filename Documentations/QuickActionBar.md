# QuickActionBar

> A Spotlight-style floating action bar for macOS: a search field that grows into a result list,
> driven by a content source the host supplies.
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
- [5. Testing the bar from a test process](#5-testing-the-bar-from-a-test-process)
- [6. Demo](#6-demo)
- [7. Implementation notes](#7-implementation-notes)
  - [7.1 Changes from upstream](#71-changes-from-upstream)
  - [7.2 Why Escape lives only in `cancelOperation(_:)`](#72-why-escape-lives-only-in-canceloperation_)
  - [7.3 The resize spring](#73-the-resize-spring)
  - [7.4 Reversible show / dismiss animations](#74-reversible-show--dismiss-animations)

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
does is in [§7.2](#72-why-escape-lives-only-in-canceloperation_).

## 4. Interrupting a dismissal

`resumePresentation()` restores the same window, and only does so while the current panel is in the
middle of its dismiss animation. Its return value tells you whether it actually interrupted a
dismissal.

A host's own shortcut for opening the bar should take the shape of the demo's open button: reverse a
dismissal still in flight with `resumePresentation()` before presenting a new bar.

## 5. Testing the bar from a test process

Two traps, both of which fail confusingly rather than loudly:

- **A key-down Escape does nothing in a test process.** The window never becomes key there, and the
  window derives `cancelOperation:` from a key-down only in its keyboard-UI step, so an Escape
  key-down sent to a non-text first responder is dropped. Send the `cancelOperation:` command itself
  instead, as `QuickActionBarEscapeTests` does.
- **Keep the content source alive past the end of its test.** Results arrive on a later main-queue
  turn, and `ResultsView.buildShortcuts()` traps when the content source is gone by then. This is a
  known, unfixed trap.

## 6. Demo

**Quick Action Bar** in the example app (`QuickActionBarDemoViewController`) exercises every option
`present(…)` takes, headings the list cannot select, the ↩ / ⌘1–⌘9 shortcuts, and a search slowed
down to show stale answers being dropped. It also lists the checks only a human can make. Its open
button reverses a dismissal still in flight with `resumePresentation()` before presenting a new bar
(see [§4](#4-interrupting-a-dismissal)).

---

## 7. Implementation notes

### 7.1 Changes from upstream

- **The `DSF` prefix is stripped from every type and filename.**
- **Every internal helper type is nested under the `QuickActionBar` namespace**, so none of them
  pollutes `UIFoundationAppKit`'s module-internal scope: `QuickActionBar.TextField`,
  `QuickActionBar.EphemeralWindow`, `QuickActionBar.Debounce`, `QuickActionBar.SingleShotTimer`,
  `QuickActionBar.FlippedClipView`, `QuickActionBar.FlippedContainerView`,
  `QuickActionBar.PrimaryRoundedView`, `QuickActionBar.DelayedIndeterminiteRadialProgressIndicator`
  and `QuickActionBar.TransparentBackgroundScroller`.
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
  [§7.4](#74-reversible-show--dismiss-animations).
- **Escape clears the query before dismissing** — see [§3](#3-escape-clear-first-then-close) and
  [§7.2](#72-why-escape-lives-only-in-canceloperation_).
- **The resize uses Spotlight's spring** — see [§7.3](#73-the-resize-spring).

### 7.2 Why Escape lives only in `cancelOperation(_:)`

The two-step Escape lives in the window's `cancelOperation(_:)` override and nowhere else, and that
is enough to catch Escape from both places focus can be:

- From the search field, nothing between the field editor and the window implements
  `cancelOperation:`, so the command reaches the window.
- From the results table, `NSTableView` hands the command to every responder above it that
  implements it, so it reaches the window too.

Both facts were read off macOS 27.2 AppKit, so no second handler lower in the chain is needed.

### 7.3 The resize spring

The expand / collapse resize is Spotlight's spring, in closed form: `QuickActionBar.ResizeSpring`,
equivalent to `Spring(duration: 0.3, bounce: 0.2)` — the default resize animation of Spotlight's
results platter on 27.2. Upstream stepped a numerical spring with hand-tuned constants (300 / 28),
which ran about a fifth slow.

**Don't go back to tuning constants.** `QuickActionBarResizeSpringTests` compares the curve with
SwiftUI's own `Spring`, so a change to the curve has to keep matching that reference.

### 7.4 Reversible show / dismiss animations

Show and dismiss can be reversed on the original window rather than by creating a new one. Each
animation carries an identifier, and a completion whose identifier is stale is discarded. Without
that, triggering the bar rapidly could leave a brief moment with no window at all, or let an old
completion close the state that replaced it.

`resumePresentation()` depends on this, and its implementation must keep two contracts:

- It must continue from the presentation layer's **current** transform and the window's current
  `NSWindow.alphaValue`, not from the start or end values, or the reversal jumps.
- The interrupted dismissal's completion must not close the window that was resumed.
