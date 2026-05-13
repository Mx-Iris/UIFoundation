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
| `FuzzySearch` (MxIris-Library-Forks) | Fuzzy string matching used by `FilteringMenu` (both public and private API variants) |

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

### Filter UI (ported from `filter-ui`)

Filter UI ships as an **opt-in SPM trait** called `FilterUI` (default: disabled). When the trait is off the Filter sources are excluded via `#if FilterUI`, the `FuzzySearch` product is not linked, and no Filter symbols are exported. To enable it:

```swift
.package(url: "…/UIFoundation", traits: ["FilterUI"])         // SPM dependency
swift build --traits FilterUI                                 // CLI
```

Wiring in `Package.swift`:
- `traits: [.trait(name: "AppleInternal"), .trait(name: "FilterUI")]`
- SPM 6.2 automatically exposes each trait name as a Swift compilation condition, so `#if FilterUI` works without any `swiftSettings` `.define` plumbing.
- The `FuzzySearch` product uses `condition: .when(traits: ["FilterUI"])` on both `UIFoundationAppKit` and `UIFoundationAppleInternal`, so it disappears entirely when disabled.
- Every Filter source file (`Sources/UIFoundationAppKit/Filter/**/*.swift`, `Sources/UIFoundationAppleInternal/Filter/**/*.swift`) is wrapped in `#if FilterUI … #endif`.
- xcassets / Localization stay in the resource list (SPM has no per-resource trait condition); they just get bundled even when the trait is off, which is harmless.

`xcodebuild` has no trait CLI flag — when running tests through Xcode tooling the active traits come from the consuming Xcode project / scheme. From the command line use `swift build --traits FilterUI` to compile the Filter code.

`UIFoundationAppKit/Filter/` hosts the AppKit filter controls migrated from [`filter-ui`](https://github.com/freysie/filter-ui):
- `FilterSearchField` / `FilterSearchFieldCell` — search field with progress, filter buttons, vibrancy-aware rendering
- `FilterTokenField` / `FilterTokenFieldCell` — token-based filter field with comparison types
- `FilteringMenu_WithoutPrivateAPIUsage` — public-API variant of the filterable menu (under `FilteringMenu+Public/`)
- SwiftUI bridges: `FilterField`, `FilterToggle`, `filterFieldStyle(_:)`
- Resources (xcassets / Localization / Documentation.docc) live in `UIFoundationAppKit/Filter/Resources/`; `Package.swift` adds a `.process("Filter/Resources")` entry on top of the existing `Resources/`

The private-API variant `FilteringMenu` ships in `UIFoundationAppleInternal/Filter/` (uses `-[NSMenu highlightItem:]`, `_handleCarbonEvents:count:handler:`, and `HIMenuGetContentView` exposed via `UIFoundationAppleInternalObjC/include/NSMenu_FilteringPrivate.h` + `HIToolbox_Private.h`). Because the private menu reuses `FilterSearchField` from the public side, `UIFoundationAppleInternal` depends on `UIFoundationAppKit`.

The package now declares `defaultLocalization: "en"` because Filter ships en/da `.lproj` resources. SF Symbol / `SymbolConfiguration` call sites are wrapped in `if #available(macOS 11.0, *)` / `if #available(macOS 12.0, *)` to keep the umbrella platform at macOS 10.15+ (only a handful of declarative previews and `addFilterButton(systemSymbolName:)` are gated with `@available(macOS 12.0, *)`).

Note: SwiftUI `Button` is shadowed by `UIFoundationAppKit.Button` (an `NSButton` subclass), so SwiftUI views inside this module must use `SwiftUI.Button` / `SwiftUI.Image` explicitly (see `FilterToggle`).

**xcassets caveat:** the Filter resources rely on `Bundle.module.image(forResource:)` and `NSColor(named:bundle:)`, which require `actool`-compiled `Assets.car`. `swift build` / `swift test` from the command line do **not** invoke `actool` and copy the `.xcassets` folders verbatim, so resource lookups return `nil` in that mode. To exercise the Filter resource path (or run `FilterResourcesTests`), use the Xcode toolchain: `xcodebuild -scheme UIFoundation-Package -destination "platform=macOS" test -only-testing:UIFoundationTests/FilterResourcesTests` (temporarily move `UIFoundation.xcworkspace` aside first because that workspace only exposes the Example schemes). Consuming this package from an Xcode app target works as expected because Xcode handles `actool` itself.

## Code Style Notes

- Extensions on AppKit/UIKit classes follow the naming convention `NSClassName+.swift`
- One extension file per class in `UIFoundationToolbox/AppKit/`
- Button style subclasses live in `UIFoundationAppKit/Button/StyleSplittedButton/` (e.g., `PushButton`, `SwitchButton`, `HelpButton`)
- The `@retroactive` keyword is used for protocol conformances on types from other modules (e.g., `NSControl.StateValue: @retroactive ExpressibleByBooleanLiteral`)
- No linter or formatter is configured — style is enforced by convention only

## Documentation

- **Reverse engineering research reports** — All reverse engineering / framework internals research documents (AppKit/UIKit/CoreAnimation binary analysis, private API investigations, etc.) must be placed under the `Researchs/` directory at the repo root. Do **not** mix them into `docs/` or scatter them across module folders.
