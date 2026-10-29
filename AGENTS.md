# AGENTS.md

UIFoundation is a Swift package of foundational UI components and utilities on top of AppKit and
UIKit: macOS (AppKit) first, with iOS, tvOS, visionOS and Mac Catalyst support. APIs are unstable
and under active development. Every view and controller is built in code — no xib, no storyboard.

- Swift tools 6.2, Swift 5 language mode (`swiftLanguageModes: [.v5]`). No linter or formatter;
  style is convention only.
- Platforms: macOS 12+, iOS 13+, Mac Catalyst 13+, tvOS 13+, visionOS 1+. The macOS floor is
  AppKitPlus's and holds trait or no trait — [AppKitPlus.md](Documentations/AppKitPlus.md). No
  watchOS: `AssociatedObject` does not build there.

## Project map

```
UIFoundation                     umbrella product — @_exported imports the modules below
├── UIFoundationAppKit           macOS only; most components live here
├── UIFoundationUIKit            iOS / tvOS / visionOS / Catalyst
├── UIFoundationShared           cross-platform views & controllers
├── UIFoundationUtilities        property wrappers, DSLs, helpers
├── UIFoundationToolbox          also a product of its own; extensions behind `.box`
│   └── UIFoundationTypealias    NSUIView, NSUIColor, NSUIFont, …
└── UIFoundationAppleInternal    `AppleInternal` trait — private API
    ├── UIFoundationAppleInternalObjC   private AppKit / Core Animation headers
    └── UIFoundationCarbonInternal      private HIToolbox / NSMenu headers

UIFoundationSettings             `Settings` trait, macOS 14+; model layer
UIFoundationSettingsUI           `Settings` trait, macOS 14+; window layer
UIFoundationComponent            frame-computing layout system ported from lkzhao/UIComponent
AppKitPlus (binary)              linked into UIFoundationAppKit and UIFoundationToolbox under the `AppKitPlus` trait
```

- `UIFoundationAppleInternal` **must not** reach an App Store target (`CABackdropLayer`, `CAFilter`,
  `@_silgen_name` for private CoreGraphics symbols). It is not a product: consumers get it through
  `import UIFoundation` with the trait on.
- The Settings products and `UIFoundationComponent` stay outside the umbrella — the first to keep
  macOS 14 off every consumer, the second because `Component` / `Spacer` collide with umbrella names
  (Evolution [`0024`](Documentations/Evolutions/0024-component-layout-system.md)).
- `Tests/UIFoundationTests/` — the one test target; coverage is sparse.
- `UIFoundationExample-macOS/` — the demo browser app, plus the `ComponentLayoutExample` package.
- `Documentations/` — one guide per component, indexed in `Documentations/README.md` (Chinese);
  decision records in `Documentations/Evolutions/`.
- `Researchs/` — reverse-engineering reports.
- `AgentPlugins/uifoundation/` — the skills downstream agents install as the `uifoundation` plugin.

| Dependency | Used for |
|---|---|
| `FrameworkToolbox` (Mx-Iris) | the `.box` namespace; `NotificationCenter.Backport` (module `FoundationToolbox`); `Mutex` (module `OSToolbox`) |
| `AssociatedObject` (p-x9) | the `@AssociatedObject` macro |
| `AppKitPlus` (AppKitSupportProgram, **binary**) | UIKit APIs ported to AppKit, behind the `AppKitPlus` trait (default off) |

`Package.swift` declares dependencies through a custom `.package(local:remote:)` helper. Consumed as
a dependency (`#filePath` containing `/checkouts/`, `/SourcePackages/` or `/.build/`) it always uses
the remote; for local development set `isEnabled: true` on a local path entry and keep the sibling
repo on disk.

<important if="you need to build, test, or run this package or the example app">

```bash
swift package update && swift build 2>&1 | xcsift
swift package update && swift test 2>&1 | xcsift
swift build 2>&1 | xcsift --print-warnings
swift test --filter UIFoundationTests.testName 2>&1 | xcsift      # one test
swift build --traits FilterUI 2>&1 | xcsift                       # one opt-in trait; same for swift test

# Every opt-in trait at once. Collisions between trait-gated sources only show up here.
swift build --traits AppKitPlus,AppleInternal,FilterUI,IDEIcons,Navigation,NSAttributedStringBuilder,QuickActionBar,Settings,SpotlightPanel,StatusItemController,SystemHUD,TabBar,WelcomePanel 2>&1 | xcsift

# Example app. It finds the library at ../../UIFoundation, and Xcode names a local package after its
# real directory, so it builds only from a checkout whose directory is called UIFoundation — never
# from a .worktrees/UIFoundation-<Purpose> worktree, not even through a symlink. From a worktree,
# rsync the tree (without .git and .build) into a scratch directory named UIFoundation and build there.
xcodebuild -project UIFoundationExample-macOS/UIFoundationExample-macOS.xcodeproj -scheme UIFoundationExample-macOS -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO build 2>&1 | xcsift

# The next two run through Xcode. Move UIFoundation.xcworkspace aside first — it only exposes the example schemes.
# Asset catalogs: swift build / swift test never run actool, so catalog lookups return nil there.
xcodebuild -scheme UIFoundation-Package -destination "platform=macOS" test -only-testing:UIFoundationTests/FilterResourcesTests
# UIKit notification-message parity: Mac Catalyst, never a simulator.
xcodebuild test -scheme UIFoundation-Package -destination 'platform=macOS,variant=Mac Catalyst' -only-testing:UIFoundationTests/UIKitNotificationMessageParityTests
```

