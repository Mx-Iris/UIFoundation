# AppKit NSGridView Layout Internals

> Based on reverse engineering macOS 26.4 AppKit (arm64e) via IDA Pro decompilation
> of `/System/Library/Frameworks/AppKit.framework/AppKit` (extracted from
> `dyld_shared_cache_arm64e`). All addresses below are slid AppKit text addresses
> in the 26.4 cache and will differ between OS versions.
>
> **Why this report exists.** `NSGridView` is famously fragile — applications
> using it routinely emit *"Unable to simultaneously satisfy constraints"* logs,
> rows collapse unexpectedly, merged regions misalign, and content views appear
> to ignore alignment hints. None of this is documented. This document explains
> why, by reading the binary.

---

## Table of Contents

- [1. Overview](#1-overview)
- [2. Class Structure](#2-class-structure)
  - [2.1 Ivar Layout](#21-ivar-layout)
  - [2.2 The Cell Table](#22-the-cell-table)
  - [2.3 Empty Content View Sentinel](#23-empty-content-view-sentinel)
- [3. Initialization & Defaults](#3-initialization--defaults)
- [4. The Anchor System (No `updateConstraints`)](#4-the-anchor-system-no-updateconstraints)
  - [4.1 No `updateConstraints` Override](#41-no-updateconstraints-override)
  - [4.2 Named Anchors: `row-boundary` / `column-boundary`](#42-named-anchors-row-boundary--column-boundary)
  - [4.3 Boundary vs Content Anchors](#43-boundary-vs-content-anchors)
  - [4.4 The "Bottom = Next Top" Trick](#44-the-bottom--next-top-trick)
  - [4.5 Hidden Row/Column Collapse](#45-hidden-rowcolumn-collapse)
  - [4.6 NSLayoutRect Cell Region](#46-nslayoutrect-cell-region)
- [5. Placement & Alignment Inheritance](#5-placement--alignment-inheritance)
  - [5.1 The Three-Level Fallback Chain](#51-the-three-level-fallback-chain)
  - [5.2 Hidden Trap: Alignment Suppresses yPlacement](#52-hidden-trap-alignment-suppresses-yplacement)
  - [5.3 Default Resolution Table](#53-default-resolution-table)
- [6. Merging Mechanics](#6-merging-mechanics)
  - [6.1 Merge Representation](#61-merge-representation)
  - [6.2 `_mergeCellsInRect:` Flow](#62-_mergecellsinrect-flow)
  - [6.3 Auto-Expansion of Merge Bounds](#63-auto-expansion-of-merge-bounds)
  - [6.4 Configurability Restrictions on Merged Cells](#64-configurability-restrictions-on-merged-cells)
- [7. Constraint Invalidation Triggers](#7-constraint-invalidation-triggers)
  - [7.1 Properties That Trigger `setNeedsUpdateConstraints:`](#71-properties-that-trigger-setneedsupdateconstraints)
  - [7.2 Properties That Do NOT Trigger Invalidation](#72-properties-that-do-not-trigger-invalidation)
- [8. setContentView: Side Effects](#8-setcontentview-side-effects)
- [9. Insertion / Removal / Move Restrictions](#9-insertion--removal--move-restrictions)
- [10. Root Causes of Layout Ambiguity](#10-root-causes-of-layout-ambiguity)
- [11. Safe Usage Patterns](#11-safe-usage-patterns)
- [12. Appendix: Decompiled Methods](#12-appendix-decompiled-methods)

---

## 1. Overview

`NSGridView` is a Swift-friendly two-dimensional layout container introduced in
macOS 10.12. Unlike `NSStackView`, which produces axis-aligned stacks, the grid
publishes per-row/per-column constants (placement, alignment, padding, spacing)
and lets every cell pick its content view independently.

The interesting part is *how* the constraints are produced. Most AppKit
container views (`NSStackView`, `NSScrollView`, etc.) override
`updateConstraints` and add real `NSLayoutConstraint` objects. **`NSGridView`
does not.** It builds layout indirectly through three private mechanisms:

1. **Named anchors** — `+[NSLayoutYAxisAnchor anchorNamed:inItem:]` /
   `+[NSLayoutXAxisAnchor anchorNamed:inItem:]` create symbolic boundary
   anchors keyed by string (`@"row-boundary"`, `@"column-boundary"`) on the
   grid view itself.
2. **Per-row/column anchor caching** — every `NSGridRow` stores exactly one
   `NSLayoutYAxisAnchor _top`; every `NSGridColumn` stores exactly one
   `NSLayoutXAxisAnchor _leading`. The opposite edge (`bottom`/`trailing`) is
   never stored; it is *recomputed* every time as the next visible row/column's
   top/leading anchor.
3. **NSLayoutRect helper** — `+[NSLayoutRect
   layoutRectWithLeadingAnchor:topAnchor:trailingAnchor:bottomAnchor:]` packages
   four anchors into an opaque per-cell layout region that AppKit's anchor
   subsystem dereferences during constraint solving.

The consequence: there is no single place where the grid's constraints can be
inspected or corrected. Misconfiguration becomes a *runtime* problem, not a
*compile-time* one, and failure modes are skewed toward soft symptoms — wrong
row heights, vanishing rows, ambiguous-constraint warnings — rather than hard
crashes.

---

## 2. Class Structure

### 2.1 Ivar Layout

Offsets are byte offsets relative to the object's `isa` pointer. The numbers
here come straight from the Objective-C class metadata embedded in the binary.

#### `NSGridView` (extends `NSView`)

```
+560  CGFloat            _rowSpacing             (default 6.0)
+568  CGFloat            _colSpacing             (default 6.0)
+576  NSMutableArray *   _columns
+584  NSMutableArray *   _rows
+592  NSMapTable *       _cellTable              // NSView -> NSGridCell, weak->weak
+600  NSInteger          _currentConstraintGeneration
+608  struct {
        int32_t isDecoding : 1;
        int32_t _unused    : 31;
      } _flags
```

Note: `_xPlacement`, `_yPlacement`, `_rowAlignment` are `@synthesize`d by the
compiler with auto-generated backing ivars (offsets not exposed in headers).

#### `NSGridRow`

```
+8   NSGridView *           _owningGridView   // strong; cleared on remove
+16  NSMutableArray *       _cells            // length == numberOfColumns (asserted)
+24  NSLayoutYAxisAnchor *  _top              // named "row-boundary", or nil for first row
+32  NSInteger              _yPlacement
+40  NSInteger              _rowAlignment
+48  NSInteger              _hasContentInGeneration
+56  CGFloat                _height           // default FLT_MIN (1.17549435e-38) sentinel
+64  CGFloat                _topPadding
+72  CGFloat                _bottomPadding
+80  BOOL                   _hidden
```

#### `NSGridColumn`

```
+8   NSGridView *           _owningGridView
+16  NSLayoutXAxisAnchor *  _leading          // named "column-boundary", or nil for first column
+24  NSInteger              _hasContentInGeneration
+32  NSInteger              _xPlacement
+40  CGFloat                _width            // default 0.0 (no sentinel)
+48  CGFloat                _trailingPadding
+56  CGFloat                _leadingPadding
+64  BOOL                   _hidden
```

#### `NSGridCell`

```
+32  NSGridCell *   _headOfMergedCell
       // nil   = unmerged
       // self  = head of a merged region
       // other = merged child (config locked)
+48  NSInteger      _xPlacement
+56  NSInteger      _yPlacement
+64  NSInteger      _rowAlignment
+    NSView *       _contentView              // @synthesize; setter has lots of side effects
+    NSGridRow *    _row                      // weak
+    NSGridColumn * _column                   // weak
+    NSArray *      _customPlacementConstraints
```

### 2.2 The Cell Table

`NSGridView._cellTable` is an `NSMapTable` with both keys and values weak
(`NSPointerFunctionsWeakMemory`, options `512 = 0x200 << 1`). It maps content
view -> owning cell. The lookup is `cellForView:`, which walks up the superview
chain until it finds an entry — so a deeply nested subview can still resolve to
its containing cell.

Every assignment of a content view writes the table; clearing the content view
removes the entry. Validation in `setContentView:` raises
`NSInvalidArgumentException` if the view is already managed by *another* cell.

### 2.3 Empty Content View Sentinel

Each row's `_cells` array is pre-filled with a singleton `NSGridEmptyContentView
*` placeholder. The placeholder is a process-wide global,
`gGridViewPlaceholderView_dontReferenceDirectly`, allocated once and reused via
`+[NSGridEmptyContentView _allocatingPlaceholder]`.

```c
// 0x18531EA70
id -[NSGridEmptyContentView _allocatingPlaceholder] {
  if (gGridViewPlaceholderView_dontReferenceDirectly) {
    objc_release(self);
    return gGridViewPlaceholderView_dontReferenceDirectly;
  }
  gGridViewPlaceholderView_dontReferenceDirectly = self;
  return self;
}
```

This means `cell.contentView == nil` is internally represented as
`emptyContentView`, and the actual `NSGridCell` object is allocated lazily on
first access:

```c
// -[NSGridRow _cellAtIndex:allocatingIfNeeded:]  0x185322E8C
v9  = [_cells objectAtIndex:index];
v10 = [NSGridCell emptyContentView];
if (v9 == v10) v11 = nil;  // unallocated
else           v11 = v9;
if (allocatingIfNeeded && v9 == v10) {
  v11 = [[NSGridCell alloc] initWithRow:self
                                column:[gridView columnAtIndex:index]];
  [_cells replaceObjectAtIndex:index withObject:v11];
}
```

So **every grid row owns exactly `numberOfColumns` array slots regardless of
whether you've put anything in them** — this is asserted on every cell access.
You cannot have a "ragged" grid.

---

## 3. Initialization & Defaults

`-[NSGridView _commonPreInit]` is the central point that hard-codes the defaults:

```c
// 0x18531ED5C
void -[NSGridView _commonPreInit] {
  self->_xPlacement   = 2;     // NSGridCellPlacementCenter
  self->_yPlacement   = 2;     // NSGridCellPlacementCenter (... but see §5.2)
  self->_rowAlignment = 1;     // NSGridRowAlignmentNone
  self->_rowSpacing   = 6.0;
  self->_colSpacing   = 6.0;
  self->_cellTable    = [[NSMapTable alloc]
                          initWithKeyOptions:512 valueOptions:512 capacity:0];
}
```

`-[NSGridView _commonPostInit]` lazily allocates `_columns` / `_rows` only if
the unarchiver did not already populate them (used by `initWithCoder:`).

Class methods:

```c
// +[NSGridView gridViewWithNumberOfColumns:rows:]  0x18531EBA8
//   -> [self alloc] initWithFrame:NSZeroRect]
//   -> for (i in cols) [v6 addColumnWithViews:@[]]
//   -> for (i in rows) [v6 addRowWithViews:@[]]

// +[NSGridView gridViewWithViews:]  0x18531EC50
//   -> takes [[v0,v1], [v2,v3], ...]
//   -> for each inner array: [v6 addRowWithViews:innerArray]
```

`gridViewWithViews:` does not pre-allocate columns; the column count grows
on-demand inside `_insertRowAtIndex:withViews:` (see §9).

---

## 4. The Anchor System (No `updateConstraints`)

### 4.1 No `updateConstraints` Override

`-[NSGridView updateConstraints]` does not exist in the binary. The grid relies
entirely on `NSLayoutAnchor`'s internal solver, with cells participating
through `NSLayoutRect` regions wired up to anchors. Every "invalidation"
ultimately just dirties the anchor system through:

- `setNeedsUpdateConstraints:` on the grid view (so AppKit reschedules a layout
  pass)
- mutation of the `_rows` / `_columns` arrays
- toggling of `NSGridRow._hidden` / `NSGridColumn._hidden` (which changes which
  anchor is returned by `_findBottomBoundaryAnchorAndContentOffset:` /
  `_findTrailingBoundaryAnchorAndContentPadding:`)

### 4.2 Named Anchors: `row-boundary` / `column-boundary`

For a row that is *not* the first visible row, the grid creates a named anchor
exactly once and caches it in `_top`:

```c
// -[NSGridRow _topBoundaryAnchor]  0x185323180
id -[NSGridRow _topBoundaryAnchor] {
  if ([self _previousVisibleRow]) {
    if (!self->_top) {
      self->_top = [[NSLayoutYAxisAnchor anchorNamed:@"row-boundary"
                                              inItem:_owningGridView] retain];
    }
    return self->_top;
  } else {
    return [_owningGridView topAnchor];   // first visible row uses the grid's own top
  }
}
```

`+[NSLayoutYAxisAnchor anchorNamed:inItem:]` is a private API that returns a
shared "named" anchor; the same string in the same item collapses to the
*same* anchor object. AppKit uses this trick to give the grid one boundary
anchor per row "slot" without having to add explicit constraints.

The X-axis variant is identical, with `@"column-boundary"`:

```c
// -[NSGridColumn _leadingBoundaryAnchor]  0x185323AFC
self->_leading = [[NSLayoutXAxisAnchor anchorNamed:@"column-boundary"
                                            inItem:_owningGridView] retain];
```

The first visible row/column piggybacks on the grid's own
`topAnchor`/`leadingAnchor`, which means the grid's own layout margins (or
custom constraints involving its top/leading anchors) directly affect the first
row/column position.

### 4.3 Boundary vs Content Anchors

Each side of a row/column has two anchors:

| | Anchor | Purpose |
|---|---|---|
| Row | `_topBoundaryAnchor` | The actual row-top edge |
| Row | `_topContentAnchor` | `_topBoundaryAnchor` offset by `topPadding` |
| Row | `_bottomBoundaryAnchor` | Bottom edge of the row |
| Row | `_bottomContentAnchor` | `_bottomBoundaryAnchor` offset by `-bottomPadding` |
| Col | `_leadingBoundaryAnchor` | The actual column-leading edge |
| Col | `_leadingContentAnchor` | `_leadingBoundaryAnchor` offset by `leadingPadding` |
| Col | `_trailingBoundaryAnchor` | Trailing edge of the column |
| Col | `_trailingContentAnchor` | `_trailingBoundaryAnchor` offset by `-trailingPadding` |

The content anchor is generated lazily — when padding == 0 it just returns the
boundary anchor (saving one anchor allocation):

```c
// -[NSGridRow _topContentAnchor]  0x1853231F0
id _topContentAnchor() {
  id boundary = [self _topBoundaryAnchor];
  if ([self topPadding] <= 0.0) return boundary;
  return [boundary anchorByOffsettingWithConstant:[self topPadding]];
}
```

### 4.4 The "Bottom = Next Top" Trick

`NSGridRow` stores **only** `_top`. The bottom edge is always queried on demand
from the *next visible row*:

```c
// -[NSGridRow _findBottomBoundaryAnchorAndContentOffset:]  0x185323254
id _findBottomBoundary(double *outOffset) {
  if ([self isHidden])
    return [self _topBoundaryAnchor];                       // collapse: see §4.5

  NSGridRow *next = [self _nextVisibleRow];
  if (next) {
    id anchor   = [next _topBoundaryAnchor];
    double pad  = [self bottomPadding];
    double space = [_owningGridView rowSpacing];
    *outOffset  = pad + space;                              // <-- combined
    return anchor;
  } else {
    *outOffset = [self bottomPadding];
    return [_owningGridView bottomAnchor];                  // last row: grid's own bottom
  }
}
```

Two consequences worth memorising:

1. **Row spacing and per-row bottomPadding are additive.** If you set
   `rowSpacing = 6` *and* `row.bottomPadding = 6`, the gap below that row is
   12 pt, not 6.
2. **Inserting/removing/hiding any visible row invalidates the bottom anchors
   of every row before it.** The grid handles this automatically by toggling
   `setNeedsUpdateConstraints:` on every row mutation, but if you
   programmatically capture an anchor reference and try to use it later, it can
   become stale.

The X-axis side is identical: `-[NSGridColumn
_findTrailingBoundaryAnchorAndContentPadding:]` (0x185323BD0).

### 4.5 Hidden Row/Column Collapse

Critical fact (and a common source of WTF moments):

```c
if ([self isHidden])
  return [self _topBoundaryAnchor];      // bottom == top -> 0-height
```

A hidden row's *bottom* boundary anchor is its own *top* boundary anchor,
forcing the row to zero height. Combined with `_nextVisibleRow` being skipped
in `_topBoundaryAnchor` lookups, hiding works as collapse, not as
display:none. This is why merged cells that span a hidden row produce
ambiguous-constraint warnings — see §10.

### 4.6 NSLayoutRect Cell Region

Each unmerged cell (or merge head) reports a four-anchor "region" via
`_optimalContentLayoutRect`:

```c
// -[NSGridCell _optimalContentLayoutRect]  0x1853247D4
if (_headOfMergedCell != nil && _headOfMergedCell != self)
  return nil;                                              // merged child: no region

NSGridCell *tail = _headOfMergedCell ? [self _findMergeTail] : self;
return [NSLayoutRect layoutRectWithLeadingAnchor: [_column   _leadingContentAnchor]
                                       topAnchor: [_row      _topContentAnchor]
                                  trailingAnchor: [tail.column _trailingContentAnchor]
                                    bottomAnchor: [tail.row    _bottomContentAnchor]];
```

`NSLayoutRect` is the bridge between the grid's anchor system and the standard
constraint solver. `+[NSGridCell layoutRect]` *itself* (0x1853248F8) raises
`NSGenericException @"Unimplemented"` — only the `_optimalContentLayoutRect` /
`NSLayoutRect` indirection is used.

---

## 5. Placement & Alignment Inheritance

### 5.1 The Three-Level Fallback Chain

Every cell resolves its effective placement / alignment through a
`cell -> row|column -> gridView -> hard-coded default` chain.

```c
// -[NSGridCell _effectiveXPlacement]  0x185324930
NSInteger r = [self xPlacement];
if (!r) r = [_column   xPlacement];
if (!r) r = [_column.gridView xPlacement];
if (!r) r = 2;                  // NSGridCellPlacementCenter (literal 2)
return r;

// -[NSGridCell _effectiveAlignment]  0x1853249F8
NSInteger r = [self rowAlignment];
if (!r) r = [_row     rowAlignment];
if (!r) {
  r = [_row.gridView rowAlignment];
  if (r <= 1) return 1;         // NSGridRowAlignmentNone
}
return r;
```

`0` is the **inherited** sentinel (`NSGridCellPlacementInherited` /
`NSGridRowAlignmentInherited`). It's the value returned by a fresh cell, and
it forces fallback. Setting `cell.xPlacement = .none` (1) is *not* inheritance
— it overrides whatever the column says.

### 5.2 Hidden Trap: Alignment Suppresses yPlacement

`_effectiveYPlacement` is the surprising one. Read carefully:

```c
// -[NSGridCell _effectiveYPlacement]  0x185324984
NSInteger v = [self yPlacement];
if (v == 0 || [self _effectiveAlignment] != 1) {       // 1 == NSGridRowAlignmentNone
  v = [_row     yPlacement];
  if (v) return v;
  v = [_row.gridView yPlacement];
  if (v) return v;
  return 3;                                            // NSGridCellPlacementFill
}
return v;
```

The condition is not "if the cell has an explicit yPlacement, use it." It is:

> Use the cell's `yPlacement` **only if** it is non-zero **and** the effective
> row alignment is `.none`.

Translated: **whenever a row alignment (e.g. `.firstBaseline`,
`.lastBaseline`) is in effect, the cell's `yPlacement` is silently discarded.**
The grid falls back to the row's or grid's `yPlacement`, defaulting to `3`
(`NSGridCellPlacementFill`).

This is a frequent surprise: developers set `cell.yPlacement = .top` to make a
control hug the top of its row, observe it being ignored when the grid has
`rowAlignment = .firstBaseline`, and assume their assignment didn't take. It
did — it is being overruled by the inheritance lookup itself.

### 5.3 Default Resolution Table

Hard-coded defaults reachable through the inheritance chain:

| Property | Sentinel value | Default after fallback | After-fallback meaning |
|---|---|---|---|
| `xPlacement` | `0` (Inherited) | `2` | Center |
| `yPlacement` | `0` (Inherited) | `3` | Fill (when alignment != .none) |
| `rowAlignment` | `0` (Inherited) | `1` | None (no baseline) |

The X-axis and Y-axis placement defaults are different (`2` vs `3`). The grid
view itself sets `xPlacement = 2`, `yPlacement = 2`, `rowAlignment = 1` in
`_commonPreInit` — but `_effectiveYPlacement` reaches a *different* default
when alignment is in effect, because it skips the cell-level value.

---

## 6. Merging Mechanics

### 6.1 Merge Representation

There is no `mergedRegions` array. Membership in a merged region is encoded
purely through `_headOfMergedCell` pointers:

```
  _headOfMergedCell == nil      ->  unmerged
  _headOfMergedCell == self     ->  head of a merged region
  _headOfMergedCell == otherCell ->  child of otherCell's merged region
```

`_findMergeBounds` (0x185324A68) walks neighbours rightward then downward,
counting how many adjacent cells share the same head, to derive the merged
rectangle on demand. `_findMergeTail` (0x185324BB0) returns the bottom-right
cell of the region, and asserts loudly if the topology is inconsistent.

### 6.2 `_mergeCellsInRect:` Flow

```c
// -[NSGridView _mergeCellsInRect:]  0x185321E90
if (rect.size.width == 1 && rect.size.height == 1) {
  // Special case: 1x1 "merge" is actually an unmerge.
  cell._headOfMergedCell = nil;
} else {
  NSGridCell *head = cellAt(rect.origin);
  for (row in rect.y..rect.y+rect.height) {
    for (col in rect.x..rect.x+rect.width) {
      NSGridCell *c = cellAt(col, row);
      assert(c._headOfMergedCell == nil);    // §6.4
      c._headOfMergedCell = head;
    }
  }
  [self setNeedsUpdateConstraints:YES];
}
```

Note the **assertion**: every cell inside the rect must currently be unmerged.
You cannot merge across an existing merged region directly — the merge will
hard-fail with `"Error while merging cell: _head != nil"`. Callers must
`_unmergeCellsInRect:` first, or use the higher-level
`mergeCellsInHorizontalRange:verticalRange:` which routes through
`_expandMergeBoundsIfNeeded:` (see §6.3).

### 6.3 Auto-Expansion of Merge Bounds

`mergeCellsInHorizontalRange:verticalRange:` is the public API and goes
through:

```c
// -[NSGridView mergeCellsInHorizontalRange:verticalRange:]  0x185321A60
rect = [self _expandMergeBoundsIfNeeded:rect];
[self _mergeCellsInRect:rect];
```

`_expandMergeBoundsIfNeeded:` (0x185321D80) iteratively grows `rect` to
*absorb* any pre-existing merged regions that the requested rectangle merely
*overlaps*. The algorithm:

1. Walk the top row of the rect; if any cell is already part of a merge,
   union the rect with that merge's bounds. Then unmerge it (§6.2 requires it).
2. Same for the bottom row.
3. Same for the left column, right column.
4. Repeat until the rectangle stops growing.

So **calling `mergeCellsInHorizontalRange:verticalRange:` with a small range
that touches a large existing merge silently grows your merge to cover the
whole existing region.** This is intentional; the alternative is a hard
assertion. But it can produce surprising results if you don't expect it.

### 6.4 Configurability Restrictions on Merged Cells

`_verifyConfigurability` (0x18532441C) is invoked by every cell-property
setter and asserts:

1. The cell's row weak-ref is still alive (cell hasn't been removed from grid).
2. The cell is unmerged or is the merge head (`_isUnmergedOrHeadOfMergedRegion`,
   0x185324D24).

Therefore the following are runtime errors on a merged child cell:

- `setContentView:` (the placeholder check happens *before* the verify — but
  a real view goes through verify)
- `setXPlacement:`, `setYPlacement:`, `setRowAlignment:`
- `setCustomPlacementConstraints:` (only if the new array is non-empty)

All of them call `_verifyConfigurability` before mutating.

The same protection covers row/column removal: `_verifyRemovalOfRowColumn:`
(0x185320BB8) iterates each cell in the row/column and refuses if any cell is
*part of* a merged region (head *or* child). You cannot delete a row that
participates in a merge. Insertions are checked similarly via
`_verifyInsertionOfRowAtIndex:` / `_verifyInsertionOfColumnAtIndex:` — you
cannot insert *into the middle* of a row index where the existing row at
that position is a merged child.

---

## 7. Constraint Invalidation Triggers

Every state-mutating setter that affects layout terminates with
`[self.gridView setNeedsUpdateConstraints:YES]`. The full set follows.

### 7.1 Properties That Trigger `setNeedsUpdateConstraints:`

(Confirmed by `xrefs_to -[NSGridView setNeedsUpdateConstraints:]`.)

| Class | Setter |
|---|---|
| `NSGridView` | `_mergeCellsInRect:`, `removeRowAtIndex:`, `removeColumnAtIndex:`, `moveColumnAtIndex:toIndex:` (and the row counterpart by symmetry) |
| `NSGridRow` | `setYPlacement:`, `setRowAlignment:`, `setHidden:`, `setHeight:` |
| `NSGridColumn` | `setHidden:`, `setWidth:` (and `setXPlacement:` by symmetry) |
| `NSGridCell` | `setContentView:`, `setXPlacement:`, `setYPlacement:`, `setRowAlignment:`, `setCustomPlacementConstraints:` |

### 7.2 Properties That Do NOT Trigger Invalidation

The following setters update their backing ivar but **do not** call
`setNeedsUpdateConstraints:` — they are pure `@synthesize`d setters in the
binary:

| Class | Property | Why this matters |
|---|---|---|
| `NSGridView` | `xPlacement`, `yPlacement`, `rowAlignment` | Defaults that propagate via inheritance. Changing them after layout has run does **not** automatically redo layout. |
| `NSGridView` | `rowSpacing`, `columnSpacing` | Same problem; inter-row gaps come from `rowSpacing` reads inside `_findBottomBoundaryAnchorAndContentOffset:`, which are only re-evaluated when something else triggers layout. |
| `NSGridRow` | `topPadding`, `bottomPadding` | Same. |
| `NSGridColumn` | `leadingPadding`, `trailingPadding` | Same. |

In practice this means: **after changing the grid's defaults (placement,
alignment, spacing) at runtime, you must call `setNeedsUpdateConstraints:YES`
yourself**, or hide/show *some* row/column to force the path. Most of the
"why isn't my spacing change applying?" questions trace back here.

---

## 8. setContentView: Side Effects

`-[NSGridCell setContentView:]` (0x1853244F4) is the most side-effect-laden
setter in the entire grid implementation. Every assignment performs:

1. **`_verifyConfigurability`** — assert the cell is configurable (alive,
   unmerged-or-head).
2. **Sentinel collapse** — if the new view is the global empty placeholder,
   treat it as `nil`.
3. **Old-cell-table cleanup** — remove the previous content view's reverse
   mapping from `NSGridView._cellTable`.
4. **Duplicate-management check** — if the new view is already managed by
   *another* cell, raise `NSInvalidArgumentException` (`"content view %@ is
   already being managed by GridView cell %p"`).
5. **New cell-table insertion** — register `view -> self` in the map table.
6. **Force `translatesAutoresizingMaskIntoConstraints = NO`** —
   *unconditionally and silently*. This means any frame-based positioning you
   set on the view will stop working as soon as the view is added to the grid.
7. **Sync hidden state** — `view.hidden = row.isHidden || column.isHidden`.
8. **Auto-add as subview** — if the view is not already a (deep) subview of
   the grid, `removeFromSuperview` it and `addSubview:` to the grid.
9. **Trigger `setNeedsUpdateConstraints:`** on the grid.

Practical implications:

- **Do not pre-set the content view's frame.** It will be ignored.
- **Do not set `translatesAutoresizingMaskIntoConstraints = YES`** on a content
  view; the grid will toggle it back to NO.
- **Do not share a content view between two cells** — the second assignment
  raises an exception.
- **Do not add the content view to a different superview first** — the grid
  will remove it from there.

---

## 9. Insertion / Removal / Move Restrictions

| Operation | Side-effect / restriction |
|---|---|
| `insertRowAtIndex:withViews:` | If `views.count > numberOfColumns`, the grid silently *adds* empty columns until it fits. The new cells in pre-existing rows are filled with `emptyContentView`. |
| `insertColumnAtIndex:withViews:` | Symmetric — silent row addition. |
| `insertRowAtIndex:` / `insertColumnAtIndex:` | `_verifyInsertion...` asserts that no cell at the target index is currently a *merged child* — the insertion would split an existing merged region. |
| `removeRowAtIndex:` / `removeColumnAtIndex:` | `_verifyRemovalOfRowColumn:` asserts that no cell in the row/column is part of any merge (head OR child). |
| `moveRowAtIndex:toIndex:` / `moveColumnAtIndex:toIndex:` | Both `_verifyRemoval` and `_verifyInsertion` apply. Moving a row/column out of and back into a region containing merged cells will assert. |

The implication for libraries is that any code that programmatically rearranges
rows/columns must first dissolve all merges, then re-establish them after the
move.

---

## 10. Root Causes of Layout Ambiguity

Putting all of the above together, the recurring "constraint ambiguity" / "auto
layout misbehaviour" patterns with `NSGridView` come down to a small list of
root causes:

| # | Root cause | Symptom |
|---|---|---|
| 1 | Content view has neither an `intrinsicContentSize` nor explicit constraints, **and** the cell's `yPlacement`/`xPlacement` is `.fill` (default for `Y`). | Cell collapses to zero height/width; "view has ambiguous layout" |
| 2 | `NSGridRow.height` is set explicitly **and** the content view's intrinsic height differs from it. | "Unable to satisfy constraints" between the row's required-height anchor distance and the content view's `intrinsicContentSize` constraint. |
| 3 | `cell.yPlacement` is set non-default while the row/grid has `rowAlignment != .none`. | Setting appears ignored — see §5.2. |
| 4 | A row is hidden while a merged cell spans across it. | The hidden row's bottom anchor collapses onto its top, but the merged cell's `_findMergeTail` still returns a cell whose `_row._bottomContentAnchor` is the *next-after-hidden* row — produces an inconsistent constraint set. |
| 5 | Same content view re-used in another cell. | `NSInvalidArgumentException` at runtime. |
| 6 | `customPlacementConstraints` set on a cell that also has a non-default `xPlacement`/`yPlacement`. | Custom constraints + auto-placement constraints conflict; one of them wins arbitrarily. |
| 7 | `addRowWithViews:` called with a too-long array. | Grid silently grows its column count; previously-defined per-column widths/placements no longer cover all columns. |
| 8 | `mergeCellsInHorizontalRange:verticalRange:` called on a region overlapping an existing merge. | Auto-expansion (§6.3) silently enlarges the merge to engulf the existing region. |
| 9 | After changing `gridView.rowSpacing` / `columnSpacing` at runtime, layout does not refresh. | These setters do not call `setNeedsUpdateConstraints:` — see §7.2. |
| 10 | Pre-assigned `contentView.frame` or `translatesAutoresizingMaskIntoConstraints = YES`. | Silently overridden by `setContentView:` (§8). |
| 11 | Merged-child cell receives `setXPlacement:`/`setYPlacement:`/`setRowAlignment:`/`setContentView:`. | Hard `NSAssertionHandler` failure with `"Cell %@ has been merged and cannot have a content view"`. |
| 12 | Both `row.bottomPadding` and `gridView.rowSpacing` are intentionally non-zero. | They are *additive*; the visual gap is `bottomPadding + rowSpacing`, not `max(...)`. (§4.4) |

---

## 11. Safe Usage Patterns

The patterns below avoid every ambiguity in §10.

### Always provide an intrinsic size or anchor-based size for content views.

```swift
let label = NSTextField(labelWithString: "Name")
// NSTextField has intrinsicContentSize - safe.
gridView.addRow(with: [label, valueField])

// For custom views with no intrinsic size:
let custom = MyView()
custom.translatesAutoresizingMaskIntoConstraints = false   // grid will set this anyway
NSLayoutConstraint.activate([
    custom.widthAnchor.constraint(equalToConstant: 120),
    custom.heightAnchor.constraint(equalToConstant: 24),
])
gridView.addRow(with: [custom])
```

### Pick exactly one of `yPlacement` and `rowAlignment`.

```swift
// For text fields/labels that should baseline-align across the row:
gridView.rowAlignment = .firstBaseline
// Do NOT also set cell.yPlacement - it will be ignored.

// For non-text content that should hug the top:
gridView.rowAlignment = .none           // <-- required, because alignment != .none suppresses yPlacement
gridView.cell(atColumnIndex: 0, rowIndex: 0).yPlacement = .top
```

### Treat `row.height` as an override, not a hint.

Setting `row.height` produces a required-priority equality constraint. Use it
only when you *must* pin a row to a specific height (e.g. a separator row).
For variable-height rows, leave `_height` at its sentinel and let
`intrinsicContentSize` win.

### Always unmerge before re-merging.

```swift
gridView.mergeCells(inHorizontalRange: NSRange(location: 0, length: 1),
                    verticalRange: NSRange(location: 0, length: 1))   // unmerge
gridView.mergeCells(inHorizontalRange: NSRange(location: 0, length: 3),
                    verticalRange: NSRange(location: 0, length: 1))   // merge anew
```

If `_expandMergeBoundsIfNeeded:` would silently grow the merge, an explicit
unmerge avoids the surprise.

### Hidden rows + merged cells: dissolve first.

If you hide rows dynamically *and* use merged cells, dissolve all merges that
span the row before hiding it, and re-establish them after the row reappears.
The collapse-on-hidden behaviour does not coordinate with merge bounds.

### After mutating grid-level defaults, force a constraint update.

```swift
gridView.rowSpacing = 12
gridView.needsUpdateConstraints = true   // mandatory - the setter does not do this
```

### Never reuse a content view between two cells.

```swift
// This raises NSInvalidArgumentException:
gridView.cell(atColumnIndex: 0, rowIndex: 0).contentView = sharedView
gridView.cell(atColumnIndex: 1, rowIndex: 0).contentView = sharedView   // BOOM
```

If you need the same visual in two places, build two view instances.

### Match `addRow(with:)` to the current column count.

```swift
precondition(views.count == gridView.numberOfColumns,
             "Row width must match grid column count")
gridView.addRow(with: views)
```

This avoids the silent column-growth side effect.

---

## 12. Appendix: Decompiled Methods

All addresses are slid `__TEXT.__text` addresses for the AppKit binary in the
macOS 26.4 `dyld_shared_cache_arm64e` cache. Use them with `idalib_open` on
the corresponding cache binary.

| Address | Symbol | Notes |
|---|---|---|
| `0x18531EA70` | `-[NSGridEmptyContentView _allocatingPlaceholder]` | Singleton allocator, §2.3 |
| `0x18531EBA8` | `+[NSGridView gridViewWithNumberOfColumns:rows:]` | Class factory |
| `0x18531EC50` | `+[NSGridView gridViewWithViews:]` | 2D-array factory |
| `0x18531ED5C` | `-[NSGridView _commonPreInit]` | Defaults, §3 |
| `0x18531EDDC` | `-[NSGridView _commonPostInit]` | Lazy column/row arrays |
| `0x18531F100` | `-[NSGridView _safeHasSubview:]` | Used by `setContentView:` |
| `0x18531F274` | `-[NSGridView _verifyMergedRegionWithHead:]` | Merge integrity check |
| `0x18531F3A0` | `-[NSGridView _sanityCheck]` | Top-level integrity check |
| `0x18531F840` | `-[NSGridView _findVisibleThingNear:after:searchRows:]` | Hidden-row skipping |
| `0x185320820` | `-[NSGridView _setCell:forContentView:]` | Cell-table maintenance |
| `0x18532083C` | `-[NSGridView cellForView:]` | Reverse lookup |
| `0x185320AB8` | `-[NSGridView removeRowAtIndex:]` | §9 |
| `0x185320BB8` | `-[NSGridView _verifyRemovalOfRowColumn:]` | §9 |
| `0x185320CB4` | `-[NSGridView _verifyInsertionOfRowAtIndex:]` | §9 |
| `0x185320DFC` | `-[NSGridView _verifyInsertionOfColumnAtIndex:]` | §9 |
| `0x185320F44` | `-[NSGridView moveColumnAtIndex:toIndex:]` | §9 |
| `0x18532126C` | `-[NSGridView _insertColumnCells:atIndex:]` | Internal |
| `0x185321390` | `-[NSGridView removeColumnAtIndex:]` | §9 |
| `0x18532154C` | `-[NSGridView _insertRowAtIndex:withViews:]` | Auto-grow columns, §9 |
| `0x185321A60` | `-[NSGridView mergeCellsInHorizontalRange:verticalRange:]` | §6.3 |
| `0x185321AA8` | `-[NSGridView _unmergeCellsInRect:]` | §6.2 |
| `0x185321B64` | `-[NSGridView _expandMergeBounds:ifNeededForCell:]` | §6.3 |
| `0x185321D80` | `-[NSGridView _expandMergeBoundsIfNeeded:]` | §6.3 |
| `0x185321E90` | `-[NSGridView _mergeCellsInRect:]` | §6.2 |
| `0x185322270` | `-[NSGridRow initWithGridView:]` | Pre-fills empty cells |
| `0x18532260C` | `-[NSGridRow setYPlacement:]` | §7.1 |
| `0x185322624` | `-[NSGridRow setRowAlignment:]` | §7.1 |
| `0x18532263C` | `-[NSGridRow setHidden:]` | §7.1, §4.5 |
| `0x185322740` | `-[NSGridRow setHeight:]` | §7.1 |
| `0x1853228AC` | `-[NSGridRow _setViews:]` | Bulk assign content views |
| `0x185322B10` | `-[NSGridRow _sanityCheck]` | Integrity check |
| `0x185322E8C` | `-[NSGridRow _cellAtIndex:allocatingIfNeeded:]` | Lazy cell allocation |
| `0x185323014` | `-[NSGridRow mergeCellsInRange:]` | Delegates to grid |
| `0x18532306C` | `-[NSGridRow _removedFromGridView]` | Cleanup |
| `0x185323180` | `-[NSGridRow _topBoundaryAnchor]` | §4.2 |
| `0x1853231F0` | `-[NSGridRow _topContentAnchor]` | §4.3 |
| `0x185323254` | `-[NSGridRow _findBottomBoundaryAnchorAndContentOffset:]` | §4.4 |
| `0x18532330C` | `-[NSGridRow _bottomBoundaryAnchor]` | §4.4 |
| `0x185323314` | `-[NSGridRow _bottomContentAnchor]` | §4.3 |
| `0x185323350` | `-[NSGridRow _nextVisibleRow]` | §4.5 |
| `0x185323364` | `-[NSGridRow _previousVisibleRow]` | §4.5 |
| `0x1853236DC` | `-[NSGridColumn setHidden:]` | §7.1 |
| `0x1853237E0` | `-[NSGridColumn setWidth:]` | §7.1 |
| `0x185323A9C` | `-[NSGridColumn _removedFromGridView]` | Cleanup |
| `0x185323AA4` | `-[NSGridColumn mergeCellsInRange:]` | Delegates to grid |
| `0x185323AFC` | `-[NSGridColumn _leadingBoundaryAnchor]` | §4.2 |
| `0x185323B6C` | `-[NSGridColumn _leadingContentAnchor]` | §4.3 |
| `0x185323BD0` | `-[NSGridColumn _findTrailingBoundaryAnchorAndContentPadding:]` | §4.4 |
| `0x185323C88` | `-[NSGridColumn _trailingBoundaryAnchor]` | §4.4 |
| `0x185323C90` | `-[NSGridColumn _trailingContentAnchor]` | §4.3 |
| `0x185323D68` | `-[NSGridCell initWithRow:column:]` | Empty `_customPlacementConstraints` |
| `0x1853241F0` | `-[NSGridCell setYPlacement:]` | §7.1 |
| `0x185324244` | `-[NSGridCell setXPlacement:]` | §7.1 |
| `0x185324298` | `-[NSGridCell setRowAlignment:]` | §7.1 |
| `0x1853242E4` | `-[NSGridCell _removedFromGridView]` | Cleanup |
| `0x185324368` | `-[NSGridCell setCustomPlacementConstraints:]` | §7.1 |
| `0x18532441C` | `-[NSGridCell _verifyConfigurability]` | §6.4 |
| `0x1853244F4` | `-[NSGridCell setContentView:]` | §8 |
| `0x1853247D4` | `-[NSGridCell _optimalContentLayoutRect]` | §4.6 |
| `0x1853248F8` | `-[NSGridCell layoutRect]` | Raises `Unimplemented` |
| `0x185324930` | `-[NSGridCell _effectiveXPlacement]` | §5.1 |
| `0x185324984` | `-[NSGridCell _effectiveYPlacement]` | §5.1, §5.2 |
| `0x1853249F8` | `-[NSGridCell _effectiveAlignment]` | §5.1 |
| `0x185324A48` | `-[NSGridCell _isMerged]` | `headOfMergedCell != nil` |
| `0x185324A58` | `-[NSGridCell _isMergeHead]` | `headOfMergedCell == self` |
| `0x185324A68` | `-[NSGridCell _findMergeBounds]` | §6.1 |
| `0x185324BB0` | `-[NSGridCell _findMergeTail]` | §6.1 |
| `0x185324D24` | `-[NSGridCell _isUnmergedOrHeadOfMergedRegion]` | §6.4 |
