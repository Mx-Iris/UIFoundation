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

## KPCTabsControl — `TabsControl` trait

- Upstream: https://github.com/onekiloparsec/KPCTabsControl
- Authors: Cédric Foellmi, Christian Tietze
- License: MIT
- Location in this repo: `Sources/UIFoundationAppKit/TabsControl/`
- Modifications:
  - The public API was nested under the `TabsControl` namespace to avoid
    polluting the umbrella module's top-level namespace
    (`Style` → `TabsControl.Style`, `Theme` → `TabsControl.Theme`,
    `DefaultStyle` → `TabsControl.DefaultStyle`, `TabsControlDataSource` →
    `TabsControl.DataSource`, `TabsControlDelegate` → `TabsControl.Delegate`,
    etc.). `TabsControl` and `TabButton` remain top-level types.
  - The `KPC` prefix was dropped from the bundled PDF template resources
    (`KPCPullDownTemplate.pdf` → `PullDownTemplate.pdf`, …) and resource
    lookups now use `Bundle.module` exclusively (the `#if SwiftPackage`
    CocoaPods branch was removed).
  - `macOS 10.13`/`10.14` availability fallbacks were dropped since the package
    targets macOS 10.15+; the now-unused `NSColor.darkerColor()` helper and the
    unused `Error.swift` were removed.
  - Wrapped every source file in `#if TabsControl && os(macOS) … #endif` so the
    feature is gated behind the `TabsControl` SPM trait.

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
