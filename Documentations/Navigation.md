# Navigation

> A `UINavigationController`-shaped container for AppKit: a stack of view controllers, a push /
> pop transition, and a two-finger swipe back.
>
> The container and its machinery are ported from the macOS App Store's own navigation stack, not
> from UIKit; the default *look* is UIKit's, with the App Store's available as a preset. Every
> constant on both sides is measured, not estimated — for the App Store's, see
> [`Researchs/AppStore-Custom-Navigation-Internals.md`](../Researchs/AppStore-Custom-Navigation-Internals.md).
> Ships behind the opt-in SPM trait `Navigation`. macOS only, no private API.

---

## Contents

- [1. Getting started](#1-getting-started)
- [2. The stack](#2-the-stack)
- [3. Contracts a host has to know](#3-contracts-a-host-has-to-know)
- [4. Configuration](#4-configuration)
- [5. Delegates](#5-delegates)
- [6. Writing a custom transition](#6-writing-a-custom-transition)
- [7. The animation layer on its own](#7-the-animation-layer-on-its-own)
- [8. What was not ported](#8-what-was-not-ported)
- [9. Known divergences from the App Store](#9-known-divergences-from-the-app-store)

---

## 1. Getting started

```swift
.package(
    url: "https://github.com/Mx-Iris/UIFoundation",
    from: "0.13.0",
    traits: ["Navigation"]
)
```

```bash
swift build --traits Navigation
swift test  --traits Navigation
```

```swift
import UIFoundation

let navigationController = NavigationController(rootViewController: LibraryViewController())
window.contentViewController = navigationController

// later
navigationController.pushViewController(AlbumViewController(album: album), animated: true)
```

There is no navigation bar. The container manages a stack and animates between its members;
titles, back buttons and toolbars are the host's, driven off
[the delegate](#5-delegates). `navigateBack(_:)` is an `@IBAction`, so a menu item or button can
target it directly and it validates itself — it greys out when there is nothing to go back to.

The example app has a live playground: **Controls ▸ Navigation**.

## 2. The stack

```swift
navigationController.pushViewController(detail, animated: true)
navigationController.popViewController(animated: true)                  // -> the removed one
navigationController.popToViewController(library, animated: true)       // -> those removed
navigationController.popToRootViewController(animated: true)            // -> those removed
navigationController.setViewControllers([library, album], animated: true)
```

`setViewControllers(_:animated:)` is the funnel — everything else is a convenience over it.
Reading and writing `viewControllers` is the same as calling it with `animated: false`.

Which animation runs is inferred from the two stacks rather than from which method was called:

| old → new | operation |
|---|---|
| the new top was not on the stack before | push |
| the new top **was** on the stack before | pop, however many levels were dropped |
| same top either way, or either side empty | none — the change applies with no animation |

So replacing the top view controller animates forward, and dropping four levels at once animates
back exactly like a single pop. Convenience accessors:

```swift
navigationController.rootViewController     // bottom of the stack
navigationController.topViewController      // what is on screen
navigationController.deepestViewController  // through nested NavigationControllers
navigationController.canPop                 // stack.count > 1
navigationController.isTransitioning
```

The stack must not contain duplicates — `pushViewController` traps in debug and no-ops in release
if you push something already on it. Duplicates would make `popToViewController(_:)` ambiguous.

## 3. Contracts a host has to know

These four are not visible in the API signatures, and each one produces a confusing result rather
than an error when it is broken.

### 3.1 The container owns child geometry

Pages are positioned **by frame**, inside
[`contentInsets`](#4-configuration), and re-laid-out on every layout pass. Use Auto Layout freely
*inside* a page; never pin a page's own view to anything outside the navigation controller.

```swift
// Wrong — the constraint fights the transition, and the page slides back as it slides in.
page.view.leadingAnchor.constraint(equalTo: window.contentLayoutGuide.leadingAnchor).isActive = true
```

Constraining the **container's** view is fine and expected; it is only the pages that are
frame-driven.

### 3.2 Children are made layer-backed

A transition animates by assigning end values inside an `NSAnimationContext` group with
`allowsImplicitAnimation = true`. That is the whole mechanism, and it needs a backing layer:
`prepare()` sets `wantsLayer = true` on the outgoing view, the incoming view, and the dimming
layer. A host that cannot tolerate layer backing on its pages cannot use the animated paths.

The practical consequence is the usual one — layer-backed views clip differently, and any drawing
that relied on overlapping siblings outside the view's own bounds will stop showing.

### 3.3 Interactive pop consumes horizontal scroll events

The swipe is not a gesture recognizer. The container overrides
`wantsScrollEventsForSwipeTracking(on:)` and `scrollWheel(with:)`, so a rightward two-finger swipe
that reaches the container starts a pop.

It only ever reaches the container if nothing inside handled it first. **A page containing a
horizontally scrollable `NSScrollView` will swallow the gesture**, and the back swipe will not
work over that region. That is AppKit's responder chain doing its job, not a bug — if you need
both, set `allowsInteractivePop = false` and drive `popViewController(animated:)` from your own
control.

Only rightward swipes are recognised, and only when the horizontal component dominates. There is
no forward swipe: the stack has nothing to go forward to.

### 3.4 Changes during a transition are deferred, not applied

Calling any stack method while `isTransitioning` is `true` stores the request and applies it when
the running transition finishes. Two transitions driving the same views at once strand a view off
screen, so the alternative was worse.

The visible consequence: `viewControllers` and `topViewController` keep reporting the **old** stack
until the animation ends. Do not read them back immediately after a push to decide what to do
next; use the [delegate](#5-delegates) instead.

## 4. Configuration

Two presets ship. **`.uiKit` is the default.**

```swift
navigationController.configuration = .appStore              // the whole look at once
navigationController.configuration.parallaxFactor = 0.4     // or one knob at a time
navigationController.configuration.contentInsets = NSEdgeInsets(top: 44, left: 0, bottom: 0, right: 0)
```

| property | `.uiKit` (default) | `.appStore` | what it is |
|---|---|---|---|
| `timing` | `0.35 s` ease-in-ease-out | `0.35 s` `cubic-bezier(0.1878, 0.0023, 0.5399, 0.9629)` | duration and easing |
| `parallaxFactor` | `0.3` | `0.2527` | how far the *outgoing* page counter-moves, as a fraction of the container's width |
| `dimmingColor` | sRGB black at 10 % | sRGB black at 22 % | laid over the outgoing page only |
| `edgeShadowWidth` | `9` | `0` | soft shadow trailing the incoming page's leading edge |
| `contentInsets` | `.zero` | `.zero` | how far pages are inset from the container's bounds |

Both sets of numbers are measured, not estimated — UIKit's from `_UINavigationParallaxTransition`,
the App Store's from its own binary.

**Pick `.appStore` to match the App Store, not because it looks better.** It is the flatter of the
two, and deliberately so: no edge shadow, five points less parallax, and a curve that is already
~63 % through the motion at half the time and then crawls. Put together, the thing that stays
visible longest is the outgoing page drifting left, which reads as content sliding sideways rather
than as one page moving over another. `.uiKit`'s 9 pt shadow is what gives the arriving page a
visible edge, and it is the single biggest difference between the two.

Two more things worth knowing:

- The **incoming** page always travels the full width; `parallaxFactor` is only the counter-slide
  behind it. The difference between the two speeds is the parallax.
- The App Store uses **the same curve in both directions** — it does not reverse it for the pop.
  `TimingCurve.appStoreNavigation.reversed` is there if you disagree; AppStoreKit ships that exact
  reversed curve too, and never calls it.

`contentInsets` is honoured by the transition as well as by static layout, so a container that
sits under a translucent title bar animates within the inset rectangle rather than under the bar.

Assigning `configuration` while a transition is running does **not** disturb it: the slide keeps
the geometry it started with, and the new values take effect on the next transition. (Without that
the page snaps to its new resting frame mid-slide — exactly what a settings slider dragged during
an animation would do.)

Right-to-left layouts are handled from the container's `userInterfaceLayoutDirection`: everything
mirrors, and the back swipe stays a *rightward* swipe (it follows the trackpad, not the text
direction).

## 5. Delegates

```swift
navigationController.delegate = self

func navigationController(_ controller: NavigationController,
                          willShow viewController: NSViewController,
                          animated: Bool) {
    titleField.stringValue = viewController.title ?? ""
    backButton.isHidden = !controller.canPop
}
```

Both callbacks have default no-op implementations, so implement only what you need.

An **abandoned interactive pop** deserves a note. The gesture sends `willShow` for the view
controller being revealed as soon as it starts, because a host wants to cross-fade its chrome
during the drag. If the user lets go before halfway, the pop is cancelled and the delegate
receives `willShow` **and** `didShow` for the view controller that was already on top. Chrome
driven purely off `willShow` therefore ends up back where it started.

## 6. Writing a custom transition

Set `transitionDelegate` and return your own type for either direction; return `nil` for the
default look.

```swift
func navigationController(_ controller: NavigationController,
                          pushTransitionFrom sourceView: NSView,
                          to destinationView: NSView,
                          in containerView: NSView) -> (any ViewTransition)? {
    CrossFadeTransition(containerView: containerView,
                        sourceView: sourceView,
                        destinationView: destinationView,
                        configuration: controller.configuration)
}
```

A transition is a **value describing** an animation, not a running one:

```swift
public protocol ViewTransition {
    init(containerView: NSView, sourceView: NSView, destinationView: NSView,
         configuration: NavigationConfiguration)
    var timing: AnimationTiming { get }
    func prepare()                       // add views, turn on wantsLayer, seat at fraction 0
    func apply(_ fraction: CGFloat)      // write the state for any fraction
    func cleanUp(isFinished: Bool)       // remove what is leaving, restore what stays
}
```

Because `apply(_:)` can be called with any fraction, the same description serves both the
automatic run and a gesture. Conform to `InteractiveViewTransition` — the three extra members all
have default implementations — and the back swipe will drive your transition too. A transition
that is *not* interactive simply doesn't get the swipe; the gesture declines to start rather than
falling back to the built-in look.

## 7. The animation layer on its own

The pieces underneath are usable without the navigation controller:

```swift
let interpolator = Interpolator(fromValue: CGRect.zero, toValue: view.bounds, curve: .navigation)
let transformation = KeyPathTransformation(target: view, property: \NSView.frame, interpolator: interpolator)
transformation.apply(0.5)
```

- `Interpolatable` — one requirement, `solvedValue(between:and:forInput:)`. Conformances for
  `CGFloat`, `Double`, `CGPoint`, `CGSize`, `CGRect`. Blending **extrapolates** past `0...1` so a
  rubber-banding gesture keeps moving.
- `Interpolator<Value>` — two ends and a curve. **Each interpolator carries its own curve**, and
  applies it in `value(forInput:)`. Callers pass raw fractions.
- `TimingCurve` — control points or a named curve, with `caMediaTimingFunction` for CoreAnimation
  and `solvedProgress(forFraction:)` for evaluating it by hand. `reversed` mirrors it through the
  diagonal.
- `Transformation` / `KeyPathTransformation` / `ClosureTransformation` — one property being driven.
- `ViewPropertyInterpolator` — a bundle of transformations. Its `apply(_:)` passes the fraction
  through **un-eased**; easing already happened per-interpolator, and doing it twice is the classic
  way to make an interactive transition jump the moment the finger lifts.
- `ViewPropertyAnimator` — an `NSAnimationContext` group with a duration, a curve and a delay.

## 8. What was not ported

- **Chrome.** The App Store's back button, navigation palette, title header and double header are
  its design language, built on its own button class. Not general-purpose.
- **Routing.** Its `FlowController` / `FlowDestination` layer is business logic.
- **A UIKit-platform variant.** `UINavigationController` exists.
- **Appearance-transition forwarding.** The App Store forwards `beginAppearanceTransition` down
  the stack itself; here AppKit's own containment callbacks are left to do their job.

## 9. Known divergences from the App Store

| App Store | here | why |
|---|---|---|
| pages are framed from the container's `frame` | from its `bounds`, inset by `contentInsets` | `frame` is the container's rectangle in its *superview*, and only equals `bounds` while the container sits at the origin. It never bit them; it is still the wrong rectangle. |
| pop's first transformation is a `ClosureTransformation` | a `KeyPathTransformation`, symmetric with push | the App Store closure captures nothing but the source view, so no reason for it was visible. `ClosureTransformation` is still part of the API. |
| the whole stack is detached and re-attached on every change | only the difference is re-parented | re-parenting a view controller that did not move fires spurious appearance callbacks. |
| `Interpolator.value(forInput:)` is overloaded for `CGFloat` / `Double` / `Float` | one `CGFloat` overload | three overloads make every float-literal call site ambiguous in Swift. `Double` converts implicitly anyway. |
| a stack change during a transition applies immediately | it is deferred to the end | see [3.4](#34-changes-during-a-transition-are-deferred-not-applied). |
| dimming is an `AppStoreKit.BackgroundView` | a plain layer-backed `NSView` | only ever used for a solid fill. |
| defaults are the App Store's | defaults are **UIKit's** (`.uiKit`); the App Store's are one preset away (`.appStore`) | the App Store look is flatter than UIKit's — no edge shadow, less parallax, a front-loaded curve — and reads as sliding content rather than a page moving over another. Fidelity is still available, it is just not the default. |
| there is no edge shadow | a 9 pt edge shadow by default | ported from UIKit's `_UIVerticalEdgeShadowView` (via AppKitPlus). Set `edgeShadowWidth = 0` for the App Store's look. |
| the swipe's tracking options are the raw value `7` | the same raw value `7` | `NSEvent.SwipeTrackingOptions` names only bits 0 and 1; bit 2 is undocumented. Kept verbatim, because matching the shipped feel is the point. |

The three `InteractiveViewTransition` members are **designed, not copied**: the App Store protocol
of the same shape was only confirmed to have three method slots, and the semantics behind them
were never decompiled.
