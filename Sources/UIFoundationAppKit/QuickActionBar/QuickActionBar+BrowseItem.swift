//
//  QuickActionBar+BrowseItem.swift
//  UIFoundation
//

#if QuickActionBar && os(macOS)

import AppKit

public extension QuickActionBar {
    /// A round button beside the search field, like the Applications, Files, Actions and
    /// Clipboard buttons of macOS 26 Spotlight.
    ///
    /// Give the bar some through ``QuickActionBar/browseItems``. They bud out of the search field
    /// shortly after the bar appears, while the query is empty, and draw back into it when a query
    /// brings up results. Only macOS 26 and later show them.
    struct BrowseItem {
        /// The button's tooltip and accessibility label.
        public var title: String

        /// The button's icon. A symbol image is drawn at the `.title1` text style, the size
        /// Spotlight uses; any other image is drawn at its own size.
        public var image: NSImage

        /// Called when the button is clicked. The bar stays open; call
        /// ``QuickActionBar/cancel()`` from here to close it.
        public var action: @MainActor (QuickActionBar) -> Void

        public init(title: String, image: NSImage, action: @escaping @MainActor (QuickActionBar) -> Void) {
            self.title = title
            self.image = image
            self.action = action
        }
    }
}

#endif
