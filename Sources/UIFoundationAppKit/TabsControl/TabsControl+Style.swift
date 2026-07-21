//
//  TabsControl+Style.swift
//  UIFoundation
//
//  Ported into UIFoundation from KPCTabsControl
//  (https://github.com/onekiloparsec/KPCTabsControl) by Cédric Foellmi
//  and Christian Tietze.
//
//  MIT License — Copyright (c) 2014-2016 Cédric Foellmi
//

#if TabsControl && os(macOS)

import AppKit

extension TabsControl {
    public typealias IconFrames = (iconFrame: NSRect, alternativeTitleIconFrame: NSRect)

    public typealias TitleEditorSettings = (textColor: NSColor, font: NSFont, alignment: NSTextAlignment)

    /// Describes the control-level decoration a ``TabsControl/Style`` wants the control to render
    /// *behind* its tab buttons, instead of drawing a bezel per tab button.
    ///
    /// A style that returns a non-`nil` ``TabsControl/Style/controlDecoration`` opts into the
    /// macOS-26-style rendering path: the control floats a single Liquid-Glass selection pill (and,
    /// optionally, a hover pill and inter-tab separators) below the tab buttons, while the buttons
    /// themselves draw only their titles. This keeps the classic per-button bezel styles (Numbers,
    /// Safari, Chrome) completely untouched — they simply return `nil` and keep drawing bezels.
    public struct ControlDecoration {
        /// The corner radius of the selection and hover pills.
        public var cornerRadius: CGFloat

        /// The insets applied to a tab button's frame to compute the pill's frame. Vertical insets
        /// give the pill its floating, capsule-like appearance; horizontal insets create the small
        /// gap between adjacent pills.
        public var selectionInsets: NSEdgeInsets

        /// Whether hovering a non-selected tab reveals a subtle highlight pill.
        public var highlightsHover: Bool

        /// Whether hairline separators are drawn between adjacent tabs.
        public var drawsSeparators: Bool

        /// The vertical inset applied to each separator, shortening it relative to the tab height.
        public var separatorVerticalInset: CGFloat

        /// Whether the control draws a capsule-shaped Liquid-Glass "track" behind the whole bar
        /// (matching the system `NSTabBarTrackView`).
        public var showsBarTrack: Bool

        /// The horizontal inset applied to the tabs so their pills clear the rounded ends of the
        /// bar track. Applied on both leading and trailing edges when the style decorates.
        public var barContentInset: CGFloat

        /// Whether tabs stack (telescope into a pile at each edge) instead of shrinking further once
        /// they no longer fit at ``minimumTabWidth``, matching the system window-tab bar.
        public var allowsStacking: Bool

        /// The width a tab locks to once stacking begins. The system uses 120 pt.
        public var minimumTabWidth: CGFloat

        public init(
            cornerRadius: CGFloat = 12.0,
            selectionInsets: NSEdgeInsets = NSEdgeInsets(top: 3.0, left: 2.0, bottom: 3.0, right: 2.0),
            highlightsHover: Bool = true,
            drawsSeparators: Bool = true,
            separatorVerticalInset: CGFloat = 3.0,
            showsBarTrack: Bool = true,
            barContentInset: CGFloat = 8.0,
            allowsStacking: Bool = true,
            minimumTabWidth: CGFloat = 120.0
        ) {
            self.cornerRadius = cornerRadius
            self.selectionInsets = selectionInsets
            self.highlightsHover = highlightsHover
            self.drawsSeparators = drawsSeparators
            self.separatorVerticalInset = separatorVerticalInset
            self.showsBarTrack = showsBarTrack
            self.barContentInset = barContentInset
            self.allowsStacking = allowsStacking
            self.minimumTabWidth = minimumTabWidth
        }
    }

    /// The `Style` protocol defines everything needed to let a ``TabsControl`` draw itself with tabs.
    public protocol Style {
        // Tab Buttons
        var tabButtonWidth: TabWidth { get }
        func tabButtonOffset(position: TabPosition) -> Offset
        func tabButtonBorderMask(_ position: TabPosition) -> BorderMask?

        // Close Button
        func closeButtonFrame(tabRect rect: NSRect, atPosition position: ClosePosition) -> NSRect

        // Tab Button Titles
        func iconFrames(tabRect rect: NSRect, closePosition: ClosePosition?) -> IconFrames

        /// Title-aware variant of ``iconFrames(tabRect:closePosition:)``, called by ``TabButton``.
        ///
        /// A style that lays the icon out relative to the title — rather than pinning it to a fixed
        /// slot — needs the same inputs ``titleRect(title:inBounds:showingIcon:showingMenu:closePosition:)``
        /// gets, otherwise the two placements cannot agree. Defaults to discarding the extra context
        /// and calling ``iconFrames(tabRect:closePosition:)``, so classic styles need not implement it.
        func iconFrames(tabRect rect: NSRect, title: NSAttributedString, showingIcon: Bool, showingMenu: Bool, closePosition: ClosePosition?) -> IconFrames
        func popupRectWithFrame(_ cellFrame: NSRect, closePosition: ClosePosition?) -> NSRect
        func titleRect(title: NSAttributedString, inBounds rect: NSRect, showingIcon: Bool, showingMenu: Bool, closePosition: ClosePosition?) -> NSRect
        func titleEditorSettings() -> TitleEditorSettings
        func attributedTitle(content: String, selectionState: SelectionState) -> NSAttributedString

        // Tabs Control
        var tabsControlRecommendedHeight: CGFloat { get }
        func tabsControlBorderMask() -> BorderMask?

        // Drawing
        func drawTabButtonBezel(frame: NSRect, position: TabPosition, isSelected: Bool)
        func drawTabsControlBezel(frame: NSRect)

        // Control-level decoration (macOS 26 Liquid-Glass path)
        /// When non-`nil`, the control floats a Liquid-Glass selection pill (and optional hover pill
        /// and separators) behind the tab buttons instead of relying on per-button bezel drawing.
        /// Defaults to `nil` for classic bezel styles.
        var controlDecoration: ControlDecoration? { get }
    }

    /// A custom `Style` does not necessarily have a theme associated with it.
    /// The provided styles (Numbers.app-like, Safari and Chrome) all have an associated theme.
    public protocol ThemedStyle: Style {
        var theme: Theme { get }
    }
}

// MARK: - Default control decoration

extension TabsControl.Style {
    /// Classic bezel-drawing styles opt out of control-level decoration by default.
    public var controlDecoration: TabsControl.ControlDecoration? { nil }

    /// Styles that pin the icon to a fixed slot ignore the title context.
    public func iconFrames(
        tabRect rect: NSRect,
        title: NSAttributedString,
        showingIcon: Bool,
        showingMenu: Bool,
        closePosition: TabsControl.ClosePosition?
    ) -> TabsControl.IconFrames {
        iconFrames(tabRect: rect, closePosition: closePosition)
    }
}

#endif
