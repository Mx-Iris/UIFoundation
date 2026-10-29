# PlaybackSlider

> `PlaybackSlider`: the time slider of the Music app's full-screen player — a thin capsule with no
> knob that grows to the full height of the slider while it is pressed. A Swift port of AppKitPlus
> 0.19.0's `NSPlaybackSlider`, which ports MediaCoreUI's `MacTimeControlView` with
> `ContentBelowSliderStyle` from macOS 26.6.
>
> Ships in `UIFoundationAppKit` (`Sources/UIFoundationAppKit/PlaybackSlider/`), no trait. macOS
> only. Music's plus-lighter blending is private API and needs the `AppleInternal` trait
> (section 3). Decision record: [Evolution 0033](Evolutions/0033-playback-slider.md).

---

## Contents

- [1. Using it](#1-using-it)
- [2. What it does](#2-what-it-does)
- [3. Blending and the `AppleInternal` trait](#3-blending-and-the-appleinternal-trait)
- [4. Contracts and traps](#4-contracts-and-traps)
  - [4.1 Seek on release, not on every action](#41-seek-on-release-not-on-every-action)
  - [4.2 A container's hit test must hand back the slider](#42-a-containers-hit-test-must-hand-back-the-slider)
  - [4.3 Colours are fixed](#43-colours-are-fixed)
  - [4.4 Nothing in Interface Builder](#44-nothing-in-interface-builder)
- [5. Implementation notes](#5-implementation-notes)
  - [5.1 Where the numbers come from](#51-where-the-numbers-come-from)
  - [5.2 Springs on a clock, frames on a display link](#52-springs-on-a-clock-frames-on-a-display-link)
  - [5.3 Testing](#53-testing)

---

## 1. Using it

```swift
let timeSlider = PlaybackSlider()
timeSlider.minValue = 0
timeSlider.maxValue = duration
timeSlider.doubleValue = currentTime
timeSlider.scrubbingDelegate = self          // weak
timeSlider.box.actionBlock = { [weak self] _ in self?.timeSliderDidChangeValue() }
```

`PlaybackSlider` is an `NSSlider` subclass whose cell, `PlaybackSliderCell`, draws and tracks the
bar. Everything a slider has still works: the value and its range, `isContinuous`, target and
action, the keyboard and accessibility. `PlaybackSliderDelegate` has two methods, both with empty
default implementations:

- `playbackSliderDidBeginScrubbing(_:)` — the press. `doubleValue` is already at the pressed point,
  and the slider has not yet sent its action for it.
- `playbackSliderDidEndScrubbing(_:)` — the release, or a cancelled tracking, with `doubleValue`
  where the drag last moved it. One more action follows it.

Neither is sent for a change made with the arrow keys or VoiceOver, nor for `doubleValue` set in code.

## 2. What it does

- **Size.** 16 points tall — `intrinsicContentSize`, `sizeToFit()` and the cell's `cellSize` all
  give that height — and no intrinsic width. The alignment rectangle is the frame: Music puts its
  time labels 6 points below this row. `controlSize` changes nothing.
- **At rest** the bar is a 7-point capsule across the middle of the row. The elapsed part, the
  value's share of the whole width with no inset at either end, is white at 45 % opacity; the rest
  is white at 18 %.
- **A press** anywhere moves the value to the pointer at once and slides the elapsed part there with
  a critically damped spring (response 0.15 s). The bar grows to the full 16 points with a spring of
  mass 1, stiffness 350 and damping 40 — a little over-damped, at rest in about 0.6 s — and the
  elapsed part fades to plain white.
- **A drag** moves the value only while the pointer is at least 3 points to the left or right of the
  press; back within 3 points, the value stays where it last was. Each move is drawn at once.
- **The release** shrinks the bar back with the same spring. Released before it finished growing,
  the bar goes on growing for a moment before it turns, as Music's does: the springs carry their
  speed when they are sent somewhere new.
- **Actions.** The slider is continuous: AppKit sends the action on the press, for every movement of
  the drag it reports — whether or not the value moved — and once more after the release.
- **Direction.** The bar runs left to right in every layout direction, and so do the arrow keys: the
  cell reports `.leftToRight`. Auto Layout still places the slider by its leading edge.
- **Increase Contrast** draws with normal blending: the elapsed part in `systemGray` — `labelColor`
  while pressed — and the rest in `systemGray` at 30 %.
- **Disabled**, the whole bar is drawn at 25 % opacity.
- **Focus ring** goes round the capsule as it is drawn now.
- **Scroll wheel** does nothing: a scroll goes on to the views behind it, a scroll view among them.

## 3. Blending and the `AppleInternal` trait

Music draws the slider with SwiftUI's `.blendMode(.plusLighter)`: the bar's colours are added onto
whatever is behind it. That is Core Animation's "plusL" compositing filter on the slider's layer —
the view's own `compositingFilter` takes Core Image filters, whose addition comes out far brighter
(measured on macOS 27.2: white at 45 % over 20 % gray is 181 with plus-lighter and with "plusL",
233 with Core Image's addition filter). "plusL" is private, so:

- **With the `AppleInternal` trait** the slider sets it on its layer and keeps it there through
  appearance changes and moves between windows. Leave `wantsLayer`, the layer's `compositingFilter`
  and the view's own `compositingFilter` alone.
- **Without the trait** it never touches the layer's filter and blends normally: on a dark backdrop
  the bar is a little darker than Music's, nothing else changes.
- **Under Increase Contrast** it blends normally either way.

## 4. Contracts and traps

### 4.1 Seek on release, not on every action

The action arrives for every drag movement. A player that seeks on each one makes playback stutter
and fights the bar — playback updates move the value back under the pointer. Stop updating the
slider from playback between `playbackSliderDidBeginScrubbing(_:)` and
`playbackSliderDidEndScrubbing(_:)`, and seek once at the end. An action outside a press comes from
the keyboard or VoiceOver: seek on it at once.

### 4.2 A container's hit test must hand back the slider

Built with the macOS 27 SDK, AppKit tracks a system control with gesture recognizers collected
along the superview chain of the view the window's hit test returns. A container that overrides
`hitTest(_:)` to return itself — to make its labels inert, say — leaves the slider's recognizers
out, and the slider stops responding to clicks. Return the slider (or `nil` for the parts that
should be inert), never the container. The `appkit-mouse-event-routing` skill has the details.

### 4.3 Colours are fixed

`trackFillColor`, tick marks, a circular or vertical slider are not supported: the cell draws one
horizontal bar in Music's colours. On a light background the white bar barely shows, as Music's would.

### 4.4 Nothing in Interface Builder

Like every view here, it is made in code: `init?(coder:)` is unavailable. AppKitPlus's version
decodes from a nib and swaps a plain `NSSliderCell` for its own; this one does not.

## 5. Implementation notes

### 5.1 Where the numbers come from

Every constant — 16 and 7 points, 45 / 18 / 30 / 25 %, the 3-point threshold, both springs — and
the capsule's outline were read from MediaCoreUI on macOS 26.6 for AppKitPlus; the source comments
give the addresses into that release's dyld shared cache. The outline is SwiftUI's
`Capsule(style: .continuous)`, read from its `path(in:)` on macOS 27.2: Apple's continuous corner
along the length, a shoulder shortened to the half height across it. Change none of them without
reading the binary again.

### 5.2 Springs on a clock, frames on a display link

The springs are evaluated in closed form at the time of each frame (`PlaybackSlider+Spring.swift`),
so a late or missed frame still shows the bar where it should be. Frames come from
`NSView.displayLink(target:selector:)` on macOS 14 and later and from a 60 Hz timer before; both
hold the slider, so they stop when the bar comes to rest and when the slider leaves its window, and
start again if it comes back mid-spring. Outside a window no frames run at all.

AppKit draws a plain `NSSlider` with private subviews that cannot be made to draw this bar. A cell
that overrides `drawBar(inside:flipped:)` and the rest makes AppKit drop them and draw through the
cell; `itDrawsThroughItsCellInsteadOfAppKitsSubviews` pins that down.

### 5.3 Testing

`Tests/UIFoundationTests/PlaybackSlider/`, 40 tests ported from AppKitPlus's `NSPlaybackSliderTests`,
run with `swift test --filter PlaybackSlider` — and with `--traits AppleInternal` for the two
blending tests that only exist under the trait. Pixels are compared on an offscreen rendering at 2×.
Traps, each one met while porting:

- **No real clicks.** On macOS 27.2 a `swift test` runner started from a terminal is ended, exit
  status 0 and no results printed, a moment after it starts handling window events — posted mouse
  events or a window ordered front. The tests call the cell's tracking methods instead, which is
  what AppKit calls. AppKit's own share — the action for the press, every movement and the release —
  is therefore not covered; check it in an app.
- **Read the layer, not the view.** A layer-backed view hands a redraw request on to its layer, and
  its own `needsDisplay` reads `false` at once. The frame test checks `layer.needsDisplay()` after
  letting the layer draw.
- **Retain the test clock from the slider.** A display link or timer can fire after the test that
  made it ended; a clock captured `unowned` then crashes the runner.
- **Run the suites serialized.** The timer tests run the main run loop, which lets other main-actor
  tests run inside them.
- **Check the summary line as well as the exit status.** A runner ended by the system as in the
  first trap exits with status 0. A good run ends with `Test run with 40 tests in 3 suites passed`.
