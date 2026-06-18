//
//  TabsControl+ChromeTheme.swift
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
    public struct ChromeTheme: Theme {
        public init() {}

        public let tabButtonTheme: ButtonTheme = DefaultButtonTheme()
        public let selectedTabButtonTheme: ButtonTheme = SelectedButtonTheme(base: DefaultButtonTheme())
        public let unselectableTabButtonTheme: ButtonTheme = UnselectableButtonTheme(base: DefaultButtonTheme())
        public let tabsControlTheme: ControlTheme = DefaultControlTheme()

        fileprivate static var sharedBorderColor: NSColor { NSColor(calibratedWhite: 152 / 256.0, alpha: 1.0) }
        fileprivate static var sharedBackgroundColor: NSColor { NSColor(calibratedWhite: 216 / 256.0, alpha: 1.0) }

        fileprivate struct DefaultButtonTheme: ButtonTheme {
            var backgroundColor: NSColor { ChromeTheme.sharedBackgroundColor }
            var borderColor: NSColor { ChromeTheme.sharedBorderColor }
            var titleColor: NSColor { NSColor.controlTextColor }
            var titleFont: NSFont { NSFont.systemFont(ofSize: 14) }
        }

        fileprivate struct SelectedButtonTheme: ButtonTheme {
            let base: DefaultButtonTheme

            var backgroundColor: NSColor { NSColor(calibratedWhite: 245 / 256.0, alpha: 1.0) }
            var borderColor: NSColor { base.borderColor }
            var titleColor: NSColor { base.titleColor }
            var titleFont: NSFont { base.titleFont }
        }

        fileprivate struct UnselectableButtonTheme: ButtonTheme {
            let base: DefaultButtonTheme

            var backgroundColor: NSColor { base.backgroundColor }
            var borderColor: NSColor { base.borderColor }
            var titleColor: NSColor { NSColor.lightGray }
            var titleFont: NSFont { base.titleFont }
        }

        fileprivate struct DefaultControlTheme: ControlTheme {
            var borderColor: NSColor { ChromeTheme.sharedBorderColor }
            var backgroundColor: NSColor { ChromeTheme.sharedBackgroundColor }
        }
    }
}

#endif
