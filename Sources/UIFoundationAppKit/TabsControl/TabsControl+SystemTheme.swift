//
//  TabsControl+SystemTheme.swift
//  UIFoundation
//
//  Replicates the macOS 26 (Solarium / Liquid Glass) system window-tab appearance.
//  Reverse-engineered from AppKit 26.5 (NSTabBar / NSTabButton / NSTabBarViewButton).
//

#if TabsControl && os(macOS)

import AppKit

extension TabsControl {
    /// The theme backing ``TabsControl/SystemStyle``. It reproduces the title colouring of the
    /// macOS 26 system window-tab bar.
    ///
    /// The system draws every tab title with `[NSFont systemFontOfSize:11]` (regular weight — the
    /// selected tab is **not** bolded) and switches only the foreground colour by state:
    ///
    /// - selected tab → `labelColor`
    /// - non-selected tab → `secondaryLabelColor`
    /// - non-selectable tab → `tertiaryLabelColor`
    ///
    /// The tab and bar backgrounds are transparent: the visible material comes entirely from the
    /// Liquid-Glass selection pill floated by ``TabsControl`` (see ``TabsControl/SystemStyle``).
    public struct SystemTheme: Theme {
        public init() {}

        public let tabButtonTheme: ButtonTheme = NormalButtonTheme()
        public let selectedTabButtonTheme: ButtonTheme = SelectedButtonTheme()
        public let unselectableTabButtonTheme: ButtonTheme = UnselectableButtonTheme()
        public let tabsControlTheme: ControlTheme = SystemControlTheme()

        /// The system title font: 11 pt regular system font, identical across selection states.
        fileprivate static var titleFont: NSFont { NSFont.systemFont(ofSize: 11.0) }

        fileprivate struct NormalButtonTheme: ButtonTheme {
            var backgroundColor: NSColor { .clear }
            var borderColor: NSColor { .clear }
            var titleColor: NSColor { .secondaryLabelColor }
            var titleFont: NSFont { SystemTheme.titleFont }
        }

        fileprivate struct SelectedButtonTheme: ButtonTheme {
            var backgroundColor: NSColor { .clear }
            var borderColor: NSColor { .clear }
            var titleColor: NSColor { .labelColor }
            var titleFont: NSFont { SystemTheme.titleFont }
        }

        fileprivate struct UnselectableButtonTheme: ButtonTheme {
            var backgroundColor: NSColor { .clear }
            var borderColor: NSColor { .clear }
            var titleColor: NSColor { .tertiaryLabelColor }
            var titleFont: NSFont { SystemTheme.titleFont }
        }

        fileprivate struct SystemControlTheme: ControlTheme {
            var backgroundColor: NSColor { .clear }
            var borderColor: NSColor { .clear }
        }
    }
}

#endif