- **`swift package update` deletes the `AppKitPlus-Release` pin from the tracked `Package.resolved`**
  (it prints `Removing …/AppKitPlus-Release`): the dependency exists only under the `AppKitPlus`
  trait, and the update resolves without traits. Check `git status` after every update; if the pin is
  the only change, `git checkout -- Package.resolved` before building.
  - Passing traits is no way around it: `swift package --traits … update` and
    `swift package --enable-all-traits update` both fail with `exhausted attempts to resolve the
    dependencies graph … 'appkitplus-release'` and change nothing (measured).
  - Don't rebuild with the trait to put the pin back. Without a pin, resolution takes the newest
    AppKitPlus in range — a silent bump, and a bump needs the collision re-check in
    [AppKitPlus.md](Documentations/AppKitPlus.md).
- `xcodebuild` has no trait flag: under Xcode the consuming project or scheme picks the traits.
</important>

<important if="you are writing or modifying tests">

- **Never compare a `CGFloat` against a `Double` inside `#expect`.** Measured on macOS 26 with the
  swift-testing bundled with Swift 6.2: with `expected: Double`, `#expect(cornerRadius == expected)`
  fails even when both hold 8.0, and the message prints both sides identically. The same `==` outside
  the macro is `true` — SE-0307's implicit conversion does not survive the macro's operand capture.
  Type both sides the same (`[(Style, CGFloat)]` tables, `CGFloat(...)`); bare literals are fine.
  Most of the suite asserts geometry, so this comes up.
