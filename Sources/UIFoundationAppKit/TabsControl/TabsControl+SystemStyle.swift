//
//  TabsControl+SystemStyle.swift
//  UIFoundation
//
//  Replicates the macOS 26 (Solarium / Liquid Glass) system window-tab appearance.
//  Reverse-engineered from AppKit 26.5 (NSTabBar / NSTabButton / NSTabBarViewButton).
//

#if TabsControl && os(macOS)

import AppKit

extension TabsControl {
    /// The macOS 26 system tab style, reproducing the Liquid-Glass window-tab bar.
    ///
    /// Unlike the classic bezel styles (Numbers, Safari, Chrome), this style draws **no** per-button
    /// bezel. Instead it opts into ``TabsControl``'s control-level decoration path via
    /// ``TabsControl/Style/controlDecoration``: the control floats a real `NSGlassEffectView` behind
    /// *every* tab (frosted for non-selected tabs, lit for the selected one — matching AppKit's own
    /// per-tab glass configuration), highlights the hovered tab, and draws hairline separators
    /// between tabs. The tab buttons only render their titles on top. On systems earlier than
    /// macOS 26 the glass degrades to `NSVisualEffectView` and then a plain layer fill.
    ///
    /// Geometry mirrors the system: 12 pt pill corner radius, 120 pt minimum tab width, and titles
    /// coloured by ``TabsControl/SystemTheme``.
    public struct SystemStyle: ThemedStyle {
        public let theme: Theme
        public let tabButtonWidth: TabWidth
        public let tabsControlRecommendedHeight: CGFloat = 30.0

        private let decoration: ControlDecoration

        public init(
            theme: Theme = SystemTheme(),
            tabButtonWidth: TabWidth = .flexible(min: 120.0, max: 240.0),
            decoration: ControlDecoration = ControlDecoration()
        ) {
            self.theme = theme
            self.tabButtonWidth = tabButtonWidth
            self.decoration = decoration
        }

        // MARK: Control decoration

        public var controlDecoration: ControlDecoration? { decoration }

        // MARK: Drawing — everything is drawn by the control's glass decoration

        /// No per-button bezel: the floating Liquid-Glass pill provides the selected tab's material,
        /// and non-selected tabs are transparent.
        public func drawTabButtonBezel(frame: NSRect, position: TabPosition, isSelected: Bool) {}

        /// The bar itself is transparent; the surrounding surface (toolbar / window content) shows
        /// through, matching the system window-tab bar.
        public func drawTabsControlBezel(frame: NSRect) {}

        // MARK: Metrics

        /// Side length of both the close button and the leading icon, matching `NSTabButton`.
        private static let controlSide: CGFloat = 16.0

        /// Inset from the tab's edges to the close button / spacer slots.
        private static let edgeInset: CGFloat = 5.0

        /// Gap between the icon and the title, matching `NSTabButton`.
        private static let iconTitleSpacing: CGFloat = 6.0

        // MARK: Close button

        /// The system lays a tab out as a horizontal stack with 5 pt side insets, a 16 × 16 close
        /// button in the leading slot and a matching 16 × 16 spacer trailing it so the title stays
        /// centred. This reproduces that metric.
        public func closeButtonFrame(tabRect rect: NSRect, atPosition position: ClosePosition) -> NSRect {
            let y = rect.midY - Self.controlSide / 2.0

            switch position {
            case .left:
                return NSRect(x: rect.minX + Self.edgeInset, y: y, width: Self.controlSide, height: Self.controlSide)
            case .right:
                return NSRect(x: rect.maxX - Self.edgeInset - Self.controlSide, y: y, width: Self.controlSide, height: Self.controlSide)
            }
        }

        // MARK: Icon and title

        /// Icon and title are laid out as one centred group — the icon sits directly against the
        /// title's leading edge rather than being pinned to a slot of its own, so a short title does
        /// not drift away from its icon on a wide tab. A tab without an icon keeps the title centred
        /// exactly as before.
        public func iconFrames(
            tabRect rect: NSRect,
            title: NSAttributedString,
            showingIcon: Bool,
            showingMenu: Bool,
            closePosition: ClosePosition?
        ) -> IconFrames {
            let layout = contentLayout(
                tabRect: rect,
                title: title,
                showingIcon: showingIcon,
                showingMenu: showingMenu,
                closePosition: closePosition
            )
            // The alternative icon replaces the title outright when it no longer fits, so it is
            // centred on the tab rather than following the group.
            let alternativeTitleIconFrame = NSRect(
                x: rect.midX - Self.controlSide / 2.0,
                y: rect.midY - Self.controlSide / 2.0,
                width: Self.controlSide,
                height: Self.controlSide
            )
            return (layout.iconFrame, alternativeTitleIconFrame)
        }

        public func titleRect(
            title: NSAttributedString,
            inBounds bounds: NSRect,
            showingIcon: Bool,
            showingMenu: Bool,
            closePosition: ClosePosition?
        ) -> NSRect {
            contentLayout(
                tabRect: bounds,
                title: title,
                showingIcon: showingIcon,
                showingMenu: showingMenu,
                closePosition: closePosition
            ).titleFrame
        }

        /// Single source of truth for where the icon and the title go, so the two public entry
        /// points above cannot disagree.
        private func contentLayout(
            tabRect rect: NSRect,
            title: NSAttributedString,
            showingIcon: Bool,
            showingMenu: Bool,
            closePosition: ClosePosition?
        ) -> (iconFrame: NSRect, titleFrame: NSRect) {
            let titleSize = title.size()

            // A close button reserves its slot on the leading edge and an equally wide spacer on the
            // trailing edge, which is what keeps the system's titles optically centred.
            let reservedSlotWidth = closePosition == nil ? 0.0 : Self.controlSide
            let leadingLimit = rect.minX + Self.edgeInset + reservedSlotWidth
            var trailingLimit = rect.maxX - Self.edgeInset - reservedSlotWidth
            if showingMenu {
                trailingLimit -= popupRectWithFrame(rect, closePosition: closePosition).width + titleMargin
            }
            let availableWidth = max(0.0, trailingLimit - leadingLimit)

            let iconBlockWidth = showingIcon ? Self.controlSide + Self.iconTitleSpacing : 0.0
            let titleWidth = min(titleSize.width, max(0.0, availableWidth - iconBlockWidth))
            let contentWidth = iconBlockWidth + titleWidth
            // Centre the group, then keep it inside the content box — a title too long to centre
            // starts at the leading edge and truncates on the trailing one.
            let contentOriginX = min(
                max(rect.midX - contentWidth / 2.0, leadingLimit),
                max(leadingLimit, trailingLimit - contentWidth)
            )

            let iconFrame = NSRect(
                x: contentOriginX,
                y: rect.midY - Self.controlSide / 2.0,
                width: Self.controlSide,
                height: Self.controlSide
            )
            // The cell centres the title inside the rect it is handed, so padding both sides by
            // `titleMargin` leaves the drawn text exactly where the group wants it while still
            // letting `hasRoomToDrawFullTitle` compare against the width actually available.
            let titleFrame = NSRect(
                x: contentOriginX + iconBlockWidth - titleMargin,
                y: rect.midY - titleSize.height / 2.0 - 0.5,
                width: titleWidth + 2.0 * titleMargin,
                height: titleSize.height
            )

            return (iconFrame, titleFrame)
        }

        // MARK: Borders — none

        public func tabButtonBorderMask(_ position: TabPosition) -> BorderMask? { nil }

        public func tabsControlBorderMask() -> BorderMask? { nil }
    }
}

#endif
