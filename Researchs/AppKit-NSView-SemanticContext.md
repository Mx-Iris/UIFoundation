# AppKit NSView Semantic Context Internals

> Based on reverse engineering macOS 26.4 AppKit (arm64e) via IDA Pro decompilation of
> `/System/Library/Frameworks/AppKit.framework/AppKit` (extracted from `dyld_shared_cache_arm64e`),
> cross-checked against runtime probes, Apple's own shipping frameworks, and WebKit's public source.
> Addresses are slid AppKit text addresses in the 26.4 cache (imagebase `0x1849a3000`) and will
> differ between OS versions.
>
> **Why this report exists.** A pop-up button inside a macOS Settings-style grouped form has no
> bezel — it is a label plus a chevron. There is no public AppKit API that asks for that appearance;
> SwiftUI's `Form` gets it from a private `NSView` property, `_semanticContext`. Only one of the
> enum's values has ever been published (`NSViewSemanticContextForm = 8`, via WebKit). This document
> recovers the rest of the enum from the binary and pins each value to the AppKit code that assigns
> it, so `NSView_Private.h` can declare something better than a single magic number.

---

## Table of Contents

- [1. What a Semantic Context Is](#1-what-a-semantic-context-is)
- [2. API Surface](#2-api-surface)
- [3. Inheritance: `computed_effectiveSemanticContext`](#3-inheritance-computed_effectivesemanticcontext)
- [4. The Values](#4-the-values)
- [5. Evidence Per Value](#5-evidence-per-value)
- [6. Cells: Drawing Without a View](#6-cells-drawing-without-a-view)
- [7. How WebKit Uses It](#7-how-webkit-uses-it)
- [8. Availability History](#8-availability-history)
- [9. Why the Numbers Are Not Contractual](#9-why-the-numbers-are-not-contractual)
- [10. Practical Guidance](#10-practical-guidance)
- [11. Appendix: Key Addresses](#11-appendix-key-addresses)

---

## 1. What a Semantic Context Is

A semantic context tells a control *what kind of surface it is being drawn on*, so it can pick
matching art. It is orthogonal to appearance (light/dark), to `controlSize`, and to the control's
own style properties.

The clearest example is the form context: an `NSPopUpButton` in it drops its bezel and renders as a
label plus a small chevron — the System Settings look. `NSSegmentedCell` consults it too, all the
way down into the widget it asks CoreUI to draw:

```
+[NSSegmentedCell(StaticMethods) _widgetTypeForSegmentStyle:semanticContext:]
+[NSSegmentedCell(StaticMethods) _alignmentRectInsetsForStyle:size:semanticContext:]
+[NSSegmentedCell(StaticMethods) _preferredHeightForStyle:controlSize:semanticContext:controlView:]
```

So the context changes not only colours but metrics — alignment rect insets and preferred heights
differ per context.

## 2. API Surface

`NSView` (all private; the type name `NSViewSemanticContext` survives in the binary's property
encodings, the member names do not):

| Member | Notes |
| --- | --- |
| `_semanticContext` / `_setSemanticContext:` | The view's own explicit value. `0` means "not set". |
| `_effectiveSemanticContext` | The value actually in force, after inheritance. Read-only. |
| `computed_effectiveSemanticContext` | The uncached computation behind it (§3). |
| `+default_semanticContext` | Returns `0`. |
| `_semanticContextExplicitSomewhereInChain` | Whether any ancestor set one. |
| `_recursiveUpdateSemanticContextExplicitSomewhereInChain:` | Propagates that flag down a subtree. |

`NSWindow` has a `_semanticContext` of its own — a view with no superview falls back to its
window's value (§3).

`NSCell` carries a parallel set for view-less drawing (§6):

| Member | Notes |
| --- | --- |
| `_fallbackSemanticContext` / `_setFallbackSemanticContext:` | Used when the cell has no control view. |
| `_effectiveSemanticContextInControlView:` | Control view's effective value, else the fallback. |

Change notification, used by AppKit's own controls to redraw when the context under them changes:

```
-[NSCell _controlViewDidChangeEffectiveSemanticContext:]
addObserverForEffectiveSemanticContextIfNeeded
removeObserverForEffectiveSemanticContextIfNeeded
```

AppKit even logs a diagnostic for the degenerate case:

```
"%p was registered for changes to _effectiveSemanticContext with no control view!"
```

## 3. Inheritance: `computed_effectiveSemanticContext`

`-[NSView computed_effectiveSemanticContext]` (`0x185701e34`) is four lines of logic:

```c
own = [self _semanticContext];
if (own != 0)        return own;                                 // explicit wins
if ([self superview]) return [superview _effectiveSemanticContext]; // walk up the view tree
if ([self window])    return [window _semanticContext];             // then the window
return 1;                                                        // finally: Normal
```

Three consequences worth internalising:

1. **Setting it on a container is enough.** Descendants inherit unless they set their own non-zero
   value. This is why one call on a card view restyles every control in it.
2. **`0` is not a context, it is "inherit".** There is no way to say "explicitly normal" other than
   writing `1`.
3. **A detached view reports `1`**, not `0` — the fallback at the end of the chain.

## 4. The Values

| Value | Name we declare | Role |
| --- | --- | --- |
| 0 | `NSViewSemanticContextNone` | Not set; inherit |
| 1 | `NSViewSemanticContextNormal` | Ordinary window content |
| 2 | `NSViewSemanticContextStatusBar` | System status bar |
| 3 | `NSViewSemanticContextTitlebar` | Title bar |
| 4 | `NSViewSemanticContextToolbar` | Window toolbar |
| 5 | `NSViewSemanticContextSourceListCell` | Label/icon **inside** a source-list row |
| 6 | `NSViewSemanticContextMenu` | Menu |
| 7 | `NSViewSemanticContextSidebar` | Sidebar (the container) |
| 8 | `NSViewSemanticContextForm` | Grouped settings form |

Only `NSViewSemanticContextForm` is Apple's own spelling, taken from WebKit's
`Source/WebCore/PAL/pal/spi/mac/NSViewSPI.h`. The rest are ours. The member names are not recoverable:
AppKit's binary keeps the type name but not the members, and grepping every framework in Xcode
(including the View Debugger's DVT frameworks, which display named enum values for AppKit
properties) turns up no `NSViewSemanticContext*` member string.

## 5. Evidence Per Value

Each row is pinned by AppKit assigning the constant itself, or by reading `_effectiveSemanticContext`
off a view AppKit placed.

**0 — None.** `+[NSView default_semanticContext]` returns `0`. `computed_effectiveSemanticContext`
treats `0` as "ask my superview".

**1 — Normal.** The terminal fallback in `computed_effectiveSemanticContext`. Runtime: a detached
`NSView`, a window's content view, and a view inside an `NSPopover` all read `1`.

**2 — StatusBar.** Runtime: `NSStatusBarButton` reads `2`. Corroborated by
`-[NSTableCellView _updateSourceListAttributesInRowView:]`, which skips source-list styling when the
enclosing table's context satisfies `(context & ~4) == 2` — that is, `2` or `6`, the status bar and
menus.

**3 — Titlebar.** Runtime: `NSTitlebarView` reads `3`. Assigned by:
- `-[NSInspectorBar _auxiliaryViewController]` — `_setSemanticContext:3` on the inspector bar view.
- `-[NSTitlebarAccessoryViewController setView:]` — `3` when `NSSolariumEnabled()`, else `4`.
- `-[_NSSplitViewItemAccessoryViewWrapper _updateSemanticContextAndGroup]` — same split.

Those last two are a nice detail: under the macOS 26 ("Solarium") design, title bar accessories moved
from the toolbar context into the title bar context.

**4 — Toolbar.** `-[NSToolbarView initWithFrame:]` calls `_setSemanticContext:4` on itself, so every
view hosted in an `NSToolbarItem` inherits it — confirmed by runtime probe. Also set by
`-[_NSFullScreenMenuBarCompanionController _makeWindowIfNecessary]` on
`NSToolbarFullScreenContentView`. Independently, Apple's Podcasts ships
`-[MTMacToolbarSlider …]` doing `[nsSlider _setSemanticContext:4]` on its Catalyst-hosted `NSSlider`.

**5 — SourceListCell.** `-[NSTableCellView _updateSourceListAttributesInRowView:]` stamps
`_setSemanticContext:5` onto the cell's `textField` and `imageView` — the text and icon of a source
list row, not the row or the list. (pookjw's *Silicon* does the same thing by hand on a sidebar
collection view item's label; it is copying AppKit, not inventing a use.)

**6 — Menu.** Three AppKit menu backdrops set it in their initialisers:
`NSRootMenuWindowBackgroundView`, `NSMenuWindowManagerBackgroundView`, and
`_NSPopupMenuWindowPopoverFrame`. Outside AppKit, `-[SCTMenuView _effectiveSemanticContext]` in
Shortcut.framework is a one-line `return 6;`.

> Caveat from a runtime probe: a custom view attached to an `NSMenuItem` reads `1`, not `6`. View-based
> menu items are not parented under those backdrop views.

**7 — Sidebar.** `-[_NSSplitViewItemViewWrapper setSidebar:]` sets `7` when the item becomes a
sidebar and `0` when it stops being one. Runtime: an `NSSplitViewItem` sidebar's view **and** a
source-list `NSTableView` inside it both read `7` — the table inherits, it does not set its own.

**8 — Form.** WebKit's declaration. Corroborated inside AppKit by `-[NSBox setBoxType:]`, which sets
`_setSemanticContext:8` for box type `6` — a value IDA renders as `NSBoxCustom|NSBoxSeparator` and
which matches no documented `NSBoxType`, so presumably a private grouped-box style.

## 6. Cells: Drawing Without a View

Cell-based drawing may have no control view at all (WebKit renders CSS form controls this way).
`-[NSCell _effectiveSemanticContextInControlView:]` (`0x1850ac0b8`) is the whole story:

```c
if (controlView) return [controlView _effectiveSemanticContext];
else             return [self _fallbackSemanticContext];
```

`_fallbackSemanticContext` sits alongside `_fallbackBackingScaleFactor` and
`_fallbackBezelPresentationState` — a small family of "what to assume when there is no view".

## 7. How WebKit Uses It

WebKit is the best-documented client, and its three layers show the intended shape of the API.

**Entry point — the host app sets it, WebKit only reads it.** `WKWebView` overrides the setter purely
to notice a transition and trigger a re-render:

```objc
- (void)_setSemanticContext:(NSViewSemanticContext)semanticContext {
    auto wasUsingFormSemanticContext = _impl && _impl->useFormSemanticContext();
    [super _setSemanticContext:semanticContext];
    if (!_impl) return;
    if (wasUsingFormSemanticContext != _impl->useFormSemanticContext())
        _impl->semanticContextDidChange();
}

bool WebViewImpl::useFormSemanticContext() const {
    return [m_view.get() _semanticContext] == NSViewSemanticContextForm;
}
```

Note it only ever compares against `Form` — which is why the WebKit header declares that one member
and nothing else.

**Middle — one bit in the drawing state.** The flag is carried to the web process in
`WebPageCreationParameters` and lands in `RenderTheme::extractControlStyleStatesForRenderer` as
`ControlStyle::State::FormSemanticContext` (`1 << 10`), a sibling of `WindowActive` and
`DarkAppearance`.

**Exit — two paths, because CSS controls have no real view hierarchy.** With a stand-in view:

```objc
NSView *ControlFactoryMac::drawingView(const FloatRect& rect, const ControlStyle& style) const {
    if (!m_drawingView) m_drawingView = adoptNS([[WebControlView alloc] init]);
    [m_drawingView setAppearance:[NSAppearance currentDrawingAppearance]];
    if (style.states.contains(ControlStyle::State::FormSemanticContext))
        [m_drawingView _setSemanticContext:NSViewSemanticContextForm];
    return m_drawingView.get();
}
```

And without one, via the cell fallback from §6:

```objc
if (style.states.contains(ControlStyle::State::FormSemanticContext))
    [cell _setFallbackSemanticContext:NSViewSemanticContextForm];
```

## 8. Availability History

`_semanticContext` / `_setSemanticContext:` are old. Class-dumped AppKit headers list them — along
with `_effectiveSemanticContext` and `_recursiveUpdateSemanticContextExplicitSomewhereInChain:` — as
far back as **macOS 10.12**.

The `Form` value is much newer. WebKit added support in commit `1748148` (2022-12-13, bug 248764 /
rdar://99309431, "[macOS] Add support for theming native controls using NSViewSemanticContext"),
whose message spells out the split:

> Add a USE() macro rather than a HAVE() macro, since `NSViewSemanticContextForm` is only available
> on macOS 13, even though `NSViewSemanticContext` is available on older macOS.

and which calls `_setSemanticContext:` "existing `NSView` SPI". The gate it introduced was:

```c
#if (PLATFORM(MAC) && __MAC_OS_X_VERSION_MIN_REQUIRED >= 130000)
#define USE_NSVIEW_SEMANTICCONTEXT 1
#endif
```

That gate has since been removed from `PlatformUse.h` — the enum is unconditional in WebKit's SPI
header today. Between the ten-year-old property, WebKit's continuous dependence, and SwiftUI's own
use, there is no practical need to guard calls with `respondsToSelector:`.

## 9. Why the Numbers Are Not Contractual

The Parrot app published a named version of this enum around 2017 (`MochaUI/AppKit+Extensions.swift`):

```swift
public enum SemanticContext: Int {
    case none = 0x0, normal = 0x1, statusbar = 0x3, titlebar = 0x4
    case toolbar = 0x5, sourceList = 0x6, menu = 0x7
}
```

Every assignment from `2` upwards disagrees with what macOS 26 does — Parrot's list is shifted by
one and has no `2` at all. Whether Apple renumbered or Parrot mis-derived, the lesson is the same:
**re-verify these constants on a new OS release.** `Form = 8` is the exception: WebKit has shipped
it as a literal since macOS 13 and still does.

## 10. Practical Guidance

- **Set it on the container, once.** Inheritance does the rest; per-control calls are only needed for
  controls that fall outside the container.
- **It is read at draw time.** Changing it on a live hierarchy needs a redraw — that is precisely why
  AppKit maintains `_controlViewDidChangeEffectiveSemanticContext:` and WebKit detects the transition
  by hand. Setting it during view setup, before first display, needs nothing extra.
- **`_effectiveSemanticContext` is the debugging tool.** When a control does not restyle, read it: a
  `1` means nothing in the chain set a context, and the usual cause is setting it on a sibling rather
  than an ancestor.
- **Prefer `Form` for anything you ship.** It is the only value with a published name, the only one
  with a stated availability, and the only one an external project (WebKit) depends on.

## 11. Appendix: Key Addresses

macOS 26.4 AppKit, arm64e, imagebase `0x1849a3000`:

| Address | Symbol |
| --- | --- |
| `0x185701e2c` | `+[NSView default_semanticContext]` |
| `0x185701e34` | `-[NSView computed_effectiveSemanticContext]` |
| `0x1850ac0b8` | `-[NSCell _effectiveSemanticContextInControlView:]` |
| `0x184a9436c` | `-[NSToolbarView initWithFrame:]` — sets 4 |
| `0x1854c8ea0` | `-[_NSFullScreenMenuBarCompanionController _makeWindowIfNecessary]` — sets 4 |
| `0x184a47dd8` | `-[_NSSplitViewItemViewWrapper setSidebar:]` — sets 7 / 0 |
| `0x184ad5260` | `-[NSTableCellView _updateSourceListAttributesInRowView:]` — sets 5 |
| `0x185365cc8` | `-[NSRootMenuWindowBackgroundView initWithFrame:]` — sets 6 |
| `0x185404e4c` | `-[NSMenuWindowManagerBackgroundView initWithFrame:]` — sets 6 |
| `0x18547de58` | `-[_NSPopupMenuWindowPopoverFrame initWithFrame:]` — sets 6 |
| `0x184ce93f4` | `-[NSInspectorBar _auxiliaryViewController]` — sets 3 |
| `0x184a2f434` | `-[NSTitlebarAccessoryViewController setView:]` — sets 3 or 4 |
| `0x18563a740` | `-[_NSSplitViewItemAccessoryViewWrapper _updateSemanticContextAndGroup]` — sets 3 or 4 |
| `0x184b70ca0` | `-[NSBox setBoxType:]` — sets 8 for box type 6 |

There are 28 call sites for `_setSemanticContext:` in AppKit 26.4; the table lists the ones that pin
a value. The remainder are toolbar plumbing (`NSToolbarItemViewer`, `_NSToolbarItemViewerLabelView`,
`NSToolbarItem`, `NSToolbarConfigPanel`, `NSToolbarCollectionViewItem`, `NSToolbarItemGroupPickerView`)
and `NSThemeFrame` title bar plumbing.
