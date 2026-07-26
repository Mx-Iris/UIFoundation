//
//  Ported from Mx-Iris/SystemHUD
//  https://github.com/Mx-Iris/SystemHUD
//

#if SystemHUD && os(macOS)

import AppKit

extension SystemHUD {
    /// The appearance of a ``SystemHUD`` panel.
    public struct Configuration {
        /// The glyph shown above the title. `nil` hides the image and collapses ``imageSpacing``.
        public var image: NSImage?

        /// The vertical gap between the image and the title. Ignored when ``image`` is `nil`.
        public var imageSpacing: CGFloat

        /// The single line of text below the image. A title too wide for the screen truncates at
        /// the tail rather than widening the panel past the display.
        public var title: String

        public var titleFontSize: CGFloat

        public var titleFontWeight: NSFont.Weight

        public var titleColor: NSColor

        public var titleAlignment: NSTextAlignment

        /// Shifts the image-and-title block within the panel. Positive `y` moves it up, matching
        /// AppKit's unflipped coordinate space.
        public var offset: CGPoint

        /// The smallest the panel is ever drawn. The panel grows past this only when the content
        /// does not fit; it never shrinks below it, so a short title still gets the familiar
        /// square system-HUD shape.
        public var minimumSize: CGSize

        /// The padding kept between the content and the panel edges when the content is what
        /// determines the panel size.
        public var contentInsets: NSEdgeInsets

        /// The panel's corner radius. `0` squares off the corners.
        public var cornerRadius: CGFloat

        /// How long the panel takes to fade out once its delay elapses.
        public var dismissAnimationDuration: TimeInterval

        public init(
            image: NSImage? = nil,
            imageSpacing: CGFloat = 15,
            title: String,
            titleFontSize: CGFloat = 18,
            titleFontWeight: NSFont.Weight = .regular,
            titleColor: NSColor = .labelColor,
            titleAlignment: NSTextAlignment = .center,
            offset: CGPoint = .zero,
            minimumSize: CGSize = .init(width: 200, height: 200),
            contentInsets: NSEdgeInsets = .init(top: 20, left: 20, bottom: 20, right: 20),
            cornerRadius: CGFloat = 15,
            dismissAnimationDuration: TimeInterval = 1.0
        ) {
            self.image = image
            self.imageSpacing = imageSpacing
            self.title = title
            self.titleFontSize = titleFontSize
            self.titleFontWeight = titleFontWeight
            self.titleColor = titleColor
            self.titleAlignment = titleAlignment
            self.offset = offset
            self.minimumSize = minimumSize
            self.contentInsets = contentInsets
            self.cornerRadius = cornerRadius
            self.dismissAnimationDuration = dismissAnimationDuration
        }
    }
}

#endif