- **Anything Liquid-Glass-shaped needs a real app bundle to verify.** A `swift build` / `swift test`
  binary carries its deployment target as the `LC_BUILD_VERSION` `sdk` (measured: `sdk 15.0` against
  the example app's `27.0`), and AppKit gates the macOS 26+ look on it — toolbar platters do not
  exist in a command-line run. Assert on AppKit state instead. To see it, `vtool -set-build-version
  macos <minos> 27.0 -replace` the binary into a hand-built `.app`, re-sign ad hoc, and copy the
  SwiftPM resource bundles into `Contents/Resources/`.
- Testing traps specific to one component are in that component's guide.
</important>

## Components

<important if="you are using, changing, reviewing or testing one of the components below">

A component's guide is the single home for its contracts and for the implementation details that
look simplifiable but are not. **Read it before changing the component, and update it in the same
commit.** Folders are under `Sources/`; the sentence after each link is the trap that fails silently.

No trait:

- **Layer background** — `UIFoundationAppKit/Base/` — [LayerBackground.md](Documentations/LayerBackground.md).
  On macOS 27.2 setting `cornerRadius` turns `clipsToBounds` on, so a rounded host trims its subviews
  and any `.center` / `.outside` border.
- **MainMenu** — `UIFoundationAppKit/Menu/` — [MainMenu.md](Documentations/MainMenu.md). A
  storyboard-free app loses `@main` on its delegate: no delegate is created and no window appears
  unless the entry point is written by hand.
- **Toolbar DSL and `NSToolbar.Navigation`** — `UIFoundationAppKit/Toolbar/` —
  [ToolbarNavigation.md](Documentations/ToolbarNavigation.md). An action on the navigation
  segmented control makes a click open the menu and single-step back / forward disappears; a typed
  `actionBlock` must stay computed, since `didSet` never fires from an initializer.
- **AsyncDocument** — `UIFoundationAppKit/Document/`, `UIFoundationToolbox/AppKit/NSDocument+.swift`
  — [AsyncDocument.md](Documentations/AsyncDocument.md). `write` / `readSnapshot` must never hop to
  the main thread: NSDocument is often blocking it, waiting for them.
- **Typed notification messages** — `UIFoundationToolbox/{AppKit,UIKit}/NotificationMessages/` —
  [NotificationMessages.md](Documentations/NotificationMessages.md). Every identifier is
  `@_disfavoredOverload`; dropping it makes Apple's own shorthand ambiguous for every client, and the
  shorthand guards' results must stay discarded or they stop guarding.
- **TextFinder** — `UIFoundationAppKit/TextFinder/` — [TextFinder.md](Documentations/TextFinder.md).
  Never call `textFinder.performAction(_:)` directly; through anything but
  `textFinderClient.performTextFinderAction(_:)` it searches an index that was never built.
- **PlaybackSlider** — `UIFoundationAppKit/PlaybackSlider/` — [PlaybackSlider.md](Documentations/PlaybackSlider.md).
  Music's plus-lighter colours need the `AppleInternal` trait; without it the bar blends normally,
  a little darker, and nothing says so. Its tests must not post real clicks: the runner is ended
  with exit status 0.
- **Self-sizing row views**, **view DSLs** — blocks below.

Opt-in traits (wiring in the trait block below):

- **AppKitPlus** (`AppKitPlus`) — [AppKitPlus.md](Documentations/AppKitPlus.md). See the
  view-class and AppKitPlus blocks below.
- **Navigation** (`Navigation`) — `UIFoundationAppKit/Navigation/` —
  [Navigation.md](Documentations/Navigation.md). The container owns page frames; a page constrained
  from outside slides back mid-transition. Transitions assign final values in an implicit-animation
  group — never `CABasicAnimation` — which is what keeps the interactive pop steppable.
- **TabBar** (`TabBar`) — `UIFoundationAppKit/TabBar/` — [TabBar.md](Documentations/TabBar.md). A
  host that owns the selection must call `selectItemAtIndex(_:)` inside `tabBar(_:didCloseItem:)`;
  decoration views must return `nil` from `hitTest(_:)` or the close button dies under the macOS 27 SDK.
- **QuickActionBar** (`QuickActionBar`) — `UIFoundationAppKit/QuickActionBar/` —
  [QuickActionBar.md](Documentations/QuickActionBar.md). In a test process the window never becomes
  key, so send `cancelOperation:` instead of an Escape key-down, and keep the content source alive or
  `ResultsView.buildShortcuts()` traps.
- **FilterUI** (`FilterUI`) — `UIFoundationAppKit/Filter/`, `UIFoundationAppleInternal/Filter/` —
  [FilterUI.md](Documentations/FilterUI.md). Its asset lookups return `nil` under `swift build` /
  `swift test` (no `actool`); test the resource path through `xcodebuild`.
- **SystemHUD** (`SystemHUD`) — `UIFoundationAppKit/SystemHUD/` — [SystemHUD.md](Documentations/SystemHUD.md).
  The fade stays an `NSAnimation` on a `.common`-mode timer; `NSAnimationContext` changes the feel.
- **WelcomePanel** (`WelcomePanel`) — `UIFoundationAppKit/WelcomePanel/` —
  [WelcomePanel.md](Documentations/WelcomePanel.md). Rounded corners rest on explicit
  `clipsToBounds = true` and the list insets on `.sourceList`; remove either and they vanish.
- **Settings window** (`Settings`) — `UIFoundationSettings/`, `UIFoundationSettingsUI/` —
  [SettingsWindow.md](Documentations/SettingsWindow.md). `accessPersistedValues()` must read every
  encoded property; a change to one it skips never schedules an auto-save.
- **SpotlightPanel** (`SpotlightPanel`, enables `AppleInternal` + `Navigation`) —
  `UIFoundationAppleInternal/SpotlightPanel/` — [SpotlightPanel.md](Documentations/SpotlightPanel.md).
  The window stays borderless: `.titled` draws a second platter 40 pt outside the real one.
- **StatusItemController** (`StatusItemController`), **NSAttributedStringBuilder**
  (`NSAttributedStringBuilder`) — blocks below. **IDEIcons** (`IDEIcons`) —
  `UIFoundationShared/IDEIcons/`, no guide.

`AppleInternal` (private API):

- **Glass effect replica** — `UIFoundationAppleInternal/GlassEffect/` —
  [GlassEffectReplica.md](Documentations/GlassEffectReplica.md). SwiftUI rewrites the backdrop group
  name when the window becomes key; the `GroupPinnedBackdropLayer` class swap is what holds it.
- **Row height estimation** — `UIFoundationAppleInternal/TableView/` —
  [TableViewRowHeightEstimation.md](Documentations/TableViewRowHeightEstimation.md). Every
  `setDelegate:` — Rx delegate proxies included — turns estimation back on; turn it off in the
  `delegate` setter.
- **Scroll pockets** — `UIFoundationAppleInternal/ScrollView/` — [ScrollPockets.md](Documentations/ScrollPockets.md).
  Insetting content only through the clip view leaves the bottom pocket 0 pt tall.
- **Custom tooltips** — `UIFoundationAppleInternal/Tooltip/` — [CustomToolTip.md](Documentations/CustomToolTip.md).
  `install()` is reference-counted, so every `install()` needs its `uninstall()`; hook methods cannot
  be `@MainActor` and reach the manager through `MainActor.assumeIsolated`.
- **Semantic context** — `view._semanticContext = NSViewSemanticContextForm` (`NSView_Private.h`)
  gives a subtree the System Settings grouped-form look. It inherits, so set it once on the container;
  it is read at draw time; only `Form` (macOS 13+) is a stable name and number. Report:
  [AppKit-NSView-SemanticContext.md](Researchs/AppKit-NSView-SemanticContext.md).
</important>

<important if="you are adding, enabling or editing an opt-in trait, or code gated on one">

- Traits, all default off: `AppKitPlus`, `AppleInternal`, `FilterUI`, `IDEIcons`, `Navigation`,
  `NSAttributedStringBuilder`, `QuickActionBar`, `Settings`, `SpotlightPanel` (enables `AppleInternal`
  and `Navigation`), `StatusItemController`, `SystemHUD`, `TabBar`, `WelcomePanel`. Consumers opt in
  with `.package(url: "…/UIFoundation", traits: ["TabBar"])`.
- SwiftPM 6.2 exposes each trait as a compilation condition — `#if TabBar` needs no `.define`. Every
  source file of a gated feature is wrapped whole; macOS-only features add a platform condition
  (`#if TabBar && os(macOS)`) so an accidental enable elsewhere compiles to nothing.
- Resources cannot be trait-gated: a gated feature's catalogs and `.lproj`s ship with the trait off
  too, which is harmless.
- A collision between two gated sources appears only with every trait on: use the full-trait build,
  and build the example app.
</important>

<important if="you are adding a view or view controller, or subclassing an AppKit class">

```
NSView ·or· NSLayerBackedView                    (the latter with the AppKitPlus trait on)
 └── LayerBackedView       renders in updateLayer(); override setup() and firstLayout()
      └── XiblessView      init?(coder:) unavailable
NSViewController ·or· NSLayerBackedViewController
 └── LayerBackedViewController<View: LayerBackedView>
XiblessViewController<View: NSUIView>            contentView from an @autoclosure factory, set in loadView()
```

- Override `setup()` (called from both initializers) and `firstLayout()` (once, on the first
  `layout()`), not the initializers.
- The bases are `LayerBackedViewBase` / `LayerBackedViewControllerBase`, resolved by
  `#if AppKitPlus && canImport(AppKitPlus)` — keep both halves of that guard.
- With the trait off, `LayerBackedViewController` has only `viewWillFirstAppear` /
  `viewDidFirstAppear` of AppKitPlus's six hooks. An override of `viewWillFirstLayout`,
  `viewDidFirstLayout`, `viewUpdateLayer` or `viewSafeAreaInsetsDidChange` goes inside
  `#if AppKitPlus && canImport(AppKitPlus)`.
- **With the trait on, a subclass may not declare a property whose name AppKitPlus already added to
  that class** — Swift reports `overriding non-open property outside of its defining module`, and
  `@nonobjc` does not help. The restriction reaches every module importing UIFoundation with the
  trait on. Live hazards: `center`, `transform`, `contentMode` on any `NSView`; `layoutMargins`,
  `directionalLayoutMargins`, `preservesSuperviewLayoutMargins`, `insetsLayoutMarginsFromSafeArea`,
  `layoutMarginsDidChange()` on any `LayerBackedView`. Code that compiles with the trait off can fail
  with it on. Details in [AppKitPlus.md](Documentations/AppKitPlus.md).
</important>

<important if="you are bumping AppKitPlus, or Package.resolved changed its version">
Re-check the collision surface before anything else: `from:` is up-to-next-major even for `0.x`, so
the constraint does not make a bump safe. Survey AppKitPlus's public headers, not its
`.swiftinterface` — Objective-C categories never appear in an interface. The host classes, the grep
and the version-floor history are in [AppKitPlus.md](Documentations/AppKitPlus.md).
</important>

<important if="you are giving a view a background colour, corner radius, border or shadow">
`LayerBackedView` gets `cornerRadius`, `cornerCurve`, `backgroundColor`, `border*` and `shadow*` from
`LayerBackgroundProviding`. A view that cannot inherit from it (`NSTableCellView`, a collection
item's view) conforms to the protocol and calls `attachToSelfIfNeeded()`,
`updateLayerBackgroundIfNeeded()` and `layoutLayerBackgroundIfNeeded()` itself. Don't conform a class
that already owns `backgroundColor` (`NSTextField`, `NSTableView`, `NSScrollView`): the protocol's
property is shadowed and silently receives nothing. Example, corner-curve and clipping traps, and
pixel testing: [LayerBackground.md](Documentations/LayerBackground.md).
</important>

<important if="you are writing code shared by AppKit and UIKit">

- Use the `UIFoundationTypealias` aliases (`NSUIView`, `NSUIColor`, `NSUIFont`, …) instead of
  branching. The AppKit guard is `#if canImport(AppKit) && !targetEnvironment(macCatalyst)`.
- Stack-view alignment is the exception. `NSLayoutConstraint.Attribute` and `UIStackView.Alignment`
  disagree (AppKit has no `.fill`), so `HStackView` / `VStackView` take the shared
  `StackViewAlignment`, which emulates `.fill` on AppKit with `alignment = .notAnAttribute` plus
  pinned cross-axis edges (respecting `edgeInsets`). Defaults stay per platform: `.center` on AppKit,
  `.fill` on UIKit.
</important>

<important if="you are adding an extension, helper or convenience on an AppKit, UIKit or Foundation type">

- It goes behind FrameworkToolbox's `.box` namespace (`tableView.box.makeView(ofClass:)`,
  `button.box.setAction { … }`) so it cannot collide with Apple's or AppKitPlus's names.
  `UIFoundationToolbox.swift` `@_exported import`s FrameworkToolbox so every module sees `.box`. The
  one deliberate exception is the notification messages' nested `Backport` type.
- `NSWindow.box.restoreFrame(autosaveName:defaultSize:centerInScreen:)` and
  `NSSplitView.box.restoreDividerPositions(autosaveName:initialPositions:)` apply their fallback only
  when nothing restorable is stored (Evolution
  [`0020`](Documentations/Evolutions/0020-splitview-autosave-initial-positions.md); measured on
  macOS 26.5.2):
  - "The key exists" is not "the layout will be restored". AppKit silently declines when the stored
    entry count differs from `arrangedSubviews.count`, so a release that adds a pane leaves a dead
    key; `hasRestorableDividerPositions(autosaveName:)` replicates AppKit's whole check.
  - Re-assigning the same `autosaveName` restores nothing (an `isEqualToString:` guard), which is why
    the implementation clears the name before setting it. Keep the pair.
  - There is no `@resultBuilder` spelling on purpose: in Swift 6.2 a bare implicit member chain inside
    a builder closure cannot resolve its type, so an array literal keeps the leading-dot form.
</important>

<important if="you are using or changing the view-building DSLs or property wrappers">

- `@ViewHierarchyBuilder` — declarative hierarchy: `ViewItem` (`@dynamicMemberLookup` for
  configuration), `ControllerItem` (does `addChild`), `LayoutGuideItem`.
- `HStackView` / `VStackView` — built with FrameworkToolbox's `@ArrayBuilder<StackViewComponent>`;
  `Spacer(spacing:)` and `MaxSpacer()` are recognised specially. Per-view stack modifiers live behind
  `.stackView` (a plain wrapper, not `.box`): `fill()`, `customSpacing(_:)`, and macOS-only
  `gravity(_:)` / `visibilityPriority(_:)`, stored with `@AssociatedObject` and read at assembly. Size
  helpers (`size`, `minSize`, `maxSize`, `contentHugging`, `contentCompressionResistance`) are `.box`
  in `NSUIView+SizeConstraints.swift`; `NSUIStackView` configuration is `.box` in
  `StackView+Box.swift`. The old direct-on-view methods remain, deprecated.
- `GridView { GridRow { … } }` (macOS) — `NSGridView` DSL in `UIFoundationAppKit/GridView/`; the
  `GridView` class itself is `Base/GridView.swift`. The convenience initializer lives on `NSGridView`, so the `GridView`
  subclass inherits it and its `setup()` still runs. A bare `NSView` in a row becomes a `GridCell`;
  `GridCell.empty` is a blank cell. Cell modifiers behind `.gridView` (`columns(_:)` / `rows(_:)`
  spanning, `xPlacement`, `yPlacement`, `rowAlignment`, `placementConstraints`), and the same set on
  `GridCell`; row properties on `GridRow`; column properties via `.columns { GridColumn()… }`. The old
  `gridCell*` methods on `NSView` remain, deprecated.
  Spanning pads with `NSGridCell.emptyContentView` and merges once after all rows, with clamped,
  non-overlapping ranges. Traps: placement constraints exclude `xPlacement` / `yPlacement`; a grid- or
  row-level `rowAlignment` other than `.none` suppresses per-cell `yPlacement`; don't `.hidden()` a
  row that takes part in a merge. NSGridView's own rules are in the `appkit-internals` skill.
- `@ViewInvalidating(.display, .layout)` — invalidates the owning view on change, through the
  `_enclosingInstance` subscript; combinations nest `Invalidations.Tuple` (up to 10). AppKit-only
  extras: `.restorableState`, `.reloadData` (the view must conform to `ViewReloading`).
- `@MagicViewLoading` / `@MagicWindowLoading` — the getter calls `loadViewIfNeeded()` /
  `loadWindowIfNeeded()` and force-unwraps, so assign them in `setup()` or `loadView()` before
  anything outside reads them.
- `makeConstraints { make in … }` — `make` is the view itself; returns the activated constraints.
- `Then` (`.then` / `.with` / `.do` / `.as` on every `NSObject`) is an internal protocol duplicated
  in `UIFoundationAppKit`, `UIFoundationShared`, `UIFoundationUtilities` and `UIFoundationUIKit`; it
  is not exported.
- Target-action as closures: `TargetActionProvider` + `ActionTrampoline`, for `NSControl`, `NSCell`,
  `NSToolbarItem`, `NSMenuItem`, `NSGestureRecognizer`, `NSColorPanel`. `NSControl` has two APIs on
  separate keys: the untyped `.box.setAction { }` and the typed `.box.actionBlock`.
- `TableViewProtocol` / `OutlineViewProtocol` factories `scrollableTableView()` /
  `scrollableSingleColumnOutlineView()` return `(NSScrollView, Self)`.
</important>

<important if="you are using or changing SelfSizingScrollView, SelfSizingTableView or SelfSizingOutlineView">
`UIFoundationAppKit/Base/` (`ScrollView.swift`, `TableView.swift`, `OutlineView.swift`): a table or
tree that reports its rows' height as its intrinsic size, so it can sit in a stack view.
`SelfSizingScrollView` mirrors its document view's intrinsic size, clamped by `minimumContentSize` /
`maximumContentSize`, and scrolls past the cap.

- Both row views measure through the internal `NSTableView.selfSizingRowsContentSize` — they inherit
  from different UIFoundation bases, so a shared extension is how they agree. It reads
  `rect(ofRow:)` rather than multiplying `rowHeight`: the first row's `minY` already carries a
  `.inset` / `.sourceList` style's top inset, the last row's `maxY` the intercell spacing, and the
  bottom inset mirrors the top. Both override `invalidateIntrinsicContentSize()` to invalidate the
  enclosing scroll view — nothing else makes it ask again.
- **A disclosure does not animate, on purpose.** AppKit slides rows in over `NSAnimationContext`'s
  default 0.25 s while the reported height travels through Auto Layout on its own schedule; the two
  never line up and it reads as a jitter. `SelfSizingOutlineView` wraps the disclosure — including
  whatever a delegate does from `outlineViewItemDidExpand`, posted from inside the call — in a
  zero-duration grouping. `animatesExpansionAndCollapse = true` hands the animation back, sensible only
  when the host's height does not follow the row count.
- Overriding `expandItem(_:expandChildren:)` catches every path: `expandItem(_:)` forwards to it, and
  so does the disclosure triangle, an `NSButton` whose `_outlineControlClicked:` routes through it
  (verified by clicking). `insertRows(at:withAnimation:)` cannot be overridden — `NSOutlineView`
  marks it unavailable.
- Tests cannot see the animation (no display; rows are not even layer-backed).
  `SelfSizingRowViewsTests` asserts on `NSAnimationContext.current.duration` read in the delegate
  callback, against a plain `OutlineView` control that reads 0.25 — without the control the assertion
  passes against an implementation that does nothing.
</important>

<important if="you are using or changing StatusItemController">
`StatusItemController` trait; `UIFoundationAppKit/StatusItemController/`; ported from
hexedbits/StatusItemController (MIT, see `THIRD_PARTY_LICENSES.md`). One top-level symbol:
`@MainActor open class StatusItemController: NSObject, NSMenuDelegate`, owning `statusItem`, built with
`init(image:length:)` (`length` defaults to `NSStatusItem.squareLength`). Subclasses override
`buildMenu()`, `leftClickAction()` and `rightClickAction()` (control-click counts as right) and call
`openMenu()`, `hideMenu()` or `quit()`.

- `openMenu()` goes through `popUpMenu(_:)`, as upstream does: without it the menu fails to pop up on
  the first click.
- Upstream's public `NSEvent.isRightClickUp` / `NSApplication.isCurrentEventRightClickUp` are internal
  here, renamed `isRightClickUpForStatusItem` / `isCurrentEventRightClickUpForStatusItem`, to stay out
  of the top-level AppKit namespace. Upstream's `NSMenuItem` convenience initializer is not ported —
  `Menu/NSMenuItem+Convenience.swift` and the `@MenuBuilder` DSL supersede it.
</important>

<important if="you are using or changing NSAttributedStringBuilder">
`NSAttributedStringBuilder` trait; `UIFoundationShared/NSAttributedStringBuilder/`; tests in
`Tests/UIFoundationTests/NSAttributedStringBuilder/` (Swift Testing, gated on the same trait). Ported
from ethanhuang13/NSAttributedStringBuilder: `NSAttributedString { AText("…").font(…); LineBreak() }`
with `AText`, `ATextGroup` (`@AttrTextGroupBuilder`), `Link`, `ImageAttachment` (not on watchOS),
`Empty`, `Space`, `LineBreak`.

- Upstream's `Font` / `Color` / `Image` / `Size` / `Rect` typealiases were dropped for `NSUIFont` /
  `NSUIColor` / `NSUIImage` and plain `CGSize` / `CGRect`, so nothing collides with SwiftUI's `Font` /
  `Color` / `Image`. `Attributes` (`[NSAttributedString.Key: Any]`) stays.
- `Ligature.all` and the `vertical()`, `textBlocks(_:)`, `textLists(_:)`,
  `tighteningFactorForTruncation(_:)` and `headerLevel(_:)` modifiers are AppKit-only
  (`#if canImport(AppKit) && !targetEnvironment(macCatalyst)`).
</important>

## Code style

<important if="you are naming or adding a source file">

- **File basenames are unique within a target.** SwiftPM keys object files by basename, so two
  same-named files in different subdirectories of one target fail with `couldn't build …o because of
  multiple producers`. Prefix feature files with the feature — `Feature.swift` for the entry point,
  `Feature+Descriptor.swift` for the rest (`QuickActionBar+Helpers.swift`, `TabBar+Style.swift`);
  distinctive type names (`TabButton.swift`) stay as they are.
- Extensions on AppKit / UIKit classes are named `NSClassName+.swift`, one file per class in
  `UIFoundationToolbox/AppKit/`. Button style subclasses (`PushButton`, `SwitchButton`, `HelpButton`)
  live in `UIFoundationAppKit/Button/StyleSplittedButton/`.
</important>

<important if="you are storing a value on an object at runtime (associated objects)">
**Go through the `@AssociatedObject` macro, never by hand**: no `objc_getAssociatedObject` /
`objc_setAssociatedObject`, no direct calls to the package's `getAssociatedObject` /
`setAssociatedObject`, no pasted expansion — declare a property and put the attribute on it.

- A value with a natural default (a helper object, a collection) is non-optional with an initial
  value, `var property: Type = .init()` (`LayerBackgroundProviding.backgroundRenderer`,
  `NSView.actionHandlers`); the first read creates and stores it. Keep it optional only when `nil`
  means something (`pinnedGroupName = nil` unpins; a `nil` trampoline means no action block).
- The macro associates with `self`, so data kept on *someone else's* object goes in a
  `private extension` of that object's class (`FilteringMenu` → `NSMenuItem`, `FilterTokenFieldCell`
  → `NSTextAttachment`, `CustomToolTipManager` → `NSWindow`, `TargetActionProvider` → `NSObject`).

