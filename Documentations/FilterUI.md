# FilterUI

> AppKit filter controls — a search field with filter buttons, a token-based filter field, and a
> menu that filters its own items as you type.
>
> Ported from [freysie/filter-ui](https://github.com/freysie/filter-ui). The public-API controls
> live in `UIFoundationAppKit`; the private-API `FilteringMenu` lives in `UIFoundationAppleInternal`.
> Both ship behind the opt-in SPM trait `FilterUI` (default: off). macOS only.

---

## Contents

- [1. Getting started](#1-getting-started)
- [2. What ships](#2-what-ships)
- [3. Two `FilteringMenu`s: public API and private API](#3-two-filteringmenus-public-api-and-private-api)
- [4. Resources and the `actool` caveat](#4-resources-and-the-actool-caveat)
- [5. Implementation notes](#5-implementation-notes)

---

## 1. Getting started

```swift
.package(url: "…/UIFoundation", traits: ["FilterUI"])         // SPM dependency
```

```bash
swift build --traits FilterUI
```

With the trait off, every Filter source file compiles to nothing and no Filter symbol is exported.
The gate is `#if FilterUI`: the files under `Sources/UIFoundationAppKit/Filter/` use
`#if FilterUI && os(macOS)`, and the private menu under `Sources/UIFoundationAppleInternal/Filter/`
uses `#if FilterUI && canImport(Carbon)`. SPM 6.2 exposes each trait name as a Swift compilation
condition by itself, so no `swiftSettings` `.define` plumbing is involved.

`xcodebuild` has no command-line flag for traits. When building or testing through Xcode tooling,
the active traits come from the consuming Xcode project or scheme; from the command line, use
`swift build --traits FilterUI` to compile the Filter code.

## 2. What ships

In `UIFoundationAppKit/Filter/`:

| Symbol | What it is |
| --- | --- |
| `FilterSearchField` / `FilterSearchFieldCell` | A search field with a progress indicator, filter buttons and vibrancy-aware rendering. |
| `FilterTokenField` / `FilterTokenFieldCell` | A token-based filter field with comparison types. |
| `FilteringMenu_WithoutPrivateAPIUsage` | The public-API variant of the filterable menu, under `FilteringMenu+Public/`. |

In `UIFoundationAppleInternal/Filter/`:

| Symbol | What it is |
| --- | --- |
| `FilteringMenu` | The private-API variant of the filterable menu. See [§3](#3-two-filteringmenus-public-api-and-private-api). |

Both menus match items with the in-tree fuzzy matcher described in
[§5](#5-implementation-notes); it is `package`-level, not part of the public API.

**No SwiftUI bridges.** The original port also carried SwiftUI bridges — `FilterField`,
`FilterToggle` and `filterFieldStyle(_:)` — under `Filter/SwiftUI/`. They were removed together
with the SwiftUI previews (commit `d1cd631`, "drop SwiftUI previews and tidy filter controls") so
that the trait's surface stays pure AppKit.

**Availability.** SF Symbol and `SymbolConfiguration` call sites are wrapped in
`if #available(macOS 11.0, *)` / `if #available(macOS 12.0, *)`, and
`addFilterButton(systemSymbolName:toolTip:accessibilityDescription:symbolConfiguration:)` on
`FilterSearchField` is declared `@available(macOS 12.0, *)`. The gating was added to keep the
umbrella's platform at macOS 10.15+; the package's macOS floor has since risen to 12 (because of
the AppKitPlus dependency), so these checks are now always true on macOS but harmless.

## 3. Two `FilteringMenu`s: public API and private API

- **`FilteringMenu_WithoutPrivateAPIUsage`** (`UIFoundationAppKit`, `FilteringMenu+Public/`) uses
  only public API and is safe wherever the rest of `UIFoundationAppKit` is.
- **`FilteringMenu`** (`UIFoundationAppleInternal`) uses private API: `-[NSMenu highlightItem:]`,
  `_handleCarbonEvents:count:handler:` and `HIMenuGetContentView`. They are declared in two private
  headers, `NSMenu_FilteringPrivate.h` and `HIToolbox_Private.h`, in
  `Sources/UIFoundationCarbonInternal/include/` — the `UIFoundationCarbonInternal` target, which
  `UIFoundationAppleInternal` depends on. Like everything in `UIFoundationAppleInternal`, it must not
  ship in an App Store target.

The private menu reuses `FilterSearchField` from the public side, which is why
`UIFoundationAppleInternal` depends on `UIFoundationAppKit`.

## 4. Resources and the `actool` caveat

The Filter resources — the asset catalogs (`Colors.xcassets`, `Symbols.xcassets`,
`MoreSymbols.xcassets`), the `Localization` folder and `Documentation.docc` — live in
`UIFoundationAppKit/Filter/Resources/`. `Package.swift` processes them on top of the target's
existing `Resources/`, with one `.process("Filter/Resources/…")` entry each. Filter ships `en` and
`da` `.lproj` resources, which is why the package declares `defaultLocalization: "en"`.

SPM has no per-resource trait condition, so the asset catalogs and localizations stay in the
resource list and are bundled even when the trait is off. That is harmless.

**Asset lookups return `nil` from a command-line build.** The Filter controls load their images and
colours with `Bundle.module.image(forResource:)` and `NSColor(named:bundle:)`, which need an
`actool`-compiled `Assets.car`. `swift build` and `swift test` do not run `actool`; they copy the
`.xcassets` folders verbatim, so every such lookup returns `nil` in that mode — and several call
sites force-unwrap the colour. Consuming the package from an Xcode app target works, because Xcode
runs `actool` itself.

To exercise the resource path — or to run `FilterResourcesTests` — use the Xcode toolchain:

```bash
xcodebuild -scheme UIFoundation-Package -destination "platform=macOS" test -only-testing:UIFoundationTests/FilterResourcesTests
```

Move `UIFoundation.xcworkspace` aside temporarily first: that workspace exposes only the Example
schemes.

---

## 5. Implementation notes

- **Fuzzy search is in-tree.** `FuzzySearch.swift` (`FuzzySearchable` / `FuzzySearchResult` /
  `Collection.fuzzyMatch`) was ported and trimmed from the `fuzzy-search` package (MIT) and is used
  by both `FilteringMenu` variants, so FilterUI adds no external fuzzy-search dependency.
- **SwiftUI's `Button` is shadowed inside this module.** `UIFoundationAppKit.Button` is an
  `NSButton` subclass, so any SwiftUI view written inside `UIFoundationAppKit` must spell
  `SwiftUI.Button` and `SwiftUI.Image` explicitly. `FilterToggle` did this while it existed; keep it
  in mind if a SwiftUI bridge is ever added back.
- **Private API stays on the `AppleInternal` side.** `FilteringMenu`'s private declarations live in
  `UIFoundationCarbonInternal`, and the `UIFoundationAppKit` half of the feature uses public API only.
