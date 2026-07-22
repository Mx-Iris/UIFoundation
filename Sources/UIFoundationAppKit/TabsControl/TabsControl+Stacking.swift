//
//  TabsControl+Stacking.swift
//  UIFoundation
//
//  Reimplementation of the macOS system window-tab bar's tab *stacking* behaviour, reverse-engineered
//  from AppKit 26.5 (`NSTabBar`).
//
//  Once the tabs no longer fit at their minimum width the bar stops shrinking them: the width locks
//  to `minimumTabWidth` and the strip becomes horizontally scrollable, with the tabs that fall
//  outside the viewport telescoping into a compressed pile at each edge. The selected ("frontmost")
//  tab always keeps its full width and stays visible, acting as the anchor the piles fold against.
//
//  Everything here is pure geometry: given the tab count, the viewport width, the scroll offset and
//  the frontmost index, it yields each tab's on-screen x and width. The whole fan effect falls out of
//  a single offset function — a tab's width is simply `offset(i + 1) - offset(i)`, so as the offsets
//  bunch up near an edge the tabs visually collapse into slivers.
//

#if TabsControl && os(macOS)

import AppKit
import Foundation

extension TabsControl {
    /// The piles that currently exist in the bar. Clicking one scrolls the bar to expand it.
    ///
    /// Mirrors AppKit's internal 4-bit stacking-region mask.
    public struct StackingRegion: OptionSet {
        public let rawValue: Int

        public init(rawValue: Int) {
            self.rawValue = rawValue
        }

        /// Tabs have overflowed past the leading edge of the viewport.
        public static let leadingOverflow = StackingRegion(rawValue: 1 << 0)
        /// Tabs have overflowed past the trailing edge of the viewport.
        public static let trailingOverflow = StackingRegion(rawValue: 1 << 1)
        /// The selected tab is parked against an edge, piling the tabs before it against its leading side.
        public static let leadingOfSelected = StackingRegion(rawValue: 1 << 2)
        /// The selected tab is parked against an edge, piling the tabs after it against its trailing side.
        public static let trailingOfSelected = StackingRegion(rawValue: 1 << 3)
    }

    /// The scroll view driving the tab strip.
    ///
    /// A tab bar only ever scrolls horizontally, so a plain (non-precise) mouse wheel — which reports
    /// vertical deltas — would otherwise do nothing. This converts a vertical-dominant wheel into
    /// horizontal scrolling, mirroring `-[NSTabBarClipView shouldChangeNextScrollFromVerticalToHorizontal]`.
    /// Trackpad gestures keep their precise deltas and are passed straight through, so a genuine
    /// two-finger horizontal swipe still scrolls natively.
    final class TabsScrollView: NSScrollView {
        override func scrollWheel(with event: NSEvent) {
            let verticalDelta = event.scrollingDeltaY
            let horizontalDelta = event.scrollingDeltaX
            guard !event.hasPreciseScrollingDeltas, abs(verticalDelta) >= abs(horizontalDelta) else {
                super.scrollWheel(with: event)
                return
            }

            let clipView = contentView
            let maximumOffset = max(0.0, (documentView?.frame.width ?? 0.0) - clipView.bounds.width)
            guard maximumOffset > 0.0 else { return }

            var origin = clipView.bounds.origin
            origin.x = min(max(0.0, origin.x - verticalDelta), maximumOffset)
            clipView.setBoundsOrigin(origin)
            reflectScrolledClipView(clipView)
        }
    }

    /// Pure geometry for the stacked layout.
    ///
    /// All x values it returns are **viewport-relative** (the scroll offset is already subtracted),
    /// matching AppKit, which computes button positions in the visible bar's coordinate space.
    struct StackingGeometry {
        /// Number of tabs participating in the layout.
        let tabCount: Int
        /// The locked tab width while stacking (AppKit uses 120 pt).
        let tabWidth: CGFloat
        /// Width of the visible bar area.
        let visibleWidth: CGFloat
        /// Current horizontal scroll offset.
        let scrollOffset: CGFloat
        /// Height of a tab.
        let barHeight: CGFloat
        /// The tab the piles fold against — normally the selected tab.
        let frontmostIndex: Int?

        // MARK: - Derived metrics

        /// Total width of the un-stacked strip.
        var contentWidth: CGFloat { tabWidth * CGFloat(tabCount) }

        var maximumScrollOffset: CGFloat { max(0.0, contentWidth - visibleWidth) }

        /// AppKit scales all four slowing constants by the bar width, saturating at 1024 pt.
        private var scale: CGFloat { min(visibleWidth / 1024.0, 1.0) }

        /// Width of the compression ramp at each edge — effectively how wide a pile is.
        var slowingDistance: CGFloat { 128.0 * scale }

