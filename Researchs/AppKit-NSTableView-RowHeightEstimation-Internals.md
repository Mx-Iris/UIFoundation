# AppKit NSTableView Row Height Estimation Internals

> Static analysis: macOS 27.0 (26A428) AppKit (arm64e), IDA Pro decompilation and disassembly of
> the image in `dyld_shared_cache_arm64e`. Every address below is a slid text address in that
> cache and moves between releases.
>
> Behaviour: measured on macOS 15.5 (24F74), 26.6.2 (25G83) and 27.0 (26A428) with one and the
> same test binary. The selector `_setEstimatesRowHeights:` is present in the macOS 14.7, 15.0,
> 15.5, 26.0 and 26.3 caches as well (string search only).
>
> **Why this report exists.** In a source list outline with group rows — a kind-grouped sidebar —
> rows end up drawn over each other after a reload, or a disclosure, while the list is scrolled
> far down. The cause is AppKit's row-height estimation, a private mode that `-setDelegate:` turns
> on by itself. This report records what the switch does, what turns it on, and the measurements
> that tie it to the symptom. The API built on it is `NSTableView.box.estimatesRowHeights`
> (`Sources/UIFoundationAppleInternal/TableView/NSTableView+RowHeightEstimation.swift`).

---

## 1. The switch

