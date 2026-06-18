//
//  TabsControl+DefaultTheme.swift
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
    /// The default tabs-control theme. Combined with ``TabsControl/DefaultStyle`` it provides an
    /// experience similar to Apple's Numbers.app.
    public struct DefaultTheme: Theme {
        public init() {}

        public let tabButtonTheme: ButtonTheme = DefaultButtonTheme()
        public let selectedTabButtonTheme: ButtonTheme = SelectedButtonTheme(base: DefaultButtonTheme())
        public let unselectableTabButtonTheme: ButtonTheme = UnselectableButtonTheme(base: DefaultButtonTheme())
        public let tabsControlTheme: ControlTheme = DefaultControlTheme()

        fileprivate static var sharedBorderColor: NSColor { NSColor.separatorColor }
        fileprivate static var sharedBackgroundColor: NSColor { .controlBackgroundColor }

        fileprivate struct DefaultButtonTheme: ButtonTheme {
            var backgroundColor: NSColor { DefaultTheme.sharedBackgroundColor }
            var borderColor: NSColor { DefaultTheme.sharedBorderColor }
            var titleColor: NSColor { NSColor.labelColor }
            var titleFont: NSFont { NSFont.systemFont(ofSize: 13) }
        }

        fileprivate struct SelectedButtonTheme: ButtonTheme {
            let base: DefaultButtonTheme

            var backgroundColor: NSColor { .controlAccentColor }
            var borderColor: NSColor { NSColor.separatorColor }
            var titleColor: NSColor { .labelColor }
            var titleFont: NSFont { NSFont.boldSystemFont(ofSize: 13) }
        }

        fileprivate struct UnselectableButtonTheme: ButtonTheme {
            let base: DefaultButtonTheme

            var backgroundColor: NSColor { base.backgroundColor }
            var borderColor: NSColor { base.borderColor }
            var titleColor: NSColor { .labelColor }
            var titleFont: NSFont { base.titleFont }
        }

        fileprivate struct DefaultControlTheme: ControlTheme {
            var backgroundColor: NSColor { DefaultTheme.sharedBackgroundColor }
            var borderColor: NSColor { DefaultTheme.sharedBorderColor }
        }
    }
}

#endif
