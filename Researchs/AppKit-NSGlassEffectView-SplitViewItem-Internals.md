# AppKit NSGlassEffectView: the split view item's glass and how to replicate it

> Measured on macOS 27.0 (AppKit 2775.10.103.1, arm64e), against the RuntimeViewer dump at
> `/Volumes/DyldSharedCaches/macOS/27.0/AppKit/{ObjCHeaders,SwiftInterfaces}` and the IDA database
> `AppKit.i64` beside it. Live readings were taken with `lldb` attached to a running document
> window and lossless window captures (`screencapture -o -x -l <window>`), sampled over blank
> sidebar regions. Decision record: `Documentations/Evolutions/0022-glass-effect-replica-view.md`.

## 1. The question

A navigation stack inside a split view's sidebar slides one page over another. On macOS 15 both
pages carried an `NSVisualEffectView` and the overlap was invisible. On macOS 26 and 27 the split
view puts an `NSGlassEffectView` behind the sidebar, and nothing composited inside it matches its
colour: the settled sidebar reads rgb(40, 40, 43) at one window position, rgb(39, 39, 42) at
another, rgb(40, 40, 42) when the window is not key. Every `NSColor` preset and every
`NSVisualEffectView` material lands next to it, never on it. This note records what the glass is
made of and the one mechanism that reproduces it exactly.

## 2. What the split view builds (decompiled)

`-[_NSSplitViewItemViewWrapper wrapView]` (`0x184F71820`) decides between two backgrounds:

| Predicate | Address | Result |
|---|---|---|
| `-[NSSplitViewItem _wantsGlass]` | `0x185A824C8` | `_hasSolariumAppearance && (isSidebar \|\| isInspector)` |
| `-[NSSplitViewItem _wantsMaterialBackground]` | `0x184F7235C` | `isSidebar \|\| (isInspector && _hasSolariumAppearance)` |

With glass wanted, `wrapView` builds:

```objc
NSGlassEffectView *glass = [[NSGlassEffectView alloc] initWithFrame:self.bounds];
[glass setCornerRadius:0.0];
[glass setEffectIsInteractive:NO];
[glass set_adaptiveAppearance:1];
[glass set_variant:[self _glassVariant]];        // 0x185A836E8: sidebar 17, inspector 18, else 0
NSView *clip = [NSView new]; clip.clipsToBounds = YES; [clip addSubview:itemView];
glass.contentView = clip;
```

The material branch (`-[_NSSplitViewItemViewWrapper _updateEffectViewState]`, `0x184F9F328`) is
the pre-Solarium path: an `NSVisualEffectView` with material 7 (sidebar) or 23 (overlay), blending
`withinWindow` when overlaid. It is not taken on macOS 26/27 with the default appearance.

The 26.4 – 26.6 header dumps carry the same `_glassView` / `_glassVariant` members on the wrapper
and the same `_variant` property on `NSGlassEffectView`; the variant numbers were not re-read on
26, which is why the replica copies them off the live view instead of hardcoding 17.

## 3. What the glass is made of (live layer tree)

`NSGlassEffectView` has two subviews, in this order:

1. `ContentHolderView` — holds `contentView`, i.e. the item's view.
2. `_NSCoreHostingView<NSGlassEffectView.RootView>` — a SwiftUI hosting view that renders the glass,
   **above** the content.

The content is visible because the hosting view contains an `NSGlassEffectView.PortalLayer`
(a `CAPortalLayer`) whose `sourceLayer` is the content holder's layer, with
`hidesSourceLayer = 1` and `matchesPosition = 1`: the content is hidden where it sits and drawn
again through the portal inside the glass pipeline. Under the hosting view:

```
SwiftUI.SDFLayer
├── CALayer                                  white fill, filters = [vibrantColorMatrix]
├── CALayer (masksToBounds)
│   └── NSGlassEffectView.PortalLayer        source = content holder, hidesSourceLayer
└── CALayer
    ├── CABackdropLayer "@0"                 filters = [glassBackground], groupName = "SwiftUI:461.00.0",
    │   └── CASDFLayer → CASDFElementLayer   scale 0.25, windowServerAware = 1
    ├── CAChameleonLayer "@1"                opacity 0.1, compositingFilter = colorBlendMode
    ├── SDFPortalLayer "@2"                  source = the fill + content container
    └── CASDFLayer "@3"                      opacity 0, filters = [vibrantColorMatrix]
```

So the sidebar's colour is the window server's `glassBackground` filter over a capture of what is
behind the window, tinted by a `CAChameleonLayer` that samples the desktop. The window underneath
contributes its own `kCUIVariantContentBackgroundMaterial` (`fill` rgb(30, 30, 30) plus another
chameleon at 0.1), which is what the content pane shows and why it reads rgb(36, 36, 38).

