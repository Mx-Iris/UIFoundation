---
name: uifoundation-widgets
description: Building or migrating AppKit UI on Mx-Iris/UIFoundation — what the library already provides before hand-rolling a widget, a stack, a toolbar, a menu, a media time slider or a cell-reuse dance (scrollable view factories, .box makeView, VStackView / HStackView, NSToolbar and NSMenu result builders, PlaybackSlider), and the traps in Label, ScrollView and the builders. Use before writing AppKit view code in a project that depends on UIFoundation, and when replacing system classes with UIFoundation ones.
---

# Building AppKit UI on UIFoundation

## The rule that matters most

**Before writing any AppKit view code, search UIFoundation for something that already
does it.** Not just "is there a `Button` subclass" — look for the *composed* helpers:
factories that build a scroll view and its document view together, a reuse helper that
replaces the `makeView(withIdentifier:) as? … ?? { … }()` dance, result builders for
toolbars and menus.

This is the step that gets skipped. A mechanical class-for-class swap
(`NSButton` → `Button`) looks like the job is done while the library was offering a
one-liner for the whole block. Search first, then write.

### Where to look

Read the package source rather than guessing. SwiftPM checks it out at
`.build/checkouts/UIFoundation` for `swift build` and at
`<DerivedData>/SourcePackages/checkouts/UIFoundation` for Xcode; the same tree is on GitHub.

| Looking for | Directory |
|---|---|
| Widget subclasses (`Button`, `Label`, `TextField`, `ScrollView`, `TableView`, `OutlineView`, `Divider`, …) and the view bases `LayerBackedView` / `XiblessView` | `Sources/UIFoundationAppKit/Base/`, `…/Text/` |
| Declarative stacks, `Spacer`, `MaxSpacer` | `Sources/UIFoundationShared/View/StackView/` |
| Toolbar builder and items | `Sources/UIFoundationAppKit/Toolbar/` |
| Menu builder | `Sources/UIFoundationAppKit/Menu/` |
| `.box` helpers on system types | `Sources/UIFoundationToolbox/AppKit/` |
| Controllers: the `Xibless*` bases and `LayerBackedViewController` | `Sources/UIFoundationAppKit/Controller/` (`XiblessViewController` itself is in `Sources/UIFoundationShared/Controller/`) |
| A media time slider — Music's full-screen player bar: no knob, grows when pressed, `scrubbingDelegate` for press and release — instead of a hand-drawn progress bar or an `NSSlider` subclass | `Sources/UIFoundationAppKit/PlaybackSlider/` (`PlaybackSlider`; its plus-lighter colours need the `AppleInternal` trait, and a seek belongs on release, not on every action) |

Four greps that surface the composed helpers a class listing hides:

```bash
CHECKOUT=<checkout>/Sources   # e.g. .build/checkouts/UIFoundation/Sources
# factories returning several wired-up views at once
grep -rn "public class func\|public static func" "$CHECKOUT" | grep -iE "scrollable|make"
# everything hanging off the .box namespace for a given system class
grep -rn "extension FrameworkToolbox where Base: NSTableView" -A40 "$CHECKOUT"
# result builders
grep -rn "@resultBuilder" "$CHECKOUT"
# per-component modifiers usable inside a stack builder
grep -rn "public func" "$CHECKOUT/UIFoundationShared/View/StackView/StackViewNamespace.swift"
```

## Reach for these, not the hand-rolled version

```swift
// A scroll view + its document view, wired and single-column, in one line.
private let (scrollView, outlineView): (NSScrollView, OutlineView) =
    OutlineView.scrollableSingleColumnOutlineView()
// Also: scrollableOutlineView(), scrollableTableView(), scrollableSingleColumnTableView(),
//       scrollableCollectionView(), scrollableGridView(), scrollableDocumentView()
// Every one sets documentView and hasVerticalScroller; the single-column ones also set
// headerView = nil and add the column. AppKit makes the first column added the outline
// column, so do not set outlineTableColumn again.

// Cell reuse — replaces makeView(withIdentifier:owner:) as? T ?? { … }()
let cellView = tableView.box.makeView(ofClass: EntityTableCellView.self)
// Default identifier is String(describing: cls), so a `static let reuseIdentifier`
// holding the class name becomes dead code — delete it.

// Stacks. `.fill()` replaces hand-written "width equals the stack" constraints.
VStackView(alignment: .leading, spacing: 8) {
    Spacer(spacing: 20)
    header.stackView.fill()
    titleLabel                       // keeps its content width
    MaxSpacer()                      // absorbs the slack
}
// Contents that change with data: setViews(_:in:) replaces clear-then-refill.
stackView.setViews(rows.map(makeRow), in: .leading)

// Toolbar and menu are result builders.
NSToolbar("Main", allowsUserCustomization: false) {
    NSToolbar.Button(id, image: image).label("Refresh").toolTip("Reindex")
        .target(nil, action: #selector(MainWindowController.refresh(_:)))   // nil target: responder chain
    NSToolbar.View(id, view: someView).label("Progress")
    NSToolbar.box.flexibleSpace
    NSToolbar.SegmentedControl(id, segmentedControl: existingControl)
    NSToolbar.Search(id, searchField: existingField)
}
NSMenu {
    NSMenuItem("Open", action: #selector(open)).target(self)
    NSMenuItem.separator()
}
```

