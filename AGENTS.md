# AGENTS.md

This file provides guidance to coding agents when working with code in this repository.

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

### Semantic Context (`AppleInternal` trait)

`NSView_Private.h` declares `NSViewSemanticContext` — the private hint that tells AppKit controls
what surface they sit on. Its most useful value is `NSViewSemanticContextForm`, which produces the
System Settings grouped-form look: a pop-up button drops its bezel and shrinks to a label plus a
chevron. There is no public equivalent; SwiftUI's `Form` reaches for this same property.

```objc
view._semanticContext = NSViewSemanticContextForm;   // whole subtree follows
```

Three things to know before using it:

- **Inheritance is built in.** `_semanticContext` is a view's own value (`0` = unset);
  `_effectiveSemanticContext` is what is actually in force after walking up superviews, then the
  window. Set it once on the container holding a group of controls, not on each control.
- **It is read at draw time.** Changing it on a live hierarchy needs a redraw. Setting it during
  view setup needs nothing extra.
- **Only `Form` is a stable name and number.** It comes from WebKit's SPI header, is macOS 13+, and
  WebKit still hardcodes it. Every other member name in our enum is ours, recovered from the binary;
  the numbering has demonstrably shifted across OS releases, so re-verify before relying on one.

Full write-up — the whole enum, the AppKit call site that pins each value, the inheritance
algorithm, the `NSCell` fallback used when drawing without a view, and how WebKit consumes it:
[`Researchs/AppKit-NSView-SemanticContext.md`](Researchs/AppKit-NSView-SemanticContext.md).

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

### Toolbar DSL — `NSToolbar.Navigation`

`Sources/UIFoundationAppKit/Toolbar/` holds a builder-style `NSToolbar` API: an `ToolbarItem` base
class plus chained modifiers, with subclasses `NSToolbar.Button` / `.Item` / `.Group` / `.Menu` /
`.PopUpButton` / `.Search` / `.SegmentedControl` / `.View` / `.TrackingSeparator` / **`.Navigation`**.
No trait — it ships unconditionally on macOS.

`NSToolbar.Navigation` is a Safari-style back / forward pair in one item, because AppKit has none.
Decision record is Evolution
[`0004`](Documentations/Evolutions/0004-appkit-navigation-toolbar-item.md).

**Data is pulled, never pushed.** There is no `reloadHistory()` and its absence is the design:
`NSToolbarItem` already validates on the toolbar's validation cycle, so `validate()` re-asks the
data source whether each direction is live and how deep its history is. A host that changes its own
history has nothing to remember to call. Row *contents* are pulled later, in `menuNeedsUpdate(_:)`,
only while a menu is opening — per-row icon resolution must not land on the event loop, while
whether a menu exists at all has to be settled *before* the press.

Two AppKit behaviours are held structurally rather than by comment:

- **A segment menu opens on an ordinary click when the control's `action` is `nil`**, instead of on
  a long press — single-step navigation silently disappears. The `NSSegmentedControl` is
  **internal**, so `target` / `action` are wired once in `init` and there is no typed door to reach
  them through afterwards. (It is internal rather than `private` because the tests need it;
  `private` would buy nothing anyway, since AppKit needs the view on the item and `item.view` leads
  there for anyone who casts it — a hole no design can close.) To cause a click, call
  `performNavigation(in:)` — which is also where a host's ⌘[ / ⌘] main-menu items should land, since
  `NSToolbarItem` has no key equivalents.
- **An empty `NSMenu` still pops, as a blank box.** An empty direction gets
  `setMenu(nil, forSegment:)`, never a menu with no rows.