        /// Slowing factor applied to ordinary tabs.
        var edgeScrollingFactor: CGFloat { 64.0 * scale }

        /// Slowing factor applied to the frontmost tab as it sticks to an edge.
        var selectedSlowingFactor: CGFloat { 90.0 * scale }

        /// Whether the geometry is usable (a degenerate viewport would divide by zero).
        private var isUsable: Bool { tabCount > 0 && visibleWidth > 0 && tabWidth > 0 && scale > 0 }

        /// A copy of this geometry folded against a different frontmost tab.
        ///
        /// The anchor is the one thing a reused geometry must never keep stale. AppKit caches
        /// everything `-_recalculateLayout` produces — the tab width, the tab count, the layout
        /// bounds — but reads `-_frontmostButtonIndex` afresh on every `-_layOutButtonsAnimated:`.
        /// Freezing the anchor as well leaves the piles folded against a tab that is no longer
        /// selected, and squeezes the tab that actually *is* selected down into a sliver of the pile —
        /// where it still draws its lit glass, as a bright bar a few points wide.
        func anchored(onFrontmostIndex newFrontmostIndex: Int?) -> StackingGeometry {
            guard newFrontmostIndex != frontmostIndex else { return self }
            return StackingGeometry(
                tabCount: tabCount,
                tabWidth: tabWidth,
                visibleWidth: visibleWidth,
                scrollOffset: scrollOffset,
                barHeight: barHeight,
                frontmostIndex: newFrontmostIndex
            )
        }

        // MARK: - Slowing curves

        /// Ordinary tabs decelerate logarithmically as they enter a pile.
        private func unselectedCurve(_ depth: CGFloat) -> CGFloat {
            let factor = edgeScrollingFactor
            guard factor > 0 else { return depth }
            return factor * log(depth / factor + 1.0)
        }

        /// The frontmost tab decelerates on a gentler hyperbolic curve so it "sticks" to the edge.
        private func selectedCurve(_ depth: CGFloat) -> CGFloat {
            let factor = selectedSlowingFactor
            guard factor > 0 else { return depth }
            return depth / (depth / factor + 1.0)
        }

        /// How much travel is "held back" once a tab has entered the compression ramp.
        private func heldBack(_ position: CGFloat, _ offset: CGFloat, _ curve: (CGFloat) -> CGFloat) -> CGFloat {
            let depth = offset + slowingDistance - position
            guard depth > 0 else { return 0.0 }
            return depth - curve(depth)
        }

        /// The compression applied to a tab, with the baseline subtracted so that an unscrolled bar
        /// (and any rubber-band overshoot) compresses nothing.
        ///
        /// The `position <= 0` short-circuit is AppKit's own, from `offsetForSlowingOffsetWithCurve`,
        /// and it is what keeps the frontmost tab inside the viewport at either end of the strip. A
        /// tab at position zero is held back by the entire scroll offset, which cancels it exactly:
        /// the first tab parks at x == 0 and the last parks flush against the trailing edge. Taking
        /// the general branch there instead leaves the curve short by up to 33 pt, which drifts the
        /// selected tab off the leading edge, or pushes its pill past the trailing one where the
        /// track clips it flat.
        private func slow(_ position: CGFloat, _ offset: CGFloat, _ curve: (CGFloat) -> CGFloat) -> CGFloat {
            if position <= 0.0 { return max(offset, 0.0) }
            return heldBack(position, offset, curve) - heldBack(position, min(offset, 0.0), curve)
        }

        // MARK: - Core offset function

