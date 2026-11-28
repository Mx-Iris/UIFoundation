//
//  QuickActionBar+Configuration.swift
//  UIFoundation
//
//  Decision record: Documentations/Evolutions/0045-quick-action-bar-configuration.md
//

#if QuickActionBar && os(macOS)

import AppKit

extension QuickActionBar {
    /// Everything a host can set about how the bar looks and behaves.
    ///
    /// The bar reads it when ``QuickActionBar/present(parentWindow:initialSearchText:didClose:)``
    /// is called and keeps that copy until it closes: a change made while the bar is open applies
    /// to the next presentation.
    public struct Configuration {
        /// The placeholder shown in the empty search field.
        public var placeholderText: String

        /// The image at the leading edge of the search field. An image other than
        /// ``QuickActionBar/DefaultImage`` is scaled proportionally to fit 64 points.
        public var searchImage: NSImage

        /// The width of the bar. `nil` takes a quarter of the main screen's width, measured when
        /// the bar is presented.
        public var width: CGFloat?

        /// The height of the results list below the search field. `nil` takes a quarter of the
        /// main screen's height, measured when the bar is presented.
        public var resultsHeight: CGFloat?

        /// The corner radius of the bar's platter, kept as results make it taller. The browse
        /// buttons stay circles whatever it is.
        public var cornerRadius: CGFloat

        /// Whether the first ten rows show their keyboard shortcuts (↩ and ⌘1–⌘9).
        public var showsKeyboardShortcuts: Bool

        /// Whether the bar's panel can become the main window.
        public var canBecomeMainWindow: Bool

        /// The number of clicks that activates a row in the results.
        public var requiredClickCount: RequiredClickCount

        public init(
            placeholderText: String = QuickActionBar.DefaultPlaceholderString,
            searchImage: NSImage = QuickActionBar.DefaultImage,
            width: CGFloat? = nil,
            resultsHeight: CGFloat? = nil,
            cornerRadius: CGFloat = Configuration.defaultCornerRadius,
            showsKeyboardShortcuts: Bool = false,
            canBecomeMainWindow: Bool = true,
            requiredClickCount: RequiredClickCount = .double
        ) {
            self.placeholderText = placeholderText
            self.searchImage = searchImage
            self.width = width
            self.resultsHeight = resultsHeight
            self.cornerRadius = cornerRadius
            self.showsKeyboardShortcuts = showsKeyboardShortcuts
            self.canBecomeMainWindow = canBecomeMainWindow
            self.requiredClickCount = requiredClickCount
        }

        /// The platter's corner radius when none is set: 28 points on macOS 26 and later — half of
        /// the collapsed bar's 56-point height, as Spotlight's — and 10 points before.
        public static var defaultCornerRadius: CGFloat {
            if #available(macOS 26.0, *) {
                28
            } else {
                10
            }
        }
    }
}

#endif
