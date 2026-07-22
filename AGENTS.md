# AGENTS.md

This file provides guidance to Codex (Codex.ai/code) when working with code in this repository.

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

**Caveat**: Stack-view alignment intentionally does **not** use a `NSUI*` typealias — the two platforms' native types (`NSLayoutConstraint.Attribute` vs `UIStackView.Alignment`) have mismatched semantics (most notably, AppKit has no `.fill`). Instead, `UIFoundationShared` ships a unified `StackViewAlignment` enum which both `HStackView` / `VStackView` consume; it maps internally to each platform's native value, and emulates `.fill` on AppKit by setting `NSStackView.alignment = .notAnAttribute` and pinning each arranged subview's cross-axis edges (respecting `edgeInsets`). Defaults (`hStackDefaultValue` / `vStackDefaultValue`) are kept platform-specific to preserve historical behavior: `.center` on AppKit, `.fill` on UIKit.

### View Base Class Hierarchy

All views and controllers are created in code (no Xib/Storyboard):

```
NSView
 └── LayerBackedView      (wantsLayer=true, updateLayer path, setup(), firstLayout())
      └── XiblessView     (init?(coder:) marked @available(*, unavailable))
```

- `LayerBackedView` uses `wantsUpdateLayer = true` + `updateLayer()` for rendering (not `draw(_:)`). It conforms to `LayerBackgroundProviding` and inherits `cornerRadius` / `backgroundColor` / `border*` / `shadow*` / `shadowPath` from there.
- `setup()` — subclass override point for initialization, called from both `init(frame:)` and `init?(coder:)`.
- `firstLayout()` — called exactly once on first `layout()`, using a `lazy var _firstLayout: Void` trick. Use for size-dependent setup.
- Controllers: `XiblessViewController<View: NSUIView>` takes a generic `contentView` via `@autoclosure` factory, assigned in `loadView()`.

### `LayerBackgroundRenderer` & `LayerBackgroundProviding`

`LayerBackedView` is implemented as a thin shell over a reusable rendering helper so the same `cornerRadius` / `backgroundColor` / `border*` / `shadow*` pipeline can be dropped onto any `NSView` subclass that cannot inherit from `LayerBackedView` (typically `NSTableCellView`, `NSCollectionViewItem.view`, etc.).

Three pieces live under `Sources/UIFoundationAppKit/Base/`:

1. **`LayerBackgroundRenderer`** (`LayerBackgroundRenderer.swift`) — opaque rendering object. Holds all configuration properties + `BorderPositions` / `BorderLocation` types + the `CAShapeLayer` border sublayer. Drives the layer in `updateLayer()` / `layout()`, and triggers `owner.needsDisplay = true` on every property change. Internally weak-references its host via `attach(to:)`, which also flips `wantsLayer = true` and `layerContentsRedrawPolicy = .onSetNeedsDisplay`.
2. **`LayerBackgroundProviding`** (`LayerBackgroundProviding.swift`) — `@MainActor` protocol constrained to `NSView`. Its sole requirement is `isLayerBackingEnabled` (`Bool`), which the extension defaults to `true` — override it to opt a conformer out of the pipeline. The protocol extension provides:
   - `backgroundRenderer` as a `@AssociatedObject(.retain(.nonatomic))`-backed property (from the `AssociatedObject` macro package) — lazily initialised on first access, completely hidden from conformers.
   - All forwarding properties (`cornerRadius`, `backgroundColor`, `border*`, `shadow*`, `shadowPath`) plumbing into the renderer.
   - `attachToSelfIfNeeded()` — bind the renderer to the conforming view (call once after `super.init`); gated on `isLayerBackingEnabled`.
   - `updateLayerBackgroundIfNeeded()` / `layoutLayerBackgroundIfNeeded()` — hooks to call from the conformer's `updateLayer()` / `layout()` overrides (no-ops when `isLayerBackingEnabled` is `false`).
3. **`LayerBackedView`** — conforms to `LayerBackgroundProviding` and wires `attachToSelfIfNeeded()` / `updateLayerBackgroundIfNeeded()` / `layoutLayerBackgroundIfNeeded()` automatically. Subclasses still override `setup()` / `firstLayout()` only.

**Composition example (`NSTableCellView`):**

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

A working demo lives at `UIFoundationExample-macOS/UIFoundationExample-macOS/Demos/LayerBackgroundDemoViewController.swift` (`LayerBackgroundDemoViewController` / `LayerBackgroundCell`); it is one entry in the demo browser (see the **Example App** section).

