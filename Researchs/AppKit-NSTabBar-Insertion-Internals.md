# AppKit NSTabBar Insertion Internals

> Based on reverse engineering macOS 26.5 AppKit (arm64e) via IDA Pro decompilation, cross-checked
> against a live `NSTabBar` driven through `NSWindow.tabbingMode = .preferred`.
> Covers what happens when a tab is **added** to the Liquid-Glass window tab bar: how the strip
> scrolls to reveal it, and why the surrounding layout pass is ordered the way it is.
> Companion to the stacking geometry replicated in `TabsControl+Stacking.swift`.

---

## Table of Contents

- [1. Why this matters](#1-why-this-matters)
- [2. Measured behaviour](#2-measured-behaviour)
- [3. The insertion entry point](#3-the-insertion-entry-point)
- [4. The layout pass that reveals the tab](#4-the-layout-pass-that-reveals-the-tab)
- [5. The scroll target](#5-the-scroll-target)
- [6. `_isScrollingToRevealAddedTab`](#6-_isscrollingtorevealaddedtab)
- [7. Where a new tab starts from](#7-where-a-new-tab-starts-from)
- [8. The reveal must not move anything on screen](#8-the-reveal-must-not-move-anything-on-screen)
- [9. Tab width has no maximum](#9-tab-width-has-no-maximum)
- [10. Ivar and flag map](#10-ivar-and-flag-map)
- [11. Method of measurement](#11-method-of-measurement)

---

## 1. Why this matters

A stacked tab bar folds its overflow into compressed piles at the ends. Because folding is what keeps
every tab inside the viewport, **every** tab is trivially "visible" in the AppKit sense — so the
obvious implementation, `scrollRectToVisible:` on the tab's own frame, never scrolls at all. A bar
built that way sits still while each newly added tab piles up at the end and disappears.

The system does not do that. It scrolls the strip explicitly, and it decides where to scroll from the
tab's **un-stacked** slot rather than its folded frame.

## 2. Measured behaviour

Appending window tabs one at a time to a 700 pt window (680 pt clip, 120 pt minimum tab width) and
reading `clipView.bounds.origin.x` once each insertion settles:

| tabs | offset | layout (viewport-relative `x(width)`, `·` = faded out) |
| ---: | -----: | --- |
| 5  | 0   | `0(136) 137(135) 273(135) 409(135) 545(135)` — still divides evenly, no stacking |
| 6  | 40  | `0(80) 80(120) 200(120) 320(120) 440(120) 560(120)` |
| 7  | 160 | `0(26) 26(54) 80(120) 200(120) 320(120) 440(120) 560(120)` |
| 8  | 280 | `0(3) 3(23) 26(54) 80(120) …` |
| 12 | 760 | `-38(7·) -31(8·) -23(11·) -12(15) 0(0·) 3(23) 26(54) 80(120) …` |

Two things stand out. The offset grows by exactly one tab width per insertion, landing at
`120 · tabCount − 680` — the maximum scroll offset. And the trailing five full-width tabs never move:
the pile accretes on the **leading** side while the newest tab stays flush against the trailing edge.

Inserting into the middle instead — parking the selection at index 2 of a stacked 10-tab bar and then
inserting next to it repeatedly — gives:

| step | offset | note |
| --- | ---: | --- |
| appended to 10 | 520 | |
| select #2 | 520 | **unchanged** — selecting never scrolls |
| insert at 3 | 155 | scrolls back to reveal the new tab |
| insert at 4 | 155 | already un-compressed, no scroll |
| insert at 5 | 155 | ditto |
| insert at 6 | 245 | would have landed in the trailing ramp, so it scrolls |

## 3. The insertion entry point

```objc
- (void)insertTabBarViewItem:(NSTabBarItem *)item atIndex:(NSUInteger)index animated:(BOOL)animated
{
    NSAssert(![_tabBarViewItems containsObject:item]);
    NSAssert(index <= _tabBarViewItems.count);

    if (_selectedTabButtonIndex == NSNotFound) {
        NSAssert(_tabBarViewItems.count == 0);
        _selectedTabButtonIndex = 0;
    } else if (index <= _selectedTabButtonIndex) {
        _selectedTabButtonIndex += 1;          // the selection keeps its *tab*, not its slot
    }

    [_tabBarViewItems insertObject:item atIndex:index];
    _flags &= ~0x08;                           // clears _isInteractivelyClosingTabs

    if (_firstInsertedTabButtonIndex == NSNotFound)
        _firstInsertedTabButtonIndex = index;  // first insertion since the last layout wins

    if (!item.hideTab) {
        [self _recalculateLayout];
        [self _insertTabButtonWithTabViewItem:item atIndex:index];
        [self _scheduleButtonLayOutAnimated:animated];
    }
}
```

Three points worth transcribing:

- **Adding a tab ends a run of interactive closes.** The width pin that keeps survivors under the
  pointer exists to make repeated closing possible; a new tab needs room, so the strip must divide
  itself afresh.
- **The selection index is a plain increment**, not a selection change. Inserting ahead of the
  selected tab shifts its index while the same tab stays selected — no notification, no delegate call.
- **The inserted index is recorded, not acted on.** The scroll happens later, in the layout pass.

## 4. The layout pass that reveals the tab

```objc
- (void)_reallyUpdateButtonsAndLayOutAnimated:(BOOL)animated isSelectingButton:(BOOL)isSelecting
{
    BOOL windowVisible = animated ? self.window.isVisible : NO;

    if (self._numberOfTabsForLayout < 2) _flags &= ~0x08;

    [self _updatePinnedTabs];
    [self _updateNewTabButton];

    _flags |= 0x10;                                    // _isScrollingToRevealAddedTab
    if (!(_flags & 0x08)) {                            // not interactively closing
        [self _recalculateLayoutAndUpdateContainerViewFrames];
        if (_firstInsertedTabButtonIndex != NSNotFound) {
            [self _scrollToButtonAtIndex:_firstInsertedTabButtonIndex canScrollSelectedButton:YES];
            [self _recalculateLayoutAndUpdateContainerViewFrames];
        }
    }
    _firstInsertedTabButtonIndex = NSNotFound;         // consumed either way
    _flags &= ~0x10;

    if (isSelecting) _flags |= 0x04;                   // _selectionIsChanging

    if (windowVisible) {
        [self _beginAnimationGrouping];
        [self _layOutButtonsAnimated:YES];
        [self _restackButtonViews];
        [self _updateButtonStateAndKeyLoop];
        [self _updateIndexOfTabUnderCurrentMouseLocation:YES];
        [self _updateSeparatorVisibility];
        [self _endAnimationGrouping];
    } else {
        [self _layOutButtonsAnimated:NO];
        …
    }
}
```

The ordering is the whole trick:

1. **Container frames first.** The document view has to be able to hold the new offset before the
   clip view is asked to move there, or the move is clamped back to the old end of a strip that has
   since grown.
2. **Scroll second, unanimated.** `_scrollToButtonAtIndex:` finishes with
   `_syncedScrollBoundsToOrigin:animated:NO`.
3. **Recalculate again**, so the layout about to run is expressed against the offset the scroll left
   behind.
4. **Animate last.** The buttons spring from wherever they visually are to their final places. Had
   the scroll been animated, or run afterwards, the tabs would be chasing a viewport still in motion.

Note that the reveal is skipped entirely while `_isInteractivelyClosingTabs` is set — moving the
strip mid-close would pull the next close button out from under the pointer — but
`_firstInsertedTabButtonIndex` is consumed regardless, so a pending reveal is dropped rather than
deferred.

## 5. The scroll target

```objc
- (void)_scrollToButtonAtIndex:(NSUInteger)index canScrollSelectedButton:(BOOL)canScrollSelected
{
    if (!(_flags2 & 0x80)) return;                       // only a stacked bar can hide a tab
    if (!canScrollSelected && index == _selectedTabButtonIndex) return;

    NSRect slot = [self _unstackedFrameForButtonAtIndex:index];
    NSRect unstacked = [self _rectWithUnstackedButtons];
    if (NSContainsRect(unstacked, slot)) return;         // already standing at full width

    CGFloat target;
    if (NSMinX(slot) >= NSMinX(unstacked))
        target = NSMaxX(slot) - _layoutBounds.size.width + [self _effectiveRightStackWidthForButtonAtIndex:index];
    else
        target = NSMinX(slot) - [self _effectiveLeftStackWidthForButtonAtIndex:index];

    [self _syncedScrollBoundsToOrigin:NSMakePoint(target, 0.0) animated:NO];
}
```

with

```objc
- (CGFloat)_effectiveLeftStackWidthForButtonAtIndex:(NSUInteger)index
{
    if (index == 0) return 0.0;
    CGFloat width = _slowingDistance;
    if (index > _selectedTabButtonIndex) width += _firstButtonFrame.size.width;
    return width;
}

- (CGFloat)_effectiveRightStackWidthForButtonAtIndex:(NSUInteger)index
{
    if (index == _numberOfTabsForLayout - 1) return 0.0;
    CGFloat width = _slowingDistance;
    if (index < _selectedTabButtonIndex) width += _firstButtonFrame.size.width;
    return width;
}
```

The tab is measured by its **un-stacked slot** — where it would sit if nothing were folded — and the
target is the shortest scroll that brings that slot just past the pile on whichever side it overflows.
The extra tab width appears when the frontmost tab lies between the pile and the tab in question,
because the frontmost tab is held out at full width in front of its pile.

`_slowingDistance` is the width of one compression ramp: `128 · min(visibleWidth / 1024, 1)`, so
85.0 pt in a 680 pt bar. Checking the measurements against the formula:

- **insert at 3**, 11 tabs, offset 520 → slot `[360, 480]` lies before the visible range, so
  `360 − (85 + 120) = 155`. ✔
- **insert at 6**, 14 tabs, offset 155 → slot `[720, 840]` overflows the trailing side, so
  `840 − 680 + 85 = 245`. ✔
- **append**, `n` tabs → the last slot's `maxX` is the content width and the trailing stack width is
  zero, so the target collapses to `120n − 680`, the maximum offset. ✔ (all seven appends)

`_rectWithUnstackedButtons` is `_layoutBounds` inset by `_layoutBoundsEdgeInsetsForUnstackedButtons`,
which also allows for pinned tabs. Deriving those insets from the same two effective stack widths
reproduces every measured case and makes the containment test exactly complementary to the target
arithmetic: scrolling to the target lands the slot on the boundary, so a second call is a no-op.

## 6. `_isScrollingToRevealAddedTab`

The reveal moves the clip view, and the clip view's bounds-changed notification is also how a *user*
scroll reaches the bar. Bit `0x10` tells the two apart:

```objc
- (void)_clipViewBoundsChanged:(NSNotification *)notification
{
    NSAssert(notification.object == _scrollView.contentView);
    if ((_flags & 0x10) == 0) {
        _flags &= ~0x08;               // a real scroll ends a run of interactive closes
        [self setNeedsLayout:YES];
    }
}
```

While the flag is set the notification is ignored wholesale — it neither releases the close pin nor
schedules a layout. Without it the bar would lay itself out unanimated in the middle of the reveal
and cancel the very insertion animation the scroll was preparing for.

## 7. Where a new tab starts from

`NSTabButton` is created with a **zero-width** frame, and which edge of its target slot that frame
sits on depends on where the tab is going:

```objc
- (void)_insertTabButtonWithTabViewItem:(NSTabBarItem *)item atIndex:(NSUInteger)index
{
    NSUInteger buttonCount = _tabButtons.count;                  // before the insertion
    NSRect adjusted = [self _adjustedFrameForButtonAtIndex:index isHidden:NULL];

    CGFloat originX = (index >= buttonCount) ? NSMaxX(adjusted)          // appended
                                             : round(NSMidX(adjusted));  // inserted between two
    NSRect documentFrame = _documentView.frame;
    if (originX >= NSMinX(documentFrame)) originX = MIN(originX, NSMaxX(documentFrame));

    NSRect frame = [self _viewFrameForAdjustedButtonFrame:
                        NSMakeRect(originX, adjusted.origin.y, 0.0, adjusted.size.height)];
    NSTabButton *button = [[NSTabButton alloc] initWithFrame:frame tabBarViewItem:item];
    …
}
```

An appended tab therefore unfurls **leftward from the trailing edge** of the strip, and a tab inserted
between two others opens **symmetrically about its slot's midpoint**. Both are visible in the frame
sampling: appending, the new tab's right edge stays pinned at 680 (the viewport's trailing edge)
throughout its growth; inserting into an evenly divided bar, its centre stays fixed while the width
grows — 168 pt wide 99 at one sample, settling at 145 wide 143, centres 217.5 and 216.5.

There is no opacity change anywhere in this. A tab that is "appearing" only ever changes width.

## 8. The reveal must not move anything on screen

Button frames live in the scrolling document's space, so what the user sees is that space minus the
scroll offset. The reveal moves the offset in a single step — which means a tab that should appear to
stay put has to travel exactly that far *through the document*.

Measured across an append that scrolls 120 pt, the system shows no leap at all. Immediately after the
insertion the eight existing tabs are at `0 1 23 72 182 302 422 542`, against `0 3 26 80 200 320 440
560` before it, and they then glide to `-12 0 3 26 80 200 320 440` — each exactly one slot deeper into
its pile. An implementation that animates from the pre-scroll document position instead produces the
opposite reading: the strip jumps sideways by the full scroll distance on the first frame and spends
the whole animation walking back, so the leading tabs visibly fly in from off-screen.

## 9. Tab width has no maximum

Measured on a live `NSTabBar`: two tabs in a 1480 pt clip are 739 and 740 pt wide; three are 493 pt;
four are 369 pt. Tabs always divide the whole bar, with no upper bound, until the share would drop
below the 120 pt minimum — at which point stacking takes over and locks the width there.

This is not merely cosmetic. A maximum freezes the layout: once the existing tabs are capped, adding
one moves nothing, and the insertion has no motion to be read from at all.

## 10. Ivar and flag map

Offsets are for `NSTabBar` on macOS 26.5 arm64e, obtained from a runtime `class_copyIvarList` dump.

| offset | field |
| ---: | --- |
| 584 | `_tabBarViewItems` |
| 600 / 608 | `_tabBarViewItemsToTabButtons` / `…ToTabSeparators` (`NSMapTable`, keyed by item) |
| 616 | `_selectedTabButtonIndex` |
| 632 | `_firstInsertedTabButtonIndex` |
| 704 / 720 | `_layoutBounds.origin.x` / `.size.width` |
| 736 / 752 | `_firstButtonFrame.origin.x` / `.size.width` |
| 784 | `_numberOfTabsForLayout` |
| 800 / 816 / 824 | `_edgeScrollingFactor` / `_selectedButtonSlowingFactor` / `_slowingDistance` |
| 872 | `_numberOfPinnedTabs` |
| 968 bit 0x80 | `_isStackingButtons` |
| 969 bit 0x04 | `_selectionIsChanging` |
| 969 bit 0x08 | `_isInteractivelyClosingTabs` |
| 969 bit 0x10 | `_isScrollingToRevealAddedTab` |
| 969 bit 0x40 | `_didScheduleAnimatedLayout` |

## 11. Method of measurement

Claims here are checked, not inferred. A probe process drives a real tab group in the same address
space (`window.tabbingMode = .preferred`, `addTabbedWindow(_:ordered:)` on the **last** window to
append and on the selected window to insert next to it), walks the view hierarchy for `NSTabBar`,
`NSTabBarClipView` and `NSTabButton`, and prints frames converted into the clip view's coordinate
space after each change settles.

Two details cost real time if missed:

- The tab bar belongs to whichever window of the group is currently frontmost, so it has to be looked
  up across every window rather than held onto from the first one.
- `addTabbedWindow(_:ordered: .above)` inserts next to the **receiver**. Calling it on the first
  window repeatedly inserts at index 1 — that is a middle insert, not an append.

Layout inputs can also be read straight out of the ivars above and fed back through a transcription
of the formula, which separates a wrong formula from wrong inputs. That technique is what pinned
`_slowingDistance` to 85.0 pt independently of the decompiled constant.
