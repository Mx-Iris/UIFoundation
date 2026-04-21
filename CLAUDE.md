# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

UIFoundation is a Swift package providing foundational UI components and utilities on top of AppKit/UIKit. It primarily targets macOS (AppKit) with cross-platform support for iOS, tvOS, visionOS, and Mac Catalyst. APIs are unstable and under active development.

## Build & Test

```bash
swift package update && swift build 2>&1 | xcsift
swift package update && swift test 2>&1 | xcsift
swift build 2>&1 | xcsift --print-warnings
```

- Always run `swift package update` before building to avoid stale dependency checkouts
- Swift tools version: 6.2, language mode: Swift 5 (`swiftLanguageModes: [.v5]`)
- Platforms: macOS 10.15+, iOS 13+, macCatalyst 13+, tvOS 13+, visionOS 1+
- Test target: `UIFoundationTests` (minimal coverage — test suite is sparse)
- Run a single test: `swift test --filter UIFoundationTests.testName 2>&1 | xcsift`

## Architecture

### Products

- **UIFoundation** — Umbrella library re-exporting all public sub-modules via `@_exported import`
- **UIFoundationToolbox** — Standalone extensions and utilities (usable independently)
- **UIFoundationAppleInternal** — Private API wrappers (**must not** be linked in App Store targets; uses `CABackdropLayer`, `CAFilter`, `@_silgen_name` for private CoreGraphics symbols)

### Module Dependency Graph

```
UIFoundation (umbrella: @_exported imports)
├── UIFoundationAppKit       (macOS only)
├── UIFoundationUIKit        (iOS/tvOS/visionOS/Catalyst)
├── UIFoundationShared       (cross-platform views & controllers)
├── UIFoundationUtilities    (property wrappers, DSLs, helpers)
└── UIFoundationToolbox      (extensions via .box namespace)
    └── UIFoundationTypealias

UIFoundationAppleInternal    (separate product)
└── UIFoundationAppleInternalObjC  (private ObjC headers)
```

### External Dependencies

| Package | Usage |
|---------|-------|
| `FrameworkToolbox` (Mx-Iris) | Provides the `.box` namespace pattern for conflict-free extensions |
| `AssociatedObject` (p-x9) | `@AssociatedObject` macro for runtime-associated properties |

### Local/Remote Dependency Switching

`Package.swift` has a custom `.package(local:remote:)` helper. When the package is consumed as a dependency (detected via `#filePath` containing `/checkouts/`, `/SourcePackages/`, or `/.build/`), it always uses remote. For local development, set `isEnabled: true` on a local path entry and ensure the sibling repo exists on disk.

## Key Patterns & Conventions

### Cross-Platform Typealias

`UIFoundationTypealias` defines `NSUIView`, `NSUIColor`, `NSUIFont`, etc. All cross-platform code uses these aliases instead of `#if canImport` branching. Platform guard: `#if canImport(AppKit) && !targetEnvironment(macCatalyst)`.

**Caveat**: `NSUIStackViewAlignment` maps to `NSLayoutConstraint.Attribute` on AppKit (not `NSStackView.Alignment`), which has different semantics than UIKit's `UIStackView.Alignment`. The StackView code uses `.hStackDefaultValue`/`.vStackDefaultValue` to bridge this difference.

### View Base Class Hierarchy

All views and controllers are created in code (no Xib/Storyboard):

```
NSView
 └── LayerBackedView      (wantsLayer=true, updateLayer path, setup(), firstLayout())
      └── XiblessView     (init?(coder:) marked @available(*, unavailable))
```

- `LayerBackedView` uses `wantsUpdateLayer = true` + `updateLayer()` for rendering (not `draw(_:)`). It provides built-in `cornerRadius`, `shadowRadius`, `borderWidth` etc. via `@ViewInvalidating(.display)`.
- `setup()` — subclass override point for initialization, called from both `init(frame:)` and `init?(coder:)`.
- `firstLayout()` — called exactly once on first `layout()`, using a `lazy var _firstLayout: Void` trick. Use for size-dependent setup.
- Controllers: `XiblessViewController<View: NSUIView>` takes a generic `contentView` via `@autoclosure` factory, assigned in `loadView()`.