        /// The viewport-relative x of the leading edge of tab `index`.
        ///
        /// Evaluating this at `index` and `index + 1` and taking the difference yields the tab's
        /// (compressed) width — that difference *is* the fan effect.
        func horizontalOffset(at index: Int) -> CGFloat {
            guard isUsable else { return tabWidth * CGFloat(index) }

            let width = tabWidth
            let total = contentWidth
            let viewport = visibleWidth
            let offset = scrollOffset
            let maximumOffset = maximumScrollOffset
            let unstackedX = width * CGFloat(index)

            let unselected: (CGFloat) -> CGFloat = { self.unselectedCurve($0) }
            let selected: (CGFloat) -> CGFloat = { self.selectedCurve($0) }

            guard let frontmost = frontmostIndex, frontmost >= 0, frontmost < tabCount else {
                // No anchor: tabs in the leading half fold against the leading edge, the rest against
                // the trailing edge.
                let result: CGFloat
                if unstackedX <= offset + viewport * 0.5 {
                    result = unstackedX + slow(unstackedX, offset, unselected)
                } else {
                    result = unstackedX - slow(total - unstackedX, maximumOffset - offset, unselected)
                }
                return (result - offset).rounded(.down)
            }

            let frontmostX = width * CGFloat(frontmost)
            let leadingStick = slow(frontmostX, offset, selected)
            let trailingStick = slow(total - frontmostX - width, maximumOffset - offset, selected)
            // Where the frontmost tab actually sits once it has stuck to an edge.
            let frontmostScreenX = frontmostX + leadingStick - trailingStick - offset

            if index == frontmost { return frontmostScreenX.rounded(.down) }
            // Guarantees the frontmost tab keeps exactly `tabWidth`.
            if index == frontmost + 1 { return (frontmostScreenX + width).rounded(.down) }

            let shiftedOffset: CGFloat
            let position: CGFloat
            let trailingPosition: CGFloat
            if index > frontmost {
                // Tabs after the frontmost pile up behind its trailing edge.
                shiftedOffset = offset + trailingStick
                position = unstackedX + slow(unstackedX - frontmostScreenX - width, shiftedOffset, unselected)
                trailingPosition = total - unstackedX
            } else {
                // Tabs before the frontmost pile up against its leading edge.
                shiftedOffset = offset - leadingStick
                position = unstackedX + slow(unstackedX, shiftedOffset, unselected)
                trailingPosition = total - unstackedX - viewport + frontmostScreenX
            }

            let result = position - slow(trailingPosition, maximumOffset - shiftedOffset, unselected)
            return (result - shiftedOffset).rounded(.down)
        }

        // MARK: - Per-tab layout

        /// The viewport-relative frame of tab `index`, plus whether it has collapsed out of sight.
        ///
        /// A collapsed tab is not removed — AppKit keeps it in the hierarchy at `alphaValue == 0` so
        /// it can animate back in.
        func layout(at index: Int) -> (frame: NSRect, isCollapsed: Bool) {
            let leadingOffset = horizontalOffset(at: index)
            let trailingOffset = horizontalOffset(at: index + 1)
            var width = trailingOffset - leadingOffset
            var isCollapsed = false

            if index != frontmostIndex {
                // Only scrolled off an end, or squeezed to nothing. A tab that merely folds *under*
                // the frontmost one keeps its slice of the pile: the system draws those slivers and
                // just orders them behind it, and hiding them leaves the space they occupy blank —
                // a bald patch where the pile should be.
                if trailingOffset < 0.0 || leadingOffset > visibleWidth {
                    isCollapsed = true
                }
                if width <= 0.0 {
                    width = 0.0
                    isCollapsed = true
                }
            } else {
                width = max(width, 0.0)
            }

            let frame = NSRect(x: leadingOffset, y: 0.0, width: width, height: barHeight)
            return (frame, isCollapsed)
        }

        // MARK: - Stacking regions

        /// Which piles currently exist, evaluated against the *un-stacked* uniform grid.
        func stackingRegions(selectedIndex: Int?) -> StackingRegion {
            guard isUsable, tabCount > 1 else { return [] }

            var regions: StackingRegion = []
            let offset = scrollOffset
            let viewportMaxX = offset + visibleWidth
            func unstackedMinX(_ index: Int) -> CGFloat { tabWidth * CGFloat(index) }

            if selectedIndex != 0, unstackedMinX(0) < offset {
                regions.insert(.leadingOverflow)
            }
            if selectedIndex == nil || selectedIndex! < tabCount - 1 {
                if unstackedMinX(tabCount - 1) + tabWidth > viewportMaxX {
                    regions.insert(.trailingOverflow)
                }
            }

            if let selected = selectedIndex, selected >= 0, selected < tabCount {
                let selectedMinX = unstackedMinX(selected)
                if selectedMinX < offset {
                    regions.formUnion(selected == 0 ? [.trailingOfSelected] : [.leadingOfSelected, .trailingOfSelected])
                } else if selectedMinX + tabWidth > viewportMaxX {
                    regions.formUnion(selected < tabCount - 1 ? [.leadingOfSelected, .trailingOfSelected] : [.leadingOfSelected])
                }
            }

            return regions
        }

        /// Maps a viewport-relative x to the pile it lands on, or `[]` when it lands on a tab.
        ///
        /// The selected tab takes absolute priority: a click inside it never counts as a pile.
        func region(atViewportX x: CGFloat, existingRegions: StackingRegion, selectedFrame: NSRect?) -> StackingRegion {
            guard !existingRegions.isEmpty else { return [] }

            if let selectedFrame, x >= selectedFrame.minX, x < selectedFrame.maxX { return [] }

            let distance = slowingDistance
            var hit: StackingRegion = []

            if existingRegions.contains(.leadingOverflow), x <= distance {
                hit = .leadingOverflow
            } else if existingRegions.contains(.trailingOverflow), x >= visibleWidth - distance {
                hit = .trailingOverflow
            }

            if let selectedFrame {
                if existingRegions.contains(.trailingOfSelected), x >= selectedFrame.maxX, x <= selectedFrame.maxX + distance {
                    hit.insert(.trailingOfSelected)
                }
                if existingRegions.contains(.leadingOfSelected), x >= selectedFrame.minX - distance, x <= selectedFrame.minX {
                    hit.insert(.leadingOfSelected)
                }
            }

            return hit
        }

