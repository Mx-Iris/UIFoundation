# AppKit Control Rendering Internals

> Based on reverse engineering macOS 26.4 AppKit (arm64e) via IDA Pro decompilation.
> Companion to `AppKit-Layer-Backing-Internals.md` — this document focuses on the
> **control layer** (NSControl/NSCell/NSTextField/NSButton etc.), while the layer
> backing document focuses on the **view layer** (NSView/CALayer).

---

## Table of Contents

- [1. Overview](#1-overview)
- [2. NSControl Drawing Delegation](#2-nscontrol-drawing-delegation)
- [3. NSButton Three-Generation Architecture](#3-nsbutton-three-generation-architecture)
- [4. NSTextField Double-Layer Override Detection](#4-nstextfield-double-layer-override-detection)
  - [4.1 Cell-Layer Check — `_cellOverridesDrawingMethods`](#41-cell-layer-check--_cellOverridesDrawingMethods)
  - [4.2 View-Layer Check — `_textFieldOverridesDrawingMethods`](#42-view-layer-check--_textfieldoverridesdrawingmethods)
  - [4.3 Path Decision Flow](#43-path-decision-flow)
- [5. Separated Subviews Architecture](#5-separated-subviews-architecture)
- [6. drawRect vs updateLayer — Cost Breakdown](#6-drawrect-vs-updatelayer--cost-breakdown)
- [7. Built-in Control Rendering Strategies](#7-built-in-control-rendering-strategies)
- [8. Pitfalls Encountered](#8-pitfalls-encountered)
  - [8.1 Overriding `drawInterior` Silently Kills the Modern Path](#81-overriding-drawinterior-silently-kills-the-modern-path)
  - [8.2 Overriding `draw(_:)` Triggers the Second Check](#82-overriding-draw_-triggers-the-second-check)
  - [8.3 Double-Inset Bug](#83-double-inset-bug)
  - [8.4 `@ViewInvalidating(.display)` + Direct Layer Write = Wasted Redraw](#84-viewinvalidatingdisplay--direct-layer-write--wasted-redraw)
  - [8.5 Initial Values Lost When Only Using `didSet`](#85-initial-values-lost-when-only-using-didset)
  - [8.6 NSTextField's Surprising Default Redraw Policy](#86-nstextfields-surprising-default-redraw-policy)
  - [8.7 Recommending Method 4 With `layout()` Was Wrong for `cornerRadius`](#87-recommending-method-4-with-layout-was-wrong-for-cornerradius)
- [9. UIFoundation Practice Patterns](#9-uifoundation-practice-patterns)
  - [9.1 `InsetsTextFieldCell` — The Correct Way](#91-insetstextfieldcell--the-correct-way)
  - [9.2 `RoundedBorderLabel` — Three-Tier Cooperation](#92-roundedborderlabel--three-tier-cooperation)
- [10. How to Verify At Runtime](#10-how-to-verify-at-runtime)
- [11. Appendix: Key Function Addresses](#11-appendix-key-function-addresses)

---

## 1. Overview

AppKit controls (NSControl subclasses — NSButton, NSTextField, NSStepper, etc.)
historically drew themselves via the `NSCell` "rubber stamp" model: the control
owned a cell, and `drawRect:` delegated to `[cell drawWithFrame:inView:]`.

In modern macOS (10.14+), Apple introduced a second rendering path called
**Separated Subviews** — the control's backing layer has its contents set to
`nil`, and a set of internal subviews (labelView, bezelView, backgroundView,
borderView) each render their own portion of the control, independently and
without going through `drawRect:` at all.

This is the same split as NSView's `drawRect:` vs `updateLayer` distinction,
but one level higher — it's controlled per control, based on runtime detection
of whether the subclass has overridden certain drawing methods.

**The hidden cost**: if a subclass overrides *any* drawing method (even just
`drawInterior(withFrame:in:)` to implement insets), AppKit's override detection
kicks in and the control **silently reverts to the traditional drawRect path**,
throwing away all the performance wins of separated subviews — including the
ability to call your own `updateLayer()` method, because `wantsUpdateLayer`
returns `false` as a side effect.

This document captures every trap we hit while making `UIFoundation`'s
`InsetsTextFieldCell` / `Label` / `RoundedBorderLabel` classes work with the
modern path instead of the legacy path.

---

## 2. NSControl Drawing Delegation

`NSControl.wantsUpdateLayer` is **not** the simple `drawRect:`-override detection
used by plain NSView. It goes through three tiers of delegation:

```c
-[NSControl wantsUpdateLayer](self) {
    // Tier 1: Per-instance cache (populated once, persists)
    cache = [self _supportsDirectLayerContentsCache];
    if (cache != 2) return cache == 1;
    
    // Tier 2: View-subclass drawRect: override check (bypass with opt-in)
    if (_NSSubclassOverridesSelector(
            [self _classToCheckForWantsUpdateLayer],
            [self class],
            @selector(drawRect:))) {
        result = NO;
    }
    // Tier 3: Delegate to NSCell if control has one
    else if (NSControlDelegatesToCell(self)) {
        result = [self.cell wantsUpdateLayerInView: self];
    }
    else {
        result = YES;   // No cell, no drawRect override → modern path
    }
    
    [self _setSupportsDirectLayerContentsCache: result];
    return result;
}
```

`NSControl.updateLayer` and `NSControl.drawRect:` likewise delegate to the cell:

```c
-[NSControl updateLayer](self) {
    [self.cell updateLayerWithFrame: self.bounds inView: self];
    [self _updateDebugAlignmentRectLayer];
}

-[NSControl drawRect:](self) {
    if (self.cell) {
        if ([self currentEditor])
            [self.cell _withTemporarilySuppressedContents: drawBlock];
        else
            drawBlock();   // → [cell drawWithFrame:inView:]
    }
}
```

**Implication**: for NSControl subclasses, the decision of which rendering path
to use is driven by the **cell's** `wantsUpdateLayerInView:` return value, unless
the view subclass itself overrides `drawRect:`.

NSCell's default implementation returns `0` (NO). Each cell subclass can opt in
by overriding this method.

---

## 3. NSButton Three-Generation Architecture

NSButtonCell's `wantsUpdateLayerInView:` has extensive eligibility logic:

```c
-[NSButtonCell wantsUpdateLayerInView:](self, view) {
    // Subclass of NSButton overrides drawRect: → NO
    if (_NSSubclassOverridesSelector([NSButton class], [view class], @selector(drawRect:)))
        return NO;
    
    return [self _eligibleForSeparatedContentSubviewsInView: view];
}

-[NSButtonCell _eligibleForSeparatedContentSubviewsInView:](self, view) {
    if (self->_flags & 0x1) return YES;   // Force-enabled
    
    if (NSButtonIneligibleForContentSubviews) return NO;  // App config
    
    if (NSButtonMayNeedLegacyAutomaticBezelStyleBehavior
        && [self isBordered] && ![self bezelStyle]
        && [self controlOverridesDrawingMethodsInView: view])
        return NO;
    
    if (![view isKindOfClass: [NSButton class]]) return NO;
    
    if ([self isKindOfClass: [NSMenuItemCell class]] 
        && ![self isKindOfClass: [NSPopUpButtonCell class]])
        return NO;
    
    if ([self _subclassOverridesAnyDrawMethodsAffectingVibrancy: NO]) return NO;
    
    if ([self _interiorBackgroundFillColor]) return NO;
    
    return [view cell] == self;
}
```

Eligible buttons run through `NSButtonAppearanceBasedVisualProvider.updateLayer`:

```c
-[NSButtonAppearanceBasedVisualProvider updateLayer](self) {
    if (![self wantsBackgroundView]) {
        config = [self currentBezelConfiguration];
        if ([config shouldDrawBezel] && ![buttonCell isTransparent]) {
            options = [self coreUIBezelDrawOptionsWithFrame: bounds flipped: ...];
            layer = [self.button layer];
            appearance = [NSAppearance currentAppearance];
            
            // ★ Modern path: CoreUI renders bezel directly into layer.contents
            //   via _createOrUpdateLayer:options: — no CGContext, no bitmap!
            [appearance _createOrUpdateLayer: &layer options: options];
            return;
        }
    }
    [self.button.layer setContents: nil];
}
```

Three rendering generations visible in the decompiled code:

| Generation | Entry | Path |
|-----------|-------|------|
| **1st (legacy)** | `NSControl.drawRect:` | `cell.drawWithFrame:inView:` → `CGContext` → layer.contents (bitmap) |
| **2nd (intermediate)** | `NSButtonCell.updateLayerWithFrame:inView:` | `visualProvider.updateLayer` → `NSAppearance._createOrUpdateLayer:options:` → CoreUI renders bezel via `NSLayerContentsFacet` 9-slice into layer.contents |
| **3rd (separated subviews)** | Same as 2nd, but with internal subviews | bezel + text split into independent sibling subviews, each with own layer |

The same split applies to NSTextField and other controls via their own
visualProviders.

---

## 4. NSTextField Double-Layer Override Detection

NSTextField has **two independent override checks** that can each force it back
to the legacy drawRect path. You must pass **both** to enter the modern path.

### 4.1 Cell-Layer Check — `_cellOverridesDrawingMethods`

Fired from `NSTextFieldAppearanceBasedVisualProvider.initWithTextFieldCell:`:

```c
-[NSTextFieldAppearanceBasedVisualProvider initWithTextFieldCell:](self, cell) {
    checkClass = [NSTextFieldCell class];   // textFieldCellClassForOverrideCheck
    cellClass  = [cell class];
    
    // SEL1 and SEL2 are (empirically) drawInteriorWithFrame:inView:
    //                                 and drawWithFrame:inView:
    if (_NSSubclassOverridesSelector(checkClass, cellClass, SEL1) ||
        _NSSubclassOverridesSelector(checkClass, cellClass, SEL2)) {
        self->_cellOverridesDrawingMethods = 1;
    }
}
```

**Any subclass of NSTextFieldCell that overrides either `drawInteriorWithFrame:inView:`
or `drawWithFrame:inView:` flips this flag permanently.**

### 4.2 View-Layer Check — `_textFieldOverridesDrawingMethods`

This flag is set separately — likely from `attachToTextField:` or a similar
initialization hook. It checks whether the NSTextField subclass overrides
`drawRect:` relative to NSTextField's own implementation.

Empirically verified: overriding `NSView.draw(_:)` in an `NSTextField` subclass
(e.g., `RoundedBorderLabel` originally had `override func draw(_:)`) sets this
flag to YES.

### 4.3 Path Decision Flow

Both flags are consumed by `wantsSeparatedSubviews`:

```c
-[NSTextFieldAppearanceBasedVisualProvider wantsSeparatedSubviews](self) {
    if (!textField 
        || self->_cellOverridesDrawingMethods        // ← Check 1
        || self->_textFieldOverridesDrawingMethods)  // ← Check 2
    {
        return NO;
    }
    return [NSTextFieldAppearanceBasedVisualProvider 
            wantsSeparatedSubviewsWithBezelConfiguration: [self bezelConfiguration]];
}
```

Which ultimately drives `NSTextField.wantsUpdateLayer`:

```c
-[NSTextField wantsUpdateLayer](self) {
    cache = [self _supportsDirectLayerContentsCache];
    if (cache != 2) return cache == 1;
    
    result = [[self _visualProvider] wantsSeparatedSubviews];
    [self _setSupportsDirectLayerContentsCache: result];
    return result;
}
```

**Summary**:

| Condition | `wantsUpdateLayer` | Path |
|-----------|-------------------|------|
| Neither override | YES | updateLayer / separated subviews |
| Cell overrides drawInterior/draw | NO | drawRect |
| View overrides drawRect: | NO | drawRect |
| Both override | NO | drawRect |

---

## 5. Separated Subviews Architecture

When `wantsSeparatedSubviews` returns YES, NSTextField's `updateLayer`:

```c
-[NSTextField updateLayer](self) {
    [[self layer] setContents: nil];   // ★ Clear own contents
    
    solariumMetrics = [[self _visualProvider] updateLayer];
    if (solariumMetrics && [self supportsFauxSolariumControlMetrics]) {
        [super updateLayer];
    }
}

-[NSTextFieldAppearanceBasedVisualProvider updateLayer](self) {
    if ([self labelView]) {
        [self updateLabelView];   // ← positions and updates the labelView subview
    }
}
```

**The key realization**: in the modern path, `self.layer.contents = nil`. The
NSTextField's own layer has NO pixel content. The actual text is rendered by
an internal `labelView` subview (which has its own layer). Bezel/border/
background (if any) are separate subviews too.

This is why setting `layer.cornerRadius` or `layer.borderColor` on an NSTextField
in the modern path **only affects the rounded rectangle shape around the label
subview** — the text itself is rendered separately and can't be clipped by the
parent's cornerRadius unless `masksToBounds = true`.

### Bezel configuration → path selection

```c
+[NSTextFieldAppearanceBasedVisualProvider wantsSeparatedSubviewsWithBezelConfiguration:](config) {
    NSInteger style = [config style];
    return (style < 8) & (0xFB >> style);
    // bitmask 0xFB = 11111011:
    //   style 0 → YES     style 4 → YES
    //   style 1 → YES     style 5 → YES
    //   style 2 → NO ★    style 6 → YES
    //   style 3 → YES     style 7 → YES
}
```

Only `style == 2` is excluded. All other standard bezel styles (including
`isBordered = false` labels) qualify for separated subviews.

---

## 6. drawRect vs updateLayer — Cost Breakdown

The split point is `NSViewBackingLayer.display` (`0x1853b86a4`):

```
NSViewBackingLayer.display
  │
  ├── [view _sendViewWillDraw]
  │
  ├── if [view wantsUpdateLayer]:              ★ FAST PATH
  │     [focusStack performWithFocusView: usingBlock:^{
  │         [NSAppearance _performWithCurrentAppearance: ... usingBlock:^{
  │             [NSGraphicsContext setCurrentContext: nil];   // NO CGContext!
  │             _NSViewUpdateLayer(view);                     // → [view updateLayer]
  │         }];
  │     }];
  │     return;
  │
  ├── if [view _drawsNothing]:
  │     [self setContents: nil];
  │     return;
  │
  └── // Traditional path
      scale = [self NS_suggestedContentsScale];
      maxScale = sqrt(268435456.0 / |bounds.area|);   // pixel budget cap
      [self setContentsScale: min(scale, maxScale)];
      
      contents = [self contents] ?? new NSViewBackingLayerContents;
      // ... smart 70.7% intersection region calculation ...
      [contents update:^(CGContextRef ctx) {
          [self drawInContext: ctx];   // → drawLayer:inContext: → _drawRect:clip: → drawRect:
      }];
      [self setContents: contents];
```

**Cost difference per display pass**:

| Aspect | `updateLayer` path | `drawRect:` path |
|--------|-------------------|------------------|
| Backing store allocation | **None** | `width × height × scale² × 4` bytes |
| CGContext | `nil` (no graphics context) | Full CGContextRef with save/restore |
| Pixel budget cap | N/A | `sqrt(256MB / area)` upper bound |
| Dirty region clipping | N/A | `NSRectClipList` per `getRectsBeingDrawn:` |
| Occlusion culling | N/A | `_NSViewSubtractOccludersFromRect` |
| Content scale auto-management | Manual | Automatic |
| Retina handling | Manual | Automatic |
| Where the pixels come from | Your code sets layer properties directly (GPU renders) | CPU rasterizes into bitmap, uploads to GPU |

For a 200×30 label on 2x Retina: `~48KB` bitmap per display on drawRect path,
**zero** pixel memory on updateLayer path.

---

## 7. Built-in Control Rendering Strategies

| Control | `wantsUpdateLayer` | `updateLayer` behavior | `drawRect:` |
|---------|-------------------|------------------------|-------------|
| **NSButton** | Cell decides (`_eligibleForSeparatedContentSubviewsInView:`) | `_visualProvider.updateLayer` → `NSAppearance._createOrUpdateLayer:options:` (CoreUI direct) | Cell's `drawWithFrame:inView:` |
| **NSTextField** | `_visualProvider.wantsSeparatedSubviews` | Clears `layer.contents = nil`, delegates to labelView subview | Inherited from NSControl |
| **NSTableView** | `isViewBased` & no custom drawing flag | Sets `layer.backgroundColor` (sourceList/tinted specialized) | 0x6e0-byte method (cell-based tables) |
| **NSScrollView** | Auto-detected (no override) | Sets `backgroundColor`/`borderColor`/`borderWidth`, 9-slice border via `NSLayerContentsProvider.facetForIdentifier:` | None |
| **NSImageView** | `[self _usesSubview]` | Subview mode → no-op; non-subview mode → `[layer _display]` | None |
| **NSVisualEffectView** | Hardcoded `return 1` | Manages material layer / color fill layer (pure sublayer ops) | None |
| **NSSplitView** | No drawing override | **Empty `{ }`** — divider drawing happens via `_NSSplitViewShadowView` subview | 0xdc bytes, draws dividers for legacy path |
| **NSBox** | Delegated to child view | Empty; actual drawing in `_NSBoxSeparatorView` / `_NSBoxCustomView` subviews | Delegated |
| **NSTextField**'s `_preferredLayerContentsRedrawPolicy` | — | Returns `2` (`.duringViewResize`) | — |

Many modern AppKit controls use an internal subview-composition pattern where
the control itself is an "empty shell" layer-backed view, and rendering work
is distributed among purpose-built subviews.

---

## 8. Pitfalls Encountered

These are real traps we hit while investigating and refactoring UIFoundation's
text field / label classes. Each one costs hours to debug without reverse
engineering because AppKit silently falls back to the legacy path without any
warning.

### 8.1 Overriding `drawInterior` Silently Kills the Modern Path

**Symptom**: `updateLayer()` is never called, no matter how you override it.
NSTextField keeps going through the legacy `drawRect:` → cell drawing path.

**Cause**: `InsetsTextFieldCell` originally overrode
`drawInterior(withFrame:in:)` to shrink the cellFrame for insets:

```swift
open override func drawInterior(withFrame cellFrame: NSRect, in controlView: NSView) {
    super.drawInterior(withFrame: cellFrame.box.inset(by: contentInsets), in: controlView)
}
```

This override triggers `_NSSubclassOverridesSelector(NSTextFieldCell, InsetsTextFieldCell, drawInteriorWithFrame:inView:) = YES`,
which sets `_cellOverridesDrawingMethods = 1`, which makes `wantsSeparatedSubviews`
return NO, which makes `wantsUpdateLayer` return NO, which means `updateLayer`
is **never called** by the display cycle.

The worst part: there's no warning. The view renders correctly via the drawRect
path, so you might not even notice you're on the wrong path.

**Fix**: Delete the `drawInterior` override entirely. Use only layout methods
(`drawingRect(forBounds:)`, `titleRect(forBounds:)`, `cellSize(forBounds:)`) —
these are NOT drawing methods and don't trigger the override check.

This works because `NSTextFieldCell.drawInterior` internally asks
`[self drawingRectForBounds: cellFrame]` to determine where to draw text:

```c
-[NSTextFieldAppearanceBasedVisualProvider drawInteriorWithFrame:textDrawingHandler:](...) {
    textRect = [textFieldCell drawingRectForBounds: cellFrame];  // ★ cell's override wins
    ...
    handler(textRect);
}
```

### 8.2 Overriding `draw(_:)` Triggers the Second Check

**Symptom**: You fixed the cell override, but your specific `NSTextField`
subclass still has `wantsUpdateLayer = false`.

**Cause**: You override `NSView.draw(_:)` (equivalent of `drawRect:` in ObjC)
on the view itself. This trips the **second** override check —
`_textFieldOverridesDrawingMethods`. Both checks must pass to enter the modern
path.

`RoundedBorderLabel` originally had:

```swift
open override func draw(_ dirtyRect: NSRect) {
    super.draw(dirtyRect)
    layer?.cornerRadius = bounds.height / 2
    layer?.borderWidth = borderWidth
    layer?.borderColor = borderColor?.cgColor
}
```

Even with the cell fixed, `RoundedBorderLabel.wantsUpdateLayer` returned `false`
because the view-layer check tripped.

**Fix**: Remove the `draw(_:)` override and use `updateLayer()` instead. This
works only if the cell-layer check is also clean (see 8.1).

### 8.3 Double-Inset Bug

**Symptom**: When `contentInsets ≠ zero`, text is inset by twice the expected
amount.

**Cause**: The original `InsetsTextFieldCell` overrode both `drawingRect(forBounds:)`
AND `drawInterior(withFrame:)`, both of which inset the rect before calling
super:

```swift
override func drawingRect(forBounds rect: NSRect) -> NSRect {
    super.drawingRect(forBounds: rect.box.inset(by: contentInsets))
}

override func drawInterior(withFrame cellFrame: NSRect, in controlView: NSView) {
    super.drawInterior(withFrame: cellFrame.box.inset(by: contentInsets), in: controlView)
}
```

Call chain:
1. `drawInterior(withFrame: fullFrame)` invoked
2. Override shrinks `fullFrame` → passes `shrunkFrame` to super
3. `super.drawInterior` internally calls `self.drawingRect(forBounds: shrunkFrame)`
4. `drawingRect` override shrinks `shrunkFrame` **again**

Result: insets applied twice. Only `contentInsets == .zero` is idempotent and
masks the bug.

**Fix**: Deleting the `drawInterior` override (see 8.1) incidentally fixes this
bug — now insets are applied exactly once via `drawingRect(forBounds:)`.

### 8.4 `@ViewInvalidating(.display)` + Direct Layer Write = Wasted Redraw

**Symptom**: Your property uses `@ViewInvalidating(.display)` AND its `didSet`
writes directly to the layer. You think you're optimizing; you're actually
doing the work twice.

**Explanation**: `@ViewInvalidating(.display)` triggers `needsDisplay = true`
after the property changes. If you *also* write `layer?.borderColor = ...` in
`didSet`, both happen:

1. `didSet` writes the layer property directly → CoreAnimation schedules render
2. `@ViewInvalidating` sets `needsDisplay = true` → display cycle runs →
   `updateLayer` is called → your updateLayer re-writes the same value

The `@ViewInvalidating` trigger is wasted. Worse, if `drawRect:` path is active,
it allocates a new bitmap and re-rasterizes the full content just to honor a
borderColor change.

**Fix**: For properties that map directly to non-synced layer properties
(`borderWidth`, `borderColor`, etc.), drop `@ViewInvalidating` entirely. Use
`didSet` alone. CoreAnimation picks up the change on the next frame without a
full display cycle.

Reserve `@ViewInvalidating` for properties that *need* a real redraw
(e.g., text content, font, things that change the rasterized pixels).

### 8.5 Initial Values Lost When Only Using `didSet`

**Symptom**: You set properties via Storyboard / `@IBInspectable`, but they
don't appear on first render.

**Cause**: Property order during init:

1. `init?(coder:)` begins decoding
2. Decoder writes stored property values → `didSet` fires
3. But at this point, `self.layer` is still `nil` (layer creation is deferred
   to `_updateLayerBackedness` during the next layout pass)
4. `didSet` writes `layer?.borderColor = ...` but `layer` is nil → no-op
5. Later: `setup()` runs → `wantsLayer = true`
6. First display cycle: layer is created (with default values), `updateLayer`
   is called
7. If `updateLayer` doesn't read from the stored properties, the Storyboard
   values are forever lost

**Fix**: Always also apply the values inside `updateLayer()`:

```swift
open override func updateLayer() {
    super.updateLayer()
    layer?.cornerRadius = bounds.height / 2
    // Belt-and-suspenders: idempotent with didSet, but ensures
    // storyboard/init values are applied after layer creation.
    layer?.borderColor = borderColor?.cgColor
    layer?.borderWidth = borderWidth
}
```

`didSet` handles runtime updates (zero-cost direct layer writes); `updateLayer`
handles initial setup and any full-display-cycle refresh.

### 8.6 NSTextField's Surprising Default Redraw Policy

**Symptom**: Plain layer-backed views use `.onSetNeedsDisplay` (only redraw
when `setNeedsDisplay` is called). NSTextField seems to redraw during every
bounds change. You can't figure out why.

**Cause**: NSTextField overrides `_preferredLayerContentsRedrawPolicy`:

```c
-[NSTextField _preferredLayerContentsRedrawPolicy]() {
    return 2;   // .duringViewResize
}
```

Policy `2` means "redraw during view resize," not "redraw only when needed."
This is reasonable for text (layout changes with bounds), but it's a hidden
cost for every NSTextField in your UI.

Combined with `_needsRedisplayOnFrameChange`:

```c
-[NSView _needsRedisplayOnFrameChange]() {
    if (!self->_layer) return YES;
    return self->_isInclusiveLayerBacked
        || [self layerContentsRedrawPolicy] >= 2;  // .duringViewResize or higher
}
```

Every bounds change on an NSTextField triggers `setNeedsDisplay` → `updateLayer`/`drawRect:`
call. This is actually **good for us** in the modern path — our `updateLayer`
override gets called on every resize, which is exactly when `cornerRadius =
bounds.height / 2` needs to recompute.

But be aware: if you profile NSTextField resize and see more redraws than you
expected, this is why.

### 8.7 Recommending Method 4 With `layout()` Was Wrong for `cornerRadius`

**Symptom**: We initially suggested the "optimized" pattern of setting
`cornerRadius` in `layout()` instead of `drawRect:` / `updateLayer`.

**Cause**: We confused "which properties are in the sync table" with "where is
it safe to set layer properties." The rule is:
- `borderColor`/`borderWidth`: NOT in sync table → safe anywhere
- `cornerRadius`: IS in sync table (no guard flag) → safe only in display cycle

`layout()` runs **before** the display cycle. After `layout()` returns, AppKit
may trigger `_updateAllLayerPropertiesFromView` which reads `self->_cornerRadius`
(the NSView private ivar, default 0) and writes it to `layer.cornerRadius`,
overwriting whatever you set in `layout()`.

**Fix**: Set `cornerRadius` inside `updateLayer()` (or `drawRect:` if stuck on
legacy path). These are guaranteed to run after property sync and before
CoreAnimation commits.

---

## 9. UIFoundation Practice Patterns

### 9.1 `InsetsTextFieldCell` — The Correct Way

```swift
open class InsetsTextFieldCell: NSTextFieldCell {
    open var contentInsets: NSEdgeInsets = .box.zero

    // ✅ Layout methods only — no drawing method overrides
    open override func cellSize(forBounds rect: NSRect) -> NSSize {
        super.cellSize(forBounds: rect.box.inset(by: contentInsets))
    }

    open override func drawingRect(forBounds rect: NSRect) -> NSRect {
        super.drawingRect(forBounds: rect.box.inset(by: contentInsets))
    }

    open override func titleRect(forBounds rect: NSRect) -> NSRect {
        super.titleRect(forBounds: rect.box.inset(by: contentInsets))
    }

    // Field editor positioning
    open override func edit(withFrame rect: NSRect, in controlView: NSView, editor textObj: NSText, delegate: Any?, event: NSEvent?) {
        super.edit(withFrame: rect.box.inset(by: contentInsets), in: controlView, editor: textObj, delegate: delegate, event: event)
    }

    open override func select(withFrame rect: NSRect, in controlView: NSView, editor textObj: NSText, delegate: Any?, start selStart: Int, length selLength: Int) {
        super.select(withFrame: rect.box.inset(by: contentInsets), in: controlView, editor: textObj, delegate: delegate, start: selStart, length: selLength)
    }

    // ❌ Do NOT override drawInterior(withFrame:in:) or draw(withFrame:in:)
    //    — they trigger AppKit's _cellOverridesDrawingMethods flag and
    //    permanently force the cell's owner into the legacy drawRect path.
}
```

**Why it works**:
- `_NSSubclassOverridesSelector(NSTextFieldCell, InsetsTextFieldCell, drawInteriorWithFrame:inView:)` returns `NO`
- `_cellOverridesDrawingMethods` stays `0`
- NSTextField's `wantsSeparatedSubviews` can return `YES`
- NSTextField's `wantsUpdateLayer` returns `YES`
- Modern rendering path stays available
- The visualProvider internally calls `cell.drawingRectForBounds:` which delegates
  to our override — insets are applied naturally without any drawing-method override.

### 9.2 `RoundedBorderLabel` — Three-Tier Cooperation

```swift
@IBDesignable
open class RoundedBorderLabel: Label {
    @IBInspectable
    open dynamic var borderColor: NSColor? = nil {
        didSet { layer?.borderColor = borderColor?.cgColor }   // Fast runtime update
    }

    @IBInspectable
    open dynamic var borderWidth: CGFloat = 0 {
        didSet { layer?.borderWidth = borderWidth }            // Fast runtime update
    }

    open override func setup() {
        super.setup()
        wantsLayer = true
    }

    // ✅ Do NOT override draw(_:) — it would trip _textFieldOverridesDrawingMethods
    open override func updateLayer() {
        super.updateLayer()                          // NSTextField updates labelView
        layer?.cornerRadius = bounds.height / 2     // Safe: display cycle window
        // Belt-and-suspenders: initial values from IB/coder
        layer?.borderColor = borderColor?.cgColor
        layer?.borderWidth = borderWidth
    }
}
```

**Three-tier cooperation**:

1. **`didSet`** — Zero-cost runtime updates. Setting `borderColor = .red`
   writes directly to the layer property. CoreAnimation picks it up on the
   next frame. No display cycle, no bitmap, no `needsDisplay`.

2. **`updateLayer()`** — Display cycle's authoritative update. Called by
   `NSViewBackingLayer.display` every time the view redisplays. Sets
   `cornerRadius` (the one property that MUST be in the display-cycle window),
   and re-applies `borderColor`/`borderWidth` as a safety net for the case
   where `didSet` fired before `layer` existed (e.g., during `init?(coder:)`).

3. **`super.updateLayer()`** — NSTextField's own updateLayer. Sets
   `layer.contents = nil` and calls `visualProvider.updateLayer`, which in
   turn calls `updateLabelView` to position/update the internal labelView
   subview that actually renders the text. Your layer's `cornerRadius`
   clips the label view visually; `borderColor`/`borderWidth` draws around it.

**Why this works**:
- `_cellOverridesDrawingMethods = NO` (from `InsetsTextFieldCell` fix)
- `_textFieldOverridesDrawingMethods = NO` (no `draw(_:)` override)
- `wantsUpdateLayer = YES`
- Modern path engaged — `self.layer.contents = nil`, text rendered by
  labelView, your `cornerRadius`/border applied to the parent layer

**Performance wins**:
- Changing `borderColor` at runtime: zero bitmap allocation, zero redraw,
  pure GPU property update
- Changing `bounds`: labelView re-lays-out, updateLayer refreshes
  `cornerRadius`, no bitmap work on `self` layer
- Changing `stringValue`: labelView handles it, `self` layer untouched
- Initial display: modern path, no backing store

---

## 10. How to Verify At Runtime

Two runtime checks can confirm which path a control is on:

### Check 1: Cell method overrides

```swift
func diagnoseCellOverrides(_ cellClass: NSTextFieldCell.Type) {
    let baseClass: AnyClass = NSTextFieldCell.self
    let drawInteriorSel = #selector(NSTextFieldCell.drawInterior(withFrame:in:))
    let drawSel = #selector(NSTextFieldCell.draw(withFrame:in:))
    
    let overridesDrawInterior = 
        class_getMethodImplementation(cellClass, drawInteriorSel) 
        != class_getMethodImplementation(baseClass, drawInteriorSel)
    let overridesDraw = 
        class_getMethodImplementation(cellClass, drawSel) 
        != class_getMethodImplementation(baseClass, drawSel)
    
    let flagged = overridesDrawInterior || overridesDraw
    print("\(cellClass): _cellOverridesDrawingMethods would be \(flagged ? "YES (legacy)" : "NO (modern)")")
}
```

### Check 2: View subclass drawRect override

```swift
func diagnoseViewDrawOverride(_ viewClass: NSView.Type) {
    let baseClass: AnyClass = NSTextField.self
    let drawRectSel = #selector(NSView.draw(_:))
    
    let overrides = 
        class_getMethodImplementation(viewClass, drawRectSel)
        != class_getMethodImplementation(baseClass, drawRectSel)
    
    print("\(viewClass): _textFieldOverridesDrawingMethods would be \(overrides ? "YES (legacy)" : "NO (modern)")")
}
```

### Check 3: Actual `wantsUpdateLayer` value

```swift
// Must be attached to a layer-backed view tree first
let host = NSView(frame: NSRect(x: 0, y: 0, width: 400, height: 200))
host.wantsLayer = true
host.addSubview(suspect)
_ = host.layer

print("\(type(of: suspect)).wantsUpdateLayer = \(suspect.wantsUpdateLayer)")
```

If both override checks return NO but `wantsUpdateLayer` is still NO, the issue
is likely in the bezel configuration (style == 2 is the only excluded value).

The Example project (`UIFoundationExample-macOS/AppDelegate.swift`'s
`InsetsLabelDemoViewController`) runs all three checks on startup and prints
results to stderr.

---

## 11. Appendix: Key Function Addresses

(macOS 26.4, arm64e)

| Symbol | Address | Size |
|--------|---------|------|
| `-[NSControl wantsUpdateLayer]` | `0x1849ffea4` | 0xa8 |
| `-[NSControl updateLayer]` | `0x184ae1918` | 0x60 |
| `-[NSControl drawRect:]` | `0x184ae84b0` | 0xf0 |
| `-[NSButtonCell wantsUpdateLayerInView:]` | `0x184a24594` | 0x88 |
| `-[NSButtonCell updateLayerWithFrame:inView:]` | `0x184aeb8e0` | 0x98 |
| `-[NSButtonCell _eligibleForSeparatedContentSubviewsInView:]` | `0x1849ffb00` | 0x1b0 |
| `-[NSButtonCell _wantsSeparatedContentSubviewsInView:]` | `0x1849ffa90` | 0x5c |
| `+[NSButtonAppearanceBasedVisualProvider visualProviderForButtonCell:]` | `0x18508bff4` | 0x174 |
| `-[NSButtonAppearanceBasedVisualProvider updateLayer]` | `0x1850923b8` | 0x1c0 |
| `-[NSTextField wantsUpdateLayer]` | `0x184a0a128` | 0x58 |
| `-[NSTextField updateLayer]` | `0x18515825c` | 0x70 |
| `-[NSTextField _preferredLayerContentsRedrawPolicy]` | `0x184a0a120` | 0x8 |
| `-[NSTextFieldCell drawingRectForBounds:]` | `0x184aa8f1c` | 0xa0 |
| `-[NSTextFieldCell drawWithFrame:inView:]` | `0x184b61b44` | 0x12c |
| `-[NSTextFieldCell drawInteriorWithFrame:inView:]` | `0x184b61d50` | 0xa8 |
| `-[NSTextFieldCell _wantsSeparatedContentSubviewsInView:]` | `0x18515debc` | 0x50 |
| `-[NSTextFieldAppearanceBasedVisualProvider initWithTextFieldCell:]` | `0x1851593b0` | 0xe4 |
| `-[NSTextFieldAppearanceBasedVisualProvider wantsSeparatedSubviews]` | `0x18515b774` | 0x94 |
| `+[NSTextFieldAppearanceBasedVisualProvider wantsSeparatedSubviewsWithBezelConfiguration:]` | `0x18515b82c` | 0x30 |
| `-[NSTextFieldAppearanceBasedVisualProvider drawingRectForBounds:textBoundsSizeProvider:]` | `0x18515a0a4` | 0x298 |
| `-[NSTextFieldAppearanceBasedVisualProvider drawInteriorWithFrame:textDrawingHandler:]` | `0x18515aef0` | 0x19c |
| `-[NSTextFieldAppearanceBasedVisualProvider updateLayer]` | `0x18515bac4` | 0x50 |
| `-[NSTableView wantsUpdateLayer]` | `0x184a44fe8` | 0x74 |
| `-[NSTableView updateLayer]` | `0x184aee7a0` | 0xb8 |
| `-[NSScrollView updateLayer]` | `0x184aedeb8` | 0x2a4 |
| `-[NSImageView wantsUpdateLayer]` | `0x184a9361c` | 0x4 |
| `-[NSImageView updateLayer]` | `0x184aeefec` | 0xbc |
| `-[NSVisualEffectView wantsUpdateLayer]` | `0x184a7ca04` | 0x8 |
| `-[NSVisualEffectView updateLayer]` | `0x184ae138c` | 0xb0 |
| `-[NSSplitView wantsUpdateLayer]` | `0x184a358f0` | 0x54 |
| `-[NSSplitView updateLayer]` | `0x184b62080` | 0x4 (empty) |
| `_NSSubclassOverridesSelector` | `0x1849b3c04` | 0x68 |

---

## Cross-References

- **`AppKit-Layer-Backing-Internals.md`** — NSView-level layer backing
  mechanics. Read first if you need the foundation (property sync, guard flags,
  display cycle, etc.).

- **`Sources/UIFoundationAppKit/Text/InsetsTextFieldCell.swift`** — Concrete
  example of the "layout methods only" pattern.

- **`Sources/UIFoundationAppKit/Text/BorderLabel.swift`** — Concrete example
  of the three-tier cooperation pattern.

- **`UIFoundationExample-macOS/UIFoundationExample-macOS/AppDelegate.swift`** —
  `InsetsLabelDemoViewController` demonstrates how to verify the path at
  runtime with three diagnostic checks.
