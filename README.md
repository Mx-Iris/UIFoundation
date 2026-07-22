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

### Tabs Control

Enable the `TabsControl` trait for a multi-tab control with `Default`, `Chrome`, `Safari` and `System` styles:

```swift
.package(
    url: "https://github.com/Mx-Iris/UIFoundation",
    from: "0.13.0",
    traits: ["TabsControl"]
)
```

```swift
let tabsControl = TabsControl()
tabsControl.dataSource = self
tabsControl.delegate = self
tabsControl.style = TabsControl.SystemStyle()
tabsControl.reloadTabs()
```

`SystemStyle` replicates the macOS 26 window tab bar: a Liquid-Glass pill per tab, hairline separators, and overflow that folds into compressed piles at both ends rather than shrinking past 120 pt. Its geometry and animation are matched against a live `NSTabBar`.

See [`Documentations/TabsControl.md`](Documentations/TabsControl.md) for the full guide — the data source and delegate, how items are matched across a reload, which side owns the selection, and the stacking and scrolling models.

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
