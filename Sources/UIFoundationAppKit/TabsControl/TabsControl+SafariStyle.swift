//
//  TabsControl+SafariStyle.swift
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
    /// The Safari style. Uses mostly the default implementation of ``TabsControl/Style``.
    public struct SafariStyle: ThemedStyle {
        public let theme: Theme
        public let tabButtonWidth: TabWidth
        public let tabsControlRecommendedHeight: CGFloat = 24.0

        public init(theme: Theme = SafariTheme(), tabButtonWidth: TabWidth = .full) {
            self.theme = theme
            self.tabButtonWidth = tabButtonWidth
        }

        /// There are no icons in Safari tabs. Here we force the absence of icon, even if some are provided.
        public func iconFrames(tabRect rect: NSRect, closePosition: ClosePosition?) -> IconFrames {
            if let closePosition, closePosition == .left {
                return (.init(x: closeButtonFrame(tabRect: rect, atPosition: .left).maxX, y: 0, width: 0, height: 0), NSRect.zero)
            } else {
                return (NSRect.zero, NSRect.zero)
            }
        }

        public func titleRect(title: NSAttributedString, inBounds bounds: NSRect, showingIcon: Bool, showingMenu: Bool, closePosition: ClosePosition?) -> NSRect {
            let titleSize = title.size()
            let rect = NSRect(
                x: bounds.minX,
                y: bounds.midY - titleSize.height / 2.0 - 0.5,
                width: bounds.width,
                height: titleSize.height
            )

            guard closePosition != nil else {
                return rect
            }

            let leftPadding = closeButtonFrame(tabRect: bounds, atPosition: .left).maxX + titleMargin
            let rightPadding = closeButtonFrame(tabRect: bounds, atPosition: .right).width + titleMargin + titleMargin

            return rect.offsetBy(dx: leftPadding, dy: 0.0).shrinkBy(dx: leftPadding + rightPadding, dy: 0.0)
        }

        public func tabButtonBorderMask(_ position: TabPosition) -> BorderMask? {
            return [.bottom, .top, .right]
        }

        public func tabsControlBorderMask() -> BorderMask? {
            return BorderMask.all()
        }
    }
}

#endif