**Caveats / trade-offs:**

- Because protocol extensions cannot use `@IBInspectable`, the forwarding properties are **not editable in Interface Builder**. `@IBDesignable` still works on `LayerBackedView` itself, but the panel won't show `cornerRadius`, `borderColor`, etc. (Project policy is code-only views, so this is intentional.)
- `NSView.shadow` is a stored property on `NSView`; protocol-extension dispatch is shadowed by the class-hierarchy lookup. If you want `view.shadow = nsShadow` to fan out to `shadowColor` / `shadowOffset` / `shadowRadius`, override `shadow` explicitly on the conformer (mirroring `LayerBackgroundRenderer.shadow`).
- Conformers that already define their own `backgroundColor` (e.g. `NSTextField`, `NSTableView`) will collide with the protocol default. Don't conform those classes — they were never the target of this pipeline.

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
- **`HStackView` / `VStackView`** — Use `@ArrayBuilder<StackViewComponent>` (from FrameworkToolbox), not a custom builder. `Spacer(spacing:)` and `MaxSpacer()` are special views recognized internally. Alignment uses the cross-platform `StackViewAlignment` enum (see typealias caveat above). Stack-specific per-view modifiers live behind the `.stackView` namespace (a plain wrapper struct, not the FrameworkToolbox `.box` machinery): `view.stackView.fill()` pins cross-axis edges (AppKit + UIKit), `.stackView.customSpacing(_:)` (cross-platform), `.stackView.gravity(_:)` / `.stackView.visibilityPriority(_:)` (macOS-only). They store values via `@AssociatedObject` (read back during stack assembly). General-purpose layout helpers (`size` / `minSize` / `maxSize` / `contentHugging` / `contentCompressionResistance`) moved to `.box` in **UIFoundationToolbox** (`NSUIView+SizeConstraints.swift`); `NSUIStackView` configuration (`distribution` / `alignment` / `spacing` / `stackPadding` / `hugging` / `clippingResistance` / `edgeInsets` / `detachesHiddenViews`) moved to `.box` in `StackView+Box.swift`. The old direct-on-view methods are retained but `@available(*, deprecated)` pointing at the new namespaces.
- **`GridView` / `GridRow` (NSGridView DSL, macOS-only)** — Declarative `NSGridView` construction: `GridView(rowSpacing:columnSpacing:xPlacement:yPlacement:rowAlignment:) { GridRow { … } }`. The convenience init lives on `NSGridView`, so the existing `GridView` subclass inherits it (and its `setup()` still fires). Three result builders: `GridContentBuilder` → `[GridRow]`, `GridRowContentBuilder` → `[GridCell]` (a bare `NSView` expression is folded into a `GridCell`), `GridColumnBuilder` → `[GridColumn]` (consumed by the chained `.columns { … }`). `GridCell` / `GridColumn` are value types with chained modifiers; `GridCell.empty` is a blank cell. Per-view cell modifiers live behind the `.gridView` namespace: `view.gridView.columns(_:)` / `.gridView.rows(_:)` for spanning, plus `.gridView.xPlacement` / `.yPlacement` / `.rowAlignment` / `.placementConstraints` — stored on the view via `@AssociatedObject` and read back during assembly. `GridCell` carries the identical modifier set (`columns` / `rows` / `xPlacement` / …). The old direct `gridCell*` methods on `NSView` are retained but `@available(*, deprecated)` pointing at `.gridView`. Row props are inline on `GridRow` (`.height` / `.topPadding` / `.bottomPadding` / `.padding` / `.yPlacement` / `.rowAlignment` / `.hidden`); column props are positional via `.columns { GridColumn().width(…) … }`. Spanning is resolved by a 2-D occupancy grid that pads with `NSGridCell.emptyContentView` and runs `mergeCells(inHorizontalRange:verticalRange:)` once after all rows are added (merge ranges are clamped to the grid's dimensions and never overlap, so the auto-expansion trap can't fire). Files: `Sources/UIFoundationAppKit/Base/Grid{Cell,Row,Column}.swift` + `GridView+Builder.swift` + `GridViewNamespace.swift` + `NSView+GridCell.swift`. **Caveats** (see the `nsgridview-layout` skill): `gridCellPlacementConstraints` is mutually exclusive with `xPlacement`/`yPlacement`; a grid- or row-level `rowAlignment` other than `.none` suppresses per-cell `yPlacement`; don't `.hidden()` a row that participates in a merge.

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

### NSAttributedStringBuilder (ported from `ethanhuang13/NSAttributedStringBuilder`)

