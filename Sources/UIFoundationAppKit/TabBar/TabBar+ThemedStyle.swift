//
//  TabBar+ThemedStyle.swift
//  UIFoundation
//
//  Ported into UIFoundation from KPCTabsControl
//  (https://github.com/onekiloparsec/KPCTabsControl) by Cédric Foellmi
//  and Christian Tietze.
//
//  MIT License — Copyright (c) 2014-2016 Cédric Foellmi
//

#if TabBar && os(macOS)

import AppKit

extension TabBar {
    public enum TitleDefaults {
        static let alignment = NSTextAlignment.center
        static let lineBreakMode = NSLineBreakMode.byTruncatingMiddle
    }
}

// MARK: - Default implementation of ThemedStyle

extension TabBar.ThemedStyle {
    // MARK: Tab Buttons

    public func tabButtonOffset(position: TabBar.TabPosition) -> TabBar.Offset {
        return NSPoint()
    }

    public func tabButtonBorderMask(_ position: TabBar.TabPosition) -> TabBar.BorderMask? {
        return TabBar.BorderMask.all()
    }

    // MARK: Close Button

    public func closeButtonFrame(tabRect rect: NSRect, atPosition position: TabBar.ClosePosition) -> NSRect {
        let verticalPadding: CGFloat = 4.0
        let paddedHeight = rect.height - 2 * verticalPadding
        switch position {
        case .left:
            return .init(x: titleMargin, y: verticalPadding, width: paddedHeight, height: paddedHeight)
        case .right:
            return .init(x: rect.maxX - titleMargin - paddedHeight, y: verticalPadding, width: paddedHeight, height: paddedHeight)
        }
    }

    // MARK: Tab Button Titles

    public func iconFrames(tabRect rect: NSRect, closePosition: TabBar.ClosePosition?) -> TabBar.IconFrames {
        let verticalPadding: CGFloat = 4.0
        let paddedHeight = rect.height - 2 * verticalPadding
        let x = rect.width / 2.0 - paddedHeight / 2.0
        var closeButtonMaxX = 10.0
        var closePadding: CGFloat = 0.0
        if let closePosition, closePosition == .left {
            closeButtonMaxX = closeButtonFrame(tabRect: rect, atPosition: .left).maxX
            closePadding = 2.0
        }

        return (
            NSRect(x: closeButtonMaxX + closePadding, y: verticalPadding, width: paddedHeight, height: paddedHeight),
            NSRect(x: x + closeButtonMaxX + closePadding, y: verticalPadding, width: paddedHeight, height: paddedHeight)
        )
    }

    public func titleRect(title: NSAttributedString, inBounds bounds: NSRect, showingIcon: Bool, showingMenu: Bool, closePosition: TabBar.ClosePosition?) -> NSRect {
        let titleSize = title.size()
        let fullWidthRect = NSRect(
            x: bounds.minX,
            y: bounds.midY - titleSize.height / 2.0 - 0.5,
            width: bounds.width,
            height: titleSize.height
        )

        return paddedRectForIcon(fullWidthRect, inBounds: bounds, showingIcon: showingIcon, showingMenu: showingMenu, closePosition: closePosition)
    }

    private func paddedRectForIcon(_ rect: NSRect, inBounds bounds: NSRect, showingIcon: Bool, showingMenu: Bool, closePosition: TabBar.ClosePosition?) -> NSRect {
        if !showingIcon, closePosition == nil {
            return rect
        }
        var leftPadding: CGFloat
        var rightPadding: CGFloat
        if showingIcon {
            let iconRect = iconFrames(tabRect: bounds, closePosition: closePosition).iconFrame
            leftPadding = iconRect.maxX + titleMargin
            if let closePosition, closePosition == .right {
                if showingMenu {
                    rightPadding = popupRectWithFrame(bounds, closePosition: .right).width + closeButtonFrame(tabRect: bounds, atPosition: .right).width + titleMargin * 3
                } else {
                    rightPadding = closeButtonFrame(tabRect: bounds, atPosition: .right).width + titleMargin * 2
                }
            } else {
                if showingMenu {
                    rightPadding = popupRectWithFrame(bounds, closePosition: closePosition).width + titleMargin * 2
                } else {
                    rightPadding = closeButtonFrame(tabRect: bounds, atPosition: .left).width + titleMargin * 2
                }
            }
        } else if let closePosition {
            let closeButtonFrame = closeButtonFrame(tabRect: bounds, atPosition: closePosition)
            switch closePosition {
            case .left:
                leftPadding = closeButtonFrame.maxX + titleMargin
                rightPadding = leftPadding
                if showingMenu {
                    rightPadding += popupRectWithFrame(bounds, closePosition: closePosition).width + titleMargin
                }
            case .right:
                rightPadding = closeButtonFrame.width + titleMargin * 2
                leftPadding = rightPadding
                if showingMenu {
                    rightPadding += popupRectWithFrame(bounds, closePosition: closePosition).width + titleMargin
                }
            }
        } else {
            return rect
        }
        return rect.offsetBy(dx: leftPadding, dy: 0.0).shrinkBy(dx: leftPadding + rightPadding, dy: 0.0)
    }

