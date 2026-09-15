# macOS Spotlight Panel Internals

> Based on reverse engineering the macOS **Spotlight.app 26.6.2** binary (arm64e) via IDA Pro
> decompilation, cross-checked against the Objective-C headers and Swift interfaces exported by
> RuntimeViewer under `/Volumes/RE/Spotlight/26.6.2/`.
> Covers the panel window (`SPSpotlightPanel`), its placement arithmetic, the invocation and
> dismissal animations (`WindowAnimationCoordinator`), the content-driven sizing contract
> (`SPSizingDelegate` / `ResultPlatterBehavior`), and the measured constants in `SearchConstants`.
> Every address below is a file offset in `Spotlight.app/Contents/MacOS/Spotlight`, which loads at
> `0x100000000`.
>
> Consumed by `SpotlightPanel` — see
> [`Documentations/Evolutions/0021-spotlight-panel-replica.md`](../Documentations/Evolutions/0021-spotlight-panel-replica.md)
> and the guide at [`Documentations/SpotlightPanel.md`](../Documentations/SpotlightPanel.md).

---

## Table of Contents

- [1. Where the app is split](#1-where-the-app-is-split)
- [2. The panel window](#2-the-panel-window)
- [3. Placement](#3-placement)
- [4. Re-placement when the screen changes](#4-re-placement-when-the-screen-changes)
- [5. The invocation and dismissal animations](#5-the-invocation-and-dismissal-animations)
- [6. The sizing contract](#6-the-sizing-contract)
- [7. Measured constants](#7-measured-constants)
- [8. The keyboard table](#8-the-keyboard-table)
- [9. What was not recovered](#9-what-was-not-recovered)

---

## 1. Where the app is split

Spotlight is a mixed binary. The window and panel plumbing is Objective-C, prefixed `SP`; the
controllers, views and animation are Swift, in a module called `SpotlightAppMacOS`; the search
itself lives across `SpotlightUIShared.framework`, `SearchUI.framework` and `CoreParsec`.

| Class | Language | Role |
|---|---|---|
| `SPSpotlightPanel` | ObjC | The `NSPanel` subclass: geometry, placement, position memory, dragging |
| `SPAppDelegate` / `SPApplication` | ObjC | Process lifecycle, hotkey registration |
| `SPSpotlightKeyCommandManager` | ObjC | Takes over ⌘Space and friends through CoreGraphics SPI |
| `MainWindowController` | Swift | Owns the panel, the search controller and the animation coordinator |
| `WindowAnimationCoordinator` | Swift | The present / dismiss animations |
| `SearchViewController` | Swift | The keyboard table, query lifecycle, navigation stack root |
| `SearchNavigationController` | Swift | `NSPageController`-backed push / pop with a live transition |
| `SearchConstants` | Swift | Every geometry constant, exposed to ObjC as class properties |
| `SearchResultsViewController` | Swift | Subclass of `SearchUIResultsViewController` (private framework) |

The Swift classes are visible to Objective-C under their mangled names, e.g.
`_TtC17SpotlightAppMacOS20MainWindowController`, which is what makes their method addresses
readable from the RuntimeViewer dump — the binary is stripped, so `swift-section` recovers types
but no member addresses (`Extracted 0 symbol index`).

---

## 2. The panel window

`-[SPSpotlightPanel configureAppearanceAndBehavior]` — `0x1000117E8`:

```objc
- (void)configureAppearanceAndBehavior {
    [self setBecomesKeyOnlyIfNeeded:YES];
    [self setReleasedWhenClosed:NO];
    [self setLevel:23];
    [self setOpaque:NO];
    [self setBackgroundColor:[NSColor clearColor]];
    [self setHidesOnDeactivate:NO];
    [self setMovable:NO];
    [self setAutorecalculatesKeyViewLoop:YES];
    [self setWindowPadding:[SearchConstants windowPadding]];

    CGSSetConnectionProperty(CGSMainConnectionID(), CGSMainConnectionID(),
                             CFSTR("SetsCursorInBackground"), kCFBooleanTrue);
}
```

Two things worth noting:

- **`hidesOnDeactivate` is off.** Spotlight never closes because focus moved; it closes because
  something asked it to. It can afford that because ⌘Space brings it back.
- **`SetsCursorInBackground`** is a window-server connection property, not a window property. It
  lets the process set the cursor while it is not frontmost — needed for an I-beam over a panel
  that takes key focus without activating its application.

`windowPadding` here is `NSDirectionalEdgeInsetsZero` (`+[SearchConstants windowPadding]`,
`0x1000A9458`, which just loads `_NSDirectionalEdgeInsetsZero`). The *animation* padding is a
separate constant — see §7.

---

## 3. Placement

`-[SPSpotlightPanel defaultPositionOriginForWindowSize:screen:]` — `0x1000129D4`. The decompiled
body, with the four `frame` calls folded together:

```objc
CGPoint result;
CGFloat standardHeight = [SearchConstants standardAppBrowseHeight];
CGRect screenFrame = [screen frame];

result.x = screenFrame.origin.x + (screenFrame.size.width - windowSize.width) * 0.5;
result.y = standardHeight - windowSize.height
         + screenFrame.origin.y
         + (screenFrame.size.height - standardHeight) * 0.5;
```

Rearranged, with `H = standardAppBrowseHeight` and `h = windowSize.height`:

```
y = screen.minY + (screen.height + H) / 2 − h
```

which means the **top edge** sits at `screen.minY + (screen.height + H) / 2` — exactly where the
top edge of an `H`-tall window would be if that window were vertically centred — **regardless of
`h`**.

That is the non-obvious part of Spotlight's placement, and it is what makes the panel sit high
while collapsed and arrive at dead centre once expanded. A naive "centre the window" or "keep the
collapsed position and grow down" both look wrong next to it.

`-[SPSpotlightPanel defaultPositionOrigin]` (`0x100012924`) is the caller, and it passes the
**collapsed** size:

```objc
CGFloat width  = [SearchConstants standardWindowWidth] + padding.trailing + padding.leading;
CGFloat height = [SearchConstants heightCollapsed]     + padding.top      + padding.bottom;
return [self defaultPositionOriginForWindowSize:CGSizeMake(width, height) screen:[self screen]];
```

---

## 4. Re-placement when the screen changes

`-[SPSpotlightPanel recomputeFrame:forVisibleScreenArea:]` — `0x100013E24`. Used when the visible
screen area changes: a different display, a resolution change, the Dock appearing.

If the visible rect is unchanged (`NSEqualRects`) it simply reuses the stored top edge. Otherwise
it measures the four gaps between the last window position and the old visible area, and applies
**stickiness with a 100 pt threshold**:

```
leftGap   = lastWindow.minX − oldVisible.minX
rightGap  = oldVisible.maxX − lastWindow.maxX
topGap    = oldVisible.maxY − lastWindow.maxY
```

Horizontally:

| Condition | Result |
|---|---|
| `leftGap ≤ 100` and `rightGap − leftGap ≥ 1` | stick to the left: `x = newVisible.minX + leftGap` |
| `rightGap ≤ 100` and `leftGap − rightGap ≥ 1` | stick to the right: `x = newVisible.maxX − width − rightGap` |
| otherwise | proportional: `x = newVisible.minX + leftGap / (leftGap + rightGap) · (newWidth − width)` |

Vertically the same shape, with `topGap ≤ 100` sticking the top edge and everything else
interpolating against `topGap + storedHeight − heightCollapsed`.

---

## 5. The invocation and dismissal animations

### 5.1 Entry points

`-[MainWindowController invokeSpotlightWithResetPosition:reason:animated:completion:]`
(`0x1000309E0`) and `-[MainWindowController dismissSpotlightWithAnimated:completion:]`
(`0x100031084`) are thin Objective-C shims over the Swift bodies at `0x10002FDA0` and
`0x100030AAC`. Both end at the animation coordinator's vtable, reached as
`(swift_isaMask & *coordinator) + offset`:

| Offset from class metadata | Function | Role |
|---|---|---|
| `+0x398` | `0x10002066C` | present |
| `+0x3A0` | `0x100020FC0` | dismiss |

(`_OBJC_CLASS_$__TtC17SpotlightAppMacOS26WindowAnimationCoordinator` is at `0x10012FB18`; the two
pointers read out of `0x10012FEB0` and `0x10012FEB8`.)

### 5.2 Shape

Both functions have the same structure:

1. Gate on `[SUIUtilities isInvocationAnimationEnabled]` **and** the caller's `animated:` flag.
   When either is false, write the end state directly and call the completion — which is how the
   end state below is known exactly rather than inferred.
2. `dispatch_group_create()`, two `dispatch_group_enter` calls.
3. `CATransaction.begin()`, a completion block that leaves the group, a `CAAnimationGroup` added
   to the content view's layer, then `commit()`.
4. A second half animating the **window's** properties, also leaving the group.
5. `dispatch_group_notify` on the main queue runs the caller's completion.

The non-animated branch of the dismissal (`0x100020FC0`) ends:

```objc
[layer removeAllAnimations];
[window setAlphaValue:0.0];
[window _setContentBlurRadius:25.0];
```

and the presentation's (`0x10002066C`):

```objc
[layer removeAllAnimations];
[window setAlphaValue:1.0];
[window _setContentBlurRadius:0.0];
```

### 5.3 The layer animation

Present: `sub_100026FB8`. Dismiss: `sub_1000274B8`. Both build two `CASpringAnimation`s on
`transform.scale.x` and `transform.scale.y` and wrap them in a `CAAnimationGroup` whose duration
is the maximum of its children's.

The floating-point immediates, decoded:

| Encoded | Value | Use |
|---|---|---|
| `0x3FD1EB851EB851EC` | 0.28 | present `perceptualDuration` |
| `0x3FDA3D70A3D70A3D` | 0.41 | present `bounce`, x axis |
| `0x3FD47AE147AE147B` | 0.32 | present `bounce`, y axis |
| `0x3FF1EB851EB851EC` | 1.12 | dismissed `transform.scale.x` |
| `0x3FEE666666666666` | 0.95 | dismissed `transform.scale.y` |

Dismissal uses `initWithPerceptualDuration:bounce:` with **0.45 / 0.05** on both axes, read
directly out of the decompiled call.

So the scale is **not uniform**: 1.12 wide against 0.95 tall. The panel spreads sideways as it
leaves rather than swelling, and the two axes carry different `bounce` values on the way in.

### 5.4 The window animation

`sub_100027E84(window, isPresenting, completion, context)`.

- **Presenting** (`isPresenting == 1`) builds **one** spring, keyed `@"alphaValue"`, at
  `perceptualDuration: 0.28, bounce: 0.41`.
- **Dismissing** builds **two**: the same `alphaValue` spring, plus one keyed
  `@"contentBlurRadius"` at `perceptualDuration: 0.51, bounce: 0.05`.

The key string is at `0x1000F69B0` and reads `contentBlurRadius` — 17 bytes, matching the Swift
string header's count field. It works as an animation key because KVC's setter search includes
the `_set<Key>:` form, which is how `-_setContentBlurRadius:` is reached.

Probed on macOS 26, for the record: the real selectors are `-_setContentBlurRadius:` and
`-_contentBlurRadius`. The unprefixed `contentBlurRadius` / `setContentBlurRadius:` are **not**
selectors — they only resolve through KVC, in both directions.

**The starting blur is hard-coded to zero in both directions**, and this is easy to misread. The
`_setContentBlurRadius:` call sits *outside* the `if (isPresenting)` branch that picks the
starting alpha:

```objc
objc_msgSend(window, "setAlphaValue:", startingAlpha);   // 0.0 presenting, 1.0 dismissing
objc_msgSend(window, "_setContentBlurRadius:", 0.0);     // always 0.0
```

Taking it from the starting *state* instead — whose dismissed value is 25 — means presenting
writes 25 and, because presenting does not animate the blur at all, never writes anything again.
The blur then sticks for the whole life of the panel. This library shipped exactly that bug once;
`SpotlightPanelContentBlurTests` now guards it.

Both are installed into `window.animations`, the starting values are written directly, and an
`NSAnimationContext.runAnimationGroup` drives the animator proxy to the end state. The end-state
pairs are two 16-byte constants:

| Address | Contents | Meaning |
|---|---|---|
| `0x1000E3A90` | `(1.0, 0.0)` | present: alpha 1, blur 0 |
| `0x1000E3A70` | `(0.0, 25.0)` | dismiss: alpha 0, blur 25 |
| `0x1000E3A80` | `(1.12, 0.95)` | dismiss: the scale pair |

**The blur curve is nearly twice as slow as the opacity curve** (0.51 against 0.28). That gap is
the whole visual effect: the panel goes soft before it goes away. Matching the two durations
collapses it into an ordinary fade.

`WindowAnimationCoordinator.InvocationAnimationState` — a four-field struct of
`xScale` / `yScale` / `opacity` / `blurRadius` — is the type those pairs belong to.

### 5.5 Interruption

The coordinator holds `invocationAssertion: AnimationAssertion?` and
`animationAssertions: Set<AnimationAssertion>`, each a wrapper around a `UUID`. A completion whose
assertion is no longer in the set is dropped, which is what makes a dismissal reversible partway
through.

---

## 6. The sizing contract

Spotlight separates "how tall is the content" from "how tall should the window be":

```objc
@protocol SPSizingDelegate <NSObject>
- (CGFloat)windowHeightForMinimumSize:(CGSize)minimumSize
                        preferredSize:(CGSize)preferredSize
                          maximumSize:(CGSize)maximumSize
                useStoredSizeIfNeeded:(BOOL)useStoredSizeIfNeeded
                     usePreferredSize:(BOOL)usePreferredSize;
- (void)didInvalidateContentWithMinimumSize:(CGSize)minimumSize
                              preferredSize:(CGSize)preferredSize
                                maximumSize:(CGSize)maximumSize
                      useStoredSizeIfNeeded:(BOOL)useStoredSizeIfNeeded
                           usePreferredSize:(BOOL)usePreferredSize
                                   animated:(BOOL)animated;
@end

@protocol SPSizingProtocol <NSObject>
@property (readonly) CGFloat contentHeight;
@property (weak) id<SPSizingDelegate> sizingDelegate;
@end
```

`MainWindowController` is the delegate; the content controllers conform to `SPSizingProtocol`.

The policy object is `SpotlightUIShared.ResultPlatterBehavior`, whose field layout is recoverable
from `MainWindowController.currentPlatterBehavior`:

| Offset | Field |
|---|---|
| `0x00` | `minHeight: CGFloat` |
| `0x08` | `preferredHeight: CGFloat?` |
| `0x18` | `maxHeight: CGFloat` |
| `0x20` | `heightCanPersist: Bool` |
| `0x21` | `includeFilterBarHeight: Bool` |
| `0x22` | `collapseForEmptyResponse: Bool` |
| `0x23` | `animated: Bool` |
| `0x28` | `width: CGFloat` |

Alongside it, `MainWindowController` keeps **two separate debouncers** — `windowSizingDebouncer`
and `expansionDebouncer` — plus an `ExpansionState` enum with four cases
(`uninitalized` *(sic)* / `collapsed` / `expanding` / `expanded`) and an `isWindowAnimating` flag.
Two timers rather than one is deliberate: a response arriving in several passes would otherwise
resize the window once per pass.

---

## 7. Measured constants

`SearchConstants` exposes these as Objective-C class properties. Several branch on
`[SUIUtilities isSpotlightPlusEnabled]` — the macOS 26 Spotlight redesign — so both values are
listed.

| Property | Address | macOS 26 | Before |
|---|---|---|---|
| `heightCollapsed` | `0x1000A916C` | **56** | 52 |
| `minHeightExpanded` | `0x1000A9084` | **430** | 430 |
| `windowCornerRadius` | `0x1000A93B8` | **28** | 16 |
| `animationWindowPadding` | `0x1000A9480` | **40** on all four sides | same |
| `windowPadding` | `0x1000A9458` | zero | zero |
| `standardHorizontalContentInset` | `0x1000A9350` | **20** | 0 |
| `heightTopLevelFilters` | `0x1000A9094` | **160** | 160 |
| `separatorHeight` | `0x1000A90AC` | **1** | 1 |
| `tokenCornerRadius` | `0x1000A92E8` | **10** | 5 |
| `topLevelBrowseButtonSpacing` | `0x1000A94BC` | **10** | 10 |

Two derived helpers:

- `+[SearchConstants topLevelBrowseButtonSizeWithCollapsedWindowHeight:]` (`0x1000A94D4`) is a
  four-instruction function: `size = (height − 2, height − 2)`, i.e. a 54 × 54 square.
- `+[SearchConstants collapsedWindowWidthFor:buttonWidth:]` (`0x1000A956C`) returns
  `windowWidth − (buttonWidth + 10) · numberOfBrowseModes`.

`standardAppBrowseHeight` (`0x1000A91EC`) is `ResultPlatterBehavior.gridBrowse.minHeight +
heightCollapsed`.

---

## 8. The keyboard table

`SearchViewController` implements thirteen responder methods, all reachable from the RuntimeViewer
dump:

| Selector | Address |
|---|---|
| `selectAll:` | `0x1000C2774` |
| `copy:` | `0x1000C278C` |
| `paste:` | `0x1000C2B54` |
| `quickLookPreviewItems:` | `0x1000C2D94` |
| `deleteBackward:` | `0x1000C2F24` |
| `cancelOperation:` | `0x1000C301C` |
| `insertTab:` | `0x1000C3230` |
| `insertNewline:` | `0x1000C3418` |
| `moveDown:` | `0x1000C35BC` |
| `moveUp:` | `0x1000C35D4` |
| `moveRight:` | `0x1000C3830` |
| `moveLeft:` | `0x1000C3A50` |

`MainWindowController` carries its own `moveRight:` / `moveLeft:` / `insertNewline:` /
`insertTab:` / `insertBacktab:` (`0x100034984` onwards) for the collapsed browse-button row.

Separately, `-[SPSpotlightKeyCommandManager registerCommandKeys]` (`0x10000EF68`) opens a second
window-server connection with `CGSNewConnection` and calls
`CGSSetSymbolicHotKeyWithExclusion` six times (hotkeys 49–54), then listens on the connection's
mach port through a `CFMachPort` run-loop source. That is how Spotlight takes ⌘Space away from the
system — a process-wide effect, and out of scope for a UI library.

---

## 9. What was not recovered

- **`ResultPlatterBehavior.standardWindowWidth`** and **`gridBrowse.minHeight`**.
  `+[SearchConstants standardWindowWidth]` (`0x1000A91E4`) is a single `B` into
  `SpotlightUIShared`, which is not in the Spotlight binary. The prebuilt shared-cache database on
  `/Volumes/DyldSharedCaches/macOS/26.6.2/` does not carry that image, and building one was not
  worth two constants that a host should be choosing anyway.
- **The search field's font size and padding.** `+[SearchConstants searchFieldPadding]`
  (`0x1000A90B4`) returns 21 on the old path but reads a global and doubles it on the macOS 26
  path; the global's initialiser was not traced.
- **The expand / collapse resize curve.** The present and dismiss springs are exact; the curve
  used when the window grows to fit results was not isolated.
- **`SUIUtilities.isInvocationAnimationEnabled`.** A private framework defaults switch with no
  public equivalent.