**The appearance is the library's, not the host's.** No styling API and no forwarding properties:
two segments, `.momentary`, `.separated`, direction-aware chevrons, no menu indicator,
`isNavigational` on macOS 11+. Don't add a `segmentStyle` / `controlSize` passthrough "for
flexibility" — the control they'd forward to is the same one carrying the action, and a navigation
pair has one correct look. The only host-facing text is `backwardTitle` / `forwardTitle`, which
exist for localization (they become the tooltips and the chevrons' accessibility descriptions).

Two measurements worth not re-deriving:

- **Attaching a menu does not raise a pull-down indicator.** Measured on macOS 26:
  `showsMenuIndicator(forSegment:)` is `false` on a fresh control and stays `false` across
  `setMenu(_:forSegment:)`. The often-repeated third "gotcha" does not reproduce. The item sets it
  off once as a statement of intent, and the test suite keeps a canary in case a future release
  changes it.
- **`selectedSegment` cannot be faked on a `.momentary` control** — assigning it reads back `-1`,
  AppKit's "nothing is being tracked". A click is therefore untestable headlessly, which is why the
  dispatch is split out into `performNavigation(in:)`.

Host contracts (all three fail silently rather than loudly): history index `0` is the **nearest**
entry in that direction, not the oldest; `canNavigateIn` / `numberOfHistoryEntriesIn` run on the
event loop and must be cheap; refresh waits for the window to become key (call `validate()`
directly if an exact moment is needed).

**Full guide:** `Documentations/ToolbarNavigation.md`. Demo: **Toolbar Navigation** in the example
app — it opens its own window, since the demo browser's detail pane has no toolbar, and lists the
four checks that only a human can perform (long press being the main one).

### Self-Sizing Row Views

Three classes under `Base/` let a table or a tree size itself to its rows instead of scrolling inside a fixed frame — drop one into a stack view and it reports the height it needs:

- **`SelfSizingScrollView`** (`ScrollView.swift`) — mirrors its document view's intrinsic size, clamped by `minimumContentSize` / `maximumContentSize`. Past the cap the built-in scrollers take over. Useless on its own: the document view has to report an intrinsic size, which is what the other two do.
- **`SelfSizingTableView`** (`TableView.swift`) — a `SingleColumnTableView` whose intrinsic height is the sum of its rows.
- **`SelfSizingOutlineView`** (`OutlineView.swift`) — the same for a tree, so it grows and shrinks with every disclosure.

Both row views measure through the same internal `NSTableView.selfSizingRowsContentSize`: an outline view *is* a table view, but the two inherit from different UIFoundation bases, so a shared extension is the only way for them to agree. It reads `rect(ofRow:)` rather than multiplying `rowHeight`, because the first row's `minY` already carries the top inset a `.inset` / `.sourceList` style reserves and the last row's `maxY` already folds in the intercell spacing; the bottom inset is symmetric, so mirroring the top one completes the height. Both also override `invalidateIntrinsicContentSize()` to invalidate the enclosing scroll view — nothing else tells it to ask again.

**A disclosure does not animate, by default and on purpose.** A self-sizing outline view has two things to move at once and AppKit drives only one of them: `expandItem(_:expandChildren:)` slides the new rows in over `NSAnimationContext`'s default 0.25s duration, while the height the view reports travels through Auto Layout on its own schedule. The two timelines never line up, and it reads as a jitter. `SelfSizingOutlineView` wraps the whole disclosure in a zero-duration grouping, which also covers whatever a delegate does from `outlineViewItemDidExpand` — that notification is posted from *inside* the call. `animatesExpansionAndCollapse = true` hands the animation back, which only makes sense when the host's height does not follow the row count.

Two findings behind that implementation, both measured rather than assumed:

- **Overriding `expandItem(_:expandChildren:)` catches every path.** The programmatic `expandItem(_:)` forwards to it, and so does the user clicking the disclosure triangle — that triangle is a real `NSButton` targeting the outline view, and its `_outlineControlClicked:` action routes through the overridable method (verified by clicking it and watching the override run).
- **`insertRows(at:withAnimation:)` is not an option.** `NSOutlineView` marks it unavailable (`cannot override 'insertRows' which has been marked unavailable`), so the animation options cannot be changed at the row-insertion level.

> **Testing note.** The animation itself is not observable in a test process — with no display, rows land at their final position either way and the row views are not even layer-backed. `SelfSizingRowViewsTests` therefore asserts on the *animation context* the disclosure runs in (`NSAnimationContext.current.duration`, read from the delegate callback), and pairs it with a plain `OutlineView` control that reads 0.25. Without that control the assertion would pass against an implementation that does nothing.

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

### Tab Bar (ported from `onekiloparsec/KPCTabsControl`)

Multi-tab control for macOS (editable / reorderable / closable tabs), styled after the macOS 26 window tab bar. Ships as an **opt-in SPM trait** called `TabBar` (default: disabled), mirroring the `FilterUI` / `QuickActionBar` pattern:

```swift
.package(url: "…/UIFoundation", traits: ["TabBar"])     // SPM dependency
swift build --traits TabBar                              // CLI
swift test  --traits TabBar                              // CLI
```

```swift
let tabs = TabBar()
tabs.dataSource = self          // TabBar.DataSource
tabs.delegate = self            // TabBar.Delegate
tabs.reloadTabs()
```

`SystemStyle` is the only style shipped, and the default — `TabBar()` already wears it. It
replicates the macOS 26 Liquid-Glass window-tab bar, and is driven by control-level decoration
(`Style.controlDecoration`) rather than per-button bezel drawing: the control floats an
`NSGlassEffectView` behind every tab, draws the hairline separators, divides the bar evenly down to a
120 pt minimum and then *stacks* the overflow into piles at the ends. The upstream Numbers, Chrome and
Safari styles were removed — macOS 26 gave Safari the system tab bar, and Chrome's never had a dark
appearance — but the `ThemedStyle` / `Theme` machinery they used is still there for a custom style. Its behaviour is
matched against a real `NSTabBar` rather than eyeballed — see `Researchs/AppKit-NSTabBar-Insertion-Internals.md`
for the reverse-engineered insertion / reveal path and the measurement method.

**Who owns the selection.** By default the control does: closing a tab moves the selection to the tab
on its left. A host that keeps the active tab in its own model instead — so that commands like ⌘W act
on the model rather than on whatever the bar highlights — takes over by calling `selectItemAtIndex(_:)`
from inside `tabBar(_:didCloseItem:)`, and the control then stands down instead of overruling it.
Without that hand-off the two disagree after every close, silently: the bar lights up one tab while the
host's shortcut closes another, and on a *stacked* bar the disagreement is loud, because the selection
anchors the fold and re-selecting into a pile blows that sliver up to full width. The demo
(`TabBarDemoViewController`) is wired the host-owned way and logs any disagreement.

**No pull-down affordance.** `tabBar(_:menuForItem:)` supplies a *right-click* menu and nothing more —
it lands on the tab's `NSView.menu` and AppKit presents it. The tab draws no chevron, reserves no room
for one, and does not open the menu on a left click. Upstream KPCTabsControl did all three, because
Numbers' sheet tabs have a real pull-down button; the system bar has no such element, so the whole path
(`PullDownTemplate.pdf`, `TabButtonCell.popupImage()`, `drawPopupButtonWithFrame`, the `trackMouse`
override that hit-tested the chevron, `Style.popupRectWithFrame`, the `showingMenu:` parameter on
`Style.titleRect` / `Style.iconFrames`, and `NSImage.imageWithTint`) was removed. Don't reintroduce a
`showingMenu` argument to make a custom style "leave space for the menu" — there is nothing to leave
space for.

**Full guide:** `Documentations/TabBar.md` — API, the three host-facing contracts (item identity,
selection ownership, what a reload animates), the measured `SystemStyle` geometry, the stacking and
scrolling models, and the known divergences from the system bar.

Wiring:
- `traits: [..., .trait(name: "TabBar")]` in `Package.swift`
- Every source file under `Sources/UIFoundationAppKit/TabBar/**/*.swift` is wrapped in `#if TabBar && os(macOS) … #endif`
- macOS-only; the file-level `#if` additionally requires `os(macOS)`, so the trait compiles to nothing on UIKit / Catalyst / tvOS / visionOS / watchOS
- No bundled resources, ObjC headers, or external dependencies — pure AppKit. The upstream `Templates/*.pdf` glyphs are all gone; the last survivor (`PullDownTemplate.pdf`) is covered under **No pull-down affordance** below
- Per the unique-basename rule (see Code Style Notes), feature-scoped files are prefixed `TabBar+…` (e.g. the ported `Helpers.swift` became `TabBar+Geometry.swift`, `Style.swift` → `TabBar+Style.swift`); distinctive names such as `TabButton.swift` / `TabButtonCell.swift` keep their name, and per-class extensions stay `NSClassName+TabBar.swift`

**Namespace convention (key difference from upstream):** to avoid polluting the umbrella module's top-level namespace with generic names, the entire public API is **nested under the `TabBar` class** — Swift ≥ 6.3 (Swift 5 language mode included) permits nesting protocols inside types, which this relies on. Only `TabBar` and `TabButton` stay top-level. Map: `Style`/`ThemedStyle`/`Theme` → `TabBar.Style`/`.ThemedStyle`/`.Theme`; `TabButtonTheme`/`TabBarTheme` → `TabBar.ButtonTheme`/`.ControlTheme`; `TabBarDataSource`/`TabBarDelegate` → `TabBar.DataSource`/`.Delegate`; `TabPosition`/`ClosePosition`/`TabWidth`/`TabSelectionState` → `TabBar.TabPosition`/`.ClosePosition`/`.TabWidth`/`.SelectionState`; `SystemStyle` (+ its theme) → nested; `Offset`/`IconFrames`/`TitleEditorSettings`/`BorderMask`/`TitleDefaults` → nested; the old global `TabBarSelectionDidChangeNotification` string is now `TabBar.selectionDidChangeNotification` (`Notification.Name`). Files whose content is a protocol default-impl extension (`extension TabBar.ThemedStyle`, `extension TabBar.Theme`) are **not** lexically inside `TabBar`, so sibling nested types there must be fully qualified as `TabBar.X`; declaration files using `extension TabBar { … }` resolve short names.

### Status Item Controller (ported from `hexedbits/StatusItemController`)

A subclassable "view controller" for `NSStatusItem`-based menu bar apps on macOS. Ships as an **opt-in SPM trait** called `StatusItemController` (default: disabled), mirroring the `FilterUI` / `QuickActionBar` / `TabBar` pattern:

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

### System HUD (ported from `Mx-Iris/SystemHUD`)

The volume-HUD-shaped floating panel for macOS: a vibrancy backdrop hosting an optional glyph above a single line of text, shown below the centre of the active screen and faded out after a delay. Ships as an **opt-in SPM trait** called `SystemHUD` (default: disabled), mirroring the `TabBar` / `QuickActionBar` / `StatusItemController` pattern:

```swift
.package(url: "…/UIFoundation", traits: ["SystemHUD"])   // SPM dependency
swift build --traits SystemHUD                           // CLI
```

```swift
SystemHUD.default.configuration.image = NSImage(named: "Build")
SystemHUD.default.configuration.title = "Build Succeeded"
SystemHUD.default.show(delay: 1.0)
```

Wiring:
- `traits: [..., .trait(name: "SystemHUD")]` in `Package.swift`
- Every source file under `Sources/UIFoundationAppKit/SystemHUD/**/*.swift` is wrapped in `#if SystemHUD && os(macOS) … #endif`
- No resources, ObjC headers, or external dependencies — pure AppKit

Public API surface (one top-level symbol): `SystemHUD` (`@MainActor public final class`) with `default`, `init(configuration:)`, `configuration`, and `show(delay:)`. `SystemHUD.Configuration` carries `image` / `imageSpacing` / `title` / `titleFontSize` / `titleFontWeight` / `titleColor` / `titleAlignment` / `offset` / `minimumSize` / `contentInsets` / `cornerRadius` / `dismissAnimationDuration`. The internal `ContentView` (an `NSVisualEffectView` subclass), `Window`, and `AlphaAnimation` are nested under `SystemHUD`.

**Sizing contract.** The panel measures its content and clamps: never below `minimumSize` (default 200 × 200), never wider than the visible screen width less a 20 pt margin per side — an over-long title truncates at the tail instead of running the panel off the display. Both size and origin are recomputed on **every** `show(delay:)` and on every `configuration` assignment, against `NSScreen.main`, so a long-lived HUD follows the user between displays. `offset` moves the content inside the panel (positive `y` = up), not the panel itself.

**Fade contract.** `show(delay:)` schedules a one-shot `Timer` in `.common` run loop mode (so a HUD raised during menu tracking still dismisses). The fade itself is the upstream implementation, kept deliberately: `SystemHUD.AlphaAnimation`, an `NSAnimation` subclass that maps `currentProgress` onto `window.alphaValue`, started `.nonblocking` on an ease-in curve. A `show` during a fade calls `stop()` on the in-flight animation and resets `alphaValue` to 1. The panel is left ordered in at zero opacity rather than ordered out (it ignores mouse events, so it costs nothing). There is no public `dismiss()`. **Do not replace this with `NSAnimationContext`** — the timing was matched to the original and a swap changes the feel.

Differences from the original `Mx-Iris/SystemHUD` package: internal types nested under `SystemHUD` (`ContentView` / `Window` / `AlphaAnimation`); `dismissAnimateDuration` renamed to `dismissAnimationDuration`; `minimumSize` / `contentInsets` / `cornerRadius` added (the corner radius was hard-coded to 15); the fixed 200 × 200 window and init-time-only positioning replaced by the sizing contract above; corners rounded with `NSVisualEffectView.maskImage` instead of `layer.cornerRadius` (the mask also clips the backdrop material); `ignoresMouseEvents = true` and `collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]` added; the dismiss timer moved to `.common` run loop mode; the content layout guide is now sized explicitly (the original had no width constraint and a reversed pair of `lessThanOrEqualTo` title constraints).

**Full guide:** `Documentations/SystemHUD.md`.

### Navigation (ported from the macOS App Store)

A `UINavigationController`-shaped container for AppKit — a view controller stack, a push / pop parallax transition, and a two-finger swipe back. Ships as the opt-in SPM trait `Navigation` (default: disabled); every file under `Sources/UIFoundationAppKit/Navigation/**` is wrapped in `#if Navigation && os(macOS)`. Pure AppKit, no private API, no resources.

Ported from **the macOS App Store's own implementation, not from UIKit** — deliberately. UIKit's `_UINavigationParallaxTransition` only yields an animator on AppKit (`NSViewControllerPresentationAnimator` has two methods and no transition context), which can carry neither a stack nor an interactive gesture. The App Store's version is a real container, is AppKit-native throughout, and gets its back swipe from the public `NSEvent.trackSwipeEvent`. Full reverse-engineering report with every address: [`Researchs/AppStore-Custom-Navigation-Internals.md`](Researchs/AppStore-Custom-Navigation-Internals.md); the decision record is Evolution [`0001`](Documentations/Evolutions/0001-appstore-style-navigation-controller.md).

Four layers, deliberately decoupled — the bottom two know nothing about navigation, and the transition layer knows nothing about the stack:

```
NavigationController                  stack, delegates, swipe
  └── any ViewTransition              PushViewTransition / PopViewTransition
        ├── ViewPropertyInterpolator  [any Transformation] + TimingCurve
        │     └── Interpolator<Value: Interpolatable>
        └── ViewPropertyAnimator      NSAnimationContext wrapper
```

**The animation mechanism is load-bearing.** Transitions never build a `CABasicAnimation`. They assign *final* values to `frame` / `alphaValue` inside an `NSAnimationContext` group with `allowsImplicitAnimation = true`, which is why `prepare()` forces `wantsLayer` on every participating view. Keep it that way: `apply(fraction)` is only steppable frame-by-frame from a gesture *because* it is plain assignment. Building explicit animations would silently cost the interactive pop.

**Ease exactly once.** Each `Interpolator` carries its own curve and applies it; `ViewPropertyInterpolator.apply(_:)` passes the fraction through un-eased. Easing again at the bundle level makes a released gesture jump.

Two presets, both measured rather than estimated, exposed through `NavigationConfiguration`. **`.uiKit` is the default**: 0.35 s ease-in-ease-out, outgoing page counter-sliding `floor(width × 0.3)`, sRGB black at 10 %, and a **9 pt edge shadow** trailing the incoming page. `.appStore` is the App Store's own: 0.35 s on `cubic-bezier(0.1878, 0.0023, 0.5399, 0.9629)` **for both directions** (AppStoreKit ships a reversed curve and never calls it), `floor(width × 0.2527)`, black at 22 %, and **no edge shadow**.

**Do not flip the default back to `.appStore`.** It was the default for one review round and was rejected on sight: with no shadow to give the arriving page an edge, five points less parallax, and a curve that is ~63 % through the motion at half the time and then crawls, the App Store look reads as content sliding sideways rather than one page moving over another. Fidelity stayed available as a preset; the default is the one that looks like a navigation push. The shadow itself (`NavigationEdgeShadowView`) is a port of UIKit's `_UIVerticalEdgeShadowView` by way of AppKitPlus — its falloff is a **blur spill**, an opaque block filled entirely outside the clip so only its shadow survives, not a linear gradient, which reads noticeably harder.

Divergences from the App Store worth remembering: pages are framed from the container's `bounds` inset by `contentInsets`, not from its `frame` (theirs only works because a root view sits at the origin); only the difference between old and new stacks is re-parented, not the whole stack; a stack change requested mid-transition is deferred rather than applied on top; `Interpolator.value(forInput:)` has one `CGFloat` overload instead of three (three make every literal call site ambiguous). The three `InteractiveViewTransition` members are designed here, not copied — only their slot count was recoverable.

**A see-through page needs a stand-in background, and that is `pageBackdrop`.** The transition assumes the arriving page hides the one it covers; macOS 26 breaks that assumption, because a page must be `.clear` for the window's glass to show through, and two clear pages sliding past each other show both sets of content at once. `.automatic` (the default) gives a `windowBackgroundColor` background to the page running the **full-width slide** — the arriving page on a push, the **leaving** page on a pop — when that page reports `isOpaque == false` with no opaque layer background. The other page only takes the parallax offset and keeps no background, so the container shows through it. **The two directions get there differently and must stay that way:** a push slides a stand-in view in underneath the arriving page, which works because that page starts off screen; a pop writes the colour onto the leaving page's own layer and restores it in `cleanUp`, followed by `needsDisplay = true`, because that page already fills the container and a view slipped beneath it flashes the whole container at the moment Back is pressed. The restore-plus-redraw is what stops a `LayerBackedView` page keeping the transition's colour, since it repaints its background in `updateLayer()`. **Do not "simplify" this to writing `layer.backgroundColor` on the page and restoring it** — this package's own `LayerBackedView` rewrites that property in `updateLayer()`, so a mid-transition redraw clobbers the value and the restore writes back a stale one. A sibling view has no state to restore.

Host contracts (all four are in the guide, and each fails confusingly rather than loudly): the container owns page frames so pages must not be constrained from outside; pages are forced layer-backed; interactive pop consumes horizontal scroll events, so a page with a horizontal `NSScrollView` swallows the swipe; `viewControllers` keeps reporting the old stack until a running transition ends.

**Full guide:** `Documentations/Navigation.md`.

### Settings Window

A System Settings-shaped window plus a settings model that persists itself. Extracted from
RuntimeViewer's `RuntimeViewerSettings` / `RuntimeViewerSettingsUI` — decision record is Evolution
[`0002`](Documentations/Evolutions/0002-reusable-settings-window.md). Ships behind the opt-in SPM
trait `Settings` (default: disabled) as **two** targets, both macOS 14+, both wrapped in
`#if Settings && os(macOS)`:

- **`UIFoundationSettings`** (model layer, no AppKit) — `SettingsStorage` / `FileSystemSettingsStorage`,
  `SettingsModel`, `SettingsStore`, `PersistentSettings`, `AppSettings`.
- **`UIFoundationSettingsUI`** (UI layer) — `SettingsWindowController` / `SettingsWindow`,
  `SettingsScene`, `SettingsRootView`, `SettingsPage` + `@SettingsPageBuilder`, `SettingsForm`,
  `SettingsPageIcon`, `SettingsNavigator`. Ships `Resources/Localizable.xcstrings`: the module has
  user-facing text of its own (the back / forward buttons), and `#bundle` only resolves for a target
  that has a bundle. A literal without `bundle: #bundle` in here searches the *app's* catalog and
  silently renders the key.

Split in two because reading settings and *showing* the settings window are different jobs: services
and view models do the former everywhere, the latter happens in one place. Neither target joins the
`UIFoundation` umbrella — that would push the macOS 14 floor onto every consumer. No new external
dependencies: no dependency-injection framework, no introspection package, no macro package.

**All host customization goes through the top-level `SettingsConfiguration`** (Evolution
[`0008`](Documentations/Evolutions/0008-top-level-settings-configuration.md)): window title and size,
sidebar width and icon size, and navigation-control visibility. Pass the same value to
`SettingsScene` or an embedded `SettingsRootView`. Keep `SettingsNavigator` separate — it is live
selection/history state, not appearance — and keep the page builder separate because pages are
content. RuntimeViewer uses `sidebarIconSize: 15` to preserve its pre-migration glyph size; the
library default remains 20.

**There are two complete presentation choices** (Evolution
[`0007`](Documentations/Evolutions/0007-settings-scene.md)). `SettingsWindowController` gives AppKit
direct ownership of a window on macOS 14+. `SettingsScene` is a native SwiftUI `Settings` scene with
the same initializer shape, public configuration, and public navigator. SwiftUI apps place it in
`App.body`; macOS 26+ AppKit apps wrap it in `NSHostingSceneRepresentation`, register that with
`NSApplication.addSceneRepresentation(_:)` during `applicationWillFinishLaunching(_:)`, and open it
through `representation.environment.openSettings()`. Do not hide registration inside the scene or a
process-wide convenience: its timing belongs to the app lifecycle. SwiftUI owns a native Settings
scene's title, so `SettingsConfiguration.title` remains specific to `SettingsWindowController`.
`SettingsScene` requests `.windowToolbarStyle(.unified)` and also reconciles the backing
`NSWindow.toolbarStyle` after attachment. The second step is load-bearing: native `SwiftUI.Settings`
replaces the scene modifier with AppKit's `.preference` style on macOS 26, putting the page title above
the navigation control instead of keeping both inline like `SettingsWindowController`. Keep that
AppKit reconciliation scoped to `SettingsScene`; an embedded `SettingsRootView` must not restyle its
host window.
The runnable macOS 26 example is `SettingsSceneRepresentationExample` plus
`SettingsSceneRepresentationDemoViewController`; `AppDelegate` owns the former and performs the
launch-time registration.

The host supplies a `Codable` `@Observable` **reference model** and a page list; saving, debouncing,
loading and property-level change notification come with the box:

```swift
@Observable
final class Settings: PersistentSettings {
    var general = General()

    @MainActor func accessPersistedValues() {
        _ = general
    }

    @MainActor static let store = SettingsStore(
        defaultValue: Settings(),
        storage: FileSystemSettingsStorage(applicationDirectoryName: "MyApp")
    )
}
typealias Setting<Value> = AppSettings<Settings, Value>   // then: @Setting(\.general)
```

**The store is reached through the type, not through the environment.** `AppSettings` reads
`Root.store`, so the same door works outside SwiftUI (`Settings.current.general.x`) — which an
`@Environment`-injected store cannot do, and which matters because most settings reads in a real app
happen in services, not views. One store per model type is the deliberate consequence.

Five things measured rather than assumed (the Settings model change is Evolution
[`0005`](Documentations/Evolutions/0005-observable-settings-model.md)):

- **Redraws come from Observation, not from the property wrapper.** SwiftUI evaluates `body` inside
  a tracking scope, so reading `Root.store.value` there registers the dependency. `AppSettings`
  therefore **does not conform to `DynamicProperty`** — a conforming wrapper, a non-conforming one,
  and a view reading the store directly all redraw identically. Don't add the conformance back; it
  would read as load-bearing when it is not.
- **Invalidation follows the model property.** Reading `general` is not invalidated by an in-place
  change to `appearance`; replacing the whole Store value still updates every reader. Value-type
  sections give section-level granularity, which is enough to keep RuntimeViewer's Transformer,
  Theme and MCP listeners independent.
- **Persistence observation is explicit.** Observation has no wildcard listener, so
  `accessPersistedValues()` must read every encoded top-level property. Omitting one means a change
  to that property alone cannot schedule auto-save. Keep the method beside the coding keys.
- **Encoding is not an observation shortcut.** A probe wrapping `JSONEncoder.encode(settings)` in
  `withObservationTracking` did not receive property changes; compiler-synthesized Codable also
  sees `@Observable` backing storage. Hosts must provide explicit coding or use a coding macro that
  understands Observation.
- **Disabling sidebar collapsing needs no swizzling.** `canCollapse = false` sticks (verified on
  macOS 26 across a run-loop pass, a SwiftUI update and a resize). SwiftUI's split view controller is
  reachable **only as the `NSSplitView`'s delegate** — it is not a child of the hosting controller,
  so walking `children` finds nothing. Upstream RuntimeViewer swizzled
  `NSSplitViewItem.canCollapse`'s getter process-wide; that was never necessary and is not ported.
  `SettingsWindowChromeTests` guards this.

**Page navigation** (Evolution [`0003`](Documentations/Evolutions/0003-settings-navigation-history.md))
is a `SettingsNavigator`: the single source of truth for the selected page *and* the history behind
the ⌘[ / ⌘] chevrons in the detail pane's leading toolbar slot. It is the host's handle for driving
the window from code (`controller.navigator.navigate(to: "updates")`), which is why it exists at
all — the selection used to be a `private @State`.

`currentPageID` is read-only to hosts. Programmatic page changes go through `navigate(to:)`, which
records the visit and truncates forward history when necessary; do not make the public setter
writable again.

- **The sidebar's selection is derived from the navigator, not stored beside it.** Don't reintroduce
  the usual "selection plus an `isNavigatingThroughHistory` flag": that flag's reset depends on when
  SwiftUI writes the selection back, and there is no guarantee — reset early and a visit goes
  unrecorded, late and the user's next click is taken for a programmatic one.
- **The chevrons are one `ToolbarItem` holding a `ControlGroup` with `.controlGroupStyle(.navigation)`**
  — the exact spelling Xcode's settings window uses. Don't "simplify" it: dropping `.navigation`
  resolves to a native toolbar item with no segmented control at all, and two adjacent
  `ToolbarItem`s (or a `ToolbarItemGroup`, which still yields two `NSToolbarItem`s) draw as separate
  buttons instead of the joined capsule. Checked against a view-hierarchy capture of Xcode's own
  window: same class chain down to `SwiftUISegmentedControl`, same `segmentCount` 2 / `.momentary` /
  `.separated` / `.extraLarge`, same 73 × 36 fitting size. `SettingsNavigationControlsTests` asserts
  the first three.
- **Sub-page drill-down needs nothing from the library** — measured: a `NavigationStack` inside a
  page's own content gets SwiftUI's own `navigationStack.back` toolbar item. Deliberately *not*
  merged into `SettingsNavigator`, which tracks pages and not positions within one.
- **Correcting an earlier note here:** SwiftUI *does* build a toolbar for the settings window on
  macOS 26, and hiding the sidebar toggle in it works. `window.toolbar` is `nil` only when the panel
  is **embedded** in a host window rather than being its `contentViewController` — which is also why
  an embedded panel shows no chevrons. `SettingsNavigationControlsTests` guards the toolbar wiring.

**Full guide:** `Documentations/SettingsWindow.md`.

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
- `AppDelegate.swift` — builds a `DemoBrowserWindowController` on launch and, on macOS 26+, owns and registers the Settings scene representation during `applicationWillFinishLaunching(_:)`.
- `Browser/` — `DemoBrowserWindowController` (code-built `NSWindow`), `DemoBrowserSplitViewController` (sidebar + `DemoDetailViewController`), `DemoSidebarViewController` (source-list `NSOutlineView`; items are a private `SidebarNode` reference type because `NSOutlineView` needs stable item identity).
- `Catalog/` — `Demo` (a value type: `title` / `category` / `summary` / `minimumMacOS` / `makeViewController`) and `DemoCatalog.all` (the registry) + `DemoCatalog.grouped`.
- `Demos/` — one self-contained `NSViewController` per demo (`TabBarDemoViewController`, `SystemHUDDemoViewController`, `NavigationDemoViewController`, `LayerBackgroundDemoViewController`, `InsetsLabelDemoViewController`, `TextFinderDemoViewController`, `SettingsDemoViewController`, `SettingsSceneRepresentationDemoViewController`, `ToolbarNavigationDemoViewController`, `CustomTooltipDemoViewController`).

**To add a demo:** drop a new `NSViewController` file under `Demos/` and append one `Demo` to `DemoCatalog.all`. Nothing else changes.

**Do not let a demo dictate the window's minimum width.** Auto Layout treats an `NSHostingView`'s
ideal width — and a wrapping `NSTextField`'s single-line width — as a hard floor, so the browser
window gets pushed wide and cannot be shrunk back. Measured: three SwiftUI panels side by side
demanded 1006 pt; stacking them vertically brought it to 339 pt. Stack wide content vertically, add
`.fixedSize(horizontal: false, vertical: true)` to text that should wrap, and call
`setContentCompressionResistancePriority(.defaultLow, for: .horizontal)` on hosting views and labels.
The shared summary label at the top of the detail pane is already set up this way.

Two project facts that make this work (and matter when extending it):
- The Xcode project's app source group is a **file-system-synchronized group** (`PBXFileSystemSynchronizedRootGroup`, Xcode 16+). Any file added under the app folder is auto-included in the target — **no `project.pbxproj` edits needed** to add/move/delete demos.
- The example links the local package via an `XCLocalSwiftPackageReference` whose `traits` list selects opt-in features. **To demo a trait-gated control, add its trait there** (e.g. `TabBar`, `SystemHUD` and `Navigation` are enabled alongside `AppleInternal` / `FilterUI` / `IDEIcons` / `NSAttributedStringBuilder`); otherwise the control's symbols won't be compiled into the package and the demo won't link.

Build the example from the command line with `xcodebuild -project UIFoundationExample-macOS/UIFoundationExample-macOS.xcodeproj -scheme UIFoundationExample-macOS -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO build 2>&1 | xcsift`.

## Code Style Notes

- **Unique basenames per target**: within a single SPM target, every source file must have a unique file*name* — SwiftPM keys compiled object files by basename, so two same-named files in one target (even in different subdirectories) fail the build with `couldn't build …o because of multiple producers`. Prefix feature-scoped files with the feature name (`QuickActionBar+Helpers.swift`, `TabBar+Style.swift`) instead of relying on subdirectory paths to disambiguate. The `QuickActionBar/` and `TabBar/` feature dirs follow `Feature.swift` (entry) + `Feature+Descriptor.swift` for everything else, keeping only distinctive type-named files (e.g. `TabButton.swift`) unprefixed.
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
