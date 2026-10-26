# Layer Background

> `LayerBackedView` and the background pipeline under it: corner radius and curve, background
> colour, borders and shadow, all drawn through the backing layer rather than `draw(_:)`. The same
> pipeline can be attached to any `NSView` subclass that cannot inherit from `LayerBackedView`.
>
> Ships in `UIFoundationAppKit` (`Sources/UIFoundationAppKit/Base/`), no trait. macOS only. With the
> `AppKitPlus` trait on, `LayerBackedView`'s superclass changes — see [AppKitPlus.md](AppKitPlus.md).

---

## Contents

- [1. `LayerBackedView`](#1-layerbackedview)
- [2. The pipeline on a view you cannot subclass](#2-the-pipeline-on-a-view-you-cannot-subclass)
- [3. The three pieces](#3-the-three-pieces)
- [4. Contracts and traps](#4-contracts-and-traps)
  - [4.1 Classes that must not conform](#41-classes-that-must-not-conform)
  - [4.2 `shadow` does not fan out by itself](#42-shadow-does-not-fan-out-by-itself)
  - [4.3 Nothing in Interface Builder](#43-nothing-in-interface-builder)
  - [4.4 A rounded host clips on macOS 27.2](#44-a-rounded-host-clips-on-macos-272)
- [5. Implementation notes](#5-implementation-notes)
  - [5.1 Continuous corners and the full border](#51-continuous-corners-and-the-full-border)
  - [5.2 Testing on rendered pixels](#52-testing-on-rendered-pixels)

---

## 1. `LayerBackedView`

`LayerBackedView` (`Base/LayerBackedView.swift`) is the base view of this library; `XiblessView`
derives from it and marks `init?(coder:)` `@available(*, unavailable)`, since views here are created
in code with no xib or storyboard.

- **It renders through the layer.** `wantsUpdateLayer` is `true` and drawing happens in
  `updateLayer()`, not `draw(_:)`. `wantsLayer` is on. (In the code, `wantsUpdateLayer` returns
  `isLayerBackingEnabled`, which `LayerBackedView` answers `true`.)
- **It conforms to `LayerBackgroundProviding`**, and gets `cornerRadius` / `backgroundColor` /
  `border*` / `shadow*` / `shadowPath` from there (sections 2 and 3).
- **`setup()`** is the subclass override point for initialization. It is called from both
  `init(frame:)` and `init?(coder:)`.
- **`firstLayout()`** is called exactly once, on the first `layout()`, which makes it the place for
  size-dependent setup. The once-only guarantee is a lazy-property trick: `layout()` reads a
  private `lazy var _firstLayout` whose initializer calls `firstLayout()`, and a lazy initializer
  runs only on first access. (It is typed `() -> Void` — the initializer returns an empty closure
  that later calls invoke — where older notes describe it as `lazy var _firstLayout: Void`.)

A subclass overrides `setup()` / `firstLayout()` only; the background pipeline is wired for it.

## 2. The pipeline on a view you cannot subclass

`LayerBackedView` is a thin shell over a reusable rendering helper, so the same `cornerRadius` /
`backgroundColor` / `border*` / `shadow*` pipeline can be put on a view that cannot inherit from it —
typically an `NSTableCellView` or an `NSCollectionViewItem`'s `view`. Conform to
`LayerBackgroundProviding` and make the three calls `LayerBackedView` makes for you:

```swift
final class MyCell: NSTableCellView, LayerBackgroundProviding {
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        attachToSelfIfNeeded()        // enables layer backing, installs renderer
        cornerRadius = 10             // protocol forwarding properties
        backgroundColor = .controlBackgroundColor
        borderPositions = .all
        borderColor = .separatorColor
        borderWidth = 1
    }
    required init?(coder: NSCoder) { super.init(coder: coder); attachToSelfIfNeeded() }

    override var wantsUpdateLayer: Bool { true }
    override func updateLayer() { super.updateLayer(); updateLayerBackgroundIfNeeded() }
    override func layout()      { super.layout();      layoutLayerBackgroundIfNeeded() }
}
```

That is the whole contract: `attachToSelfIfNeeded()` once after `super.init` (in every
initializer), `wantsUpdateLayer` returning `true`, and the two hooks forwarded from `updateLayer()`
and `layout()`.

A working demo is
[`LayerBackgroundDemoViewController.swift`](../UIFoundationExample-macOS/UIFoundationExample-macOS/Demos/LayerBackgroundDemoViewController.swift)
(`LayerBackgroundDemoViewController` / `LayerBackgroundCell`), one entry in the example app's demo
browser.

## 3. The three pieces

All three live under `Sources/UIFoundationAppKit/Base/`.

**`LayerBackgroundRenderer`** ([`LayerBackgroundRenderer.swift`](../Sources/UIFoundationAppKit/Base/LayerBackgroundRenderer.swift))
is an opaque rendering object. It holds every configuration property, the `BorderPositions` /
`BorderLocation` types and the `CAShapeLayer` border sublayer. It drives the layer in `updateLayer()`
/ `layout()` and sets `owner.needsDisplay = true` on every property change. It weak-references its
host through `attach(to:)`, which also sets `wantsLayer = true` and
`layerContentsRedrawPolicy = .onSetNeedsDisplay`.

**`LayerBackgroundProviding`** ([`LayerBackgroundProviding.swift`](../Sources/UIFoundationAppKit/Base/LayerBackgroundProviding.swift))
is a `@MainActor` protocol constrained to `NSView`. Its sole requirement is `isLayerBackingEnabled`
(`Bool`), which the extension defaults to `true`; override it to opt a conformer out of the
pipeline. The protocol extension provides:

- `backgroundRenderer`, a property backed by `@AssociatedObject(.retain(.nonatomic))` (from the
  `AssociatedObject` macro package), lazily initialised on first access and completely hidden from
  conformers.
- The forwarding properties — `cornerRadius`, `cornerCurve`, `backgroundColor`, `border*`,
  `shadow*`, `shadowPath` — which plumb into the renderer.
- `attachToSelfIfNeeded()`, which binds the renderer to the conforming view. Call it once after
  `super.init`. It is gated on `isLayerBackingEnabled`.
- `updateLayerBackgroundIfNeeded()` / `layoutLayerBackgroundIfNeeded()`, the hooks to call from the
  conformer's `updateLayer()` / `layout()` overrides. Both are no-ops when `isLayerBackingEnabled`
  is `false`.

**`LayerBackedView`** conforms to `LayerBackgroundProviding` and wires `attachToSelfIfNeeded()` /
`updateLayerBackgroundIfNeeded()` / `layoutLayerBackgroundIfNeeded()` automatically.

## 4. Contracts and traps

### 4.1 Classes that must not conform

A class that already defines its own `backgroundColor` — `NSTextField`, `NSTableView` and the like —
collides with the protocol's default. Don't conform those classes; they were never the target of
this pipeline. (`NSScrollView` is another such class; `WelcomePanelController`'s
`BackgroundScrollView` overrides its `backgroundColor` instead of conforming.)

The same shadowing can come from a dependency: AppKitPlus up to 0.1.6 added a `backgroundColor` to
every `NSView` and silently cut the renderer off — see [AppKitPlus.md](AppKitPlus.md#61-why-the-floor-is-060).

### 4.2 `shadow` does not fan out by itself

`NSView.shadow` is a stored property on `NSView`, and class-hierarchy lookup wins over
protocol-extension dispatch. If you want `view.shadow = nsShadow` to fan out to `shadowColor` /
`shadowOffset` / `shadowRadius`, override `shadow` explicitly on the conformer, mirroring
`LayerBackgroundRenderer.shadow`.

### 4.3 Nothing in Interface Builder

Protocol extensions cannot use `@IBInspectable`, so the forwarding properties are **not editable in
Interface Builder**. `@IBDesignable` still works on `LayerBackedView` itself, but the inspector won't
show `cornerRadius`, `borderColor` and the rest. The project's policy is code-only views, so this is
intentional.

### 4.4 A rounded host clips on macOS 27.2

**On macOS 27.2 a rounded host clips, whatever `clipsToBounds` was** (measured). AppKit turns
`clipsToBounds` on whenever a backing layer's `cornerRadius` changes — assigning the same value
again leaves it alone, and turning it back off afterwards sticks — and `updateLayer()` copies
`clipsToBounds` into `masksToBounds` right after assigning the radius. So the host's rounded mask
trims its subviews and its border sublayer: a `.center` or `.outside` border loses the part outside
the bounds unless the conformer turns `clipsToBounds` off once the radius has reached the layer.

This package does not compensate for it; it is noted as a follow-up in Evolution
[`0031`](Evolutions/0031-layer-background-corner-curve.md).

## 5. Implementation notes

### 5.1 Continuous corners and the full border

**A continuous full border is the border layer's own border, not a stroked path.** `cornerCurve`
(`.circular` by default) goes onto the backing layer, so the fill, the mask and a pathless shadow
follow it. A border stroked along a path cannot follow it: Core Animation has no API that hands out
the continuous corner as a path, and `NSBezierPath` only knows circular arcs.

So when `cornerCurve == .continuous`, `cornerRadius > 0` and `borderPositions == .all`, the
`CAShapeLayer` gets no path and draws its own `borderWidth` / `borderColor`, which follow its
`cornerCurve`. Its frame is the host's bounds inset by `borderInsets` and then grown by 0, half a
border width or a whole one for `.inside` / `.center` / `.outside`, and its radius grows by the same
amount. Circular corners and partial borders still stroke a path, unchanged. Decision record:
Evolution [`0031`](Evolutions/0031-layer-background-corner-curve.md).

### 5.2 Testing on rendered pixels

**Test the pipeline on rendered pixels, against clipped references.** `CALayer.render(in:)` draws
the rounded background of a layer that does not mask to its bounds up to 1.5 pt outside the curve:
at circular radius 20, the top row starts at column 31 at 2×, where the geometry and a clipped layer
both give 34. A fill used as a reference must therefore be clipped.
[`LayerBackgroundCornerCurveTests`](../Tests/UIFoundationTests/LayerBackgroundCornerCurveTests.swift)
shows the setup, including how to turn clipping off for good when a test needs the outer half of a
border (see [4.4](#44-a-rounded-host-clips-on-macos-272)).
