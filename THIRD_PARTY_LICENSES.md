# Third-Party Licenses

UIFoundation contains code derived from the third-party projects listed below.
Each component is bundled inside an opt-in SPM trait and isolated under its own
directory so the surrounding license can be preserved.

---

## DSFQuickActionBar — `QuickActionBar` trait

- Upstream: https://github.com/dagronf/DSFQuickActionBar
- Author: Darren Ford
- License: MIT
- Location in this repo: `Sources/UIFoundationAppKit/QuickActionBar/`
- Modifications:
  - Dropped the `DSF` prefix from all type names and filenames
    (`DSFQuickActionBar` → `QuickActionBar`, `DSFTextField` →
    `QuickActionBarTextField`, etc.).
  - Removed the SwiftUI bridge (`QuickActionBar.swift` /
    `NSViewRepresentable` wrapper).
  - Removed the `DSFAppearanceManager` dependency in favour of stock AppKit
    (`NSColor.controlAccentColor`,
    `NSWorkspace.shared.accessibilityDisplay*`,
    `NSAppearance.performAsCurrentDrawingAppearance(_:)`).
  - Wrapped every source file in `#if QuickActionBar … #endif` so the feature
    is gated behind the `QuickActionBar` SPM trait.

### License

```
MIT License

Copyright (c) 2022 Darren Ford

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

---

## KPCTabsControl — `TabBar` trait

- Upstream: https://github.com/onekiloparsec/KPCTabsControl
- Authors: Cédric Foellmi, Christian Tietze
- License: MIT
- Location in this repo: `Sources/UIFoundationAppKit/TabBar/`
- Modifications:
  - The public API was nested under the `TabBar` namespace to avoid
    polluting the umbrella module's top-level namespace
    (`Style` → `TabBar.Style`, `Theme` → `TabBar.Theme`,
    `TabBarDataSource` →
    `TabBar.DataSource`, `TabBarDelegate` → `TabBar.Delegate`,
    etc.). `TabBar` and `TabButton` remain top-level types.
  - The `KPC` prefix was dropped from the bundled PDF template resources
    (`KPCPullDownTemplate.pdf` → `PullDownTemplate.pdf`, …) and resource
    lookups now use `Bundle.module` exclusively (the `#if SwiftPackage`
    CocoaPods branch was removed).
  - The upstream Numbers, Chrome and Safari styles (and their themes) were
    removed in favour of a single `TabBar.SystemStyle` replicating the
    macOS 26 window tab bar. The `ThemedStyle` / `Theme` machinery they were
    built on is retained for anyone writing a style of their own.
  - `macOS 10.13`/`10.14` availability fallbacks were dropped since the package
    targets macOS 10.15+; the now-unused `NSColor.darkerColor()` helper and the
    unused `Error.swift` were removed.
  - Wrapped every source file in `#if TabBar && os(macOS) … #endif` so the
    feature is gated behind the `TabBar` SPM trait.

### License

```
The MIT License (MIT)

Copyright (c) 2014-2016 Cédric Foellmi (@onekiloparsec)

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

---

## StatusItemController — `StatusItemController` trait

- Upstream: https://github.com/hexedbits/StatusItemController
- Author: Jesse Squires / Hexed Bits
- License: MIT
- Location in this repo: `Sources/UIFoundationAppKit/StatusItemController/`
- Modifications:
  - Demoted the upstream public `NSEvent.isRightClickUp` and
    `NSApplication.isCurrentEventRightClickUp` properties to `internal`
    and suffixed them with `ForStatusItem`
    (`NSEvent.isRightClickUpForStatusItem`,
    `NSApplication.isCurrentEventRightClickUpForStatusItem`) so they do
    not leak into UIFoundation's top-level AppKit namespace.
  - Did not port the upstream `NSMenuItem`
    `convenience init(title:image:target:action:keyEquivalent:isEnabled:)`
    because `Sources/UIFoundationAppKit/Menu/NSMenuItem+Convenience.swift`
    already provides a richer set of convenience initializers,
    chained modifiers, and an `@MenuBuilder` DSL that supersede it.
  - Wrapped every source file in `#if StatusItemController && os(macOS) … #endif`
    so the feature is gated behind the `StatusItemController` SPM trait
    and is macOS-only.
  - Did not port the upstream Example app, placeholder
    `StatusItemControllerTests` (empty), Jazzy docs, `.podspec`,
    `.xcodeproj`, CHANGELOG, or CI scripts.

### License

```
MIT License

Copyright (c) 2020 Hexed Bits

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```