Three traps, all measured:

- **Never type the property `Any` or `AnyObject`, optional or not.** The generated getter casts with
  `as? Any` / `as? AnyObject`, and with nothing stored that produces `Optional(nil)` / `NSNull`, never
  `nil`: an optional reads "already set" before anything was stored, and a non-optional returns the
  placeholder instead of its initial value. Use the concrete type; for one of several ObjC classes,
  `NSObject?` reads back `nil` correctly.
- **A macro-backed property only looks stored.** On a class installed with `object_setClass`
  (`GroupPinnedBackdropLayer`), which must add no storage, deleting the attribute turns it into a real
  stored property that outlives an instance someone else allocated.
- **A protocol extension can be a circular reference.** In `extension TargetActionProvider` a
  property typed `ActionTrampoline<Self>?` fails with `circular reference` on the protocol, trailed by
  dozens of misleading follow-on errors. Declare it on the conformers' common superclass (`NSObject`)
  and restore the type in a computed wrapper (`FrameworkToolbox.actionTrampoline`).
</important>

<important if="you are adding a lock, or state shared across threads">
**Locks are FrameworkToolbox's `Mutex` (module `OSToolbox`)** — never `NSLock`, `os_unfair_lock` or
`OSAllocatedUnfairLock` by hand. Unlike the standard library's it does not need macOS 15. A target
that locks names the `OSToolbox` product itself (`UIFoundationToolbox` re-exports `FrameworkToolbox`,
which does not contain it), and so does the example's `ComponentLayoutExample` package. Put every
guarded field into one `Mutex<State>` rather than a lock beside several `var`s: nothing reaches them
without the lock, and the class passes `Sendable` checking with no `@unchecked`
(`SwiftSyntaxHighlighter` in the example, the storages in `Tests/UIFoundationTests/Settings/`).

