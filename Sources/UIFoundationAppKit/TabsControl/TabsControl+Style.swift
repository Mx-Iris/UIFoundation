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
    }

    /// A custom `Style` does not necessarily have a theme associated with it.
    /// The provided styles (Numbers.app-like, Safari and Chrome) all have an associated theme.
    public protocol ThemedStyle: Style {
        var theme: Theme { get }
    }
}

#endif
