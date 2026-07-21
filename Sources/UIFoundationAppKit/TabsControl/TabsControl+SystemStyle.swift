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

        // MARK: Close button

        /// The system lays a tab out as a horizontal stack with 5 pt side insets, a 16 × 16 close
        /// button in the leading slot and a matching 16 × 16 spacer trailing it so the title stays
        /// centred. This reproduces that metric.
        public func closeButtonFrame(tabRect rect: NSRect, atPosition position: ClosePosition) -> NSRect {
            let side: CGFloat = 16.0
            let edgeInset: CGFloat = 5.0
            let y = rect.midY - side / 2.0

            switch position {
            case .left:
                return NSRect(x: rect.minX + edgeInset, y: y, width: side, height: side)
            case .right:
                return NSRect(x: rect.maxX - edgeInset - side, y: y, width: side, height: side)
            }
        }

        // MARK: Borders — none

        public func tabButtonBorderMask(_ position: TabPosition) -> BorderMask? { nil }

        public func tabsControlBorderMask() -> BorderMask? { nil }
    }
}

#endif