- **`~Copyable` does not get in the way of a local.** A local `let` captured by an escaping closure
  (`Task.detached`, a completion block) is borrowed there and the function keeps using it, as
  `AsyncDocumentBridge` does. Only consuming it after the capture fails (measured on a probe, Swift 6.4).
- **Keep caller-supplied code out of `withLock`.** The lock is an `os_unfair_lock`, which crashes
  when its holder takes it again, where `NSLock` would deadlock. Produce the value first, then store
  it inside (`AsyncDocument.canAsynchronouslyWrite`). The one deliberate exception is
  `QuickActionBar.SearchTask`, which calls its completion with the lock held — that is what stops an
  invalidated task from delivering — and whose only completion is the bar's own, which just hops to
  the main queue.
</important>

<important if="you are adding or editing a private Objective-C header">
Private headers live in `UIFoundationAppleInternalObjC/include/` (AppKit, Core Animation) and
`UIFoundationCarbonInternal/include/` (HIToolbox, `NSMenu`). Two shapes, picked by whether the SDK
ships a public header for the class:

- `<Class>_Private.h` re-opens a public class with `@interface ClassName ()` (`NSView_Private.h`,
  `NSScrollView_Private.h`, `CALayer_Private.h`, `NSColor_Private.h`).
- `<Class>.h` declares a fully private class — symbols only in the framework's `.tbd` — as a whole
  `@interface ClassName : NSObject` (`NSScene.h`, `CABackdropLayer.h`, `NSToolTip.h`,
  `NSToolTipManager.h`). An Apple documentation page does not make a class public: `NSToolTipManager`
  has one and no SDK header. Check first with
  `grep "interface NSToolTipManager" $(xcrun --sdk macosx --show-sdk-path)/System/Library/Frameworks/AppKit.framework/Headers/*.h`.
