# AppKitPlus

> What changes when the `AppKitPlus` trait is on: [AppKitPlus](https://github.com/AppKitSupportProgram/AppKitPlus-Release)
> ports UIKit's APIs onto AppKit, and this package uses it as the base class of `LayerBackedView` /
> `LayerBackedViewController` and as the owner of `NSEdgeInsets: Equatable`.
>
> AppKitPlus ships as a **binary** `.xcframework` (a dynamic framework built with library evolution
> on). It sits behind the opt-in SPM trait `AppKitPlus` (default: off) and reaches
> `UIFoundationAppKit` and `UIFoundationToolbox`. macOS only.

---

## Contents

- [1. Getting started](#1-getting-started)
- [2. What the trait changes](#2-what-the-trait-changes)
  - [2.1 The layer-backed base classes](#21-the-layer-backed-base-classes)
  - [2.2 `LayerBackedViewController`](#22-layerbackedviewcontroller)
  - [2.3 `NSEdgeInsets` equality](#23-nsedgeinsets-equality)
- [3. What it costs, trait on or off](#3-what-it-costs-trait-on-or-off)
- [4. The name-collision contract](#4-the-name-collision-contract)
- [5. Something AppKitPlus already does for you](#5-something-appkitplus-already-does-for-you)
- [6. Maintainer notes: bumping AppKitPlus](#6-maintainer-notes-bumping-appkitplus)
  - [6.1 Why the floor is 0.6.0](#61-why-the-floor-is-060)
  - [6.2 Re-check the collision surface first](#62-re-check-the-collision-surface-first)
  - [6.3 Survey the headers, not the `.swiftinterface`](#63-survey-the-headers-not-the-swiftinterface)
  - [6.4 What 0.6.0 added](#64-what-060-added)
- [7. Related records](#7-related-records)

---

## 1. Getting started

```swift
.package(url: "https://github.com/Mx-Iris/UIFoundation", from: "…", traits: ["AppKitPlus"])
```

```bash
swift build --traits AppKitPlus
```

If your app links AppKitPlus itself, turn this trait on (the README says the same). With AppKitPlus
linked and the trait off, `==` on `NSEdgeInsets` becomes ambiguous in your code, and that ambiguity
is yours to resolve — see [2.3](#23-nsedgeinsets-equality).

## 2. What the trait changes

### 2.1 The layer-backed base classes

All views and controllers in this library are created in code, with no xib or storyboard. The
layer-backed pair resolves its superclass from the trait:

```
NSView  ·or·  NSLayerBackedView   (the latter with the `AppKitPlus` trait on)
 └── LayerBackedView      (wantsLayer=true, updateLayer path, setup(), firstLayout())
      └── XiblessView     (init?(coder:) marked @available(*, unavailable))

NSViewController ·or· NSLayerBackedViewController   (the latter with the trait on)
 └── LayerBackedViewController<View: LayerBackedView>
```

The switch is two public typealiases: `LayerBackedViewBase`
([`LayerBackedView.swift`](../Sources/UIFoundationAppKit/Base/LayerBackedView.swift)) is
`NSLayerBackedView` or `NSView`, and `LayerBackedViewControllerBase`
([`LayerBackedViewController.swift`](../Sources/UIFoundationAppKit/Controller/LayerBackedViewController.swift))
is `NSLayerBackedViewController` or `NSViewController`. What `LayerBackedView` itself does — the
`updateLayer()` path, `setup()`, `firstLayout()`, the background pipeline — is the same either way
and is described in [LayerBackground.md](LayerBackground.md). The decision record for the view side
is Evolution [`0017`](Evolutions/0017-appkitplus-layer-backed-view.md).

**The guard is `#if AppKitPlus && canImport(AppKitPlus)`, not the trait alone.** The trait being on
does not by itself guarantee the module is linked: an Xcode consumer can enable the trait without
the product reaching this target. Without the `canImport` half, that combination fails on the
`import` instead of falling back to `NSView`.

### 2.2 `LayerBackedViewController`

`LayerBackedViewController<View: LayerBackedView>`
(`Sources/UIFoundationAppKit/Controller/LayerBackedViewController.swift`) is the controller-side
counterpart of `LayerBackedView`. It has the same `contentView` shape as
`XiblessViewController<View: NSUIView>` — a generic `contentView` taken through an `@autoclosure`
factory and assigned in `loadView()` — and its base class is resolved by the same trait guard,
through `LayerBackedViewControllerBase`. Decision record: Evolution
[`0018`](Evolutions/0018-layer-backed-view-controller.md).

**Only two of `NSLayerBackedViewController`'s six hooks survive the trait being off.**

| Hook | Trait off |
|------|-----------|
| `viewWillFirstAppear` / `viewDidFirstAppear` | Polyfilled here, driven from `viewWillAppear()` / `viewDidAppear()`: `super` first, then the flag, then the hook — the same order as AppKitPlus |
| `viewWillFirstLayout` / `viewDidFirstLayout` / `viewUpdateLayer` / `viewSafeAreaInsetsDidChange` | **Not** polyfilled — the view drives them |

A subclass that overrides one of the four unpolyfilled hooks must wrap the override in
`#if AppKitPlus && canImport(AppKitPlus)`, or it will not compile with the trait off.

**Overriding `loadView()` is safe.** `NSLayerBackedViewController` does its wiring in `-setView:` —
the view's back reference, the layout guides, the additional safe-area insets, the safe-area KVO —
and not in `-loadView`, so assigning `view` keeps all six hooks attached.
`LayerBackedViewControllerTests` keeps a canary on this through `layerBackedView`, which goes `nil`
exactly when that path stops recognising the root view.

The overridden `loadView()` also reproduces the one thing AppKitPlus's own `loadView()` does besides
installing the view: `autoresizingMask = [.width, .height]`. `XiblessViewController` does not do
this, and was deliberately left alone.

### 2.3 `NSEdgeInsets` equality

`NSEdgeInsets`'s `Equatable` conformance and `==` in `UIFoundationToolbox`
([`NSEdgeInsets+.swift`](../Sources/UIFoundationToolbox/AppKit/NSEdgeInsets+.swift)) are compiled
**only with the trait off**. AppKitPlus declares the same conformance, as UIKit does for
`UIEdgeInsets`, and two copies make `==` ambiguous in every module that imports both. `Hashable`
stays in this package and uses AppKitPlus's `==` — which is why `UIFoundationToolbox` depends on
the AppKitPlus product under the trait.

## 3. What it costs, trait on or off

**The package's macOS floor is 12 because of this dependency, whether or not the trait is on.** A
binary target's platform requirement is checked on the package graph, so neither `@available` nor a
compilation condition can hold the floor at 10.15 while the trait merely *exists*. Measured:

```
error: the library 'UIFoundation' requires macos 10.15, but depends on the product 'AppKitPlus' which requires macos 12.0
```

The "keep the floor down, annotate each declaration" trick that `UIFoundationSettings` (macOS 14)
uses works only for source targets.

**With the trait off, SwiftPM does not fetch AppKitPlus at all** — no `Package.resolved` entry, no
clone, no download (measured). A default consumer pays nothing beyond the floor.

## 4. The name-collision contract

**A subclass may not declare a property whose name AppKitPlus already added to that class.** Swift
treats it as an illegal override — `overriding non-open property outside of its defining module` —
not as shadowing. It is *not* an Objective-C bridging artefact: `@nonobjc` on the extension property
does not help (measured on a pure-Swift probe).

**It travels with the module.** A target that only does `import UIFoundation` and never imports
AppKitPlus still inherits the collision, so every consumer that turns this trait on lives under the
same restriction.

Three names have already been hit here:

| Where | Was | Now | Collides with |
|-------|-----|-----|---------------|
| `QuickActionBar.ResultsTableView` | `parent` | `resultsView` | `NSFocusItem.parent`, via `NSView (Focus)` |
| Example app's `NavigationDemoViewController` | `navigationController` | `navigationStackController` | `NSViewController.navigationController` |
| `XiblessCollectionViewItem` | `contentView` | *(unchanged)* | fixed upstream in 0.2.1 instead |

The third row is the one to imitate. `contentView` is a name any `NSCollectionViewItem` /
`NSTableCellView` subclass wants, so it was fixed in AppKitPlus rather than worked around here. When
a collision is on a name this library owns and downstream code also wants, prefer the upstream fix.

Three members of `NSView (Geometry)` are live collision hazards on **any** `NSView` subclass:
`center`, `transform` and `contentMode`. This library is immune only because its own spellings live
behind `.box` — `FrameworkToolbox<NSUIView>.center` is a different declaration site, which is
exactly what that namespace is for. Verified: no `NSView` subclass in `UIFoundationComponent` or
`UIFoundationToolbox` declares any of the three.

Since 0.6.0, five more names sit on `NSLayerBackedView` itself, and so on every `LayerBackedView`
subclass while the trait is on — see [6.4](#64-what-060-added).

## 5. Something AppKitPlus already does for you

`NSView (UpdateProperties)` ships `setNeedsUpdateProperties` / `updateProperties` /
`updatePropertiesIfNeeded` with **automatic Observation tracking** on macOS 14+. It uses
`withObservationTracking`, re-armed through a main-queue hop because `onChange` fires on `willSet`,
and is driven by a per-instance dynamic subclass rather than a process-wide swizzle. AppKit has no
equivalent of UIKit's `updateProperties()` of its own — measured, zero hits across the macOS 27 SDK's
AppKit headers. Before hand-rolling an observation-driven rebuild, check whether this trait is
already on.

## 6. Maintainer notes: bumping AppKitPlus

### 6.1 Why the floor is 0.6.0

**The `NSEdgeInsets` conformance in [2.3](#23-nsedgeinsets-equality) first ships in AppKitPlus
0.6.0** — 0.5.0's `.swiftinterface` has none. Lower the floor again and a trait-on build that
resolves an older AppKitPlus fails on `Hashable`, for want of `Equatable`.

The two releases that earlier raises of the floor excluded both failed **silently**:

- **Through 0.1.6**, an `NSView (Appearance)` category declared `backgroundColor`, which shadows
  `LayerBackgroundProviding`'s property of the same name. The renderer simply stops receiving the
  value — in this module *and* in every downstream one — and `LayerBackedTableCellView` was hit too,
  despite not inheriting the new base class. 0.1.6 also lowered content compression resistance to
  500.
- **Through 0.2.0**, `NSCollectionViewItem` / `NSTableCellView` carried an extension property named
  `contentView`; 0.2.1 renamed it `configurationContentView`.

`LayerBackedViewBaseClassTests` keeps a canary on the first two (the `backgroundColor` shadowing and
the compression resistance).

### 6.2 Re-check the collision surface first

**When bumping AppKitPlus, re-check the collision surface before anything else.** The hosts that
matter are `NSView`, `NSViewController`, `NSTableCellView`, `NSTableRowView`,
`NSCollectionViewItem`, `NSControl`, `NSButton`, `NSMenuItem`, `NSToolbarItem`, `NSWindow`,
`NSTableView`, `NSOutlineView`, `NSCollectionView`, `NSEvent`, `NSCell`.

The version requirement does not protect you: `from:` is up-to-next-major even for `0.x`, so a 0.3.0
will be picked up automatically.

**Verify with every trait on, not just this one.** `swift build --traits AppKitPlus` compiles a
subset that misses these collisions entirely — the `parent` collision lives in `QuickActionBar`
sources and only surfaces when both traits are on. Use the full trait list (see the build commands in
`AGENTS.md`), and build the example app too; that is what caught the `navigationController`
collision.

### 6.3 Survey the headers, not the `.swiftinterface`

**`AppKitPlus.swiftinterface` cannot show you most of the surface.** Most of AppKitPlus's AppKit
surface ships as **Objective-C categories**, and a category never appears in a `.swiftinterface`.
Measured: the 0.4.4 interface (2432 lines) contains no `extension AppKit.NSView` whatsoever, while the
sources carry **17** `NSView` categories (`Geometry`, `ViewHierarchy`, `Appearance`, `Interactions`,
`Animation`, `Focus`, `UpdateProperties`, `TraitEnvironment`, `Accessories`, `NavigationSupport`, …)
and 8 on `NSViewController`.

Evolution [`0024`](Evolutions/0024-component-layout-system.md) drew the opposite conclusion from that
same interface file and was wrong; the correction is recorded in its research section (the quoted
block after "AppKitPlus 帮不上这个忙", and the decision-log entry of 2026-09-21).

Grep the public headers instead:

```bash
grep -rn "^@interface NSView (" <AppKitPlus checkout>/AppKitPlus/**/*.h
```

### 6.4 What 0.6.0 added

**Five members on `NSLayerBackedView` itself**: `layoutMargins`, `directionalLayoutMargins`,
`preservesSuperviewLayoutMargins`, `insetsLayoutMarginsFromSafeArea` and `layoutMarginsDidChange()`.
With the trait on, every `LayerBackedView` subclass inherits them, so a subclass that declares one
compiles with the trait off and fails with it on (`cannot override with a stored property
'layoutMargins'`, measured on a probe). None in this repo or the example app declares one (checked
at the bump).

**Swift extensions with UIKit spellings**: `NSEdgeInsets.zero`, `NSDirectionalEdgeInsets.zero`,
`Codable` on both inset types, and `NSBezierPath`'s `init(roundedRect:cornerRadius:)` /
`addLine(to:)` / `addArc(withCenter:…)`. These repeat names in `LayerBackgroundRenderer.swift` (a
`package` `NSEdgeInsets.zero`) and `NVActivityIndicatorShape.swift` (internal `NSBezierPath`
helpers). Both still compile without ambiguity in the full-trait build, tests included, and neither
is public, so neither reaches a consumer.

## 7. Related records

- Evolution [`0017`](Evolutions/0017-appkitplus-layer-backed-view.md) — `LayerBackedView` on
  `NSLayerBackedView`.
- Evolution [`0018`](Evolutions/0018-layer-backed-view-controller.md) — `LayerBackedViewController`.
- Evolution [`0024`](Evolutions/0024-component-layout-system.md) — carries the corrected
  `.swiftinterface` survey.
- [LayerBackground.md](LayerBackground.md) — the background pipeline `LayerBackedView` is built on.
