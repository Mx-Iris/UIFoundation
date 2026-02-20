# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

UIFoundation is a Swift package providing foundational UI components and utilities on top of AppKit/UIKit. It primarily targets macOS (AppKit) with cross-platform support for iOS, tvOS, visionOS, and Mac Catalyst. APIs are unstable and under active development.

## Build & Test

```bash
swift build 2>&1 | xcsift
swift test 2>&1 | xcsift
swift build 2>&1 | xcsift --print-warnings
```

- Swift tools version: 6.2, language mode: Swift 5 (`swiftLanguageModes: [.v5]`)
- Platforms: macOS 10.15+, iOS 13+, macCatalyst 13+, tvOS 13+, visionOS 1+

## Architecture

### Products

- **UIFoundation** — Umbrella library re-exporting all public sub-modules
- **UIFoundationToolbox** — Standalone extensions and utilities (usable independently)
- **UIFoundationAppleInternal** — Private API wrappers (App Store rejection risk)

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

## Key Patterns & Conventions

### Cross-Platform Typealias

`UIFoundationTypealias` defines `NSUIView`, `NSUIColor`, `NSUIFont`, etc. All cross-platform code uses these aliases instead of `#if canImport` branching. Platform guard: `#if canImport(AppKit) && !targetEnvironment(macCatalyst)`.

### "Xibless" Base Classes

All views and controllers are created in code (no Xib/Storyboard). Base classes follow the pattern:

```swift
open class LayerBackedView: NSView {
    override init(frame:) { super.init(...); commonInit() }
    required init?(coder:) { super.init(...); commonInit() }
    open func setup() {}  // Subclass override point
}
```

Key base classes: `LayerBackedView`, `XiblessView`, `XiblessViewController<View>`, `XiblessWindowController<Window>`.

### `.box` Namespace Extensions

All extensions on framework types go through the `.box` namespace (from FrameworkToolbox) to avoid naming collisions:

```swift
tableView.box.makeView(ofClass: MyCell.self)
button.box.setAction { sender in ... }
```

### `@ViewInvalidating` Property Wrapper

Auto-triggers view invalidation on property changes. Supports `.display`, `.layout`, `.constraints`, `.intrinsicContentSize`:

```swift
@ViewInvalidating(.display)
open dynamic var cornerRadius: CGFloat = 0
```

### `@resultBuilder` DSLs

- **`@ViewHierarchyBuilder`** — Declarative view hierarchy construction with `ViewItem` nodes
- **`@StackViewBuilder`** — SwiftUI-like `HStackView`/`VStackView` with `Spacer()`, `.size()`, `.gravity()` modifiers

### `Then` Protocol

Chain initialization: `.then { }` (reference types), `.with { }` (value types), `.do { }` (side effects), `.as { }` (type casting).

### Target-Action as Closures

`TargetActionProvider` + `ActionTrampoline` converts target-action to closure API on `NSControl`, `NSMenuItem`, `NSGestureRecognizer`, `NSToolbarItem`, `NSColorPanel`.

### `@MagicViewLoading`

Property wrapper that auto-calls `loadViewIfNeeded()` when a view controller's outlet is accessed.

## Code Style Notes

- Extensions on AppKit/UIKit classes follow the naming convention `NSClassName+.swift`
- One extension file per class in `UIFoundationToolbox/AppKit/`
- Button style subclasses live in `UIFoundationAppKit/Button/StyleSplittedButton/` (e.g., `PushButton`, `SwitchButton`, `HelpButton`)
- The `@retroactive` keyword is used for protocol conformances on types from other modules