## Traps, each one paid for

**`Label` is not `NSTextField(labelWithString:)`.** Its `setup()` only clears editable /
bordered / background. Three properties stay at `NSTextField`'s defaults and differ from
the system factory: the cell **wraps**, `lineBreakMode` is `.byWordWrapping` (the factory
clips), and horizontal hugging is 250 (the factory uses 251). Leave them and list titles
wrap onto a second line instead of staying on one. `isSelectable` and `isBezeled` are
already correct — `isEditable = false` propagates to the first, `isBordered = false`
shares cell state with the second. Do not reason from a bare `NSTextField()`, whose
defaults for those two are the opposite. `Label` also copies its string into `toolTip` on
every `stringValue` / `attributedStringValue` assignment; set `syncStringValueToolTip` to
`false` where a tooltip is unwanted.

Fix once, in a project-level subclass overriding `setup()`, and pin it with a test that
compares every property against the system factory. Do the same for
`wrappingLabelWithString:` (only `isSelectable` needs putting back).

**`ScrollView.drawsBackground` always reads `false`, and assigning it does nothing.** Any
scroll view that must paint — a list background, anything with
`borderType = .bezelBorder` — has to stay an `NSScrollView`, or it renders as a hollow
well.

**`VStackView` / `HStackView` are `final`.** A stack-shaped widget composes one instead
of subclassing it: an outer `NSView` holding the stack, pinned edge to edge. Costs one
view in the hierarchy, keeps the assembly declarative.

**`@ArrayBuilder` lives in `SwiftStdlibToolbox`** (the `FrameworkToolbox` package).
UIFoundation depends on it but re-exports only `FrameworkToolbox`, so a module writing a
stack builder must depend on and import `SwiftStdlibToolbox` itself — otherwise
`buildPartialBlock is not available due to missing import`.

**Some helpers are `internal`.** `Then.then { }` is not usable from another module; use a
local variable.

**Toolbar items chain their action.** Every item that carries one — `Item`, `Button`,
`View`, `Menu`, `Group`, `PopUpButton`, `SegmentedControl` — has `.target(_:action:)`,
`.target(_:)` and `.action(_:)`, so an item routed through the responder chain stays
inside the builder with a `nil` target. Before UIFoundation 0.32.0 only `Item` had them,
which is why older code pulls such items out into locals.

**Standard toolbar items sit on `.box`:** `NSToolbar.box.flexibleSpace`, not
`ToolbarItem.flexibleSpace`. And `NSToolbar.View` takes its view in `init(_:view:)`.

**A toolbar item's view must be configured before `window.toolbar = …`.** That
assignment calls the delegate and measures each view on the spot; a view configured
afterwards is measured in whatever state it was in. A spinning `NSProgressIndicator`
reports no intrinsic width at all, so it also needs an explicit size constraint. The
builder form is immune to the ordering — it hands over items already built.

**Thin subclasses inherit the ObjC factory initialisers.** `Button` overrides both of
`NSButton`'s designated inits, so `Button(checkboxWithTitle:target:action:)` compiles.
Try it before writing a wrapper.

## Migration order

1. Project-level subclasses that close a semantic gap (labels first), each with an
   equivalence test against the system factory.
2. Reusable widget module.
3. Shell view controllers, including toolbars and menus.
4. A check script so the next new screen cannot regress: scan the AppKit sources for
   constructions of system classes that have counterparts, fail non-zero on a hit, and
   allow an inline `// <marker>-exempt: <reason>` escape. Match **constructions**
   (`NSFoo(`) only, never type annotations, or every delegate signature trips it.
   **Verify the script can go red** by injecting one violation and watching it fail —
   a checker that only ever passes is worse than none.

Keep a documented exemption list rather than widening the matcher; each exemption should
name the reason (the `ScrollView` background trap accounts for most of them).

## Do not swap these

- `NSTextView` — no counterpart.
- `NSProgressIndicator` — UIFoundation's `Indicator` is a different animation
  (`IndicatorType.ballbeat`, `.lineScale`, …). Swapping changes the look.
  `ProgressIndicator` is only `NSProgressIndicator` with `allowsVibrancy` on, made for
  the filter field.
- `NSView` as a base class or plain container. `LayerBackedView` / `XiblessView` are
  worth choosing deliberately, but they render through `updateLayer()`: a view that draws
  in `draw(_:)` stops drawing unless it overrides `isLayerBackingEnabled` to return
  `false`.
- `NSTableColumn`, `NSMenuItem.separator()` and other stateless factories.

## With the `AppKitPlus` trait

With UIFoundation's `AppKitPlus` trait on, `LayerBackedView` and
`LayerBackedViewController` build on AppKitPlus's layer-backed base classes. For
AppKitPlus API that UIFoundation does not wrap, see the `appkit-app-modernization` skill
of the `appkitplus` plugin.