SwiftUI-style `@resultBuilder` for composing `NSAttributedString`. Ships as part of `UIFoundationShared` behind an **opt-in SPM trait** called `NSAttributedStringBuilder` (default: disabled), mirroring the `FilterUI` / `IDEIcons` pattern:

```swift
.package(url: "…/UIFoundation", traits: ["NSAttributedStringBuilder"])   // SPM dependency
swift build --traits NSAttributedStringBuilder                          // CLI
swift test  --traits NSAttributedStringBuilder                          // CLI
```

```swift
let attributed = NSAttributedString {
    AText("Hello world")
        .font(.systemFont(ofSize: 24))
        .foregroundColor(.red)
    LineBreak()
    AText("with Swift")
        .font(.systemFont(ofSize: 20))
        .foregroundColor(.orange)
}
```

Wiring:
- `traits: [.trait(name: "AppleInternal"), .trait(name: "FilterUI"), .trait(name: "IDEIcons"), .trait(name: "NSAttributedStringBuilder")]` in `Package.swift`
- Every source file under `Sources/UIFoundationShared/NSAttributedStringBuilder/**/*.swift` is wrapped in `#if NSAttributedStringBuilder … #endif`
- Tests under `Tests/UIFoundationTests/NSAttributedStringBuilder/**/*.swift` use **Swift Testing** (`@Suite` / `@Test` / `#expect`) and are gated on the same trait

Components: `AText`, `ATextGroup` (nested-grouping with `@AttrTextGroupBuilder`), `Link`, `ImageAttachment` (non-watchOS), `Empty`, `Space`, `LineBreak`. The original `Font` / `Color` / `Image` / `Size` / `Rect` typealiases were dropped in favor of `NSUIFont` / `NSUIColor` / `NSUIImage` (from `UIFoundationTypealias`) and plain `CGSize` / `CGRect`, so the API doesn't collide with SwiftUI's `Font` / `Color` / `Image`. `Attributes` (`= [NSAttributedString.Key: Any]`) is preserved. The `Ligature.all` case and `vertical()` / `textBlocks(_:)` / `textLists(_:)` / `tighteningFactorForTruncation(_:)` / `headerLevel(_:)` modifiers are gated on `#if canImport(AppKit) && !targetEnvironment(macCatalyst)`. `ImageAttachment` is wrapped in `#if !os(watchOS)`.

### Filter UI (ported from `filter-ui`)

Filter UI ships as an **opt-in SPM trait** called `FilterUI` (default: disabled). When the trait is off the Filter sources are excluded via `#if FilterUI` and no Filter symbols are exported. To enable it:

```swift
.package(url: "…/UIFoundation", traits: ["FilterUI"])         // SPM dependency
swift build --traits FilterUI                                 // CLI
```

Wiring in `Package.swift`:
- `traits: [.trait(name: "AppleInternal"), .trait(name: "FilterUI")]`
- SPM 6.2 automatically exposes each trait name as a Swift compilation condition, so `#if FilterUI` works without any `swiftSettings` `.define` plumbing.
- Every Filter source file (`Sources/UIFoundationAppKit/Filter/**/*.swift`, `Sources/UIFoundationAppleInternal/Filter/**/*.swift`) is wrapped in `#if FilterUI … #endif`.
- xcassets / Localization stay in the resource list (SPM has no per-resource trait condition); they just get bundled even when the trait is off, which is harmless.

`xcodebuild` has no trait CLI flag — when running tests through Xcode tooling the active traits come from the consuming Xcode project / scheme. From the command line use `swift build --traits FilterUI` to compile the Filter code.

