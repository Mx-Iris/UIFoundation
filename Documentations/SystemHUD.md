# SystemHUD

> The volume-HUD-shaped floating panel for macOS: a vibrancy backdrop with an optional glyph above a
> single line of text, shown below the centre of the active screen and faded out after a delay.
>
> Ported from [Mx-Iris/SystemHUD](https://github.com/Mx-Iris/SystemHUD).
> Ships behind the opt-in SPM trait `SystemHUD`. macOS only.

---

## Contents

- [1. Getting started](#1-getting-started)
- [2. Configuration](#2-configuration)
- [3. Sizing and positioning](#3-sizing-and-positioning)
- [4. Showing and fading](#4-showing-and-fading)
- [5. Panel behaviour](#5-panel-behaviour)
- [6. Changes from the original package](#6-changes-from-the-original-package)

---

## 1. Getting started

```swift
.package(
    url: "https://github.com/Mx-Iris/UIFoundation",
    from: "0.13.0",
    traits: ["SystemHUD"]
)
```

```bash
swift build --traits SystemHUD
swift test  --traits SystemHUD
```

The shared HUD is enough for a host that only ever shows one message at a time:

```swift
SystemHUD.default.configuration.image = NSImage(named: "Build")
SystemHUD.default.configuration.title = "Build Succeeded"
SystemHUD.default.show(delay: 1.0)
```

Anything more — several HUDs with different looks, or a HUD whose configuration must not be
disturbed by other code — takes its own instance:

```swift
let buildHUD = SystemHUD(configuration: .init(
    image: NSImage(systemSymbolName: "checkmark.circle", accessibilityDescription: nil),
    title: "Build Succeeded",
    titleFontWeight: .medium
))
buildHUD.show(delay: 1.2)
```

| Member | Notes |
| --- | --- |
| `SystemHUD.default` | A shared instance. Its configuration starts with an empty title. |
| `init(configuration:)` | Builds the panel up front; the window is created but not shown. |
| `configuration` | Assigning re-lays out the panel immediately. |
| `show(delay:)` | Shows the panel, then fades it out `delay` seconds later. |

`SystemHUD` is `@MainActor`. Call it from the main thread, as with any AppKit object.

## 2. Configuration

`SystemHUD.Configuration` is a value type — mutate it in place, or build a fresh one and assign.

| Property | Default | Notes |
| --- | --- | --- |
| `image` | `nil` | The glyph above the title. `nil` also collapses `imageSpacing`. |
| `imageSpacing` | `15` | Vertical gap between the glyph and the title. Ignored when `image` is `nil`. |
| `title` | — | A single line. Too wide for the screen truncates at the tail. |
| `titleFontSize` | `18` | |
| `titleFontWeight` | `.regular` | |
| `titleColor` | `.labelColor` | |
| `titleAlignment` | `.center` | |
| `offset` | `.zero` | Shifts the glyph-and-title block inside the panel. Positive `y` moves it **up** — AppKit's unflipped coordinate space. |
| `minimumSize` | `200 × 200` | The panel never draws smaller than this. |
| `contentInsets` | `20` all round | Padding kept when the content is what determines the panel size. |
| `cornerRadius` | `15` | `0` squares the corners off. |
| `dismissAnimationDuration` | `1.0` | How long the fade-out takes once the delay elapses. |

Because the type is a struct, editing the shared HUD one property at a time works the way it reads:

```swift
SystemHUD.default.configuration.title = "Build Failed"
SystemHUD.default.configuration.image = NSImage(named: "BuildFailure")
```

Each assignment re-lays out the panel, so a burst of edits does redundant layout work. It is cheap
enough not to matter for a HUD, but building one `Configuration` and assigning it once avoids it.

## 3. Sizing and positioning

The panel measures its content — glyph height, spacing, title height, and the wider of glyph and
title — and then clamps:

- **Lower bound:** `minimumSize`. A short title still gets the familiar square system-HUD shape
  rather than collapsing to a strip.
- **Upper bound (width only):** the screen's visible width less a 20 pt margin per side. Past that
  the title truncates at the tail instead of the panel running off the display.

Position is fixed: horizontally centred on the screen, and vertically at 38 % of the visible height
below its centre — where the system puts its own volume HUD. `offset` shifts the content *within*
the panel, not the panel itself.

Both size and position are recomputed on **every** `show(delay:)` (and on every `configuration`
assignment), against `NSScreen.main` — the screen holding the key window, or the one with the
pointer when no window is key. This is what keeps a long-lived HUD on the right display after the
user moves to another screen or changes resolution.

## 4. Showing and fading

`show(delay:)` orders the panel in at full opacity and starts a one-shot timer. When the timer
fires, the panel fades to zero over `dismissAnimationDuration` on an ease-in curve.

The fade is driven by `SystemHUD.AlphaAnimation`, an `NSAnimation` subclass that maps each progress
step onto the panel's `alphaValue` and runs `.nonblocking`. Two details matter to a host that shows
HUDs in bursts:

- **The timer runs in `.common` run loop mode**, so a HUD raised while a menu is tracking or a
  window is being resized still dismisses itself instead of sticking around until the interaction
  ends.
- **A `show` during a fade interrupts it.** The in-flight animation is stopped outright and the
  panel snaps back to full opacity, then the timer restarts.

The panel is left ordered in at zero opacity rather than ordered out — it ignores mouse events, so
an invisible panel costs nothing. There is no public `dismiss()`. A HUD is a fire-and-forget
readout; a host that needs to take it away early can call `show(delay:)` with a short delay.

## 5. Panel behaviour

The window is borderless, transparent, shadowless, and floating (`.floating` level). Two properties
are worth calling out because they are what make it safe to show over anything:

- `ignoresMouseEvents = true` — the panel never swallows a click, not even during the window it is
  faded out but not yet ordered out.
- `collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]` — it follows the
  user across spaces, shows over full-screen windows, and stays put in Mission Control, matching
  the system HUD.

Corners are rounded with `NSVisualEffectView.maskImage` (a resizable nine-part rounded rectangle)
rather than `layer.cornerRadius`, because the mask also clips the backdrop material itself.

## 6. Changes from the original package

The port keeps the shape of the original API — `SystemHUD.default`, a `Configuration` struct,
`show(delay:)` — with these differences:

| Change | Why |
| --- | --- |
| `SystemHUDView` / `SystemHUDWindow` / `AlphaAnimation` nested as `SystemHUD.ContentView` / `.Window` / `.AlphaAnimation` | Those names are too generic to sit at the top level of `UIFoundationAppKit`. The fade behaviour is unchanged. |
| `dismissAnimateDuration` → `dismissAnimationDuration` | Grammar; no other rename. |
| New: `minimumSize`, `contentInsets`, `cornerRadius` | The first two are what the content-driven sizing needs; the corner radius was previously hard-coded to 15. |
| Panel re-measures and re-positions on every show | The original positioned once at init against `NSScreen.main` and used a fixed 200 × 200 window, so a HUD built on one display kept appearing there, and a long title was clipped. |
| Corners use `NSVisualEffectView.maskImage` | `layer.cornerRadius` does not clip the backdrop material itself. |
| `ignoresMouseEvents`, `collectionBehavior`, `.common` timer mode, `@MainActor` | Behaviour the original left at AppKit defaults. |
| Layout guide is sized explicitly | The original guide had no width constraint and a reversed pair of `lessThanOrEqualTo` title constraints, leaving the horizontal layout ambiguous. |

A live playground is in the example app: **Controls → System HUD**
(`UIFoundationExample-macOS/UIFoundationExample-macOS/Demos/SystemHUDDemoViewController.swift`).