Live readings of the sidebar glass: `_variant 17`, `_subvariant nil`, `style 0`, `tintColor nil`,
`_adaptiveAppearance 1`, `_backdropGroupName nil`, `_groupIdentifier nil`, `_subduedState 0`,
`_scrimState 0`, `_contentLensing 0`.

## 4. Experiments

All inside the sidebar page of a live window, comparing an untouched region (top) against the
region covered by the probe (bottom). Values are exact reads of lossless captures.

| # | Probe | Top (real sidebar) | Bottom (probe) |
|---|---|---|---|
| 1 | Nested `NSGlassEffectView`, variant 17, adaptive appearance 1, corner radius 0 | 40, 40, 43 | **41, 41, 45** |
| 2 | Same, `_backdropGroupName` set to the outer group's name | 40, 40, 43 | 41, 41, 45 |
| 3 | Same, nested `CABackdropLayer.groupName` set to the outer's (`SwiftUI:461.00.0`) | 40, 40, 42 | **40, 40, 42** |
| 4 | As 3, window not key | 40, 40, 42 | 40, 40, 42 |
| 5 | As 3, window moved elsewhere on the desktop | 39, 39, 41 | 39, 39, 41 |
| 6 | As 3, window resized | 39, 39, 41 | 39, 39, 41 |
| 7 | As 3, nested glass itself resized twice | 40, 40, 43 | 40, 40, 43 |
| 8 | As 3 in the shipped replica, then the window made key by activating the app | 39, 39, 41 | **41, 41, 43** |

Notes:

- **1** is glass on glass: the nested backdrop captures the outer glass's output and the chameleon
  tints it a second time — the shift is a colourize toward the desktop tint, not a brightness step.
- **2** shows `_backdropGroupName` is stored (reads back) but does not name the layer's group;
  `_groupIdentifier` behaves the same, and a SwiftUI update (the view being resized) does not apply
  either. The setters (`0x185DDE958`, `0x185DDE7D0`) store into ivars through a shared helper and
  nothing else.
- **3** is the mechanism: layers in one backdrop group share one capture of what lies behind the
  group, so both glasses filter the same input. The result is opaque — a solid red view placed
  under the nested glass stays fully hidden (bottom still reads 40, 40, 42; hiding the glass shows
  rgb(255, 2, 0)).
- **4 – 7** show the sharing survives key-state changes, moves, window resizes and the nested
  glass's own resizes; SwiftUI kept the patched group name through all of them in that probe.
- **8** contradicts that for the shipped replica: read back after the app was activated, the
  replica's backdrop layer — the same `CABackdropLayer` instance — carried `SwiftUI:773.00.0`
  again, the name SwiftUI had generated for it, and the inspector's replica went from the shared
  `SwiftUI:505.00.0` back to its own `SwiftUI:631.00.0`. Resigning key did not do it; becoming key
  did, every time. The system glass's own layers kept their names. So SwiftUI writes its
  `groupName` back on at least that update, and a name set once is not enough: the replica changes
  the layer's class to one that answers every write with the pinned name (`object_setClass`, the
  mechanism KVO uses), and re-checks on key-state notifications in case the layer is replaced.
  Why probe 4 did not show it is not established; the probe glass was configured before it was
  ever added to a superview, the replica's is configured on `viewDidMoveToWindow`.

### Timing

A freshly added `NSGlassEffectView` has **no** layers under its backing layer after `addSubview`,
after `layoutSubtreeIfNeeded()`, after the window's `displayIfNeeded()` and after
`CATransaction.flush()`, while the process is stopped. They exist once the run loop has turned.
A replica therefore cannot be installed at the instant it is needed; it has to live in the page
and join the group after its first commit.

## 5. Private surface used

Declared in `Sources/UIFoundationAppleInternalObjC/include/NSGlassEffectView_Private.h` and
`CABackdropLayer.h`:

| Symbol | Role |
|---|---|
| `-[NSGlassEffectView _variant]` / `set_variant:` | material recipe (17 sidebar, 18 inspector) |
| `-[NSGlassEffectView _subvariant]` | refinement, `nil` here |
| `-[NSGlassEffectView _adaptiveAppearance]` | key-state adaptation, 1 here |
| `CABackdropLayer.groupName` | the backdrop group |
| `object_setClass` on SwiftUI's `CABackdropLayer` | pins the group name against SwiftUI's rewrites (`GroupPinnedBackdropLayer`) |

`CAPortalLayer` and `CAChameleonLayer` were inspected (`sourceLayer`, `hidesSourceLayer`,
`matchesPosition`, `matchesTransform`, `allowsBackdropGroups`; chameleon has no properties beyond
`CALayer`'s) but are not used by the replica.
