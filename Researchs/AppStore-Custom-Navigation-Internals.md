# macOS App Store Custom Navigation Internals

> Based on reverse engineering the macOS **App Store 26.6** application binary (arm64e) and its
> **AppStoreKit 26.6** framework via IDA Pro decompilation, cross-checked against the Swift type
> metadata exported by RuntimeViewer.
> Covers the app's own navigation container (`BaseNavigationController`), the push / pop
> transitions it drives, the small interpolation framework underneath them, and the two-finger
> interactive back swipe.
> Every address below is a file offset in the binary named in its section heading.

---

## Table of Contents

- [1. Why this matters](#1-why-this-matters)
- [2. The four layers](#2-the-four-layers)
- [3. Layer 1 — interpolation primitives (AppStoreKit)](#3-layer-1--interpolation-primitives-appstorekit)
- [4. Layer 2 — transformations and the animation driver (App Store)](#4-layer-2--transformations-and-the-animation-driver-app-store)
- [5. Layer 3 — the transitions](#5-layer-3--the-transitions)
- [6. Layer 4 — `BaseNavigationController`](#6-layer-4--basenavigationcontroller)
- [7. The interactive back swipe](#7-the-interactive-back-swipe)
- [8. What `layoutFrame` actually resolves to](#8-what-layoutframe-actually-resolves-to)
- [9. Constant table](#9-constant-table)
- [10. Address map](#10-address-map)
- [11. Method of measurement](#11-method-of-measurement)

---

## 1. Why this matters

AppKit ships no navigation container. `NSViewControllerPushTransition` exists in AppKit's binary
but is misnamed and dead: it performs no translation at all, and nothing in AppKit instantiates it.
Apple's own macOS App Store therefore had to build a navigation stack from scratch, and the result
is the closest thing to a first-party answer for "what should a UIKit-style push look like on the
Mac".

Two things make it worth copying rather than copying UIKit:

- It is **AppKit-native throughout** — `NSAnimationContext`, `NSView.frame`, `NSEvent`'s swipe
  tracking. No transition context, no reparenting into a container view, no private API.
- It supports an **interactive back swipe**, which the UIKit port in AppKitPlus deliberately left
  out because UIKit's interactive machinery has no AppKit counterpart. The App Store solves it with
  `NSEvent.trackSwipeEvent`, which is public and much simpler.

## 2. The four layers

```
BaseNavigationController               // the stack, the delegates, the swipe
  └── any ViewTransition               // PushViewTransition / PopViewTransition
        ├── ViewPropertyInterpolator   // [any Transformation] + TimingCurve
        │     └── KeyPathTransformation / ClosureTransformation
        │           └── Interpolator<Value: Interpolatable>   (AppStoreKit)
        │                 └── TimingCurve                     (AppStoreKit)
        └── ViewPropertyAnimator       // NSAnimationContext wrapper
```

The split is worth preserving: the bottom two layers know nothing about navigation, and the
transition layer knows nothing about the stack. A transition is a **value** describing three views
and a list of interpolated properties; it can be stepped by hand (interactive) or handed to the
animator (automatic) without changing anything.

## 3. Layer 1 — interpolation primitives (AppStoreKit)

### `Interpolatable`

```swift
public protocol Interpolatable {
    static func solvedValue(between: Self, and: Self, forInput: CGFloat) -> Self
}
```

One requirement. Conformers seen in use: `CGFloat`, `CGRect`, `CGPoint`.

### `Interpolator<Value: Interpolatable>`

```swift
public struct Interpolator<Value: Interpolatable> {
    var curveFunction: CAMediaTimingFunction
    var fromValue: Value
    var toValue: Value

    init(fromValue: Value, toValue: Value, curve: TimingCurve)   // 0x1E47326B4
    func value(forInput: CGFloat) -> Value                       // 0x1E47327F0
    func value(forInput: Double) -> Value                        // 0x1E4732858
    func value(forInput: Float) -> Value                         // 0x1E47328C0
}
```

Note the stored property is an already-resolved `CAMediaTimingFunction`, not the `TimingCurve`
enum — the curve is converted once at init. **Each interpolator carries its own curve**, which is
why the transition's `apply(_:)` (§5) can pass a raw, uncurved fraction straight through.

### `TimingCurve`

```swift
public enum TimingCurve {
    case controlPoints(Float, Float, Float, Float)
    case easeInOut, easeIn, easeOut, linear

    var caMediaTimingFunction: CAMediaTimingFunction { get }   // 0x1E4257C98
    var controlPoint1: CGPoint { get }                         // 0x1E4257DE4
    var controlPoint2: CGPoint { get }                         // 0x1E4257E54
    var reversed: TimingCurve { get }                          // 0x1E4257EC4

    static var customNavigation: TimingCurve { get }           // 0x1E4257FA0
    static var customNavigationPop: TimingCurve { get }        // 0x1E42580E0
    static var horizontalPush: TimingCurve { get }             // 0x1E4258150
    static var easingCurve1/2/3: TimingCurve { get }           // 0x1E4258164 / 78 / 8C
}
```

**`customNavigation`** is a plain 16-byte literal load from `0x1E47F06A0`:

| bytes | float32 | role |
|---|---|---|
| `a5 4e 40 3e` | `0.1878` | control point 1, x |
| `99 bb 16 3b` | `0.0023` | control point 1, y |
| `e3 36 0a 3f` | `0.5399` | control point 2, x |
| `9d 80 76 3f` | `0.9629` | control point 2, y |

**`customNavigationPop`** is computed lazily (`swift_once` → `0x1E4257FB4`) and is exactly
`customNavigation.reversed`: it builds a `CAMediaTimingFunction` from the four numbers above, reads
back control points 1 and 2, and returns `(1 − p2.x, 1 − p2.y, 1 − p1.x, 1 − p1.y)` —
`(0.4601, 0.0371, 0.8122, 0.9977)`.

**`customNavigationPop` has zero cross-references in the App Store binary.** It ships but is never
called; the pop transition uses `customNavigation` like the push does (§5).

## 4. Layer 2 — transformations and the animation driver (App Store)

```swift
protocol Transformation {
    func apply(_ fraction: CGFloat)          // sole requirement, PWT +0x8
}

struct KeyPathTransformation<Target, Value: Interpolatable>: Transformation {
    let target: Target
    let property: ReferenceWritableKeyPath<Target, Value>
    let interpolator: Interpolator<Value>
}

struct ClosureTransformation<Value: Interpolatable>: Transformation {
    let interpolator: Interpolator<Value>
    let body: (Value) -> Void
}

struct ViewPropertyInterpolator {
    var transformations: [any Transformation]
    var curve: TimingCurve
}

struct AnimationTiming {
    var duration: Double
    var curve: TimingCurve
}
```

### `ViewPropertyAnimator`

```swift
struct ViewPropertyAnimator {
    var animations: [() -> Void]
    var completions: [() -> Void]
    var duration: Double
    var curve: TimingCurve
    var delay: Double
}
```

`run()` (`0x10000FF30`) branches on `delay`: `delay > 0` schedules through
`DispatchQueue.main.asyncAfter(deadline: .now() + delay)`, otherwise it calls the immediate path
(`0x10001037C`) directly. The immediate path is, in full (body at `0x100010854`):

```swift
NSAnimationContext.runAnimationGroup({ context in
    context.duration = duration
    context.timingFunction = curve.caMediaTimingFunction
    context.allowsImplicitAnimation = true
    for animation in animations { animation() }
}, completionHandler: {
    for completion in completions { completion() }
})
```

**This is the load-bearing detail of the whole design.** The transitions never build a
`CABasicAnimation`. They assign the *final* value to `view.frame` / `view.alphaValue`, and
`allowsImplicitAnimation = true` inside the group makes CoreAnimation interpolate it — which is
also why every participating view is forced to `wantsLayer = true` first (§5).

## 5. Layer 3 — the transitions

```swift
protocol ViewTransition {
    init(containerView: NSView, sourceView: NSView, destinationView: NSView)   // PWT +0x8
    var timing: AnimationTiming { get }                                        // PWT +0x10
    func prepare()                                                             // PWT +0x18
    func apply(_ fraction: CGFloat)                                            // PWT +0x20
}

protocol InteractiveViewTransition: ViewTransition { /* 3 further requirements */ }

struct PushViewTransition: ViewTransition, InteractiveViewTransition {
    let containerView: NSView
    let sourceView: NSView
    let destinationView: NSView
    let dimmingView: BackgroundView
    let interpolator: ViewPropertyInterpolator
}
// PopViewTransition has an identical shape.
```

### `timing`

`0x10016F4F0` returns `AnimationTiming(duration: 0.35, curve: .customNavigation)` — the duration is
the literal `0x3FD6666666666666`. The Push and Pop witness tables both point at this same address:
the two getters were byte-identical and the linker folded them, which is itself the proof that
**pop uses the same duration and the same (un-reversed) curve as push**.

### The dimming view

Both transitions create `BackgroundView(frame:backgroundColor:cornerRadius:)` with a process-wide
lazily-initialised colour (`swift_once` → `0x1002860A4`):

```swift
NSColor(_colorLiteralRed: 0, green: 0, blue: 0, alpha: 0.22)
```

### Geometry

Everything is measured against `containerView.layoutFrame` (§8) and one constant:

```swift
let parallaxShift = floor(layoutFrame.width * 0.2527)
```

`PushViewTransition.init` (`0x10016E6F0`) appends three transformations, all sharing
`.customNavigation`:

| # | kind | target / property | from | to |
|---|---|---|---|---|
| 1 | KeyPath | `sourceView.frame` | `layoutFrame` | `layoutFrame` shifted by `−parallaxShift` (LTR) / `+parallaxShift` (RTL) |
| 2 | KeyPath | `destinationView.frame` | `layoutFrame` at `x = maxX` (LTR) / `x = minX − width` (RTL) | `layoutFrame` |
| 3 | KeyPath | `dimmingView.alphaValue` | `0.0` | `1.0` |

`PopViewTransition.init` (`0x1003C1E6C`) is the mirror image:

| # | kind | target / property | from | to |
|---|---|---|---|---|
| 1 | **Closure** | `sourceView.frame` | `layoutFrame` | `layoutFrame` at `x = maxX` (LTR) / `x = minX − width` (RTL) |
| 2 | KeyPath | `destinationView.frame` | `layoutFrame` shifted by `−parallaxShift` (LTR) / `+parallaxShift` (RTL) | `layoutFrame` |
| 3 | KeyPath | `dimmingView.alphaValue` | `1.0` | `0.0` |

Pop's first entry is a `ClosureTransformation` rather than a key path; the closure body is
`0x1003C29E8`. The captured box holds only `sourceView`, so the closure is at minimum a
`{ sourceView.frame = $0 }` — the reason for preferring a closure here was not established.

**The incoming view travels the full container width; the outgoing view travels 25.27 % of it in
the opposite direction.** That 0.2527 is the App Store's parallax factor. (UIKit's own
`_UINavigationParallaxTransition` uses 30 % — `width − round(width × 0.7)`.)

### `prepare()`

`PushViewTransition.prepare()` (`0x10016F32C`):

```swift
sourceView.wantsLayer = true
destinationView.wantsLayer = true
containerView.addSubview(destinationView)
dimmingView.wantsLayer = true
dimmingView.frame = containerView.layoutFrame
containerView.addSubview(dimmingView, positioned: .below, relativeTo: destinationView)
apply(0)
```

The dimming view sits **between** the two controller views: above the outgoing one, below the
incoming one. So it darkens only the view being pushed away.

### `apply(_:)`

`0x10016F3D0` (push) and `0x1003C2AAC` (pop) are the same loop:

```swift
for transformation in interpolator.transformations {
    transformation.apply(fraction)
}
```

The fraction is passed through **uncurved** — each `Interpolator` applies its own
`CAMediaTimingFunction`. That matters for the interactive path, where the raw gesture amount is fed
in directly and must still land on the same eased values the automatic animation would produce.

## 6. Layer 4 — `BaseNavigationController`

```swift
class BaseNavigationController: NSViewController, NSUserInterfaceValidations {
    let objectGraph: BaseObjectGraph                                  // app-specific DI
    var stack: [NSViewController]
    weak var delegate: BaseNavigationControllerDelegate?              // willShow / didShow
    weak var transitionDelegate: BaseNavigationControllerTransitionDelegate?
    var isCustomTransitioning: Bool
    var deepestViewController: NSViewController { get }               // 0x100147B94
}
```

### The transition factory — `0x1000C4FF8`

```swift
func transition(from: NSViewController,
                to: NSViewController,
                operation: Operation) -> (any ViewTransition)?
```

`operation` is an enum with `0 = push`, `1 = pop`, and a third case meaning "no transition" that
returns `nil` immediately. For push and pop it first asks `transitionDelegate` (witness slots +0x8
and +0x10 respectively) with `(containerView, sourceView, destinationView, navigationController)`;
if that returns `nil`, or there is no delegate, it constructs the built-in
`PushViewTransition` / `PopViewTransition`.

### The single funnel — `setStack(_:animated:)` at `0x1000C5530`

Everything (push, pop, pop-to-root, replace) goes through one method. Order of operations:

1. Compute `(fromViewController, toViewController, operation)` from old vs. new stack
   (`0x1000C7974`).
2. `willChangeValue(for:)` — KVO, around the whole swap.
3. `delegate?.navigationController(_:willShow:animated:)` — skipped when `operation` is the
   "no transition" case.
4. Old stack: `removeFromParentViewController()` on every element.
   New stack: `addChildViewController(_:)` on every element.
5. If `isViewLoaded == false`, skip all view work.
6. **Animated path**: build the transition; if non-`nil`, `prepare()`, read `timing`, build a
   `ViewPropertyAnimator` whose single animation is `transition.apply(1.0)` and whose completion
   tears down (removes the outgoing view and the dimming view), then `run()`.
7. **Non-animated path** (also the fallback when the transition is `nil`):
   `oldStack.last?.view.removeFromSuperview()`, then
   `view.addSubview(newTop.view)` and `newTop.view.frame = view.layoutFrame`, then
   `view.window?.recalculateKeyViewLoop()`.
8. Assign `self.stack = newStack`, `didChangeValue(for:)`,
   `delegate?.navigationController(_:didShow:animated:)`.

Note that step 7 sets the frame **after** `addSubview` and uses no Auto Layout at all: the
container owns child geometry outright.

### Other members

| selector | address | behaviour |
|---|---|---|
| `navigateBack:` | `0x1000C72A0` | the ⌘[ / back-button action |
| `validateUserInterfaceItem:` | `0x1000C7328` | disables back when `stack.count < 2` |
| `makeFirstResponder` | `0x1000C7524` | hands focus to the top controller |
| `beginAppearanceTransition:forwarding:` | `0x1000C76D0` | forwards appearance callbacks down the stack |
| `endAppearanceTransitionWithForwarding:` | `0x1000C7838` | ditto |

## 7. The interactive back swipe

Two overrides, and no gesture recognizer.

```objc
- (BOOL)wantsScrollEventsForSwipeTrackingOnAxis:(NSEventGestureAxis)axis;   // 0x1000C6578
```

Disassembles to `CMP X2, #1 / CSET W0, EQ` — i.e. `axis == .horizontal`.

```swift
override func scrollWheel(with event: NSEvent) {            // 0x1000C6584
    guard stack.count >= 2 else { return }
    guard abs(event.scrollingDeltaY) < abs(event.scrollingDeltaX) else { return }
    guard event.scrollingDeltaX > 0 else { return }         // rightward only — back, never forward
    guard event.phase == .began else { return }

    let top = stack[stack.count - 1]
    let below = stack[stack.count - 2]
    let transition = popTransition(from: top, to: below)    // 0x1000C63BC

    event.trackSwipeEventWithOptions(
        NSEventSwipeTrackingOptions(rawValue: 7),
        dampenAmountThresholdMin: 0.0,
        max: 1.0,
        usingHandler: { gestureAmount, phase, isComplete, stop in ... })
}
```

The options constant is `MOV W2, #7` at `0x1000C6788` — verified in assembly, since the argument
order in the pseudocode is scrambled by the mixed integer / floating-point registers.
`NSEventSwipeTrackingOptions` publicly declares only `.lockDirection` (`1`) and
`.clampGestureAmount` (`2`); **bit 2 (`4`) has no public name.**

The handler receives a gesture amount already clamped to `0…1`, which is fed straight into
`transition.apply(_:)`. Completion and cancellation go through `InteractiveViewTransition`'s three
extra requirements.

## 8. What `layoutFrame` actually resolves to

Every rectangle in §5 comes from `containerView.layoutFrame`, a member of AppStoreKit's
`LayoutMarginsAware` protocol. The default implementation constrained to `NSView` decompiles to:

```swift
extension LayoutMarginsAware where Self: NSView {
    var layoutFrame: CGRect { frame.subtracting(insets: NSEdgeInsetsZero) }
}
```

Two consequences worth flagging before copying this:

- It is **`frame`, not `bounds`** — the container's rectangle in its *superview's* coordinate
  space, then used as a child frame in the container's *own* space. These agree only while the
  container's origin is `(0, 0)`, which is true for a view controller's root view in the usual
  setup but is not guaranteed.
- The insets are the literal `NSEdgeInsetsZero`, inlined. `BackgroundView` carries a stored
  `layoutMargins`, so conformers can inset; the plain-`NSView` default does not.

## 9. Constant table

| constant | value | source |
|---|---|---|
| transition duration | `0.35 s` | `0x10016F4F0`, literal `0x3FD6666666666666` |
| timing curve (push **and** pop) | `cubic-bezier(0.1878, 0.0023, 0.5399, 0.9629)` | `0x1E47F06A0` |
| reversed curve (present, unused) | `cubic-bezier(0.4601, 0.0371, 0.8122, 0.9977)` | computed at `0x1E4257FB4` |
| parallax factor | `floor(width × 0.2527)` | `0x10016E6F0`, `0x1003C1E6C` |
| dimming colour | `sRGB black, alpha 0.22` | `0x1002860A4` |
| dimming position | between outgoing and incoming view | `0x10016F32C` |
| swipe axis | horizontal only | `0x1000C6578` |
| swipe direction | `scrollingDeltaX > 0` only | `0x1000C6584` |
| swipe options | `7` (`.lockDirection | .clampGestureAmount | 0x4`) | `0x1000C6788` |
| swipe dampen range | `0.0 … 1.0` | `0x1000C6584` |

## 10. Address map

### App Store 26.6 (`/Volumes/RE/AppStore/26.6/App Store`, arm64e, imagebase `0x100000000`)

| address | symbol / role |
|---|---|
| `0x1000C4FF8` | `BaseNavigationController.transition(from:to:operation:)` |
| `0x1000C5530` | `BaseNavigationController.setStack(_:animated:)` |
| `0x1000C6578` | `-[BaseNavigationController wantsScrollEventsForSwipeTrackingOnAxis:]` |
| `0x1000C6584` | `BaseNavigationController.scrollWheel(with:)` body |
| `0x1000C63BC` | interactive pop transition factory |
| `0x1000C72A0` | `-[BaseNavigationController navigateBack:]` |
| `0x1000C7328` | `-[BaseNavigationController validateUserInterfaceItem:]` |
| `0x1000C7974` | old-stack / new-stack → `(from, to, operation)` |
| `0x10000FF30` | `ViewPropertyAnimator.run()` |
| `0x10001037C` | `ViewPropertyAnimator` immediate path |
| `0x100010854` | the `NSAnimationContext` group body |
| `0x10016E6F0` | `PushViewTransition.init(containerView:sourceView:destinationView:)` |
| `0x10016F32C` | `PushViewTransition.prepare()` |
| `0x10016F3D0` | `PushViewTransition.apply(_:)` |
| `0x10016F4F0` | `timing` getter (folded, shared by push and pop) |
| `0x100551E30` | `PushViewTransition : ViewTransition` witness table |
| `0x1002860A4` | dimming colour `swift_once` initialiser |
| `0x1003C1E6C` | `PopViewTransition.init(containerView:sourceView:destinationView:)` |
| `0x1003C29E8` | pop's source-view closure body |
| `0x1003C2AAC` | `PopViewTransition.apply(_:)` |
| `0x10055AA08` | `PopViewTransition : ViewTransition` witness table |

### AppStoreKit 26.6 (dyld shared cache, imagebase `0x1E4086000`)

| address | symbol |
|---|---|
| `0x1E4257C98` | `TimingCurve.caMediaTimingFunction` |
| `0x1E4257EC4` | `TimingCurve.reversed` |
| `0x1E4257FA0` | `static TimingCurve.customNavigation` |
| `0x1E4257FB4` | `customNavigationPop` `swift_once` initialiser |
| `0x1E42580E0` | `static TimingCurve.customNavigationPop` |
| `0x1E47F06A0` | the four `customNavigation` control-point floats |
| `0x1E47326B4` | `Interpolator.init(fromValue:toValue:curve:)` |
| `0x1E47327F0` | `Interpolator.value(forInput: CGFloat)` |
| `0x1E435E428` | `BackgroundView.init(frame:backgroundColor:cornerRadius:)` |

## 11. Method of measurement

- Swift type layouts, field offsets, protocol witness-table slot kinds and the AppStoreKit method
  addresses come from RuntimeViewer's exported `.swiftinterface` files under
  `/Volumes/RE/AppStore/26.6/SwiftInterfaces/` and
  `/Volumes/DyldSharedCaches/macOS/26.6/AppStoreKit/SwiftInterfaces/`.
- The App Store binary is stripped of Swift local symbols, so App-Store-side functions were located
  by taking cross-references to the type-metadata accessors that *are* named
  (`$s9App_Store18PushViewTransitionVMa`, `$s9App_Store17PopViewTransitionVMa`) and by walking out
  from the surviving Objective-C `IMP`s on `BaseNavigationController`.
- Witness-table slots were read as raw pointers out of `__const` and matched against the slot kinds
  RuntimeViewer reported for each protocol.
- Every constant in §9 was confirmed in disassembly, not only in pseudocode. Two cases where that
  mattered: the `trackSwipeEventWithOptions:` argument order, and the float literals, which
  Hex-Rays prints as integers.