</important>

## Example app

<important if="you are adding a demo or changing the example app">
`UIFoundationExample-macOS/` is a single-window demo browser: a source-list sidebar grouped by
category, the selected demo's view controller on the right. No storyboard or xib — the menu is
`MainMenu.standard()`. Under `UIFoundationExample-macOS/UIFoundationExample-macOS/`:

- `AppDelegate.swift` — the hand-written `@main enum App` entry point (a storyboard-free app cannot
  put `@main` on its delegate — [MainMenu.md](Documentations/MainMenu.md)), plus `AppDelegate`, which
  on macOS 26+ owns and registers the Settings scene representation in
  `applicationWillFinishLaunching(_:)` and opens a `DemoBrowserWindowController` on launch.
- `Browser/` — the window controller, the split view controller, and `DemoSidebarViewController`,
  whose outline items are a private `SidebarNode` reference type because `NSOutlineView` needs stable
  item identity.
- `Catalog/` — `Demo` (`title`, `category`, `summary`, `minimumMacOS`, `makeViewController`) and the
  `DemoCatalog.all` registry.
- `Demos/` — one self-contained `NSViewController` per demo.

**To add a demo**, drop an `NSViewController` file under `Demos/` and append one `Demo` to
`DemoCatalog.all`. The app's source group is file-system-synchronized
(`PBXFileSystemSynchronizedRootGroup`), so no `project.pbxproj` edit is needed to add, move or delete
a file.

