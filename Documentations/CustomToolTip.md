# CustomToolTip

> A customizable replacement for the look of AppKit's tooltips. Every `NSView.toolTip` keeps working
> as before; `CustomToolTipManager` restyles the panel AppKit's private `NSToolTipManager` draws —
> process-wide, per view, or both.
>
> Lives in `UIFoundationAppleInternal` (`Sources/UIFoundationAppleInternal/Tooltip/`) and uses
> private API, so it is **not App-Store-safe**. It has no trait of its own: it ships unconditionally
> with the `AppleInternal` trait. macOS only.
>
> Evidence for everything below: [`AppKit-NSToolTipManager-Internals.md`](../Researchs/AppKit-NSToolTipManager-Internals.md).

---

## Contents

- [1. Getting started](#1-getting-started)
- [2. `ToolTipStyle`](#2-tooltipstyle)
- [3. `CustomToolTipManager`](#3-customtooltipmanager)
- [4. Implementation notes](#4-implementation-notes)
  - [4.1 The hook](#41-the-hook)
  - [4.2 Why every hook method calls `MainActor.assumeIsolated`](#42-why-every-hook-method-calls-mainactorassumeisolated)
  - [4.3 Layer-backing reconciliation](#43-layer-backing-reconciliation)
  - [4.4 Private headers](#44-private-headers)

---

## 1. Getting started

Enable the `AppleInternal` trait, then:

```swift
import UIFoundation

// once, in applicationDidFinishLaunching:
CustomToolTipManager.install()

// global tweak applied to every NSView.toolTip
CustomToolTipManager.shared.globalStyle = .default

// per-view override (associated-object backed)
view.box.customTooltipStyle = .default.with { $0.cornerRadius = 10 }
```

The sources are compiled under `#if canImport(AppKit) && !targetEnvironment(macCatalyst)`, inside a
target that exists only with `AppleInternal` on.

## 2. `ToolTipStyle`

A value type describing how a tooltip looks. Every field is optional; `nil` means "what the system
would do".

| Group | Fields |
| --- | --- |
| Text and placement | `font`, `textColor`, `backgroundColor`, `contentMargin`, `yOffsetFromCursor`, `initialDelay` |
| Layer-backed fields | `cornerRadius`, `borderColor`, `borderWidth`, `shadowColor`, `shadowOffset`, `shadowRadius` |

- **`.system`** is the all-`nil` style: a no-op, the stock tooltip.
- **`.default`** is the recommended preset.
- **`with(_:)`** returns a mutated copy, so presets are adjusted rather than rebuilt:
  `.default.with { $0.cornerRadius = 10 }`.

A partially filled style works field by field: each `nil` field falls back to AppKit's own value
(see [§4.1](#41-the-hook)). Setting any of `backgroundColor` or the layer-backed fields switches the
tooltip panel from the system blur to a layer-backed view (see [§4.3](#43-layer-backing-reconciliation)).

## 3. `CustomToolTipManager`

A `@MainActor` singleton, `CustomToolTipManager.shared`.

- **`install()` / `uninstall()` are reference-counted.** N calls to `install()` need N calls to
  `uninstall()` before the original behaviour is fully restored, so independent parts of an app can
  each install without coordinating.
- **`globalStyle`** is the process-wide fallback, applied to every `NSView.toolTip`.
- **`setStyle(_:for:)`**, or the equivalent `view.box.customTooltipStyle`, attaches a per-view
  override. It wins over `globalStyle` for that view only; setting `nil` falls back to
  `globalStyle`.

Per-view overrides work in isolation: one styled view can co-exist with other views that still get
the unmodified system tooltip, including the system blur.

The per-view slot is `_customTooltipStyle`, stored on `NSView` through
`@AssociatedObject(.copy(.nonatomic))` in `NSView+CustomToolTip.swift` and exposed as
`FrameworkToolbox<NSView>.customTooltipStyle`.

---

## 4. Implementation notes

### 4.1 The hook

`CustomToolTipManagerHook` is a `@DynamicSubclassHook` container, from `FrameworkToolbox`'s
`ObjCRuntimeToolbox` module. Installing it isa-swizzles the `NSToolTipManager.shared` singleton —
only that one object changes class; nothing is swizzled process-wide. It overrides:

- **`displayToolTip:`** — records which tooltip (and so which view) is being displayed, in
  thread-local storage, so the field hooks below can resolve that view's style.
- **`toolTipAttributes`, `toolTipTextColor`, `toolTipBackgroundColor`, `toolTipContentMargin`,
  `toolTipYOffset`** — each returns the resolved style's value for its field, and falls back to
  `callSuper()` when that field is `nil`. That per-field fallback is what lets a partially populated
  `ToolTipStyle` behave like the system for everything it does not set.
- **`installContentView:forToolTip:toolTipWindow:isNew:`** — the layer-backed content-view swap,
  described in [§4.3](#43-layer-backing-reconciliation).

`_newToolTipWindow` is declared in the private header but deliberately not overridden: the system
keeps creating the panel and its `NSVisualEffectView`, and the reconciliation happens afterwards.

### 4.2 Why every hook method calls `MainActor.assumeIsolated`

The `@DynamicSubclassHook` macro forbids `@MainActor` hook methods, yet `CustomToolTipManager` is
main-actor isolated. Each hook method therefore wraps its calls into the manager in
`MainActor.assumeIsolated { ... }`. That is sound because `NSToolTipManager` only ever runs on the
main thread, which the research report verifies. Don't replace it with a hop (`Task { @MainActor … }`
or `DispatchQueue.main.async`): the hook has to return the value synchronously.

### 4.3 Layer-backing reconciliation

The hook overrides `installContentView:forToolTip:toolTipWindow:isNew:` because AppKit calls it once
per tooltip display, before `addDrawingSubviewForToolTip:` — the right moment to match the panel to
the style resolved for the tooltip being shown. On each call it:

1. Inspects the resolved style and decides whether it needs layer backing: it does when any of
   `backgroundColor`, `cornerRadius`, `borderColor`, `borderWidth`, `shadowColor`, `shadowOffset`
   or `shadowRadius` is set.
2. Swaps `panel.contentView` accordingly, between the system `NSVisualEffectView`
   (`material = .toolTip`) and a `LayerBackedView`.
3. Resets the cached draw views `_normalToolTipDrawView` / `_expansionToolTipDrawView` to `nil`
   through KVC, so the system rebuilds them inside the new content view.
4. Saves the panel's pre-customization `backgroundColor`, `isOpaque` and `hasShadow` in an
   associated object, and restores them when the resolved style stops needing layer backing.

Because this runs on every display rather than once per panel, switching a view back to a style
without layer-backed fields restores the system blur for that view's tooltips, and per-view
overrides behave exactly like the global style.

### 4.4 Private headers

All three live in `Sources/UIFoundationAppleInternalObjC/include/`:

| Header | Declares |
| --- | --- |
| `NSToolTipManager.h` | The whole class. It is fully private — no public AppKit header declares it, despite Apple's documentation page. Declares `+sharedToolTipManager` (bridged to Swift as `.shared` through `NS_SWIFT_NAME(shared)`), the initial tooltip delay setter, and every hook target. |
| `NSToolTip.h` | The private tooltip model class. Only `view`, `cell`, `string` and `trackingNum` are needed, so the hook can route each display to the right per-view style. |
| `NSColor_Private.h` | Adds `+toolTipColor` to the public `NSColor`. |

The naming follows the repository's rule: `<Class>.h` for a class with no public header,
`<Class>_Private.h` for a category on a public one.
