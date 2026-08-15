#if Settings && os(macOS)

import SwiftUI

/// A native SwiftUI settings scene backed by UIFoundation settings pages.
///
/// Use this directly from a SwiftUI app:
///
/// ```swift
/// var body: some Scene {
///     SettingsScene {
///         SettingsPage("General", symbol: "gearshape") { GeneralPage() }
///     }
/// }
/// ```
///
/// On macOS 26 and later, an AppKit app can wrap the same scene in
/// `NSHostingSceneRepresentation` and register it with
/// `NSApplication.addSceneRepresentation(_:)`.
@available(macOS 14.0, *)
public struct SettingsScene: Scene {
    /// The window and sidebar values captured when this scene was created.
    ///
    /// SwiftUI owns the native Settings scene's window title. The remaining
    /// sizing, sidebar, and navigation-control values configure its content.
    public let configuration: SettingsConfiguration

    /// Which page is on screen, and the history behind the back and forward
    /// buttons. Safe to read and write before the scene is presented.
    public let navigator: SettingsNavigator

    private let pages: [SettingsPage]

    /// - Parameters:
    ///   - configuration: Window and sidebar customization. Defaults reproduce
    ///     the standard UIFoundation settings presentation.
    ///   - navigator: Drives the selection and history. Defaults to a fresh one
    ///     starting on the first page; either way it is published as
    ///     ``navigator``.
    ///   - pages: Sidebar entries, in order. The first is selected initially.
    @MainActor
    public init(
        configuration: SettingsConfiguration = .init(),
        navigator: SettingsNavigator? = nil,
        @SettingsPageBuilder pages: () -> [SettingsPage]
    ) {
        let resolvedPages = pages()
        self.configuration = configuration
        self.navigator = navigator ?? SettingsNavigator(initialPageID: resolvedPages.first?.id)
        self.pages = resolvedPages
    }

    @MainActor
    public var body: some Scene {
        SwiftUI.Settings {
            SettingsRootView(
                configuration: configuration,
                navigator: navigator,
                pages: { pages }
            )
            .settingsSceneWindowChrome()
            .frame(minWidth: configuration.contentWidth, maxWidth: configuration.contentWidth)
            .frame(minHeight: configuration.minimumContentHeight)
        }
        .windowToolbarStyle(.unified)
    }
}

#endif
