# AppKit Layer Backing Internals

> Based on reverse engineering macOS 26.4 AppKit (arm64e) via IDA Pro decompilation + RuntimeViewer runtime introspection.

> **See also**: [`AppKit-Control-Rendering-Internals.md`](AppKit-Control-Rendering-Internals.md)
> for the control-layer companion document, covering NSControl/NSCell/NSTextField/NSButton's
> double-layer override detection, separated-subviews architecture, and the pitfalls
> of overriding `drawInterior` / `draw(_:)` on controls.

---

## Table of Contents

- [1. Overview](#1-overview)
- [2. Two Modes: Layer Backing vs Layer Hosting](#2-two-modes-layer-backing-vs-layer-hosting)
- [3. Layer Creation Flow](#3-layer-creation-flow)
  - [3.1 setWantsLayer:](#31-setwantslayer)
  - [3.2 _updateLayerBackedness](#32-_updatelayerbackedness)
  - [3.3 _createLayerAndInitialize](#33-_createlayerandinitialize)
  - [3.4 setLayer:](#34-setlayer)
- [4. Property Sync: View Ivar -> Layer (One-Way)](#4-property-sync-view-ivar---layer-one-way)
  - [4.1 Sync Mechanism](#41-sync-mechanism)
  - [4.2 Full Property Sync](#42-full-property-sync)
  - [4.3 Guard Flags](#43-guard-flags)
  - [4.4 Safety Table](#44-safety-table)
- [5. Display Cycle](#5-display-cycle)
  - [5.1 NSViewBackingLayer.display](#51-nsviewbackinglayerdisplay)
  - [5.2 wantsUpdateLayer Auto-Detection](#52-wantsupdatelayer-auto-detection)
  - [5.3 _NSViewUpdateLayer](#53-_nsviewupdatelayer)
  - [5.4 Traditional Draw Path](#54-traditional-draw-path)
- [6. NSView's Private Layer Properties](#6-nsviews-private-layer-properties)
- [7. layerContentsRedrawPolicy](#7-layercontentsredrawpolicy)
- [8. Inclusive Layer Backing](#8-inclusive-layer-backing)
- [9. Layer Tree Management](#9-layer-tree-management)
- [10. Correct Patterns](#10-correct-patterns)
- [11. Common Mistakes](#11-common-mistakes)
- [12. Hidden Behaviors (Reverse Engineering Only)](#12-hidden-behaviors-reverse-engineering-only)
  - [12.1 actionForLayer:forKey: — Animation Key Mapping](#121-actionforlayerforkey--animation-key-mapping)
  - [12.2 updateLayer Called Outside Display Cycle](#122-updatelayer-called-outside-display-cycle)
  - [12.3 Shadow Opacity Hardcoded to 1.0](#123-shadow-opacity-hardcoded-to-10)
  - [12.4 Shadow Setter Also Controls masksToBounds](#124-shadow-setter-also-controls-maskstobounds)
  - [12.5 wantsUpdateLayer Cache Invalidation](#125-wantsupdatelayer-cache-invalidation)
  - [12.6 Draw Delegate — Semi-Transparent Non-Layer-Backed Views](#126-draw-delegate--semi-transparent-non-layer-backed-views)
  - [12.7 Auto Layer Backing of Window Root](#127-auto-layer-backing-of-window-root)
  - [12.8 Crossfade Contents Transition](#128-crossfade-contents-transition)
  - [12.9 _needsRedisplayOnFrameChange Logic](#129-_needsredisplayonframechange-logic)
  - [12.10 _performWithoutAnimation: Is Not What You Think](#1210-_performwithoutanimation-is-not-what-you-think)
  - [12.11 Geometry Flipping XOR](#1211-geometry-flipping-xor)
  - [12.12 _ViewLayerSurface — Associated Object Mechanism](#1212-_viewlayersurface--associated-object-mechanism)
- [13. NSView Ivar Layout](#13-nsview-ivar-layout)
- [14. Appendix: Decompiled Methods](#14-appendix-decompiled-methods)

---

## 1. Overview

AppKit's layer backing system is the bridge between NSView's drawing model and Core Animation's layer tree. When a view is "layer-backed," AppKit creates and manages a `CALayer` on the view's behalf, automatically synchronizing view properties to layer properties.

The key insight from reverse engineering is that **layer properties are one-way projections of view ivars**. AppKit treats the view's instance variables as the source of truth and overwrites layer properties from those ivars at multiple points during the view lifecycle. This is why Apple's documentation says not to directly modify layer properties on a layer-backed view.

However, the implementation is more nuanced than the documentation suggests — some properties have guard flags that make direct modification safe under specific conditions, while others are unconditionally overwritten.

---

## 2. Two Modes: Layer Backing vs Layer Hosting

AppKit distinguishes two modes internally via the `_appkitManagesLayer` bitfield (offset +168, bit 0):

### Layer Backing (AppKit Owns the Layer)

- Entered by setting `wantsLayer = true` and letting AppKit create the layer
- `_appkitManagesLayer = 1`
- View is set as the layer's `delegate`
- AppKit performs **full property sync** (13 properties from view ivars to layer)
- `layerContentsRedrawPolicy` defaults to `.onSetNeedsDisplay`
- AppKit manages sublayer ordering via `_buildLayerTree` / `_insertMissingSubviewLayers`
- Drawing happens via `drawRect:` or `updateLayer`

### Layer Hosting (You Own the Layer)

- Entered by calling `setLayer:` with your own layer **before** setting `wantsLayer = true`
- `_appkitManagesLayer = 0`
- View is **not** the layer's delegate
- AppKit performs only **minimal sync** (geometry, hidden, masksToBounds)
- `layerContentsRedrawPolicy` is forced to `.never`
- You are fully responsible for sublayer management
- No AppKit drawing on the layer

### Comparison Table

| Aspect | Layer Backing | Layer Hosting |
|--------|--------------|---------------|
| Who creates layer | AppKit via `makeBackingLayer` | Developer via `setLayer:` |
| `_appkitManagesLayer` | 1 | 0 |
| View is delegate | Yes | No |
| Property sync | Full (13 properties) | Minimal (3 properties) |
| Redraw policy | `.onSetNeedsDisplay` (default) | `.never` (forced) |
| Sublayer management | AppKit | Developer |
| Drawing support | `drawRect:` / `updateLayer` | None |

---

## 3. Layer Creation Flow

### 3.1 setWantsLayer:

`setWantsLayer:` does **not** directly create a layer. It only sets a flag bit:

```c
-[NSView setWantsLayer:](self, wantsLayer) {
    // Guard: only proceed if value actually changes or layer is missing
    if (wantsLayer == ((_atomicFlags._wantsLayer) == 0) || (wantsLayer && !self->_layer)) {
        [self willChangeValueForKey:@"wantsLayer"];
        
        os_unfair_lock_lock(&self->_atomicFlagsLock);
        // Set bit 16 of _atomicFlags (the _wantsLayer flag)
        self->_atomicFlags = (self->_atomicFlags & 0xFFFEFFFF) | (wantsLayer ? 0x10000 : 0);
        os_unfair_lock_unlock(&self->_atomicFlagsLock);
        
        [self didChangeValueForKey:@"wantsLayer"];
    }
}
```

The `wantsLayer` getter simply reads bit 16 of `_atomicFlags`:

```c
-[NSView wantsLayer](self) {
    return self->_atomicFlags._wantsLayer;  // bit 16 at offset +164
}
```

The actual layer creation is deferred to `_updateLayerBackedness`, which is called later during the layout/display cycle.

### 3.2 _updateLayerBackedness

This is the **core decision maker** for whether and how a view gets a layer. It's a 0x308-byte method with complex branching:

```
_updateLayerBackedness(self):
  |
  |-- Guard: return if self == nil
  |-- Guard: return if _superview exists AND _appkitManagesLayer is set
  |
  |-- if wantsLayer == YES:
  |     v2 = [self canDrawSubviewsIntoLayer]   // determines "inclusive" mode
  |     v3 = 1  (needs layer)
  |
  |-- if wantsLayer == NO:
  |     |-- if _hasAutoSetWantsLayer (byte+176 bit 5) is set:
  |     |     if [self canDrawSubviewsIntoLayer]:
  |     |       v2 = 1  (inclusive)
  |     |     else:
  |     |       v2 = _hasAutoCanDrawSubviewsIntoLayer (byte+174 bit 4)
  |     |-- else: v2 = 0, v3 = 0 (no layer needed)
  |
  |-- Check NSViewManageLayerTreeLoosely app config
  |-- v5 = (!NSViewManageLayerTreeLoosely) & v2   // inclusive flag
  |
  |-- Assert: !(v3 && v5)  // "!inclusive" assertion
  |
  |-- if state changed (v3 != had_no_layer, or v5 differs from _isInclusiveLayerBacked):
  |     |
  |     |-- Mark layer tree as needing rebuild (_setViewsNeedBuildLayerTree)
  |     |-- Disable CA actions (CATransaction.setDisableActions = true)
  |     |
  |     |-- if v3 (needs layer):
  |     |     [self setNeedsDisplay:YES]
  |     |     if v5 (inclusive):
  |     |       |-- Create NSViewBackingLayer, name = "ClassName (inclusive)"
  |     |       |-- [self setLayer: backingLayer]
  |     |       |-- _appkitManagesLayer = 1
  |     |       |-- [backingLayer setDelegate: self]
  |     |       |-- Execute initialization block without animation
  |     |       |-- [backingLayer setNeedsDisplay]
  |     |       |-- if layerContentsRedrawPolicy == 0: set to 1 (.onSetNeedsDisplay)
  |     |     else (non-inclusive):
  |     |       |-- [self _createLayerAndInitialize]
  |     |
  |     |-- else (remove layer):
  |     |     [self _removeLayerIfOwnedByAppKit]
  |     |
  |     |-- [self _updateDrawDelegateForAlphaValue]
  |     |-- Set _isInclusiveLayerBacked flag
  |     |-- Restore CA actions
  |     |-- if layerContentsRedrawPolicy >= 1: [self setNeedsDisplay:YES]
```

### 3.3 _createLayerAndInitialize

Creates the actual layer via `makeBackingLayer` and performs initial setup:

```c
-[NSView _createLayerAndInitialize](self) {
    CALayer *layer = [self _createLayer];  // calls makeBackingLayer
    
    // Assert: layer must not be nil
    NSAssert(layer != nil, @"Views must return a valid layer from -makeBackingLayer.");
    
    // Name the layer for debugging
    if ([layer isKindOfClass:[NSViewBackingLayer class]]) {
        [layer setName: [self className]];
    } else {
        [layer setName: [NSString stringWithFormat:@"%@: %@",
            [layer className], [self className]]];
    }
    
    // Assign layer and set up backing
    [self setLayer: layer];                    // triggers full property sync
    self->_appkitManagesLayer = 1;             // mark as AppKit-managed
    [self->_layer setDelegate: self];          // view becomes delegate
    
    // Initialize without animation
    [NSView _performWithoutAnimation:^{
        // Initial layer configuration block
    }];
    
    // Mark dirty if needed
    if ([self layerContentsRedrawPolicy] >= 1) {
        CGRect bounds = [self bounds];
        [self _setLayerNeedsDisplayInViewRect: bounds];
    }
}
```

The default `makeBackingLayer` simply returns an `NSViewBackingLayer` instance:

```c
-[NSView makeBackingLayer](self) {
    return [NSViewBackingLayer layer];
}
```

### 3.4 setLayer:

The most complex method in the layer system (0x488 bytes). It handles both adding and removing layers:

#### Removing the Old Layer

```c
if (self->_layer != newLayer) {
    // Notify layer tree system
    [self._viewRoot _setViewsNeedBuildLayerTree];
    
    CALayer *oldLayer = self->_layer;
    if (oldLayer) {
        [oldLayer removeFromSuperlayer];
        [oldLayer NS_setView: nil];           // break view association
        
        // Clear delegate only if AppKit owns this layer
        if (self->_appkitManagesLayer && [oldLayer delegate] == self) {
            [oldLayer setDelegate: nil];
        }
        
        self->_isInclusiveLayerBacked = 0;
        
        // Migrate sublayers without animation
        NSArray *sublayers = [[oldLayer sublayers] copy];
        [NSView _performWithoutAnimation:^{
            // Reparent sublayers to new layer
        }];
        
        [oldLayer autorelease];
    }
```

#### Setting the New Layer

```c
    self->_layer = [newLayer retain];
    
    if (newLayer) {
        [newLayer NS_setView: self];                    // associate view
        [newLayer setAllowsGroupBlending: self->_allowsGroupBlending];
        [newLayer setEdgeAntialiasingMask: 0];          // hardcoded: no edge AA
        
        BOOL isBackingLayer = [newLayer respondsToSelector:@selector(...)];
        self->_appkitManagesLayer = isBackingLayer;
        
        if (!isBackingLayer) {
            // Layer Hosting mode
            [self setLayerContentsRedrawPolicy: NSViewLayerContentsRedrawNever];
            [self _updateLayerGeometryFromView];
            [self _updateLayerHiddenFromView];
            // Workarounds for specific apps (Textview, MavensLabelView)
            [self _updateLayerMasksToBoundsFromView];
        }
        
        // Add to ancestor's layer
        CALayer *ancestorLayer = [[self _ancestorWithLayer] layer];
        [ancestorLayer addSublayer: self->_layer];
        
        if (isBackingLayer) {
            // Layer Backing mode
            // Optionally enable async drawing
            if (NSViewShouldSetDrawsAsynchronously) {
                [newLayer setContentsFormat: kCAContentsFormatRGBA8Uint];
                [newLayer setDrawsAsynchronously: YES];
            }
            
            // ★ Full property sync
            [self _updateAllLayerPropertiesFromView];
        }
    }
```

#### Post-Assignment

```c
    // Fix sublayer ordering
    [self._superview _insertMissingSubviewLayers];
    [self _rootLayerBackWindowIfNeeded];
    
    // Mark dirty
    if (self->_layer && [self layerContentsRedrawPolicy] >= 1 && ![self _drawsNothing]) {
        [self->_layer setNeedsDisplay];
    }
    
    // Notify superview
    [self _setWindowNeedsDisplayInViewsDrawableRect];
    [_NSAutomaticFocusRing setNeedsUpdateForView: self];
    
    // Engage auto layout if needed
    if ([self _needsLayoutEngine] && ![self _isDeallocating]) {
        [self _engageAutolayout];
    }
    
    // Handle wantsUpdateLayer path
    if ([self wantsUpdateLayer]) {
        [self setNeedsLayout: YES];
        if (!self->_layer && ![self _isDeallocating]) {
            [self _didRemoveLayer];
        }
    }
}
```

---

## 4. Property Sync: View Ivar -> Layer (One-Way)

### 4.1 Sync Mechanism

Every NSView property that has a corresponding CALayer property follows a consistent pattern. When the view's setter is called, it:

1. Stores the new value in the view's ivar
2. Calls `_performAnimatedAction:` with a block
3. The block calls the corresponding `_updateLayer*FromView` method
4. That method reads the ivar and writes to the layer

```c
// _performAnimatedAction: — only executes the block if view is layer-backed
-[NSView _performAnimatedAction:](self, block) {
    if ([self _isLayerBacked]) {
        block();  // execute the layer sync block
    }
}
```

#### Concrete Examples

**setAlphaValue:**

```c
-[NSView setAlphaValue:](self, alphaValue) {
    if (self->_alphaValue != alphaValue) {
        if (_isLayerBacked) {
            self->_alphaValue = alphaValue;
            [self _performAnimatedAction:^{
                [self _updateLayerOpacityFromView];
                // → [self.layer setOpacity: self->_alphaValue]
            }];
        } else {
            [self setNeedsDisplay:YES];
            self->_alphaValue = alphaValue;
            [self setNeedsDisplay:YES];
        }
    }
}
```

**setShadow:**

```c
-[NSView setShadow:](self, shadow) {
    if (shadow != self->_shadow) {
        self->_shadow = [shadow copy];
        [self _performAnimatedAction:^{
            [self _updateLayerShadowFromView];
            // → [self.layer setShadowColor/Offset/Radius/Opacity: ...]
        }];
    }
}
```

**setFrameSize:** — direct call, no block indirection:

```c
-[NSView setFrameSize:](self, newSize) {
    // ... validation, animation checks ...
    self->_frame.size = newSize;
    [self _updateLayerGeometryFromView];  // immediate sync, no block
    // ... subview resizing, layout, notifications ...
}
```

### 4.2 Full Property Sync

`_updateAllLayerPropertiesFromView` syncs all 13 layer-relevant properties at once:

```c
-[NSView _updateAllLayerPropertiesFromView](self) {
    [self _updateLayerGeometryFromView];            // frame/bounds/position/anchorPoint
    [self _updateLayerShadowFromView];              // shadow*
    [self _updateLayerHiddenFromView];              // hidden
    [self _updateLayerFiltersFromView];             // filters
    [self _updateLayerBackgroundFiltersFromView];   // backgroundFilters
    [self _updateLayerCompositingFilterFromView];   // compositingFilter
    [self _updateLayerMaskFromView];                // mask
    [self _updateLayerOpacityFromView];             // opacity
    [self _updateLayerCanDrawConcurrentlyFromView]; // drawsAsynchronously
    [self _updateLayerContentsGravityFromView];     // contentsGravity
    [self _updateLayerMasksToBoundsFromView];       // masksToBounds
    [self _updateLayerBackgroundColorFromView];     // backgroundColor (GUARDED)
    [self _updateLayerCornerRadiusFromView];        // cornerRadius
}
```

**When this runs:**
- During `setLayer:` for backing layers (`_appkitManagesLayer == 1`)
- During layer tree rebuilds (`_buildLayerTree`)
- View hierarchy changes that re-evaluate layer backedness

### 4.3 Guard Flags

Not all sync methods are created equal. Some check a guard flag before overwriting:

#### `_setBackgroundColor` Guard (offset +178, 1 bit)

```c
-[NSView setBackgroundColor:](self, color) {
    self->_setBackgroundColor = 1;              // ★ Set guard flag
    self->_backgroundColor = [color copy];      // Store in ivar (offset +424)
    if (self->_layer)
        [self _updateLayerBackgroundColorFromView];
}

-[NSView _updateLayerBackgroundColorFromView](self) {
    if (!self->_setBackgroundColor)
        return;                                 // ★ Guard: skip if never set via NSView API
    
    NSAppearance *appearance = [self effectiveAppearance];
    [NSAppearance _performWithCurrentAppearance:appearance usingBlock:^{
        CGColorRef cgColor = [self->_backgroundColor CGColor];
        [self.layer setBackgroundColor: cgColor];
    }];
}
```

**Implication**: If you never call `[view setBackgroundColor:]`, the `_setBackgroundColor` flag stays 0, and `_updateLayerBackgroundColorFromView` is a **no-op**. Direct `layer.backgroundColor = ...` will survive all property syncs.

#### No Guard: `cornerRadius`

```c
-[NSView _updateLayerCornerRadiusFromView](self) {
    CALayer *layer = [self layer];
    CGFloat radius = self->_cornerRadius;       // ivar at offset +416, default 0.0
    [layer setCornerRadius: radius];            // Always overwrites, no guard
}
```

### 4.4 Safety Table

| Layer Property | View Source | Sync Method | Guard? | Direct Modification Safe? |
|---|---|---|---|---|
| `backgroundColor` | `_backgroundColor` (+424) | `_updateLayerBackgroundColorFromView` | **YES** (`_setBackgroundColor` flag) | Safe if `setBackgroundColor:` never called |
| `cornerRadius` | `_cornerRadius` (+416) | `_updateLayerCornerRadiusFromView` | NO | **Unsafe** — reset to 0.0 on full sync |
| `opacity` | `_alphaValue` (+328) | `_updateLayerOpacityFromView` | NO | **Unsafe** — always synced from `alphaValue` |
| `shadow*` | `_shadow` (+360) | `_updateLayerShadowFromView` | NO | **Unsafe** — always synced from `NSShadow` |
| `hidden` | `_atomicFlags._hidden` | `_updateLayerHiddenFromView` | NO | **Unsafe** — always synced from view hidden |
| `masksToBounds` | computed | `_updateLayerMasksToBoundsFromView` | NO | **Unsafe** — computed: `clipsToBounds && !shadow` |
| `contentsGravity` | computed | `_updateLayerContentsGravityFromView` | NO | **Unsafe** — computed: `layerContentsPlacement + isFlipped` |
| `filters` | `_contentFilters` (+336) | `_updateLayerFiltersFromView` | NO | **Unsafe** — always synced from `contentFilters` |
| `backgroundFilters` | `_backgroundFilters` (+344) | `_updateLayerBackgroundFiltersFromView` | NO | **Unsafe** |
| `compositingFilter` | `_compositingFilter` (+352) | `_updateLayerCompositingFilterFromView` | NO | **Unsafe** |
| `contents` | set in display cycle | N/A | N/A | Only safe inside `updateLayer` |

---

## 5. Display Cycle

### 5.1 NSViewBackingLayer.display

`NSViewBackingLayer` is the default backing layer class. Its `display` method (0x5cc bytes) is the entry point for all layer-backed drawing:

```
NSViewBackingLayer.display(self):
  |
  |-- view = [self NS_view]
  |-- if !view → goto cleanup
  |
  |-- [view _sendViewWillDraw]         // notify view tree
  |
  |-- if [view _isInclusiveLayerBacked]:
  |     |-- if !(view._allowsGroupBlending & 2) && inclusiveSubtreeDrawsNothing(view):
  |     |     [self setContents: nil]   // nothing to draw, skip
  |     |     goto cleanup
  |     |-- else: fall through to content rendering
  |
  |-- if [view wantsUpdateLayer]:       ★ FAST PATH
  |     |-- focusStack = [NSFocusStack currentFocusStack]
  |     |-- window = [view window]
  |     |-- [focusStack performWithFocusView:view inWindow:window usingBlock:^{
  |     |       NSAppearance *appearance = [view effectiveAppearance];
  |     |       [NSAppearance _performWithCurrentAppearance:appearance usingBlock:^{
  |     |           [NSGraphicsContext setCurrentContext: nil];  // no CGContext needed!
  |     |           _NSViewUpdateLayer(view);
  |     |       }];
  |     |   }];
  |     |-- goto cleanup
  |
  |-- if [view _drawsNothing]:
  |     [self setContents: nil]          // nothing to draw
  |     goto cleanup
  |
  |-- // Traditional draw path (backing store rendering)
  |-- Check NSViewUseViewBackingStore config
  |-- scale = [self NS_suggestedContentsScale]
  |-- bounds = [self bounds]
  |
  |-- // Pixel budget: cap scale to avoid excessive memory
  |-- maxScale = sqrt(268435456.0 / |bounds.area|)
  |-- [self setContentsScale: min(scale, maxScale)]
  |
  |-- // Set opaque from view
  |-- if NSViewBackingLayerSetOpaque:
  |     [self setOpaque: [view _appearanceSensitiveIsOpaque]]
  |
  |-- // Delegate path (non-backing-store)
  |-- if delegate doesn't respond to specific selector:
  |     [super display]                  // CALayer's display
  |     goto cleanup
  |
  |-- // Backing store path (NSViewBackingLayerContents)
  |-- contents = [self contents] as? NSViewBackingLayerContents ?? new
  |-- preparedRect = [view preparedContentRect]
  |-- visibleRect = [view visibleRect]
  |
  |-- // Smart content region calculation:
  |-- // If intersection(visibleRect, bounds) >= 70.7% of bounds area,
  |-- // merge visible + bounds into a single draw region
  |-- if intersectionArea >= boundsArea * 0.707106781:
  |     drawRegion = union(visibleRect, bounds)
  |
  |-- [contents setPixelTransform: view._backingTransform]
  |-- [contents setRetainedRect: fullRegion]
  |-- [contents setRequiredRect: drawRegion]
  |-- [contents update:^(CGContextRef ctx) {
  |       [self drawInContext: ctx];
  |   }];
  |-- [self setContents: contents]
  |
  cleanup:
  |-- [view release]
```

### 5.2 wantsUpdateLayer Auto-Detection

AppKit automatically determines `wantsUpdateLayer` by checking if the subclass overrides `drawRect:` at runtime:

```arm64
-[NSView wantsUpdateLayer]:
    ; Load _atomicFlags
    ADRP    X8, #_OBJC_IVAR_$_NSView._atomicFlags@PAGE
    LDRSW   X8, [X8, #_OBJC_IVAR_$_NSView._atomicFlags@PAGEOFF]
    ADD     X8, X0, X8
    LDRB    W8, [X8, #1]            ; byte+1 of _atomicFlags
    TBNZ    W8, #5, return_false    ; _drawnByAncestor → force NO

    ; Check cached result (_supportsDirectLayerContentsCache at offset +173)
    BL      _objc_msgSend$_supportsDirectLayerContentsCache
    CMP     W0, #2                  ; 0=NO, 1=YES, 2=unknown
    B.NE    use_cached_value

    ; Cache miss: compute by checking if drawRect: is overridden
    BL      _objc_msgSend$_classToCheckForWantsUpdateLayer  ; returns [NSView class]
    BL      _objc_opt_class                                  ; self's actual class
    BL      _NSSubclassOverridesSelector                     ; selector = drawRect:
    EOR     W20, W0, #1             ; NOT overridden → return YES
    BL      _objc_msgSend$_setSupportsDirectLayerContentsCache:

use_cached_value:
    CMP     W0, #0
    CSET    W20, NE                 ; 0 → NO, 1 → YES

return_false:
    MOV     W20, #0
```

**Key insight**: If your subclass does NOT override `draw(_:)` / `drawRect:`, `wantsUpdateLayer` automatically returns `true`. The result is cached per-class in `_supportsDirectLayerContentsCache` (2 bits at offset +173).

Related optimization — `_drawsNothing`:

```c
-[NSView _drawsNothing](self) {
    static IMP nsViewDrawRect = NULL;
    if (!nsViewDrawRect)
        nsViewDrawRect = [NSView instanceMethodForSelector:@selector(drawRect:)];
    return [self methodForSelector:@selector(drawRect:)] == nsViewDrawRect;
}
```

### 5.3 _NSViewUpdateLayer

The C function that actually invokes `updateLayer` on the view:

```c
void _NSViewUpdateLayer(NSView *view) {
    NSGraphicsContext *ctx = view->_renderContexts[2];
    [ctx becomeCurrentContext];
    
    kdebug_trace(735576253, view, 0, 0, 0);  // dtrace probe: begin
    
    if (NSObservationTrackingEnabled()) {
        [view _updateLayerWithObservationTracking];
    } else {
        [view updateLayer];
    }
    
    kdebug_trace(735576254, view, 0, 0, 0);  // dtrace probe: end
    
    [ctx resignCurrentContext];
}
```

And NSView's default `updateLayer` simply invokes the `_updateLayerHandler` block if one is set:

```c
-[NSView updateLayer](self) {
    id block = self->_updateLayerHandler;  // ivar at offset +384
    if (block) {
        block(self);
    }
}
```

### 5.4 Traditional Draw Path

When `wantsUpdateLayer` is `false` and the view overrides `drawRect:`, the traditional path is:

```
NSViewBackingLayer.drawInContext:(ctx)
  → [view drawLayer:self inContext:ctx]
    → -[NSView _drawRect:clip:]
      |
      |-- If printing (not drawing to screen):
      |     proceed to draw
      |
      |-- If layer-backed but not in traditional draw path:
      |     NSViewUpdateLayerSurface(self)
      |     return
      |
      |-- Subtract occluders (NSUseOccluders config)
      |     _NSViewSubtractOccludersFromRect(self, rect)
      |
      |-- [self setUpGState]
      |
      |-- if !NSIsEmptyRect(drawRect) || [self _drawRectIfEmpty...]:
      |     [NSGraphicsContext saveGraphicsState]
      |     
      |     if [self wantsDefaultClipping]:
      |       if drawing to screen:
      |         [self getRectsBeingDrawn:&rects count:&count]
      |         NSRectClipList(rects, count)
      |       else if clip:
      |         NSRectClip(rect)
      |     
      |     _NSViewDrawRect(self, rect)  → [self drawRect: rect]
      |     
      |     [NSGraphicsContext restoreGraphicsState]
```

---

## 6. NSView's Private Layer Properties

NSView has private accessors for properties commonly set directly on the layer:

### cornerRadius

```c
-[NSView cornerRadius]     { return [self _cornerRadius]; }       // thunk
-[NSView setCornerRadius:] { return [self _setCornerRadius:]; }   // thunk

-[NSView _cornerRadius](self) {
    return self->_cornerRadius;  // ivar at offset +416
}

-[NSView _setCornerRadius:](self, value) {
    if (self->_cornerRadius != value) {
        self->_cornerRadius = value;
        if (self->_layer)
            [self _updateLayerCornerRadiusFromView];
        [self _updateCornerConstraintsIfNeeded];
        [self _updateAdaptationLayoutGuideConstraintsIfNecessary];
    }
}
```

### backgroundColor

```c
-[NSView backgroundColor](self) {
    return [[self->_backgroundColor retain] autorelease];  // ivar at offset +424
}

-[NSView setBackgroundColor:](self, color) {
    self->_setBackgroundColor = 1;          // set guard flag at offset +178
    if (self->_backgroundColor != color) {
        [self->_backgroundColor release];
        self->_backgroundColor = [color copy];
        if (self->_layer)
            [self _updateLayerBackgroundColorFromView];
    }
}
```

### updateLayerHandler

```c
// A block property that NSView's default updateLayer calls
@property (copy) id /* block */ updateLayerHandler;  // ivar at offset +384
```

---

## 7. layerContentsRedrawPolicy

Stored as 3 bits in `_layerContentsRedrawPolicy` (offset +169, bits 4–6):

| Value | Enum | Behavior |
|-------|------|----------|
| 0 | `.never` | Never redraw layer contents. Forced for Layer Hosting. |
| 1 | `.onSetNeedsDisplay` | Redraw only when `setNeedsDisplay:` is called. Default for Layer Backing. |
| 2 | `.duringViewResize` | Redraw during live resize. |
| 3 | `.beforeViewResize` | Cache content before resize, draw at final size. |
| 4 | `.crossfade` | Crossfade between old and new content during resize. |

The setter validates the range:

```c
-[NSView setLayerContentsRedrawPolicy:](self, newPolicy) {
    NSAssert(newPolicy <= NSViewLayerContentsRedrawCrossfade,
        @"%@: invalid parameter not satisfying: newPolicy <= NSViewLayerContentsRedrawCrossfade");
    
    uint16_t bits = *(uint16_t *)(self + 169);
    if (newPolicy != ((bits >> 6) & 7)) {
        *(uint16_t *)(self + 169) = (bits & 0xFE3F) | ((newPolicy & 7) << 6);
    }
}
```

The `setNeedsDisplayInRect:` method checks the policy before propagating to the layer:

```c
-[NSView setNeedsDisplayInRect:](self, rect) {
    // ... notification, vibrancy update ...
    
    if (self->_layer) {
        if ([self layerContentsRedrawPolicy] >= NSViewLayerContentsRedrawOnSetNeedsDisplay) {
            [self _setLayerNeedsDisplayInViewRect: rect];
            // → [self convertRectToLayer: rect]
            // → [self->_layer setNeedsDisplayInRect: convertedRect]
        }
    } else {
        // Walk up superview chain looking for inclusive layer ancestor
        NSView *ancestor = self;
        while ((ancestor = ancestor->_superview)) {
            if (ancestor->_layer) {
                if (ancestor->_isInclusiveLayerBacked) {
                    CGRect converted = [ancestor convertRect:rect fromView:self];
                    converted = [ancestor convertRectToLayer: converted];
                    [ancestor->_layer setNeedsDisplayInRect: converted];
                }
                break;
            }
        }
    }
}
```

---

## 8. Inclusive Layer Backing

When `canDrawSubviewsIntoLayer` returns `true`, AppKit uses "inclusive" layer backing where all subviews are drawn into a single shared layer:

```c
-[NSView _isInclusiveLayerBacked](self) {
    // Debug assertion when NSViewManageLayerTreeLoosely is off
    if (!NSViewManageLayerTreeLoosely && self->_isInclusiveLayerBacked) {
        __assert_rtn("NSViewIsInclusiveLayerBacked", "NSView.m", 14247,
            "self->_isInclusiveLayerBacked == NO");
    }
    return self->_isInclusiveLayerBacked;  // bit at offset +178
}
```

In the display path, inclusive layer backing has a special optimization:

```c
// In NSViewBackingLayer.display:
if ([view _isInclusiveLayerBacked]) {
    if (!(view->_allowsGroupBlending & 2) && inclusiveSubtreeDrawsNothing(view)) {
        [self setContents: nil];  // entire subtree draws nothing → skip
        return;
    }
    // Fall through to content rendering
}
```

---

## 9. Layer Tree Management

### _buildLayerTree

Controlled by the `NSViewManageLayerTreeLoosely` app configuration. Walks the superview chain to determine layer requirements:

```c
-[NSView _buildLayerTree](self) {
    if (!self) return;
    
    // Check config: if NSViewManageLayerTreeLoosely → return (loose management)
    if (NSViewManageLayerTreeLoosely) return;
    
    // Determine context by walking superview chain
    NSView *superview = self;
    BOOL someAncestorWantsLayer = NO;
    BOOL isLayerBacked = NO;
    BOOL hasNonInclusiveLayerAncestor = NO;
    BOOL hasInclusiveAncestor = NO;
    
    while ((superview = [superview superview])) {
        if (!someAncestorWantsLayer)
            someAncestorWantsLayer = [superview wantsLayer];
        isLayerBacked = [superview _isLayerBacked];
        if (isLayerBacked && !hasInclusiveAncestor)
            hasNonInclusiveLayerAncestor = ![superview _isInclusiveLayerBacked];
        if (!hasInclusiveAncestor)
            hasInclusiveAncestor = [superview _isInclusiveLayerBacked];
    }
    
    BOOL ownLayerRequirement = isLayerBacked & !hasInclusiveAncestor;
    
    // Disable CA actions during tree build
    id oldDisableActions = [CATransaction disableActions];
    [CATransaction setDisableActions: YES];
    
    [self _buildLayerTreeWithOwnLayerRequirement: ownLayerRequirement
                          someAncestorWantsLayer: someAncestorWantsLayer
                                  singleLayerOut: NULL
                                   layerArrayOut: NULL];
    
    [CATransaction setDisableActions: oldDisableActions];
}
```

### _removeLayerIfOwnedByAppKit

Only removes layers that AppKit created:

```c
-[NSView _removeLayerIfOwnedByAppKit](self) {
    // Check bit 4 of byte+169 — if set, layer is custom (user-provided)
    if (self->_layersFrozenForTransplant)
        return;
    
    if (self->_layer && ![self wantsLayer] && ![self _usesCustomLayer]) {
        [self setLayer: nil];
    }
}
```

---

## 10. Correct Patterns

### Pattern 1: Override `updateLayer` (Recommended)

```swift
class CustomView: NSView {
    var cornerRadius: CGFloat = 0 {
        didSet { needsDisplay = true }
    }

    var fillColor: NSColor? {
        didSet { needsDisplay = true }
    }

    override var wantsUpdateLayer: Bool { true }

    override func updateLayer() {
        layer?.cornerRadius = cornerRadius
        layer?.backgroundColor = fillColor?.cgColor
    }
}
```

### Pattern 2: `@ViewInvalidating` + `updateLayer` (UIFoundation Style)

```swift
class LayerBackedView: NSView {
    @ViewInvalidating(.display)
    open dynamic var cornerRadius: CGFloat = 0

    @ViewInvalidating(.display)
    open dynamic var borderWidth: CGFloat = 0

    override var wantsUpdateLayer: Bool { true }

    override func updateLayer() {
        layer?.cornerRadius = cornerRadius
        layer?.borderWidth = borderWidth
    }
}
```

### Pattern 3: One-Time Setup via `makeBackingLayer`

```swift
class CustomLayerView: NSView {
    override func makeBackingLayer() -> CALayer {
        let layer = CAGradientLayer()
        layer.colors = [NSColor.red.cgColor, NSColor.blue.cgColor]
        return layer
    }
}
```

### Pattern 4: Use NSView's Private API (Use with Caution)

```swift
// Goes through proper ivar → layer pipeline, but uses private API
view.setValue(10.0, forKey: "_cornerRadius")

// Or via perform
view.perform(Selector(("_setCornerRadius:")), with: 10.0)
```

---

## 11. Common Mistakes

| Mistake | Why It Breaks | Fix |
|---------|---------------|-----|
| `layer.cornerRadius = 10` outside `updateLayer` | Reset to 0.0 on next `_updateAllLayerPropertiesFromView` | Set in `updateLayer` or use `_setCornerRadius:` |
| `layer.opacity = 0.5` | Overwritten by `_alphaValue` on any `setAlphaValue:` call | Use `view.alphaValue = 0.5` |
| `layer.isHidden = true` | Overwritten by `_updateLayerHiddenFromView` | Use `view.isHidden = true` |
| `layer.masksToBounds = true` | Computed from `clipsToBounds && !shadow` | Use `view.clipsToBounds = true` |
| `layer.shadowRadius = 5` | Overwritten from `view.shadow` | Set `view.shadow = NSShadow(...)` |
| `layer.backgroundColor` | Actually safe if `setBackgroundColor:` never called (guarded) | OK, but don't mix with NSView's setter |
| Setting properties in `viewDidMoveToWindow` | May run during property sync cycle | Use `updateLayer` |
| Overriding both `drawRect:` and `updateLayer` | `wantsUpdateLayer` auto-detects `drawRect:` override; if overridden, `updateLayer` won't be called | Choose one path |

---

## 12. Hidden Behaviors (Reverse Engineering Only)

These behaviors are **not documented** by Apple and can only be discovered through binary analysis.

### 12.1 actionForLayer:forKey: — Animation Key Mapping

When a CALayer asks its delegate (the view) for an animation action, AppKit uses a **static dictionary** to map layer keys to view animation keys:

```
Layer Key           → View Animation Key
─────────────────────────────────────────
"opacity"           → "alphaValue"
"position"          → "frameOrigin"
"bounds"            → "bounds"
"hidden"            → "hidden"
"filters"           → "contentFilters"
"backgroundFilters" → "backgroundFilters"
"compositingFilter" → "compositingFilter"
"shadowRadius"      → "shadow.shadowBlurRadius"
"shadowColor"       → "shadow.shadowColor"
"shadowOffset"      → "shadow.shadowOffset"
"cornerRadius"      → "cornerRadius"
"sublayers"         → "subviews"
"onOrderIn"         → NSAnimationTriggerOrderIn
"onOrderOut"        → NSAnimationTriggerOrderOut
─────────────────── ─────────────────────
"contents"          → [NSNull null]  ← ALWAYS suppressed
"contentsScale"     → [NSNull null]  ← ALWAYS suppressed
"delegate"          → [NSNull null]  ← ALWAYS suppressed
"onDraw"            → [NSNull null]  ← ALWAYS suppressed
```

**Critical suppression rule**: If `allowsImplicitAnimation == NO` OR `allowsAsynchronousAnimation == NO`, the method returns `[NSNull null]` immediately — **all animations suppressed**. This is why most layer property changes don't animate unless you explicitly use `NSAnimationContext.runAnimationGroup`.

**Mapped keys** go through `[self animationForKey: viewKey]` to look up the actual `CAAnimation`. Only `CAAnimation` subclasses are accepted; other return values are discarded.

**Consequence**: If you add a custom animation for a key not in this dictionary (e.g., `"borderWidth"`), `actionForLayer:forKey:` returns `nil`, which means Core Animation uses its **default** implicit animation. This can cause unexpected 0.25s animations on custom layer properties.

### 12.2 updateLayer Called Outside Display Cycle

`_updateLayerGeometryFromView` contains a hidden code path controlled by the `NSUpdateLayerAfterUpdateGeometry` user default:

```c
// At the end of _updateLayerGeometryFromView:
if (NSUpdateLayerAfterUpdateGeometry) {
    if (self->_layer && [self wantsUpdateLayer]) {
        _NSViewUpdateLayer(self);  // ★ Direct call, bypasses display cycle!
    }
}
```

**Impact**: When this default is enabled, `updateLayer` gets called directly from within `setFrameSize:` → `_updateLayerGeometryFromView`. This means:

1. `updateLayer` runs **outside** `NSViewBackingLayer.display`
2. `_sendViewWillDraw` is **NOT called** before it
3. The appearance context is **NOT set up** (`_performWithCurrentAppearance:` is not used)
4. Dynamic colors resolved in your `updateLayer` may get the **wrong appearance**
5. Your `updateLayer` may see **partially-updated state** (frame changed but layout not yet complete)

**Defensive pattern**: Always resolve dynamic colors via `effectiveAppearance` in your `updateLayer`, never rely on `NSAppearance.currentDrawingAppearance`:

```swift
override func updateLayer() {
    let appearance = effectiveAppearance
    appearance.performAsCurrentDrawingAppearance {
        layer?.backgroundColor = myDynamicColor.cgColor
    }
}
```

### 12.3 Shadow Opacity Hardcoded to 1.0

`NSShadow` has no `shadowOpacity` property. AppKit compensates by **hardcoding** `layer.shadowOpacity`:

```c
// _updateLayerShadowColorFromView:
if (shadow) {
    [layer setShadowColor: [shadow.shadowColor CGColor]];
    [layer setShadowOpacity: 1.0f];   // ★ HARDCODED!
} else {
    [layer setShadowOpacity: 0.0f];   // Remove shadow
}
```

**Impact**: 
- `layer.shadowOpacity` is always overwritten to **1.0** (shadow exists) or **0.0** (no shadow)
- Any custom `layer.shadowOpacity` value (e.g., 0.5) is destroyed on the next shadow sync
- If you need partial shadow opacity, use a semi-transparent `shadowColor` instead:

```swift
// ❌ Won't work — overwritten to 1.0
layer?.shadowOpacity = 0.5

// ✅ Works — opacity encoded in color alpha
let shadow = NSShadow()
shadow.shadowColor = NSColor.black.withAlphaComponent(0.5)
shadow.shadowBlurRadius = 10
view.shadow = shadow
```

### 12.4 Shadow Setter Also Controls masksToBounds

`_updateLayerShadowFromView` doesn't just update shadow properties — it also **overwrites `masksToBounds`**:

```c
-[NSView _updateLayerShadowFromView](self) {
    NSShadow *shadow = [self shadow];
    CALayer *layer = [self layer];
    
    if (shadow) {
        [layer setShadowOffset: shadow.shadowOffset];
        [layer setShadowRadius: shadow.shadowBlurRadius];
    }
    [self _updateLayerShadowColorFromView];  // sets color + opacity
    
    // ★ ALSO controls masksToBounds!
    BOOL clipsToBounds = [self clipsToBounds];
    BOOL masksToBounds = shadow ? NO : clipsToBounds;
    [layer setMasksToBounds: masksToBounds];
}
```

**Impact**: Setting `shadow` on a view **forces `masksToBounds = NO`** regardless of `clipsToBounds`. This is intentional (shadows need to render outside bounds), but undocumented. If you set both `clipsToBounds = true` AND `shadow`, the shadow wins.

This also means calling `setShadow:` triggers a `masksToBounds` change, which can affect:
- Child view clipping
- Corner radius rendering (rounded corners require `masksToBounds` in some configurations)
- Scroll view content clipping

### 12.5 wantsUpdateLayer Cache Invalidation

The `wantsUpdateLayer` result is cached in `_supportsDirectLayerContentsCache` (2 bits at offset +173). The cache has three states:

| Value | Meaning |
|-------|---------|
| 0 | NO — subclass overrides `drawRect:` |
| 1 | YES — subclass does NOT override `drawRect:` |
| 2 | Unknown — needs recomputation |

`_resetSupportsDirectLayerContentsCache` clears the cache:

```c
-[NSView _resetSupportsDirectLayerContentsCache](self) {
    self->_supportsDirectLayerContentsCache = 0;  // clear bits → triggers recompute
    if (![self _usesCustomLayer]) {
        [self setNeedsLayout: YES];   // ★ Also triggers layout!
    }
}
```

**Impact**: If you use method swizzling to dynamically add or remove `drawRect:`, the `wantsUpdateLayer` cache will be **stale**. You must call `_resetSupportsDirectLayerContentsCache` (private API) after swizzling, or the view will continue using the old drawing path.

Even more subtle: this method triggers `setNeedsLayout:`, which means **cache invalidation causes a layout pass**. If called during layout, this can trigger layout recursion.

### 12.6 Draw Delegate — Semi-Transparent Non-Layer-Backed Views

AppKit has a hidden "draw delegate" system for views with `alphaValue < 1.0` that are NOT layer-backed:

```c
-[NSView _updateDrawDelegateForAlphaValue](self) {
    if ([self _isLayerBacked] || self->_alphaValue >= 1.0) {
        // Layer-backed or fully opaque: clear draw delegate
        if (_hasDrawDelegate && [self _drawDelegate] == self) {
            [self _setDrawDelegate: nil];
        }
    } else {
        // Non-layer-backed AND semi-transparent: set self as draw delegate
        if (!_hasDrawDelegate) {
            [self _setDrawDelegate: self];
        }
    }
}
```

The draw delegate is stored in a **global weak map table** (`gDrawDelegates`), protected by `_NSAppKitLock`:

```c
-[NSView _setDrawDelegate:](self, delegate) {
    if (delegate) {
        _NSAppKitLock();
        if (!gDrawDelegates)
            gDrawDelegates = [NSMapTable mapTableWithWeakToWeakObjects];
        [gDrawDelegates setObject:delegate forKey:self];
        _NSAppKitUnlock();
        
        os_unfair_lock_lock(&self->_atomicFlagsLock);
        self->_atomicFlags._hasDrawDelegate = 1;
        os_unfair_lock_unlock(&self->_atomicFlagsLock);
    } else {
        os_unfair_lock_lock(&self->_atomicFlagsLock);
        self->_atomicFlags._hasDrawDelegate = 0;
        os_unfair_lock_unlock(&self->_atomicFlagsLock);
        
        _NSAppKitLock();
        [gDrawDelegates removeObjectForKey: self];
        _NSAppKitUnlock();
    }
}
```

**Impact**: When a non-layer-backed view has partial transparency, AppKit uses this global map table to manage drawing delegation. This is why semi-transparent non-layer-backed views have different (slower) drawing behavior. The global lock (`_NSAppKitLock`) can also be a contention point if many views change alpha simultaneously.

### 12.7 Auto Layer Backing of Window Root

`_rootLayerBackWindowIfNeeded` can **silently** force layer backing on the window's root view:

```c
-[NSView _rootLayerBackWindowIfNeeded](self) {
    if (self->_window) {
        NSView *rootView = [[self _viewRoot] _rootViewForViewRoot];
        if (rootView && !rootView->_layer) {
            if (NSViewShouldRootLayerBackViaWantsLayerGeometryTest(
                    [self->_window contentView])) {
                rootView->_hasAutoSetWantsLayer = 1;
                [rootView _updateLayerBackedness];
            }
        }
    }
}
```

**Impact**: This is called from `setLayer:`. When ANY view in a window gets a layer, AppKit may **automatically** give the root view a layer too. The `_hasAutoSetWantsLayer` flag marks this as system-initiated. This is why setting `wantsLayer = true` on one view can cause the entire window to become layer-backed.

### 12.8 Crossfade Contents Transition

Hidden inside `_updateLayerGeometryFromView`, there's a special animation for `layerContentsRedrawPolicy == .crossfade (4)`:

```c
// In _updateLayerGeometryFromView, after bounds change:
if ([self _needsRedisplayOnFrameChange]) {
    [self setNeedsDisplay: YES];
    
    if ([self layerContentsRedrawPolicy] == 4  // .crossfade
        && allowsImplicitAnimation) {
        // Add CA crossfade transition for "contents" key
        [layer addAnimation: [CATransition animation] forKey: @"contents"];
    }
}
```

And in `actionForLayer:forKey:`:

```c
// Special case for crossfade
if (layerContentsRedrawPolicy == 4  // .crossfade
    && [self wantsUpdateLayer]
    && ![self _isInclusiveLayerBacked]
    && [key isEqualToString: @"contents"]) {
    return nil;  // Return nil → CA provides DEFAULT animation (crossfade)
}
```

**Impact**: The `.crossfade` policy works through two mechanisms:
1. `actionForLayer:forKey:` returns `nil` for "contents" → CA's default crossfade
2. `_updateLayerGeometryFromView` explicitly adds a `CATransition` during bounds changes

If you use `.crossfade` but also override `actionForLayer:forKey:`, you'll break this mechanism.

### 12.9 _needsRedisplayOnFrameChange Logic

The logic for when a frame change triggers redisplay is more nuanced than documented:

```c
-[NSView _needsRedisplayOnFrameChange](self) {
    if (!self->_layer) return YES;  // Non-layer-backed: always redisplay
    
    // Layer-backed: only if inclusive OR policy >= .duringViewResize
    return self->_isInclusiveLayerBacked
        || [self layerContentsRedrawPolicy] >= 2;  // .duringViewResize or higher
}
```

**Impact**: With the default `.onSetNeedsDisplay` policy (1), **frame changes do NOT trigger layer redisplay**. The layer content is simply scaled/stretched. Only with policy >= 2 does a frame change trigger `setNeedsDisplay:`. This is why views with default layer backing may show blurry content during resize — the layer contents aren't being redrawn.

### 12.10 _performWithoutAnimation: Is Not What You Think

```c
+[NSView _performWithoutAnimation:](block) {
    NSAnimationContext *ctx = [NSAnimationContext currentContext];
    if ([ctx allowsImplicitAnimation]) {
        [ctx setAllowsImplicitAnimation: NO];
        block();
        [ctx setAllowsImplicitAnimation: YES];  // ★ Always restores to YES!
    } else {
        block();  // Already off, just execute
    }
}
```

**Impact**: This method has a subtle bug/design choice: it always restores `allowsImplicitAnimation` to `YES`, not to its previous value. If the animation context had `allowsImplicitAnimation = NO` before this call, it stays `NO` (the `if` branch is skipped). But if something inside the block modifies the animation context, the restoration to `YES` could be incorrect.

In practice, AppKit uses this during layer tree construction and property sync to ensure no implicit animations fire during setup.

### 12.11 Geometry Flipping XOR

Layer geometry flipping is computed as the **XOR** of the view's flip state and its ancestor's:

```c
// In _updateLayerGeometryFromView:
BOOL isFlipped = [self isFlipped];

// Cache flipped state
self->_cachedIsFlipped = isFlipped;

// Geometry flip = XOR of view and ancestor
BOOL geometryFlipped = isFlipped;
if (ancestorWithLayer) {
    geometryFlipped = isFlipped ^ [ancestorWithLayer isFlipped];
}
[layer setGeometryFlipped: geometryFlipped];
```

**Impact**: If both the view and its ancestor are flipped, the geometry is NOT flipped (XOR cancels). This is correct behavior but non-obvious. If you manually set `layer.geometryFlipped`, it will be overwritten by this logic on the next geometry sync.

### 12.12 _ViewLayerSurface — Associated Object Mechanism

The `_NSViewLayerSurface` object is stored via **`objc_getAssociatedObject`** using the class itself as the key:

```c
bool NSViewHasLayerSurface(NSView *view) {
    return objc_getAssociatedObject(view, [_NSViewLayerSurface class]) != nil;
}

void NSViewUpdateLayerSurface(NSView *view) {
    _NSViewLayerSurface *surface = objc_getAssociatedObject(view, [_NSViewLayerSurface class]);
    [surface update];
}
```

**Impact**: The layer surface is NOT an ivar — it's an associated object. This means:
- It doesn't show up in ivar dumps
- It's managed by the ObjC runtime's associated object mechanism
- It's automatically cleaned up when the view is deallocated (OBJC_ASSOCIATION_RETAIN)
- `_updateLayerGeometryFromView` checks for it and calls `NSViewUpdateLayerSurface` first if present

---

## 13. NSView Ivar Layout

Verified via RuntimeViewer runtime introspection:

### Object / Struct Ivars

| Offset | Type | Name | Layer Relevance |
|--------|------|------|-----------------|
| +48 | `NSView *` | `_superview` | Superview chain for layer tree |
| +72 | `CGRect` | `_frame` | Source for layer geometry |
| +104 | `CGRect` | `_bounds` | Source for layer bounds |
| +136 | `NSArray *` | `_subviews` | Sublayer ordering |
| **+144** | **`CALayer *`** | **`_layer`** | **The backing/hosting layer** |
| +152 | `NSWindow *` | `_window` | |
| +196 | `os_unfair_lock_s` | `_atomicFlagsLock` | Protects `_atomicFlags` |
| **+328** | **`CGFloat`** | **`_alphaValue`** | **Source → `layer.opacity`** |
| +336 | `NSArray *` | `_contentFilters` | Source → `layer.filters` |
| +344 | `NSArray *` | `_backgroundFilters` | Source → `layer.backgroundFilters` |
| +352 | `CIFilter *` | `_compositingFilter` | Source → `layer.compositingFilter` |
| **+360** | **`NSShadow *`** | **`_shadow`** | **Source → `layer.shadow*`** |
| **+384** | **`id /* block */`** | **`_updateLayerHandler`** | **Default `updateLayer` block** |
| +392 | `NSAppearance *` | `_cachedEffectiveAppearance` | |
| **+416** | **`CGFloat`** | **`_cornerRadius`** | **Source → `layer.cornerRadius`** |
| **+424** | **`NSColor *`** | **`_backgroundColor`** | **Source → `layer.backgroundColor`** |
| +432 | `CGRect` | `_preparedContentRect` | Incremental drawing region |
| +496 | `NSViewController *` | `_viewController` | |

### Bitfield: `_vFlags` (offset +160, 32 bits)

| Bit | Name | Notes |
|-----|------|-------|
| 18 | `canDrawSubviewsIntoLayer` | Enables inclusive layer backing |
| 21 | `needsDisplay` | View needs display |

### Bitfield: `_atomicFlags` (offset +164, 32 bits)

| Bit | Name | Notes |
|-----|------|-------|
| 1 | `_hidden` | Source → `layer.hidden` |
| 8 | `_drawnByAncestor` | Forces `wantsUpdateLayer` to NO |
| 13 | `_hasDrawDelegate` | Has draw delegate |
| **16** | **`_wantsLayer`** | **The `wantsLayer` flag** |
| 17 | `_dontSuppressLayerAnimation` | Allow layer animation |
| 18 | `_canDrawConcurrently` | Source → `layer.drawsAsynchronously` |

### Loose Bitfields (offsets 168–192)

| Offset | Name | Bits | Notes |
|--------|------|------|-------|
| **168.0** | **`_appkitManagesLayer`** | **1** | **1 = Layer Backing, 0 = Layer Hosting** |
| 168.6 | `_drawsNothing` | 1 | Cached: subclass doesn't override `drawRect:` |
| **169.4–6** | **`_layerContentsRedrawPolicy`** | **3** | **Enum 0–4** |
| 170.0–3 | `_layerContentsPlacement` | 4 | Source → `layer.contentsGravity` |
| **173.5–6** | **`_supportsDirectLayerContentsCache`** | **2** | **0=NO, 1=YES, 2=recompute** |
| 174.3 | `_hasCanDrawSubviewsIntoLayerAncestor` | 1 | |
| 176.5 | `_hasAutoSetWantsLayer` | 1 | Parent forced wantsLayer |
| **177.3** | **`_clipsToBounds`** | **1** | **Input to `masksToBounds` computation** |
| **178.5** | **`_isInclusiveLayerBacked`** | **1** | **Inclusive (shared) layer mode** |
| **178.6** | **`_setBackgroundColor`** | **1** | **Guard flag for backgroundColor sync** |

### Key Constants

| Constant | Value | Usage |
|----------|-------|-------|
| Pixel budget | 268,435,456 (268M) | `sqrt(268M / bounds.area)` caps `contentsScale` |
| Inclusive area threshold | 0.707106781 (1/sqrt(2)) | If intersection/bounds >= 70.7%, merge to full redraw |

---

## 14. Appendix: Decompiled Methods

### Method Addresses (macOS 26.4 arm64e)

| Method | Address | Size |
|--------|---------|------|
| `-[NSView setWantsLayer:]` | `0x1849ee9b0` | 0xdc |
| `-[NSView wantsLayer]` | `0x1849eee50` | 0x18 |
| `-[NSView wantsUpdateLayer]` | `0x1849f663c` | 0x90 |
| `-[NSView updateLayer]` | `0x184ae108c` | 0x24 |
| `-[NSView makeBackingLayer]` | `0x1849ef8dc` | 0xc |
| `-[NSView layer]` | `0x1849f02b8` | 0x10 |
| `-[NSView setLayer:]` | `0x1849ef970` | 0x488 |
| `-[NSView _updateLayerBackedness]` | `0x1849eeb48` | 0x308 |
| `-[NSView _createLayerAndInitialize]` | `0x18570716c` | 0x180 |
| `-[NSView _updateAllLayerPropertiesFromView]` | `0x185707324` | 0x90 |
| `-[NSView _buildLayerTree]` | `0x185703f70` | 0x1b0 |
| `-[NSView setAlphaValue:]` | `0x184a0d18c` | 0x1fc |
| `-[NSView setFrameSize:]` | `0x184a01614` | 0x704 |
| `-[NSView setShadow:]` | `0x184b695b8` | 0xac |
| `-[NSView setBackgroundColor:]` | `0x185708de8` | 0x98 |
| `-[NSView _setCornerRadius:]` | `0x185708f30` | 0x70 |
| `-[NSView _drawsNothing]` | `0x185705814` | 0x68 |
| `-[NSView _isInclusiveLayerBacked]` | `0x185705018` | 0xa4 |
| `-[NSView _removeLayerIfOwnedByAppKit]` | `0x184bf7698` | 0x7c |
| `-[NSView setNeedsDisplay:]` | `0x1849eee80` | 0x98 |
| `-[NSView setNeedsDisplayInRect:]` | `0x1849eef18` | 0x364 |
| `-[NSView setLayerContentsRedrawPolicy:]` | `0x1849e5768` | 0xa8 |
| `-[NSView layerContentsRedrawPolicy]` | `0x1849efeb8` | 0x14 |
| `-[NSView _drawRect:clip:]` | `0x184bf0980` | 0x37c |
| `-[NSViewBackingLayer display]` | `0x1853b86a4` | 0x5cc |
| `-[NSViewBackingLayer drawInContext:]` | `0x1853b8f50` | 0x5c |
| `_NSViewUpdateLayer` | `0x184a7da24` | 0xa4 |

---

**Source**: macOS 26.4 dyld shared cache (arm64e), IDA Pro decompilation + RuntimeViewer runtime introspection.
