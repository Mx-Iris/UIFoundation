# UIFoundation

> **This framework is currently under development, and the stability of any API is not guaranteed.**

A Swift package providing foundational UI components and utilities on top of AppKit/UIKit. Primarily targets macOS (AppKit) with cross-platform support for iOS, tvOS, visionOS, and Mac Catalyst.

## Requirements

- Swift 6.2+ (language mode: Swift 5)
- macOS 10.15+ / iOS 13+ / Mac Catalyst 13+ / tvOS 13+ / visionOS 1+

## Installation

### Swift Package Manager

```swift
dependencies: [
    .package(url: "https://github.com/Mx-Iris/UIFoundation", from: "0.1.0")
]
```

### Products

| Product | Description |
|---------|-------------|
| **UIFoundation** | Umbrella library re-exporting all public sub-modules |
| **UIFoundationToolbox** | Standalone extensions and utilities (usable independently) |
| **UIFoundationAppleInternal** | Private API wrappers (**App Store rejection risk**) |
| **UIFoundationRunningApplication** | Running applications and BSD processes — models, observers, picker UI (macOS 11+, not in the umbrella) |

## Usage

### Xibless Base Classes

All views and controllers are created purely in code — no Xib or Storyboard required. Override `setup()` for initialization:

```swift
class MyView: XiblessView {
    let titleLabel = NSTextField(labelWithString: "")

    override func setup() {
        addSubview(titleLabel)
    }
}
```

Typed view controllers with generic `contentView`:

```swift
class MyViewController: XiblessViewController<MyView> {
    override func viewDidLoad() {
        super.viewDidLoad()
        contentView.titleLabel.stringValue = "Hello"
    }
}
```

`LayerBackedView` provides built-in support for corner radius, border, shadow, and background color — all with automatic redraw on property change:

```swift
class CardView: LayerBackedView {
    override func setup() {
        cornerRadius = 12
        backgroundColor = .white
        shadowRadius = 4
        shadowOpacity = 0.15
        borderWidth = 1
        borderColor = .separatorColor
    }
}
```

### `.box` Namespace Extensions

