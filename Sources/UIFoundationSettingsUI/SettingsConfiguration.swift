#if Settings && os(macOS)

import AppKit

/// The window and sidebar values a host can customize when constructing settings UI.
///
/// The same value configures ``SettingsWindowController``, ``SettingsScene``, and an
/// independently hosted ``SettingsRootView``. Page navigation state remains in
/// ``SettingsNavigator`` rather than this value type.
@available(macOS 14.0, *)
public struct SettingsConfiguration {
    /// Window title used by ``SettingsWindowController``. Localize this in the host application.
    /// SwiftUI owns the title of a native ``SettingsScene``.
    public var title: String

    /// Fixed width of the settings window's content.
    public var contentWidth: CGFloat

    /// Floor for the settings window's resizable content height.
    public var minimumContentHeight: CGFloat

    /// Width of the page list.
    public var sidebarWidth: CGFloat

    /// Width and height of every icon in the page list.
    public var sidebarIconSize: CGFloat

    /// Whether the detail pane shows its back and forward controls.
    ///
    /// Hiding the controls leaves the navigator working; only the buttons disappear.
    public var showsNavigationControls: Bool

    public init(
        title: String = "Settings",
        contentWidth: CGFloat = 715,
        minimumContentHeight: CGFloat = 400,
        sidebarWidth: CGFloat = 185,
        sidebarIconSize: CGFloat = 20,
        showsNavigationControls: Bool = true
    ) {
        self.title = title
        self.contentWidth = contentWidth
        self.minimumContentHeight = minimumContentHeight
        self.sidebarWidth = sidebarWidth
        self.sidebarIconSize = sidebarIconSize
        self.showsNavigationControls = showsNavigationControls
    }
}

#endif