`UIFoundationAppKit/Filter/` hosts the AppKit filter controls migrated from [`filter-ui`](https://github.com/freysie/filter-ui):
- `FilterSearchField` / `FilterSearchFieldCell` — search field with progress, filter buttons, vibrancy-aware rendering
- `FilterTokenField` / `FilterTokenFieldCell` — token-based filter field with comparison types
- `FilteringMenu_WithoutPrivateAPIUsage` — public-API variant of the filterable menu (under `FilteringMenu+Public/`)
- `FuzzySearch.swift` — in-tree fuzzy string matcher (`FuzzySearchable` / `FuzzySearchResult` / `Collection.fuzzyMatch`) used by both `FilteringMenu` variants; ported and trimmed from the `fuzzy-search` package (MIT), so there is no external fuzzy-search dependency
- SwiftUI bridges: `FilterField`, `FilterToggle`, `filterFieldStyle(_:)`
- Resources (xcassets / Localization / Documentation.docc) live in `UIFoundationAppKit/Filter/Resources/`; `Package.swift` adds a `.process("Filter/Resources")` entry on top of the existing `Resources/`

The private-API variant `FilteringMenu` ships in `UIFoundationAppleInternal/Filter/` (uses `-[NSMenu highlightItem:]`, `_handleCarbonEvents:count:handler:`, and `HIMenuGetContentView` exposed via `UIFoundationAppleInternalObjC/include/NSMenu_FilteringPrivate.h` + `HIToolbox_Private.h`). Because the private menu reuses `FilterSearchField` from the public side, `UIFoundationAppleInternal` depends on `UIFoundationAppKit`.

The package now declares `defaultLocalization: "en"` because Filter ships en/da `.lproj` resources. SF Symbol / `SymbolConfiguration` call sites are wrapped in `if #available(macOS 11.0, *)` / `if #available(macOS 12.0, *)` to keep the umbrella platform at macOS 10.15+ (only a handful of declarative previews and `addFilterButton(systemSymbolName:)` are gated with `@available(macOS 12.0, *)`).

Note: SwiftUI `Button` is shadowed by `UIFoundationAppKit.Button` (an `NSButton` subclass), so SwiftUI views inside this module must use `SwiftUI.Button` / `SwiftUI.Image` explicitly (see `FilterToggle`).

**xcassets caveat:** the Filter resources rely on `Bundle.module.image(forResource:)` and `NSColor(named:bundle:)`, which require `actool`-compiled `Assets.car`. `swift build` / `swift test` from the command line do **not** invoke `actool` and copy the `.xcassets` folders verbatim, so resource lookups return `nil` in that mode. To exercise the Filter resource path (or run `FilterResourcesTests`), use the Xcode toolchain: `xcodebuild -scheme UIFoundation-Package -destination "platform=macOS" test -only-testing:UIFoundationTests/FilterResourcesTests` (temporarily move `UIFoundation.xcworkspace` aside first because that workspace only exposes the Example schemes). Consuming this package from an Xcode app target works as expected because Xcode handles `actool` itself.

### Quick Action Bar (ported from `dagronf/DSFQuickActionBar`)

Spotlight-style floating action bar for macOS. Ships as an **opt-in SPM trait** called `QuickActionBar` (default: disabled), mirroring the `FilterUI` / `IDEIcons` / `NSAttributedStringBuilder` pattern:

```swift
.package(url: "…/UIFoundation", traits: ["QuickActionBar"])     // SPM dependency
swift build --traits QuickActionBar                             // CLI
swift test  --traits QuickActionBar                             // CLI
```

```swift
let bar = QuickActionBar()
bar.contentSource = self
bar.present(placeholderText: "Search…")
```

Wiring:
- `traits: [.trait(name: "AppleInternal"), .trait(name: "FilterUI"), .trait(name: "IDEIcons"), .trait(name: "NSAttributedStringBuilder"), .trait(name: "QuickActionBar")]` in `Package.swift`
- Every source file under `Sources/UIFoundationAppKit/QuickActionBar/**/*.swift` is wrapped in `#if QuickActionBar … #endif`
- macOS-only; the file-level `#if` block additionally requires `import AppKit`, so the trait compiles to nothing on UIKit / Catalyst / tvOS / visionOS / watchOS even if accidentally enabled there

Public API surface:
- `QuickActionBar` — the controller (was `DSFQuickActionBar`)
- `QuickActionBar.resumePresentation()` — 仅在当前 panel 正处于 dismiss animation 时恢复同一个 window；返回值用于区分是否真正打断了关闭。实现必须从 presentation layer 的当前 transform 和 `NSWindow.alphaValue` 接续，且旧 animation completion 不得再关闭已恢复的 window。
- `QuickActionBarContentSource` — delegate protocol (was `DSFQuickActionBarContentSource`); `canSelectItem` / `didSelectItem` / `quickActionBarDidCancel` have default no-op implementations
- `QuickActionBar.SearchTask` — async-capable search task with `complete(with:)` / `cancel()`
- `QuickActionBar.RequiredClickCount` — `.single` / `.double`

The SwiftUI `NSViewRepresentable` bridge from upstream was intentionally **not ported** — only the AppKit controller is provided.

Differences from upstream `DSFQuickActionBar`:
- `DSF` prefix stripped from every type and filename. All internal helper types are nested under the `QuickActionBar` namespace (`QuickActionBar.TextField`, `QuickActionBar.EphemeralWindow`, `QuickActionBar.Debounce`, `QuickActionBar.SingleShotTimer`, `QuickActionBar.FlippedClipView`, `QuickActionBar.FlippedContainerView`, `QuickActionBar.PrimaryRoundedView`, `QuickActionBar.DelayedIndeterminiteRadialProgressIndicator`, `QuickActionBar.TransparentBackgroundScroller`) so they do not pollute `UIFoundationAppKit`'s module-internal scope.
- `CreateARGB32` / `scaleImageProportionally` / `usingEffectiveAppearance(ofWindow:)` are exposed as static methods on `QuickActionBar` (`QuickActionBar.createARGB32Image(width:height:drawBlock:)`, `QuickActionBar.scaleImageProportionally(_:to:)`, `QuickActionBar.usingEffectiveAppearance(of:_:)`).
- `DSFAppearanceManager` dependency removed; reads accent / dark / increase-contrast / reduce-transparency directly from `NSColor.controlAccentColor`, `effectiveAppearance.bestMatch(from:)`, and `NSWorkspace.shared.accessibilityDisplay*`. `UsingEffectiveAppearance(ofWindow:)` is replaced by an in-tree `usingEffectiveAppearance(of:_:)` that uses `NSAppearance.performAsCurrentDrawingAppearance(_:)` on macOS 11+ with an `NSAppearance.current` fallback for 10.15.
- `PrivacyInfo.xcprivacy` is not bundled (UIFoundation has no privacy manifest of its own).
- Original MIT license and per-file copyright are preserved, plus a top-level entry in `THIRD_PARTY_LICENSES.md` at the repo root.
- show/dismiss animation 支持在原 window 上反向打断；通过 animation identifier 淘汰过期 completion，避免快速重复触发时出现短暂无窗口或旧 completion 误关新状态。

### Tabs Control (ported from `onekiloparsec/KPCTabsControl`)

Numbers.app-style multi-tab control for macOS (editable / reorderable / closable tabs, with `Default`, `Chrome`, `Safari` and `System` styles). Ships as an **opt-in SPM trait** called `TabsControl` (default: disabled), mirroring the `FilterUI` / `QuickActionBar` pattern:

```swift
.package(url: "…/UIFoundation", traits: ["TabsControl"])     // SPM dependency
swift build --traits TabsControl                              // CLI
swift test  --traits TabsControl                              // CLI
```

```swift
let tabs = TabsControl()
tabs.dataSource = self          // TabsControl.DataSource
tabs.delegate = self            // TabsControl.Delegate
tabs.style = TabsControl.DefaultStyle()   // or .ChromeStyle() / .SafariStyle() / .SystemStyle()
tabs.reloadTabs()
```

`SystemStyle` replicates the macOS 26 Liquid-Glass window-tab bar and is the one style driven by
control-level decoration (`Style.controlDecoration`) rather than per-button bezel drawing: the control
floats an `NSGlassEffectView` behind every tab, draws the hairline separators, divides the bar evenly
down to a 120 pt minimum and then *stacks* the overflow into piles at the ends. Its behaviour is
matched against a real `NSTabBar` rather than eyeballed — see `Researchs/AppKit-NSTabBar-Insertion-Internals.md`
for the reverse-engineered insertion / reveal path and the measurement method.

Wiring:
- `traits: [..., .trait(name: "TabsControl")]` in `Package.swift`
- Every source file under `Sources/UIFoundationAppKit/TabsControl/**/*.swift` is wrapped in `#if TabsControl && os(macOS) … #endif`
- macOS-only; the file-level `#if` additionally requires `os(macOS)`, so the trait compiles to nothing on UIKit / Catalyst / tvOS / visionOS / watchOS
- PDF template glyphs live in `Sources/UIFoundationAppKit/TabsControl/Templates/` and are bundled via `.copy("TabsControl/Templates")` (always copied, harmless when the trait is off); loaded with `Bundle.module.url(forResource:withExtension:subdirectory:)`
- Per the unique-basename rule (see Code Style Notes), feature-scoped files are prefixed `TabsControl+…` (e.g. the ported `Helpers.swift` became `TabsControl+Geometry.swift`, `Style.swift` → `TabsControl+Style.swift`); distinctive names such as `TabButton.swift` / `TabButtonCell.swift` keep their name, and per-class extensions stay `NSClassName+TabsControl.swift`

**Namespace convention (key difference from upstream):** to avoid polluting the umbrella module's top-level namespace with generic names, the entire public API is **nested under the `TabsControl` class** — Swift ≥ 6.3 (Swift 5 language mode included) permits nesting protocols inside types, which this relies on. Only `TabsControl` and `TabButton` stay top-level. Map: `Style`/`ThemedStyle`/`Theme` → `TabsControl.Style`/`.ThemedStyle`/`.Theme`; `TabButtonTheme`/`TabsControlTheme` → `TabsControl.ButtonTheme`/`.ControlTheme`; `TabsControlDataSource`/`TabsControlDelegate` → `TabsControl.DataSource`/`.Delegate`; `TabPosition`/`ClosePosition`/`TabWidth`/`TabSelectionState` → `TabsControl.TabPosition`/`.ClosePosition`/`.TabWidth`/`.SelectionState`; `DefaultStyle`/`ChromeStyle`/`SafariStyle` (+ matching themes) → nested; `Offset`/`IconFrames`/`TitleEditorSettings`/`BorderMask`/`TitleDefaults` → nested; the old global `TabsControlSelectionDidChangeNotification` string is now `TabsControl.selectionDidChangeNotification` (`Notification.Name`). Files whose content is a protocol default-impl extension (`extension TabsControl.ThemedStyle`, `extension TabsControl.Theme`) are **not** lexically inside `TabsControl`, so sibling nested types there must be fully qualified as `TabsControl.X`; declaration files using `extension TabsControl { … }` resolve short names.

### Status Item Controller (ported from `hexedbits/StatusItemController`)

A subclassable "view controller" for `NSStatusItem`-based menu bar apps on macOS. Ships as an **opt-in SPM trait** called `StatusItemController` (default: disabled), mirroring the `FilterUI` / `QuickActionBar` / `TabsControl` pattern:

```swift
.package(url: "…/UIFoundation", traits: ["StatusItemController"])   // SPM dependency
swift build --traits StatusItemController                           // CLI
swift test  --traits StatusItemController                           // CLI
```

```swift
final class MyStatusItem: StatusItemController {
    override func buildMenu() -> NSMenu {
        NSMenu {
            NSMenuItem("Preferences…", action: #selector(openPrefs))
            NSMenuItem.separator()
            NSMenuItem("Quit", action: #selector(quit))
        }
    }
    override func leftClickAction()  { openMenu() }
    override func rightClickAction() { openMenu() }
}

// In NSApplicationDelegate:
let controller = MyStatusItem(image: NSImage(named: "StatusBarIcon")!)
```

Wiring:
- `traits: [..., .trait(name: "StatusItemController")]` in `Package.swift`
- Every source file under `Sources/UIFoundationAppKit/StatusItemController/**/*.swift` is wrapped in `#if StatusItemController && os(macOS) … #endif`
- macOS-only; the file-level `#if` additionally requires `os(macOS)`, so the trait compiles to nothing on UIKit / Catalyst / tvOS / visionOS / watchOS even if accidentally enabled there
- No new resources, ObjC headers, or external dependencies — pure AppKit

Public API surface (intentionally minimal — only one top-level symbol):
- `StatusItemController` — `@MainActor open class … : NSObject, NSMenuDelegate`. Owns `statusItem: NSStatusItem`. Construct with `init(image: NSImage, length: CGFloat = NSStatusItem.squareLength)`. Subclasses override:
  - `buildMenu() -> NSMenu` — return the menu shown on a click
  - `leftClickAction()` / `rightClickAction()` — left vs. right click dispatch (control-click counts as right)
  - The provided actions are `openMenu()`, `hideMenu()`, and `@objc public func quit()` (calls `NSApp.terminate(self)`)

Differences from upstream `hexedbits/StatusItemController`:
- The upstream public properties `NSEvent.isRightClickUp` and `NSApplication.isCurrentEventRightClickUp` are demoted to **`internal`** and renamed (`isRightClickUpForStatusItem` / `isCurrentEventRightClickUpForStatusItem`), since they are only used by `StatusItemController` itself and would otherwise pollute UIFoundation's top-level AppKit namespace and bypass the `.box` convention.
- The upstream `NSMenuItem` `convenience init(title:image:target:action:keyEquivalent:isEnabled:)` is **not** ported — `Sources/UIFoundationAppKit/Menu/NSMenuItem+Convenience.swift` already provides a richer set of convenience initializers, chained modifiers, and an `@MenuBuilder` DSL that fully supersede it.
- `popUpMenu(_:)` is still used inside `openMenu()` for the same reason the upstream cites: bypassing it causes the menu to fail to pop up on the first click.

Files: `Sources/UIFoundationAppKit/StatusItemController/StatusItemController.swift` + `StatusItemController+Helpers.swift`. Licensed under MIT; see `THIRD_PARTY_LICENSES.md` for the full attribution.

### Custom Tooltip (`UIFoundationAppleInternal/Tooltip/`)

macOS-only customizable replacement for the `NSToolTipManager` pipeline. Lives in `UIFoundationAppleInternal` (private API; not App-Store-safe). No SPM trait — this ships unconditionally with the `AppleInternal` trait.

```swift
import UIFoundation

// once, in applicationDidFinishLaunching:
CustomToolTipManager.install()

// global tweak applied to every NSView.toolTip
CustomToolTipManager.shared.globalStyle = .default

// per-view override (associated-object backed)
view.box.customTooltipStyle = .default.with { $0.cornerRadius = 10 }
```

Pieces (under `Sources/UIFoundationAppleInternal/Tooltip/`):
- `ToolTipStyle` — value type with `font`, `textColor`, `backgroundColor`, `contentMargin`, `yOffsetFromCursor`, `initialDelay`, plus the layer-backed fields (`cornerRadius`, `borderColor`, `borderWidth`, `shadowColor`, `shadowOffset`, `shadowRadius`). `.system` is the all-`nil` no-op; `.default` is the recommended preset. `with(_:)` mutates a copy.
- `CustomToolTipManager` — `@MainActor` singleton. `install()` / `uninstall()` are ref-counted; `globalStyle` is the process-wide fallback; `setStyle(_:for:)` (or `view.box.customTooltipStyle`) attaches a per-view override.
- `CustomToolTipManagerHook` — `@DynamicSubclassHook` container (from `FrameworkToolbox/ObjCRuntimeToolbox`) that isa-swizzles the `NSToolTipManager.shared` singleton and overrides `displayToolTip:` (for the per-view TLS), `toolTipAttributes` / `toolTipTextColor` / `toolTipBackgroundColor` / `toolTipContentMargin` / `toolTipYOffset` (per-field nil-fallback to `callSuper()`), and `_newToolTipWindow` / `installContentView:forToolTip:toolTipWindow:isNew:` (layer-backed contentView swap). The macro forbids `@MainActor` hook methods, so each method wraps manager calls in `MainActor.assumeIsolated { ... }` — `NSToolTipManager` only ever runs on the main thread (verified in the RE report).
- `NSView+CustomToolTip.swift` — stores `_customTooltipStyle` on `NSView` via `@AssociatedObject(.copy(.nonatomic))` and exposes it through `FrameworkToolbox<NSView>.customTooltipStyle`.

Private ObjC headers (in `UIFoundationAppleInternalObjC/include/`):
- `NSToolTipManager.h` — fully private class (no public AppKit header declares it, despite Apple's documentation page); declares `+sharedToolTipManager` (bridged as `.shared` via `NS_SWIFT_NAME(shared)`), `initialToolTipDelay`, plus every hook target.
- `NSToolTip.h` — private model class; we only need `view` / `cell` / `string` / `trackingNum` so the hook can route to per-view styles.
- `NSColor_Private.h` — adds `+toolTipColor` to the public `NSColor`.

Layer-backing reconciliation: the hook overrides `installContentView:forToolTip:toolTipWindow:isNew:` (called once per tooltip display, before `addDrawingSubviewForToolTip:`). On each call it inspects the resolved style and swaps `panel.contentView` between the system `NSVisualEffectView` (`material = .toolTip`) and a `LayerBackedView`, depending on whether any of `backgroundColor` / `cornerRadius` / `borderColor` / `borderWidth` / `shadowColor` / `shadowOffset` / `shadowRadius` is set. The previously cached `_normalToolTipDrawView` / `_expansionToolTipDrawView` are reset to `nil` via KVC so the system rebuilds them inside the new content view; the panel's pre-customization `backgroundColor` / `isOpaque` / `hasShadow` are saved in an associated object and restored when the resolved style stops needing layer backing. Per-view overrides work in isolation — a single styled view can co-exist with other views that still get the unmodified system tooltip.

Reference: full reverse-engineering report at [`Researchs/AppKit-NSToolTipManager-Internals.md`](Researchs/AppKit-NSToolTipManager-Internals.md).

## Example App (macOS)

`UIFoundationExample-macOS/` is a single-window **demo browser**: a sidebar (source list, grouped by category) on the left, the selected demo's view controller on the right. All code, no storyboard-driven UI (the storyboard is kept **only** for the main menu — it has no initial controller and never auto-opens a window).

Structure under `UIFoundationExample-macOS/UIFoundationExample-macOS/`:
- `AppDelegate.swift` — builds a `DemoBrowserWindowController` on launch; nothing else.
- `Browser/` — `DemoBrowserWindowController` (code-built `NSWindow`), `DemoBrowserSplitViewController` (sidebar + `DemoDetailViewController`), `DemoSidebarViewController` (source-list `NSOutlineView`; items are a private `SidebarNode` reference type because `NSOutlineView` needs stable item identity).
- `Catalog/` — `Demo` (a value type: `title` / `category` / `summary` / `minimumMacOS` / `makeViewController`) and `DemoCatalog.all` (the registry) + `DemoCatalog.grouped`.
- `Demos/` — one self-contained `NSViewController` per demo (`TabsControlDemoViewController`, `LayerBackgroundDemoViewController`, `InsetsLabelDemoViewController`, `TextFinderDemoViewController`, `CustomTooltipDemoViewController`).

**To add a demo:** drop a new `NSViewController` file under `Demos/` and append one `Demo` to `DemoCatalog.all`. Nothing else changes.

Two project facts that make this work (and matter when extending it):
- The Xcode project's app source group is a **file-system-synchronized group** (`PBXFileSystemSynchronizedRootGroup`, Xcode 16+). Any file added under the app folder is auto-included in the target — **no `project.pbxproj` edits needed** to add/move/delete demos.
- The example links the local package via an `XCLocalSwiftPackageReference` whose `traits` list selects opt-in features. **To demo a trait-gated control, add its trait there** (e.g. `TabsControl` is enabled alongside `AppleInternal` / `FilterUI` / `IDEIcons` / `NSAttributedStringBuilder`); otherwise the control's symbols won't be compiled into the package and the demo won't link.

Build the example from the command line with `xcodebuild -project UIFoundationExample-macOS/UIFoundationExample-macOS.xcodeproj -scheme UIFoundationExample-macOS -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO build 2>&1 | xcsift`.

## Code Style Notes

- **Unique basenames per target**: within a single SPM target, every source file must have a unique file*name* — SwiftPM keys compiled object files by basename, so two same-named files in one target (even in different subdirectories) fail the build with `couldn't build …o because of multiple producers`. Prefix feature-scoped files with the feature name (`QuickActionBar+Helpers.swift`, `TabsControl+Style.swift`) instead of relying on subdirectory paths to disambiguate. The `QuickActionBar/` and `TabsControl/` feature dirs follow `Feature.swift` (entry) + `Feature+Descriptor.swift` for everything else, keeping only distinctive type-named files (e.g. `TabButton.swift`) unprefixed.
- **Private ObjC header naming** (`Sources/UIFoundationAppleInternalObjC/include/`): the convention has two shapes, picked by whether AppKit ships a public header for the class.
  - `<Class>_Private.h` — for **public** AppKit/CoreAnimation classes where we re-open with `@interface ClassName ()` to add private methods. Examples: `NSView_Private.h`, `NSScrollView_Private.h`, `CALayer_Private.h`, `NSColor_Private.h`.
  - `<Class>.h` — for **fully private** classes that have no public AppKit header (their symbols only appear in the framework's `.tbd`). We declare the entire `@interface ClassName : NSObject` ourselves. Examples: `NSScene.h`, `CABackdropLayer.h`, `NSToolTip.h`, **`NSToolTipManager.h`** (despite the public Apple docs page, `NSToolTipManager` has no entry in any SDK header — verify with `grep "interface NSToolTipManager" $(xcrun --sdk macosx --show-sdk-path)/System/Library/Frameworks/AppKit.framework/Headers/*.h` before assuming a class is public).
- Extensions on AppKit/UIKit classes follow the naming convention `NSClassName+.swift`
- One extension file per class in `UIFoundationToolbox/AppKit/`
- Button style subclasses live in `UIFoundationAppKit/Button/StyleSplittedButton/` (e.g., `PushButton`, `SwitchButton`, `HelpButton`)
- The `@retroactive` keyword is used for protocol conformances on types from other modules (e.g., `NSControl.StateValue: @retroactive ExpressibleByBooleanLiteral`)
- No linter or formatter is configured — style is enforced by convention only

## Documentation

- **Reverse engineering research reports** — All reverse engineering / framework internals research documents (AppKit/UIKit/CoreAnimation binary analysis, private API investigations, etc.) must be placed under the `Researchs/` directory at the repo root. Do **not** mix them into `docs/` or scatter them across module folders.