### `.box` Namespace Extensions

All extensions on framework types go through the `.box` namespace (from FrameworkToolbox) to avoid naming collisions:

```swift
tableView.box.makeView(ofClass: MyCell.self)
button.box.setAction { sender in ... }
```

`UIFoundationToolbox.swift` uses `@_exported import FrameworkToolbox` to propagate the `.box` accessor to all downstream modules.

### `@ViewInvalidating` Property Wrapper

Auto-triggers view invalidation on property changes. Uses Swift's `_enclosingInstance` subscript (not standard `wrappedValue`) to access the owning view. Supports combining multiple invalidation types:

```swift
@ViewInvalidating(.display)
open dynamic var cornerRadius: CGFloat = 0

@ViewInvalidating(.display, .layout)
open dynamic var someProperty: CGFloat = 0
```

Multi-invalidation is implemented via nested `Invalidations.Tuple<I1, I2>` types with up to 10 parameter overloads. AppKit-only extras: `.restorableState`, `.reloadData` (requires view to conform to `ViewReloading`).

### `@resultBuilder` DSLs

- **`@ViewHierarchyBuilder`** — Declarative view hierarchy construction. Core types: `ViewItem<View>` (supports `@dynamicMemberLookup` for property config), `ControllerItem<VC>` (handles `addChild`), `LayoutGuideItem`.
- **`HStackView` / `VStackView`** — Use `@ArrayBuilder<StackViewComponent>` (from FrameworkToolbox), not a custom builder. `Spacer(spacing:)` and `MaxSpacer()` are special views recognized internally. macOS-only modifiers: `.gravity(_:)`, `.visibilityPriority(_:)` stored via `@AssociatedObject`.

### `Then` Protocol

Internal protocol duplicated in each module (`UIFoundationAppKit`, `UIFoundationShared`, `UIFoundationUtilities`, `UIFoundationUIKit`) — not publicly exported. All `NSObject` subclasses get `.then { }`, `.with { }`, `.do { }`, `.as { }` via `extension NSObject: Then {}`.

### Target-Action as Closures

`TargetActionProvider` + `ActionTrampoline<T>` (an NSObject holding a `(T) -> Void` closure as `@objc func invoke(_:)`). Stored on the provider via `@AssociatedObject`. Conformers: `NSControl`, `NSCell`, `NSToolbarItem`, `NSMenuItem`, `NSGestureRecognizer`, `NSColorPanel`.

**Note**: `NSControl` has two coexisting action APIs with separate associated keys — legacy `.box.setAction { sender in ... }` (untyped `ActionHandler`) and type-safe `.box.actionBlock` (via `TargetActionProvider`).

### `@MagicViewLoading` / `@MagicWindowLoading`

Property wrappers using `_enclosingInstance` subscript: on **get**, calls `loadViewIfNeeded()` / `loadWindowIfNeeded()` then returns the stored value. The stored value is force-unwrapped — subclasses must assign these properties in `setup()` or `loadView()` before any external access.

### `ConstraintMaker`

`makeConstraints { make in ... }` returns activated `[NSLayoutConstraint]` where `make` is the view itself (no proxy object needed).

### Factory Methods

`TableViewProtocol` / `OutlineViewProtocol` provide `scrollableTableView()` / `scrollableSingleColumnOutlineView()` static factories returning `(NSScrollView, Self)` tuples.

## Code Style Notes

- Extensions on AppKit/UIKit classes follow the naming convention `NSClassName+.swift`
- One extension file per class in `UIFoundationToolbox/AppKit/`
- Button style subclasses live in `UIFoundationAppKit/Button/StyleSplittedButton/` (e.g., `PushButton`, `SwitchButton`, `HelpButton`)
- The `@retroactive` keyword is used for protocol conformances on types from other modules (e.g., `NSControl.StateValue: @retroactive ExpressibleByBooleanLiteral`)
- No linter or formatter is configured — style is enforced by convention only

## Documentation

- **Reverse engineering research reports** — All reverse engineering / framework internals research documents (AppKit/UIKit/CoreAnimation binary analysis, private API investigations, etc.) must be placed under the `Researchs/` directory at the repo root. Do **not** mix them into `docs/` or scatter them across module folders.