        // MARK: - Revealing an inserted tab

        /// Room the leading pile needs before the tab at `index` can stand at full width.
        ///
        /// `-[NSTabBar _effectiveLeftStackWidthForButtonAtIndex:]`. The leading tab needs none; every
        /// other tab needs the compression ramp, plus one whole tab when the frontmost tab is behind
        /// it, because the frontmost tab is held out at full width in front of the pile.
        private func leadingStackWidth(forButtonAt index: Int) -> CGFloat {
            guard index > 0 else { return 0.0 }
            return index > (frontmostIndex ?? Int.max) ? slowingDistance + tabWidth : slowingDistance
        }

        /// Room the trailing pile needs before the tab at `index` can stand at full width.
        ///
        /// `-[NSTabBar _effectiveRightStackWidthForButtonAtIndex:]`, mirroring the leading side.
        private func trailingStackWidth(forButtonAt index: Int) -> CGFloat {
            guard index != tabCount - 1 else { return 0.0 }
            return index < (frontmostIndex ?? Int.max) ? slowingDistance + tabWidth : slowingDistance
        }

        /// The offset the strip must scroll to for the tab at `index` to stand un-compressed in the
        /// viewport, or `nil` if it already does.
        ///
        /// `-[NSTabBar _scrollToButtonAtIndex:canScrollSelectedButton:]`: it tests the tab's
        /// *un-stacked* slot — where the tab would sit if nothing were folded — against the part of
        /// the viewport that holds full-width tabs, and scrolls the shortest distance that brings the
        /// slot just inside on whichever side it overflows. Testing the tab's *stacked* frame instead
        /// would never scroll at all: folding is what keeps every tab inside the viewport, so a
        /// collapsed tab is already "visible" by that measure, and a bar told to reveal a newly added
        /// tab would sit still while the tab piled up at the end.
        ///
        /// AppKit takes the containment rectangle from `-_layoutBoundsEdgeInsetsForUnstackedButtons`,
        /// which also allows for pinned tabs — something this control has no notion of. Using the same
        /// stack widths the target arithmetic is built from makes the two exactly complementary, so
        /// scrolling to the target lands the tab on the boundary and a second call is a no-op.
        func scrollTargetForRevealing(buttonAt index: Int) -> CGFloat? {
            guard index >= 0, index < tabCount else { return nil }

            let slotMinX = tabWidth * CGFloat(index)
            let slotMaxX = slotMinX + tabWidth
            let leadingStack = leadingStackWidth(forButtonAt: index)
            let trailingStack = trailingStackWidth(forButtonAt: index)

            let unstackedMinX = scrollOffset + leadingStack
            let unstackedMaxX = scrollOffset + visibleWidth - trailingStack
            guard slotMinX < unstackedMinX || slotMaxX > unstackedMaxX else { return nil }

            let target = slotMinX < unstackedMinX
                ? slotMinX - leadingStack
                : slotMaxX - visibleWidth + trailingStack
            return min(max(0.0, target), maximumScrollOffset)
        }

        /// The scroll offset to animate to when the given pile is clicked — a "page" in that direction.
        func scrollTarget(for region: StackingRegion) -> CGFloat {
            let page = max(tabWidth, visibleWidth - (tabWidth + slowingDistance * 2.5))
            let scrollsForward = region.contains(.trailingOverflow) || region.contains(.leadingOfSelected)
            let target = scrollsForward ? scrollOffset + page : scrollOffset - page
            return min(max(0.0, target), maximumScrollOffset)
        }

        // MARK: - Z-ordering

        /// The layer `zPosition` for a tab, so the piles fold correctly.
        ///
        /// Front to back: the frontmost tab, then the tabs after it (nearest first), then the tabs
        /// before it (nearest first).
        func zPosition(at index: Int) -> CGFloat {
            guard let frontmost = frontmostIndex else { return CGFloat(tabCount - index) }
            if index == frontmost { return 100_000.0 }
            if index > frontmost { return 50_000.0 - CGFloat(index - frontmost) }
            return 10_000.0 - CGFloat(frontmost - index)
        }
    }
}

#endif
