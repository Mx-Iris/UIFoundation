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
>
> **§10 is a later addition, read off macOS 27.2** (build 26B118), where the code has moved out of
> the app binary into private frameworks. It covers Escape and the results platter's resize curve,
> consumed by both `SpotlightPanel` and `QuickActionBar` through
> [`Documentations/Evolutions/0032-escape-clears-query-before-dismissing.md`](../Documentations/Evolutions/0032-escape-clears-query-before-dismissing.md).
>
> **§11 is the browse buttons beside the search field on 27.2** — their geometry, the springs that
> bud them out of the field and draw them back in, what triggers them, and how the merged glass is
> drawn, with the AppKit counterpart. Consumed by `QuickActionBar` through
> [`Documentations/Evolutions/draft-quick-action-bar-browse-items.md`](../Documentations/Evolutions/draft-quick-action-bar-browse-items.md).

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
- [10. macOS 27.2: Escape and the resize curve](#10-macos-272-escape-and-the-resize-curve)
- [11. macOS 27.2: the browse buttons](#11-macos-272-the-browse-buttons)

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
  worth two constants that a host should be choosing anyway. *(The 27.2 standard width has since
  been read — §10.4.)*
- **The search field's font size and padding.** `+[SearchConstants searchFieldPadding]`
  (`0x1000A90B4`) returns 21 on the old path but reads a global and doubles it on the macOS 26
  path; the global's initialiser was not traced.
- **The expand / collapse resize curve.** The present and dismiss springs are exact; the curve
  used when the window grows to fit results was not isolated. *(Recovered from 27.2 — §10.4.)*
- **`SUIUtilities.isInvocationAnimationEnabled`.** A private framework defaults switch with no
  public equivalent.

---

## 10. macOS 27.2: Escape and the resize curve

Read off macOS 27.2 build 26B118. Addresses are unslid addresses in that build's dyld shared cache
(cache UUID `b39b8e818b0e3d1491b55ed0494535d6`, archived at
`/Volumes/DyldSharedCaches/macOS/27.2-beta/` — the directory was named `27.2/` when this section
was written; `27.2/` now holds the release build, 26B123); the IDA databases are
`SpotlightUIInternal+SpotlightUIShared+SpotlightUIServices.i64` and `AppKit.i64` in the same
directory, and the app binary's is `/Volumes/RE/Spotlight/27.2/Spotlight.i64`. Every method address
came from the interface dumps beside them or from `runtime-viewer-cli` on the running system, and
every conclusion below was checked against the disassembly.

### 10.1 Where the code went

The 27.2 `Spotlight.app` executable is a shell, 124 KB per slice: `SPApplication` and the
`AppDelegate`. The panel, the search field and the keyboard handling moved to
`SpotlightUIInternal.framework`, with `SpotlightUIShared` and `SpotlightUIServices` beside it —
all three `BuildAliasOf = SpotlightApp`, with the app's own `SourceVersion` (250001012107000). The
Swift module is now `SpotlightUIInternal`, so the classes of §1 appear as
`_TtC19SpotlightUIInternal20SearchViewController` and so on.

Most calls between these classes go through Swift vtables (`(isa & swift_isaMask) + offset`). A
slot was resolved by reading the class metadata at that offset: the metadata address is the
`_OBJC_CLASS_$_…` symbol (from `ipsw dyld symaddr`), and for a pure Swift class the `…CN` symbol.
swift-section's "VTable offset" numbers are those byte offsets divided by eight —
`didPressLeadingButton` is slot 224, offset `0x700`.

### 10.2 Escape, in two layers

**The search field.** `-[SearchField control:textView:doCommandBySelector:]` (`0x2ADF78550`, Swift
body `0x2ADF81318`) handles `cancelOperation:` and nothing else. If the field's current query is not
empty (vtable `+0x170`, `0x2ADF76880`: `!QueryRepresentation.isEmpty`), it clears the field
(`+0x2A8`, `0x2ADF78E80`: `stringValue = ""` when it is not empty already, then the text-change path
and the field's delegate), sends an `SFClearInputFeedback`, and returns `YES`. An empty field
returns `[[self nextResponder] tryToPerform:@selector(cancelOperation:) with:self]`.

**The view controller.** `SearchViewController.cancelOperation(_:)` (Swift `0x2AE004D28`, thunk
`0x2AE004FF8`) drops a pending Return, then takes the first of:

1. The page controller holds two or more pages (`+0x708`, `0x2ADFF9E64`): go back, through
   `didPressLeadingButton()` (`0x2ADFF9BC0`).
2. The search field has a query, or a top-level browsing filter is active (`+0x2B0`,
   `0x2ADFEF194`, read from the browse button controller): clear the filter (`+0x6F8`,
   `0x2ADFF9A98`), reset the search (`0x2ADFF550C`, which clears the field through the same
   `+0x2A8`), and put the focus back in the field (navigation bar `+0x248`, `0x2ADF8C394`, called
   with `true`).
3. Otherwise dismiss: the window state's `dismiss(with:completion:)` (`+0x120`) with
   `SFViewDisappearEvent` 5 and no completion.

So with text in the field, Escape empties it and the empty query collapses the results; the
second Escape reaches the view controller with nothing to clear and closes the panel.

Two neighbours that do not take part: `-[FluidWindow cancelOperation:]` (`0x2AE039948`, body
`0x2AE0397D0`) acts only for a transient window style, forwarding to its forwarding responder or to
`super`; and `-[SPApplication sendEvent:]` in the app binary (`0x100002278`) handles no keys, only
application deactivation (type 13, subtype 2, `applicationLostFocusWithReason:` 22).

### 10.3 How AppKit routes the command

From the same build's AppKit:

- **Nothing on a field editor's chain implements `cancelOperation:` except the window.** `NSTextView`,
  `NSTextField`, `NSControl`, `NSView`, `NSResponder`, `NSPanel`, `NSWindowController` and
  `NSApplication` have no implementation (`runtime-viewer-cli`), so an Escape a text field's
  delegate does not take travels up to the window.
- **`-[NSTableView cancelOperation:]`** (`0x18AF5F8B8`) aborts an in-cell edit when one is active.
  Otherwise it walks the whole `nextResponder` chain and sends `cancelOperation:` to **every**
  responder that implements it, without stopping after the first — a view controller handling it
  does not keep it from reaching the window too.
- **`-[NSWindow cancelOperation:]`** (`0x18ADF1BA0`) calls `-[NSWindow _cancelKey:]` (`0x18ADF38A0`)
  when the window is visible, which tries an Escape key equivalent and otherwise sends `cancel:` (or
  `complete:`) to the first responder.
- **For a first responder that is not a text view, Escape becomes a command in the window.**
  `-[NSTableView keyDown:]` (`0x18A6BF13C`) only ends a type-select search on Escape;
  `-[NSWindow keyDown:]` (`0x18A678DA4`) tries `performKeyEquivalent:`, then
  `_NSPostProcessKeyboardUIKey`, then `-[NSApplication _handleKeyEquivalent:]`. In a test process —
  the window is never key there — a key-down Escape sent to a table changes nothing at all
  (measured), so tests send `cancelOperation:` to the table directly.

### 10.4 The resize curve

The results platter's size animation is described by `SpotlightUIShared.WindowSizingAnimation`: a
horizontal and a vertical `AxisAnimation`, each with an `expansion` and a `collapse`
`SwiftUI.Animation` and optional callbacks run alongside.

- `AxisAnimation.default` (getter `0x22F18F700`, initialiser `0x22F18F4B8`) sets both to
  `Animation.spring(Spring(duration: 0.3, bounce: 0.2), blendDuration: 0)`;
  `WindowSizingAnimation.default` (`0x22F18FC0C`, initialiser `0x22F18FAF4`) uses it on both axes.
- `ResultPlatterBehavior.standard` (`0x22F190A58`), the behaviour of an ordinary query, carries
  that default. `sizingAnimation` (`0x22F192530`) falls back to `linear(duration: 0)` — no animation
  — when a behaviour has none.
- `standard`'s sizes: width 640 (520 when `SUIUtilities.isCampoEnabled`, the `spotlightWidth`
  default when that is positive), a preferred height of 410 and a maximum of 5000;
  `heightCanPersist` and `ignoreIndexing` are on.

For a unit mass, `Spring(duration: 0.3, bounce: 0.2)` is a natural frequency of 2π / 0.3 and a
damping ratio of 0.8: stiffness ≈ 438.65 and damping ≈ 33.51. It peaks a quarter of a second in, at
1 + e^(−0.8π / 0.6) ≈ 1.0152, and settles a little after its duration.

The panel's content is SwiftUI in 27.2: the search field and the results sit in one glass element
clipped to a rounded rectangle, whose height comes from `WindowAnimatedHeightModifier`, driven by
the Observable `WindowAnimationCoordinator` (class metadata `0x2E3F6E400`; `sizingHAnimation` /
`sizingVAnimation`, `animatedWindowHeight`, `immediateWindowHeight`). The browse buttons beside the
field are a `MitosisButtonStack` (§11).

### 10.5 Not settled

- Whether the results stay visible, clipped by the shrinking platter, while it collapses, or are
  cleared first.
- How soon after a cleared query the collapse starts. 26.6.2 had an expansion debouncer (§6); 27.2's
  `WindowSizingCoordinator` still has one, but its delay was not read.

---

## 11. macOS 27.2: the browse buttons

The round buttons beside the search field — Applications, Files, Actions and Clipboard — and the
way they bud out of the field. Spotlight's side is read off macOS 27.2 build 26B118, with the cache
and database of §10. The AppKit counterpart in §11.6 is read off build 26B123 (cache
`b411828b445038e3973aafe7b7b5bef5` at `/Volumes/DyldSharedCaches/macOS/27.2/`, databases
`AppKit+UIKitCore+UIKitMacHelper+UpdateCycle.i64` and `SwiftUICore.i64` beside it). Everything was
checked in the assembly unless marked *inferred*; the motion was compared with a 60 fps screen
recording of Spotlight on 26B123.

### 11.1 Types

- **`BrowseButton`**, a SwiftUI view. `AnimationState { browseMode: SSFilterResult (+0x0),
  index: Int (+0x8), isTranslated (+0x10), isScaled (+0x11), isVisible (+0x12) }`; the view also
  holds the colour scheme, `windowWidth`, `collapsedWindowHeight`, `isSelected`, `action` and
  `onHover`. Body `0x2ADF4B088`, its `ZStack` content `0x2ADF4B3BC`, the icon label closure
  `0x2ADF4C9A0`.
- **`MitosisButtonStack`**, body `0x2ADF4DD3C` → item builder `0x2ADF4D658`:
  `ForEach(buttonStates.reversed(), id: \.index) { BrowseButton(…).id(index).offset(x: −(animatedWindowWidth − anticipatedWindowWidth) × 0.5) }`.
  The offset only re-centres the stack while the window's width animates and is 0 at rest. The list
  is reversed so that index 0, the button nearest the field, draws on top (*inferred* from `ZStack`
  order). In the root `ZStack { MitosisButtonStack, field }` the field draws above every button.
- **`BrowseButtonController`**, a pure Swift `Observable` class, metadata `0x2E3F74DF0`, vtable
  entry k at `(25 + k) × 8`: show `0x2ADF17F6C` (+0x370), hide `0x2ADF189D0` (+0x378),
  `showBrowseButtonForSizeChange` `0x2ADF17A98`, `showBrowseButtonsIfNeeded` `0x2ADF19500`, the
  `allowsBrowseButtons` getter `0x2ADF161AC`.

### 11.2 Geometry and each button's look

| Part | Value | Where |
|---|---|---|
| Button size | `h ≥ 56 ? h − 2 : 54` for the collapsed height h (Campo: `h ≥ 86 ? h − 2 : 84`) | `topLevelBrowseButtonSize` `0x2ADFA8FBC` |
| Spacing | 10 | double at `0x2AE0893D0` |
| Collapsed field width | `W − (size + 10) × modeCount` | `0x2ADFA90B4` |
| Position | x = collapsed field width + (isTranslated ? 10 + size / 2 + index × (size + 10) : 0); y = h / 2 | `0x2ADF4B2D0`–`35C` |
| Circle | `Circle().foregroundStyle(.clear)`, content shape and clip `Circle`, `_glassElement(cornerRadius: nil` → capsule`, style: .continuous)` | assembly |
| Circle scale | `isScaled ? 1 : 0.1`, anchor centre | `0x2ADF4B950`–`988` |
| Selection background | `SelectionMaterialView().opacity(isSelected && isVisible ? 1 : 0)`, clipped to a circle | `0x2ADF4B8CC`–`8E8` |
| Icon | `Image(_internalSystemName: symbolName ?? "magnifyingglass").font(.title)` | assembly |
| Icon blur, opacity, scale | `isVisible ? 0 : 10` (not opaque); `isVisible ? 1 : 0`; `isScaled ? 1 : 0.1`, anchor centre | `0x2ADF4CA64`–`A78` |
| Icon frame | the button's size, `padding(.horizontal, 5)` | pseudocode |
| Enabled | `isEnabled && isTranslated` (the key path is *inferred*) | closure `0x2ADF4D414` |
| Accessibility | `accessibilityHidden(!isVisible)`, `focusable(false)` | assembly |

For a 640-point window and a 56-point collapsed height with four modes: the collapsed field is 384
points; untranslated buttons are 5.4-point dots centred on x = 384, inside the still full-width
field; translated centres are at 421, 485, 549 and 613, and the last button's right edge is at 640.

The modes (`topLevelBrowseModes`, `0x22F233B88`) are applications, files and actions, then the
pasteboard only when the pasteboard-history setting is on. Their symbols, read with `ipsw` from the
`SSFilterResult` factories in SpotlightServices (the argument's role is *inferred* from its value):
`appstore` (Applications), `folder` (Files), `app.2.stack.3d` (Actions), `document.on.document`
(Clipboard).

### 11.3 Choreography

Every step goes through `WindowAnimationCoordinator.animate` (`0x2ADF2FFB4`):
`withAnimation(animation, completionCriteria: .removed)` plus an animation assertion. With
`SUIUtilities.isBrowseButtonAnimationEnabled` off, the same body runs without animation. All values
are SwiftUI `Spring(duration:bounce:)` with `blendDuration: 0`.

**Show** issues everything in one run-loop turn; nothing is staggered except through each index's
own spring and the icons' delay:

| Order | Change | Animation | Where |
|---|---|---|---|
| 0 | `buttonStates` = initial (every flag false); `mitosisSmoothness = 100` | none | the immediate `0x4059000000000000` |
| 1 | `mitosisSmoothness = 0` | spring(0.71, 0.01) | `0x2ADF13A94` |
| 2 | `horizontalBrowseButtonAnimation = spring(0.39, 0.39)`; `isSearchHorizontallyExpanded = false` | spring(0.39, 0.39) | `0x2ADF13AC8` |
| 3, each i | `isTranslated = true` | 0.35/0.43, 0.45/0.39, 0.55/0.35, 0.60/0.31; past index 3, 0.45 + 0.1i / max(0.39 − 0.04i, 0) | `0x2ADF13AEC` |
| 4, each i | `isScaled = true` | 0.41/0.394, 0.55/0.35, 0.65/0.32; from index 3, 0.41 + 0.1i / max(0.394 − 0.04i, 0), i.e. 0.71/0.274 | `0x2ADF13D14` |
| 5, each i | `isVisible = true`, then `selectedButton = highlightedButton = mode` | spring(0.49, 0.15).delay(0.17) | `0x2ADF13974` |

**Hide** (`0x2ADF189D0`) returns at once, calling only its completion, when the field is already
expanded or there is no window coordinator:

| Order | Change | Animation | Where |
|---|---|---|---|
| 0 | `mitosisSmoothness = 0` | none | |
| 1 | every `isVisible = false` | spring(0.20, 0.05) | `0x2ADF13F24` |
| 2 | `horizontalBrowseButtonAnimation` = this spring; `isSearchHorizontallyExpanded = true`; `mitosisSmoothness = 100`; every `isTranslated` and `isScaled` false; then the completion | spring(0.41, 0.12) | `0x2ADF13EF0` |

*Inferred:* `mitosisSmoothness` starts at 0 (initialiser `0x2ADF280CC`), so on the very first show
after launch the 0 → 100 → 0 changes land in one update and the first value probably does not
animate; every later show starts from the 100 that hide leaves behind. `QuickActionBar` animates
from 100 every time.

### 11.4 What triggers them

- **Invocation.** `SpotlightContentView` (body `0x2ADF58B04`) has an `onChange(of: invocationState)`
  (closure `0x2ADF5C4F0`). On `.invoking` (raw value 1; the order is dismissed, invoking, invoked,
  dismissing), with `SpotlightWindowState.showBrowseButtons` true, it calls `show(nil)`. On
  `.dismissed` it calls vtable +0x398 instead, which was not decompiled.
- **Size changes.** `showBrowseButtonForSizeChange(isCollapse:)`: collapsing with
  `expandButtonsOnCollapse` set and buttons allowed calls show; otherwise it calls
  `hide(animated: true)` when buttons are not allowed (or the field is already expanded).
- **On request.** `showBrowseButtonsIfNeeded()` needs `allowsBrowseButtons` and an expanded field,
  sets `expandButtonsOnCollapse = true`, then calls `onShowBrowseButtons` if one is installed and
  show otherwise.
- **`allowsBrowseButtons`** is true only while the window is invoking or invoked, the stored flag is
  set, no browse mode is active and two more state checks pass. The query path (`0x2AE00AB00`) sets
  the stored flag from the query's type (`TopLevelFiltersQuery.showBrowseSuggestions`). An empty or
  non-empty query does not call show or hide by itself.
- **No delay on any of these paths.** Yet on the recording the field starts to narrow 28–29 frames
  (about 0.47 s) after the panel's first visible frame, and its first frames follow spring(0.39,
  0.39) to within half a frame. When `.invoking` actually fires was not traced; running
  `log stream --predicate 'eventMessage CONTAINS "browse:"'` while invoking Spotlight would show it,
  since each path logs its own `browse: …` line.

### 11.5 The field's width, the merged glass, and the rest

- **The field's width** (`0x2ADF5A12C`) is `isolatedAnimation(animation, value: w) { $0.frame(width: w) }`,
  w being the coordinator's `animatedWindowWidth` while expanded and
  `collapsedWindowWidth(for:buttonWidth:)` of it otherwise. The animation (`0x2ADF16D30`) is
  `horizontalBrowseButtonAnimation` — spring(0.39, 0.39) on show, spring(0.41, 0.12) on hide —
  unless a window-size flag picks `sizingHAnimation`. It runs alongside the translation, started in
  the same call. The field's glass has a continuous corner radius of half the collapsed height.
- **The merged glass.** `GlassElementModifier` (on the Solarium path) only writes an anchor
  preference, `GlassElement { id, cornerRadius?, style, anchor(bounds), enabled }` (`0x2ADFA0800`).
  The root view applies `_glassBackdropLayer(smoothness: coordinator.mitosisSmoothness, enabled: WindowStyling.isTransient)`
  (call site `0x2ADF63264`; the smoothness through vtable +0x3D8). That builds `GlassEffect`
  (`0x2ADFA0C58`, `0x2ADFA0F2C`), which draws in a `GeometryReader` background
  `Rectangle().foregroundStyle(.clear).materialEffect(Material._glass(.regular.size(.large).adaptive(false).excludingShadow().interactionState(.disabled).contentLensing(true)), in: _ShapeSet(shapes:, smoothness:))`.
  The shapes (`0x2ADFA155C`) are each enabled element's anchor resolved into a `Capsule` path, or a
  `RoundedRectangle(r)` path when it has a radius, so scale and position animations reach them. It
  is one glass material over a smooth union of shapes, `mitosisSmoothness` being the union's
  smoothing distance in points — not `GlassEffectContainer`, not `glassEffectUnion`, not a shader,
  not a `CAFilter`.
- **Hover** only reports `(Bool, mode)` to the controller as the highlight; the button draws nothing
  for it. **Pressed** is the system borderless button style. **Selected** puts the selection
  material behind the circle at full opacity and the icon in the dark colour scheme.
- **The ⌘ overlay** (`BrowseButtonShortcutIndicatorOverlay`, `0x2ADF4E1C0`) shows each button's digit
  key (`keyCodeForDigit(index + 1)`) at opacity 1 or 0 from the keyboard-indicator controller,
  collapsed-height tall, with a trailing padding of 57 or 20.

### 11.6 The AppKit counterpart: `NSGlassEffectContainerView.spacing`

Build 26B123.

- **`spacing` is stored as the smoothness.** `-[NSGlassEffectContainerView setSpacing:]`
  (`0x18B31947C`) calls the Swift setter `0x18B3194C8`: inside an implicit-animation context it
  forwards to `animator().setSpacing(_:)`; otherwise, when the value changed, it writes the
  `_smoothness` ivar (offset 0x220) and calls `setNeedsLayout:YES` — nothing else.
  `+defaultAnimationForKey:` (`0x18B31E554`) animates exactly one key, `"spacing"`, with a plain
  `CABasicAnimation`.
- **It reaches SwiftUI on the next layout pass, synchronously.** `layout()` (`0x18B31CA38`) reads
  `spacing` every pass, writes `RootView { groups, spacing }` into the effects view's hosting view
  and calls `ViewGraphHost.updateRoot(transaction:)`. The `RootView` body (`0x18B31C6E4`) builds one
  `MaterialGroup` per group, whose body (`0x18B319E70`) calls
  `_GlassEffectContainer.init(smoothness: spacing, content:)` (call at `0x18B31A078`) — and, when
  `UnifiedGlassDisabled` holds, also `materialEffect(material, in: _ShapeSet(elements:, smoothness: spacing))`
  (`0x18B31BBD4`).
- **It is the same number Spotlight sets.** In SwiftUICore the public
  `GlassEffectContainer.init(spacing:)` (`0x190C8C0C4`) is a single branch to
  `_GlassEffectContainer.init(smoothness:)` (`0x190C89D10`), which stores
  `_Glass.Smoothness(function: .default, value: spacing ?? min(Spacing.defaultValue.width, .height))`;
  `GlassEffectAnimatedPathSet.updateValue` (`0x1911F0350`) merges a container entry's paths into one
  `PathSet { elements, smoothness, smoothnessFunction }` — the field `_ShapeSet` sets. *Inferred:*
  shapes farther apart than about the smoothness do not blend, so the one number is both the merge
  distance and the blend radius. How Core Animation rasterises it was not traced.
- **Which views merge is decided by identity, not distance.** SwiftUI's
  `GlassContainer.Storage.appendToExistingEntry` (`0x190BB3240`) groups by group ID and namespace,
  `Variant.ID` and model ID. AppKit's `layout()` groups members by `GlassIdentity` — configuration,
  backdrop context, `backdropGroupName`, colour scheme, contrast, adaptive appearance — and
  different identities never merge.
- **Shapes come from frames and corner radii.** For each member `layout()` takes its private
  `_path`, else `effectiveCornerRadii` (uniform → `RoundedRectangle(cornerRadius:style: .continuous)`,
  otherwise `UnevenRoundedRectangle`), else `cornerRadius`, builds the path in the member's
  `bounds` and maps it into the container with `_NSViewGetTransformToAncestor` (`0x18AD40D6C`), which
  uses frame and bounds origins, flippedness and the bounds matrix but never `CALayer.transform`.
- **What marks the container for layout.** A frame change does — `setFrameOrigin:` →
  `_invalidateFocus` → `geometryInWindowDidChange` → `renewGState`, which `NSGlassEffectView`
  overrides (`0x18B31672C`) to mark its container. `setCornerRadius:` (`0x18B30EC7C`) marks only the
  glass view itself.
- **Members at any depth are collected**: `viewDidMoveToSuperview` (`0x18B3162B4`) walks up to the
  nearest container (helper `0x18B305DA4`) and joins its `_components`. Hidden members, members
  with `_disableEmbeddingCount > 0` and `_variant == 13` are skipped.
- **Collected paths are not animated in steady state.** The update's transaction animation
  (`0x18B32A344`) is only a member's pending layout animation, written by the `_variant` setter in an
  implicit-animation context, or a one-shot ease-out when the appearance or backdrop context
  changes.

### 11.7 Not settled

- Where the ≈0.47 s start delay comes from.
- What vtable +0x398, called on `.dismissed`, resets.
- How Core Animation rasterises `PathSet.smoothness` — a true smooth-minimum radius in points is
  *inferred*.
