//
//  TabsControl+SafariTheme.swift
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
    public struct SafariTheme: Theme {
        public init() {}

        public let tabButtonTheme: ButtonTheme = DefaultButtonTheme()
        public let selectedTabButtonTheme: ButtonTheme = SelectedButtonTheme()
        public let unselectableTabButtonTheme: ButtonTheme = UnselectableButtonTheme(base: DefaultButtonTheme())
        public let tabsControlTheme: ControlTheme = DefaultControlTheme()

        fileprivate static var sharedBackgroundColor: NSColor { NSColor(white: 0.72, alpha: 1.0) }
        fileprivate static var sharedBorderColor: NSColor { NSColor(white: 0.61, alpha: 1.0) }

        fileprivate struct DefaultButtonTheme: ButtonTheme {
            var backgroundColor: NSColor { SafariTheme.sharedBackgroundColor }
            var borderColor: NSColor { SafariTheme.sharedBorderColor }
            var titleColor: NSColor { NSColor(white: 0.38, alpha: 1.0) }
            var titleFont: NSFont { NSFont.systemFont(ofSize: NSFont.systemFontSize) }
        }

        fileprivate struct SelectedButtonTheme: ButtonTheme {
            var backgroundColor: NSColor { NSColor(white: 0.79, alpha: 1.0) }
            var borderColor: NSColor { NSColor(white: 0.64, alpha: 1.0) }
            var titleColor: NSColor { NSColor(white: 0.08, alpha: 1.0) }
            var titleFont: NSFont { NSFont.systemFont(ofSize: NSFont.systemFontSize) }
        }

        fileprivate struct UnselectableButtonTheme: ButtonTheme {
            let base: DefaultButtonTheme

            var backgroundColor: NSColor { base.backgroundColor }
            var borderColor: NSColor { base.borderColor }
            var titleColor: NSColor { NSColor(white: 0.94, alpha: 1.0) }
            var titleFont: NSFont { base.titleFont }
        }

        fileprivate struct DefaultControlTheme: ControlTheme {
            var backgroundColor: NSColor { SafariTheme.sharedBackgroundColor }
            var borderColor: NSColor { SafariTheme.sharedBorderColor }
        }
    }
}

#endif