`NSTableRowHeightData` (the table's row geometry store, `-[NSTableView _rowHeightData]`) carries
the state:

```objc
@interface NSTableRowHeightData : NSObject <NSCopying> {
    NSTableView *_tableView;                       // +0x08
    NSInteger _numberOfRows;                       // +0x10
    struct { CGFloat x0; CGFloat x1; } *_rowSpans; // +0x18
    NSInteger _rowSpansCapacity;                   // +0x20
    NSInteger _gapRow;                             // +0x28
    CGFloat _gapRowHeight;                         // +0x30
    CGFloat _estimatedRowHeight;                   // +0x38
    NSMutableIndexSet *_cachedRows;                // +0x40
    int32_t _hasValidNumberOfRows : 1;             // +0x48, 0x01
    int32_t _supportsVariableRowHeights : 1;       //        0x02
    int32_t _hasValidRowSpansStorage : 1;          //        0x04
    int32_t _updatingRowSpans : 1;                 //        0x08
    int32_t _automaticallyEstimatesRowHeights : 1; //        0x10
}
```

Rows outside `_cachedRows` are laid out at `_estimatedRowHeight`; a row is cached once its real
height has been computed.

| Method | Address | What it does |
|---|---|---|
| `-[NSTableView _estimatesRowHeights]` | `0x185B42F08` | `_rowHeightData != nil && (flags & 0x10) != 0` |
| `-[NSTableView _setEstimatesRowHeights:]` | `0x185B42F30` | See below |
| `-[NSTableRowHeightData setAutomaticallyEstimatesRowHeights:]` | `0x1859F9CFC` | On a change: flips `0x10`, allocates `_cachedRows` (on) or releases it (off), then `-invalidate` |
| `-[NSTableRowHeightData invalidate]` | `0x1859F9BF0` | Sets `_numberOfRows` and `_gapRow` to −1, clears flags `0x01`, `0x02` and `0x04` (`AND W8, W8, #0xF8` at `0x1859F9C2C`), zeroes `_estimatedRowHeight`, empties `_cachedRows`, frees the row spans |

`-_setEstimatesRowHeights:`:

1. `NO` stays `NO`. `YES` becomes `YES` only when **all** of the following hold (otherwise it is
   treated as `NO`):
   - the app configuration `NSTableViewCanEstimateRowHeights` is true (section 3);
   - `-isViewBased`;
   - two flags of the second `_tvFlagsExtra` word are clear, `0x6000000` and `0x10000000` (their
     meaning was not established);
   - `-_supportsVariableHeightRows` (section 3).
2. If the result equals the current flag, return.
3. Otherwise `-[NSTableRowHeightData setAutomaticallyEstimatesRowHeights:]`, and then, when the
   row height data has a valid row count or valid span storage (`flags & 0x05`),
   `-[NSTableView reloadData]` — tail-called through `objc_msgSend` at `0x185B42FFC`. **That
   reload is never reached.** The flags are read back after
   `-setAutomaticallyEstimatesRowHeights:` has run `-invalidate`, which clears both of them, so
   the check always fails. A runtime counter on a `reloadData` override agrees: it stayed at zero
   through delegate changes that flipped the switch and through direct switches of a populated,
   displayed list. What a switch does is discard the row geometry, to be recomputed on the next
   query; the row views already on screen are left where they are (section 4.5).

## 2. Who asks for it

Cross-references to `_objc_msgSend$_setEstimatesRowHeights:` — the only way the method is reached:

| Caller | Call site | Argument |
|---|---|---|
| `-[NSOutlineView setDelegate:]` | `0x184F752D8` (tail call) | `YES` |
| `-[NSTableView setDelegate:]` | `0x184FA1C7C` | `YES` — not read off the disassembly, but a runtime probe on 27.0 shows it: a plain `NSTableView` with group rows, or with automatic row heights, estimates once its delegate is set, and again after the delegate is re-assigned; with `rowSizeStyle = .custom` and neither, it never does |
| `-[NSTableViewBackedMenuRepresentation init]` | `0x185989E6C` | not inspected |

`-[NSOutlineView setDelegate:]` does its work only when the delegate actually changes, and ends
with `[self _setEstimatesRowHeights:YES]`. So **every change of delegate asks for estimation
again**, whatever was set before — including the resets a delegate proxy performs on its own
(RxCocoa-style proxies re-assign themselves to refresh AppKit's `respondsToSelector:` cache).
Nothing else in AppKit turns estimation on or off.

## 3. When the request is granted

### 3.1 The app configuration

The first `YES` request reads `NSTableViewCanEstimateRowHeights` through
`_NSGetBoolAppConfig` (`0x184ED0B38`):

- `-[NSUserDefaults standardUserDefaults] objectForKey:` — any domain, the argument domain
  included — decides when present;
- otherwise `NSTableViewCanEstimateRowHeightsDefaultValueFunction` (`0x185B4367C`), which returns
  `YES` for every app except three by bundle identifier: `com.iconfactory.Twitterrific5` and
  `com.kurzweiledu.3000` (any version), `com.filemaker.client.pro12` before version 22;
- the result is cached for the life of the process (`sNSTableViewCanEstimateRowHeightsComputedValue`);
  a value that differs from the default is reported to analytics, and logged when it came from the
  command line or `NSLogUnusualAppConfig` is set.

Setting the default to `NO` therefore turns estimation off for **every** table in the process —
including tables with `usesAutomaticRowHeights`, which rely on estimation to avoid measuring every
row's Auto Layout height up front.

### 3.2 Variable-height rows

`-[NSTableView _supportsVariableHeightRows]` (`0x184FA3AD0`) is
`_hasVariableRowHeightsBecauseOfGroupRows || _hasVariableRowHeights`:

- `-_hasVariableRowHeightsBecauseOfGroupRows` (`0x1857F0ADC`): the delegate answers the group-row
  question — flag `0x40` of the byte at `+0x328`, which is bit 38 of `_tvFlagsExtra` (ivar offset
  804) and which `-[NSOutlineView setDelegate:]` sets from `outlineView:isGroupItem:` — and then
  either `NSTableViewCanUseGoldenStyles()`, or the table is not an outline view, or
  `-_usesSourceListColors`.
- `-_hasVariableRowHeights` (`0x1857F0A68`): the delegate answers a height-of-row method (flag
  `0x20` of that byte, bit 37, from `outlineView:heightOfRowByItem:`), or `rowSizeStyle` is not
  `.custom`, or `-_hasInterGroupSpacing` (not decompiled; read from the name), or
  `usesAutomaticRowHeights`.

A source list outline whose delegate implements `outlineView(_:isGroupItem:)` satisfies the first
clause, so it estimates from the moment its delegate is set.

## 4. What goes wrong while estimating (measured)

### 4.1 The geometry

Source list style, `rowHeight` 24, rows served by a view-based outline with group rows, measured
identically on all three releases:

| Row | `rect(ofRow:)` |
|---|---|
| a regular row | 24 pt tall |
| a group row | 19 pt tall |
| gap above every group row but the first | 13 pt, outside any row's rect |

So rows differ in height and the table estimates. `rect(ofRow:)` answers from the estimate for
rows that were never measured, and the answer moves as rows get measured: in a 1,192-row list,
two successive queries for row 700 returned `y 16811.32` and then `y 16867.54`, with only other
rows' geometry queried in between. The table's own frame height is an estimate as well
(`28738.175` before layout, `28738.0` after).

### 4.2 The symptom

Scroll a list like the one above past its second group row, then call `-reloadData` — or expand an
item there. The next layout places part of the visible rows at estimated positions and corrects
the estimate part-way through; the row views already placed are not moved. Nothing is visibly
wrong yet, because the stale views are consistent with each other. The next scroll brings in rows
at the corrected positions, and those are drawn over the stale ones: two row views at nearly the
same `y`, different titles. The offset between the two is the estimate's error — 0.1 pt to 72 pt
in the runs recorded here.

**The list must contain at least one expandable item.** With the same group rows and the same
row count but no item that has children, no row was ever misplaced, estimation or not (checked
with one expandable row in fifty, one in ten and one in three: all misplace; none: never).
A kind-grouped sidebar always has nested types, so this condition holds there.

Deterministic reproductions, identical verdicts and misplacement counts on 15.5, 26.6.2 and 27.0:

| Sequence (after the list is loaded and laid out) | Estimating | Estimation off |
|---|---|---|
| scroll to y 20000 → `reloadData` → scroll to y 20100 | rows drawn over each other | clean |
| same, laying out synchronously after each step | rows drawn over each other | clean |
| scroll to y 27800 → expand an item there (animated or not) → scroll up 100 | rows drawn over each other | clean |

Randomized sessions (typing into a filter, clearing it, jumping to far objects, full reloads,
disclosures, scrolling; 240 steps each) misplaced rows in 7 of 7 seeds with estimation on — 1 to 7
failing checkpoints per seed, depending on the seed and the release. With estimation turned off
after every change of delegate, 6 of the 7 seeds were clean; the seventh is section 4.3.

### 4.3 An unconfirmed residue: animated collapse with estimation off

In one run, with estimation off, a group row stayed 24 pt below its `rect(ofRow:)` after an
*animated* collapse of an item above it, and a later scroll drew the next row over it. The same
sequence reproduced three more times in a row — all while a second copy of the harness was
running on the same machine — and then not once in 26 reruns, 6 reruns of the build that had
produced it, 20 reruns next to a concurrent harness, or with the main thread stalled during the
animation. It never appeared with a non-animated collapse, and never with estimation on. It is
recorded here as timing-dependent and unconfirmed; making disclosures non-animated (a
zero-duration `NSAnimationContext` around `expandItem`/`collapseItem`) did avoid it in every run
where it had appeared.

### 4.4 Workarounds that were measured and rejected

| Workaround | Outcome |
|---|---|
| `floatsGroupRows = false` | Fixes the reload sequence, not the expansion one |
| Ask `rect(ofRow:)` for every row after each structural change | Fixes most sequences; when the table has already tiled inside `-reloadData`, the refinement it triggers *creates* stale rows (seen after keyboard selection moved to the last row) |
| `noteHeightOfRows(withIndexesChanged:)` for all rows, `tile()`, `layoutSubtreeIfNeeded()` after the reload | No effect |
| A height-of-row delegate returning one height for every row | No effect: the 13 pt gap above group rows remains, so rows still differ |
| The `NSTableViewCanEstimateRowHeights` default | Works, but for every table in the process (section 3.1) |

### 4.5 Switching with estimated rows on screen

Section 1, step 3 predicts that a switch leaves the displayed rows alone. Measured with the list of
section 4.2 scrolled to y 27800 with estimation on, then switched off, on 27.0:

| After switching off | Rows not at `rect(ofRow:)` |
|---|---|
| nothing | 27 — every visible row, 56 pt below where the table now places it |
| `layoutSubtreeIfNeeded()`, or a run loop turn | 27, unchanged |
| `noteHeightOfRows(withIndexesChanged:)` for all rows | 27, unchanged |
| `tile()` | 24, and 5 pairs of rows drawn over each other |
| `reloadData()` | none, and none after a further scroll |
| (switched off while the list still showed its first rows) | none, and none after scrolling to y 27800 |

So a switch is safe while the rows on screen were measured rather than estimated — before the
table shows rows, or in the same call in which `-setDelegate:` turned estimation on — and needs a
`reloadData()` otherwise. Neither `needsLayout` nor `needsDisplay` is set by the switch.

### 4.6 Cost

Turning estimation off costs one exact pass over the row geometry per reload: in the same
harness, `reloadData` plus layout of a 14,205-row list took 27–34 ms against 22–32 ms while
estimating; for 1,192 rows the difference was lost in the noise. Turning it back off after each
change of delegate adds nothing measurable either: re-assigning the delegate of the 14,205-row
list the way a delegate proxy does (nil, then the delegate again), plus layout, took 13–60 ms with
and without it.

## 5. Using the switch

1. Set the delegate first; turn estimation off after it (section 2).
2. Turn it off again after every change of delegate — a subclass does this in an override of
   `delegate`'s setter.
3. Check support before calling: `NSTableView.instancesRespond(to:)` for both selectors. The
   library's wrapper returns `nil` and ignores assignments when either is missing.
4. Switch before the table shows rows, or call `reloadData()` after switching: a switch moves no
   row view that is already on screen (section 4.5).