All extensions on framework types use the `.box` namespace (via [FrameworkToolbox](https://github.com/Mx-Iris/FrameworkToolbox)) to avoid naming collisions:

```swift
let cell = tableView.box.makeView(ofClass: MyCell.self)
tableView.box.scrollRowToVisible(row, animated: true, scrollPosition: .centeredVertically)

if tableView.box.hasValidClickedRow { /* ... */ }

let labels = view.box.subviews(type: NSTextField.self, depth: .max)
view.box.sendToFront()
```

### Closure-Based Target-Action

Convert target-action to closures on `NSControl`, `NSMenuItem`, `NSGestureRecognizer`, `NSToolbarItem`, `NSColorPanel`:

```swift
button.box.actionBlock = { sender in
    print("Clicked: \(sender)")
}

let click = NSClickGestureRecognizer { recognizer in
    print("Clicked at \(recognizer.location)")
}

menuItem.box.action { item in
    print("Selected: \(item.title)")
}
```

### `@ViewInvalidating` Property Wrapper

Auto-triggers view invalidation when property values change:

```swift
class BadgeView: LayerBackedView {
    @ViewInvalidating(.display)
    var badgeColor: NSColor = .systemRed

    @ViewInvalidating(.display, .layout)
    var badgeSize: CGFloat = 8
}
```

### Declarative View Hierarchy

Build view hierarchies declaratively with `@ViewHierarchyBuilder`:

```swift
view.hierarchy {
    ViewItem(headerView) {
        titleLabel
        subtitleLabel
    }
    ViewItem(contentView) {
        ControllerItem(childViewController)
    }
}
```

### SwiftUI-Style Stack Views

`HStackView` and `VStackView` with result builder syntax, `Spacer()`, and layout modifiers:

```swift
let toolbar = HStackView(spacing: 8) {
    iconView.size(width: 24, height: 24)
    titleLabel
    MaxSpacer()
    closeButton.size(30)
}

let sidebar = VStackView(spacing: 12) {
    headerView
    Spacer(spacing: 4)
    listView
}
```

### Constraint DSL

Create and activate constraints with typed access to the view's anchors:

```swift
label.makeConstraints { make in
    make.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16)
    make.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16)
    make.centerYAnchor.constraint(equalTo: view.centerYAnchor)
}
```

### Quick Action Bar

Enable the `QuickActionBar` trait to present a Spotlight-style search panel:

```swift
.package(
    url: "https://github.com/Mx-Iris/UIFoundation",
    from: "0.13.0",
    traits: ["QuickActionBar"]
)
```

```swift
let actionBar = QuickActionBar()
actionBar.contentSource = self
actionBar.present(placeholderText: "Search")

actionBar.cancel()

if actionBar.resumePresentation() {
    // An in-progress dismissal was reversed without recreating the panel.
}
```

`resumePresentation()` returns `true` only while the existing panel is dismissing. Its fade and transform animations continue from their current presentation values, allowing repeated shortcut presses to reverse the transition smoothly.

### Tab Bar

Enable the `TabBar` trait for a multi-tab control styled after the macOS 26 window tab bar:

```swift
.package(
    url: "https://github.com/Mx-Iris/UIFoundation",
    from: "0.13.0",
    traits: ["TabBar"]
)
```

```swift
let tabBar = TabBar()
tabBar.dataSource = self
tabBar.delegate = self
tabBar.reloadTabs()
```

`SystemStyle` — the default — replicates the macOS 26 window tab bar: a Liquid-Glass pill per tab, hairline separators, and overflow that folds into compressed piles at both ends rather than shrinking past 120 pt. Its geometry and animation are matched against a live `NSTabBar`.

See [`Documentations/TabBar.md`](Documentations/TabBar.md) for the full guide — the data source and delegate, how items are matched across a reload, which side owns the selection, and the stacking and scrolling models.

### System HUD

Enable the `SystemHUD` trait for the volume-HUD-shaped floating panel — a vibrancy backdrop with an optional glyph above a single line of text:

```swift
.package(
    url: "https://github.com/Mx-Iris/UIFoundation",
    from: "0.13.0",
    traits: ["SystemHUD"]
)
```

```swift
SystemHUD.default.configuration.image = NSImage(named: "Build")
SystemHUD.default.configuration.title = "Build Succeeded"
SystemHUD.default.show(delay: 1.0)
```

The panel sizes itself to its content — never below `minimumSize`, never wider than the screen, truncating an over-long title instead — and re-centres on the active screen every time it is shown. It ignores mouse events and shows over full-screen windows, so it is safe to raise from anywhere. Showing again during the fade-out stops that fade and restores full opacity.

See [`Documentations/SystemHUD.md`](Documentations/SystemHUD.md) for the full guide.

### Navigation

Enable the `Navigation` trait for a `UINavigationController`-shaped container: a view controller stack, a push / pop parallax transition, and a two-finger swipe back.

```swift
.package(
    url: "https://github.com/Mx-Iris/UIFoundation",
    from: "0.13.0",
    traits: ["Navigation"]
)
```

```swift
let navigationController = NavigationController(rootViewController: LibraryViewController())
window.contentViewController = navigationController

navigationController.pushViewController(AlbumViewController(album: album), animated: true)
navigationController.popToRootViewController(animated: true)
```

AppKit ships no navigation container, so the container itself is ported from the one the macOS App Store built for itself rather than from UIKit — the App Store's version is a real stack, is AppKit-native throughout (`NSAnimationContext`, `NSView.frame`, `NSEvent` swipe tracking), and uses no private API.

Two looks ship, both measured from the originals. `.uiKit` — the default — reproduces `UINavigationController`'s push: 0.35 s ease-in-ease-out, the outgoing page counter-sliding 30 % of the width under a 10 % black dim, with a 9 pt shadow trailing the arriving page's edge. `.appStore` reproduces the App Store's, which is flatter on purpose: `cubic-bezier(0.1878, 0.0023, 0.5399, 0.9629)`, 25.27 % counter-slide, 22 % dim, no shadow.

```swift
navigationController.configuration = .appStore          // or adjust one knob at a time
navigationController.configuration.parallaxFactor = 0.4
```

`transitionDelegate` replaces the animation outright.

There is no navigation bar: titles and back buttons stay the host's, driven off `NavigationControllerDelegate`. Pages are positioned by frame inside the container, so lay a page out with constraints internally and never pin it to anything outside.

See [`Documentations/Navigation.md`](Documentations/Navigation.md) for the full guide — the contracts a host has to keep, the configuration surface, and how to write a custom transition.

### Welcome Panel

Enable the `WelcomePanel` trait for the Xcode-style welcome window — app icon, name and version above a short action list on the left, a recent-project list on the right. macOS 11+:

```swift
.package(
    url: "https://github.com/Mx-Iris/UIFoundation",
    from: "0.13.0",
    traits: ["WelcomePanel"]
)
```

```swift
var configuration = WelcomePanelController.Configuration(style: .xcode15)
configuration.primaryAction = .init(
    image: NSImage(systemSymbolName: "plus.square", accessibilityDescription: nil),
    title: "Create New File…",
    action: { _ in NSDocumentController.shared.newDocument(nil) }
)

let panel = WelcomePanelController(configuration: configuration)
panel.dataSource = self
panel.delegate = self
panel.showWindow(nil)
```

Three styles imitate three Xcode generations: `.xcode14` is a titled window with a "show this window on launch" checkbox and two-line action rows; `.xcode15` is borderless and rounded over a vibrancy backdrop with title-only pills; `.xcode26` is a measured replica of Xcode 26's own welcome window — a 20 pt radius, `.fullScreenUI` material behind both panes, a 36 pt bold title, capsule action rows, and the blue icon glow Xcode draws in dark mode.

The project list is pulled, not pushed — the data source is re-asked when it is assigned, on every `showWindow(_:)`, and whenever the window becomes visible again. Return `true` from `welcomePanelUsesRecentDocumentURLs(_:)` to take the list straight from `NSDocumentController` instead of supplying one.

See [`Documentations/WelcomePanel.md`](Documentations/WelcomePanel.md) for the full guide — the seven host contracts and the style table — and [`Researchs/Xcode26-WelcomeWindow-Internals.md`](Researchs/Xcode26-WelcomeWindow-Internals.md) for how the Xcode 26 style was measured.

### Running Application Picker

Enable the `RunningApplication` trait for the running-application / BSD-process picker, plus the value-type models and observers behind it. macOS 11+:

```swift
.package(
    url: "https://github.com/Mx-Iris/UIFoundation",
    from: "0.13.0",
    traits: ["RunningApplication"]
)
```

This one is **not part of the `UIFoundation` umbrella** — its macOS 11 floor is higher than the package's 10.15, and joining the umbrella would raise that floor for everyone. Depend on the product and import it directly:

```swift
.product(name: "UIFoundationRunningApplication", package: "UIFoundation")
```

```swift
import UIFoundationRunningApplication

let picker = RunningPickerTabViewController(
    processConfiguration: .init(style: .list, allowsFields: [.icon, .name, .pid, .executablePath])
)
picker.delegate = self
NSWindow(contentViewController: picker).makeKeyAndOrderFront(nil)
```

Each tab renders as a multi-column `.table` or a `.list` of rows carrying a name, inline badges and a subtitle; the style can be switched at runtime and selection, search text and sort survive it. The two styles treat an unremarkable value oppositely on purpose — a list omits it, a table prints it in a receded colour, because a column of blanks reads as broken.

Models come with architecture, platform and sandbox detection. `Platform` is read from the executable's Mach-O `LC_BUILD_VERSION`, which is what identifies simulator processes — architecture cannot, since a process inside an iOS Simulator on Apple silicon runs as native `arm64`, exactly like its host counterparts.

```swift
let simulated = RunningProcessEnumerator.listProcesses()
    .filter { $0.platform?.isSimulator == true }
```

See [`Documentations/RunningApplication.md`](Documentations/RunningApplication.md) for the full guide — the four host contracts (most importantly that a `nil` platform means "unknown", not "not a simulator") and the known limitations.

### Cross-Platform Typealias

`UIFoundationTypealias` provides `NSUI`-prefixed aliases (`NSUIView`, `NSUIColor`, `NSUIFont`, etc.) enabling cross-platform code without `#if canImport` branching:

```swift
class MyView: NSUIView {
    var textColor: NSUIColor = .labelColor
    var font: NSUIFont = .systemFont(ofSize: 14)
}
```

## Dependencies

- [FrameworkToolbox](https://github.com/Mx-Iris/FrameworkToolbox) — Provides the `.box` namespace pattern
- [AssociatedObject](https://github.com/p-x9/AssociatedObject) — `@AssociatedObject` macro for runtime-associated properties

## License

UIFoundation is available under the MIT license. See the [LICENSE](LICENSE) file for more information.
