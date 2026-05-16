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