- **To demo a trait-gated feature, add its trait** to the `traits` list of the project's
  `XCLocalSwiftPackageReference`. A product outside the umbrella also needs an
  `XCSwiftPackageProductDependency` and a Frameworks-phase entry — `UIFoundationSettings` /
  `UIFoundationSettingsUI` do — or the demo's import does not resolve.
- **Don't let a demo set the window's minimum width.** Auto Layout treats an `NSHostingView`'s ideal
  width, and a wrapping `NSTextField`'s single-line width, as a hard floor, so the window is pushed
  wide and cannot shrink back (measured: three SwiftUI panels side by side demanded 1006 pt, stacked
  vertically 339 pt). Stack wide content vertically, add `.fixedSize(horizontal: false, vertical: true)`
  to wrapping text, and lower horizontal compression resistance (`.defaultLow`) on hosting views and
  labels. The detail pane's shared summary label is already set up this way.
</important>

## Documentation

<important if="you are writing documentation, or changing public API or behaviour">

- **Keep this file an index.** A component's detail goes into its guide, with one line here pointing
  at it: Codex reads only the first 64 KB of this file and drops the rest, and Claude Code tells the
  model this file may be irrelevant, so length costs attention. A rule belongs here only if it applies
  across components.
- A component's guide changes in the same commit as its behaviour. A new guide is added to
  `Documentations/README.md`.
- Reverse-engineering reports (binary analysis, private API investigations) go in `Researchs/` at the
  repo root, nowhere else. The one exception is Mac Catalyst — how UIKit runs on AppKit (UIKitCore's
  Mac build, UIKitMacHelper): that research lives in the AppKitPlus repository under
  `Documentations/Researchs/MacCatalyst/`, which has its own system-version baseline. The reports that
  used to sit here moved there on 2026-10-29; write new Catalyst research there, not here.
- `AgentPlugins/uifoundation/skills/` holds `uifoundation-widgets` and `uifoundation-settings-layer`.
  A change to the public API they describe — a widget, a builder, a `.box` helper, the settings types
  — updates the affected skill in the same commit and bumps `version` in both
  `AgentPlugins/uifoundation/.claude-plugin/plugin.json` and `.codex-plugin/plugin.json`: Claude Code
  and Codex update an installed plugin only when that version changes.
</important>