    public func titleEditorSettings() -> TabBar.TitleEditorSettings {
        return (
            textColor: NSColor(calibratedWhite: 1.0 / 6, alpha: 1.0),
            font: theme.tabButtonTheme.titleFont,
            alignment: TabBar.TitleDefaults.alignment
        )
    }

    public func attributedTitle(content: String, selectionState: TabBar.SelectionState) -> NSAttributedString {
        let activeTheme = theme.tabButtonTheme(fromSelectionState: selectionState)

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = TabBar.TitleDefaults.alignment
        paragraphStyle.lineBreakMode = TabBar.TitleDefaults.lineBreakMode

        let attributes = [NSAttributedString.Key.foregroundColor: activeTheme.titleColor,
                          NSAttributedString.Key.font: activeTheme.titleFont,
                          NSAttributedString.Key.paragraphStyle: paragraphStyle]

        return NSAttributedString(string: content, attributes: attributes)
    }

    public func popupRectWithFrame(_ cellFrame: NSRect, closePosition: TabBar.ClosePosition?) -> NSRect {
        var popupRect = NSRect.zero
        popupRect.size = TabButtonCell.popupImage().size
        if let closePosition, closePosition == .right {
            popupRect.origin = NSPoint(x: closeButtonFrame(tabRect: cellFrame, atPosition: .right).minX - popupRect.width - 5, y: cellFrame.midY - popupRect.height / 2)
        } else {
            popupRect.origin = NSPoint(x: cellFrame.maxX - popupRect.width - 5, y: cellFrame.midY - popupRect.height / 2)
        }
        return popupRect
    }

    // MARK: Tab Bar

    public func tabBarBorderMask() -> TabBar.BorderMask? {
        return TabBar.BorderMask.top.union(TabBar.BorderMask.bottom)
    }

    // MARK: Drawing

    public func drawTabBarBezel(frame: NSRect) {
        theme.tabBarTheme.backgroundColor.setFill()
        frame.fill()

        let borderDrawing = BorderDrawing.fromMask(frame, borderMask: tabBarBorderMask())
        drawBorder(borderDrawing, color: theme.tabBarTheme.borderColor)
    }

    public func drawTabButtonBezel(frame: NSRect, position: TabBar.TabPosition, isSelected: Bool) {
        let activeTheme = isSelected ? theme.selectedTabButtonTheme : theme.tabButtonTheme
        activeTheme.backgroundColor.setFill()
        frame.fill()

        let borderDrawing = BorderDrawing.fromMask(frame, borderMask: tabButtonBorderMask(position))
        drawBorder(borderDrawing, color: activeTheme.borderColor)
    }

    fileprivate func drawBorder(_ border: BorderDrawing, color: NSColor) {
        guard case let .draw(borderRects: borderRects) = border
        else { return }

        color.setFill()
        color.setStroke()
        borderRects.fill()
    }
}

// MARK: -

private enum BorderDrawing {
    case empty
    case draw(borderRects: [NSRect])

    fileprivate static func fromMask(_ sourceRect: NSRect, borderMask: TabBar.BorderMask?) -> BorderDrawing {
        guard let mask = borderMask else { return .empty }

        var outputCount = 0
        var remainderRect = NSRect.zero
        var borderRects: [NSRect] = [NSRect.zero, NSRect.zero, NSRect.zero, NSRect.zero]

        if mask.contains(.top) {
            NSDivideRect(sourceRect, &borderRects[outputCount], &remainderRect, 0.5, .minY)
            outputCount += 1
        }
        if mask.contains(.left) {
            NSDivideRect(sourceRect, &borderRects[outputCount], &remainderRect, 0.5, .minX)
            outputCount += 1
        }
        if mask.contains(.right) {
            NSDivideRect(sourceRect, &borderRects[outputCount], &remainderRect, 0.5, .maxX)
            outputCount += 1
        }
        if mask.contains(.bottom) {
            NSDivideRect(sourceRect, &borderRects[outputCount], &remainderRect, 0.5, .maxY)
            outputCount += 1
        }

        guard outputCount > 0 else { return .empty }

        return .draw(borderRects: borderRects)
    }
}

#endif
