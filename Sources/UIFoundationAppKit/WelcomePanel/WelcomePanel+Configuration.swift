#if WelcomePanel && os(macOS)

import AppKit

@available(macOS 11.0, *)
extension WelcomePanelController {
    /// Everything the panel renders, plus the style that decides how it renders.
    ///
    /// Every text / font / color field is optional: `nil` falls back to the style's own default,
    /// which for the two labels means the host app's bundle name and short version string.
    public struct Configuration {
        public var style: Style
        public var welcomeLabelText: String?
        public var welcomeLabelFont: NSFont?
        public var welcomeLabelColor: NSColor?
        public var versionLabelText: String?
        public var versionLabelFont: NSFont?
        public var versionLabelColor: NSColor?
        public var appIconImage: NSImage?
        public var appIconImageShadow: NSShadow?
        public var primaryAction: Action?
        public var secondaryAction: Action?
        public var tertiaryAction: Action?
        public var checkShowOnLaunch: Bool

        /// The non-nil actions in primary → secondary → tertiary order.
        public var allActions: [Action] {
            [primaryAction, secondaryAction, tertiaryAction].compactMap { $0 }
        }

        public init(
            style: Style = .xcode14,
            welcomeLabelText: String? = nil,
            welcomeLabelFont: NSFont? = nil,
            welcomeLabelColor: NSColor? = nil,
            versionLabelText: String? = nil,
            versionLabelFont: NSFont? = nil,
            versionLabelColor: NSColor? = nil,
            appIconImage: NSImage? = nil,
            appIconImageShadow: NSShadow? = nil,
            primaryAction: Action? = nil,
            secondaryAction: Action? = nil,
            tertiaryAction: Action? = nil,
            checkShowOnLaunch: Bool = true
        ) {
            self.style = style
            self.welcomeLabelText = welcomeLabelText
            self.welcomeLabelFont = welcomeLabelFont
            self.welcomeLabelColor = welcomeLabelColor
            self.versionLabelText = versionLabelText
            self.versionLabelFont = versionLabelFont
            self.versionLabelColor = versionLabelColor
            self.appIconImage = appIconImage
            self.appIconImageShadow = appIconImageShadow
            self.primaryAction = primaryAction
            self.secondaryAction = secondaryAction
            self.tertiaryAction = tertiaryAction
            self.checkShowOnLaunch = checkShowOnLaunch
        }
    }
}

#endif
