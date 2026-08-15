#if Settings && os(macOS)

import AppKit
import SwiftUI
import UIFoundationAppKit

/// The settings window itself. Its own type so hosts can recognise it.
@available(macOS 14.0, *)
public final class SettingsWindow: NSWindow {}

/// A ready-made settings window: sidebar of pages, grouped forms, fixed width.
///
/// ```swift
/// let controller = SettingsWindowController {
///     SettingsPage("General", symbol: "gearshape") { GeneralPage() }
///     SettingsPage("Updates", symbol: "arrow.down.circle") { UpdatesPage() }
/// }
/// controller.showWindow(nil)
/// ```
///
/// Pages reach the settings through ``AppSettings``, which finds them on the
/// model type — this controller neither takes nor forwards a store.
///
/// Hosts that want a single shared settings window should hold one of these
/// themselves; the controller intentionally has no singleton of its own.
/// SwiftUI apps, and AppKit apps using the macOS 26 scene bridge, can use
/// ``SettingsScene`` instead.
///
/// Use ``navigator`` to open the window on a particular page, or to drive the
/// back / forward navigation from the host's own menu:
///
/// ```swift
/// controller.navigator.navigate(to: "updates")
/// controller.showWindow(nil)
/// ```
@available(macOS 14.0, *)
open class SettingsWindowController: XiblessWindowController<SettingsWindow> {
    /// The window and sidebar values captured when this controller was created.
    public let configuration: SettingsConfiguration

    /// Which page is on screen, and the history behind the back / forward
    /// buttons. Safe to read and write before the window has ever been shown.
    public let navigator: SettingsNavigator

    private let pages: [SettingsPage]

    /// - Parameters:
    ///   - configuration: Window and sidebar customization. Defaults reproduce
    ///     the standard UIFoundation settings window.
    ///   - navigator: Drives the selection and history. Defaults to a fresh one
    ///     starting on the first page; either way it is published as
    ///     ``navigator``.
    ///   - pages: Sidebar entries, in order. The first is selected initially.
    public init(
        configuration: SettingsConfiguration = .init(),
        navigator: SettingsNavigator? = nil,
        @SettingsPageBuilder pages: () -> [SettingsPage]
    ) {
        let resolvedPages = pages()
        self.pages = resolvedPages
        self.configuration = configuration
        self.navigator = navigator ?? SettingsNavigator(initialPageID: resolvedPages.first?.id)

        super.init(
            windowGenerator: SettingsWindow(
                contentRect: NSRect(
                    x: 0,
                    y: 0,
                    width: configuration.contentWidth,
                    height: configuration.minimumContentHeight
                ),
                styleMask: [.titled, .miniaturizable, .closable, .resizable, .fullSizeContentView],
                backing: .buffered,
                defer: false
            )
        )
    }

    override open func windowDidLoad() {
        super.windowDidLoad()

        contentWindow.title = configuration.title
        // A settings window has no business going full screen.
        contentWindow.collectionBehavior.insert(.fullScreenNone)

        let rootView = SettingsRootView(
            configuration: configuration,
            navigator: navigator,
            pages: { pages }
        )
            .frame(minWidth: configuration.contentWidth, maxWidth: configuration.contentWidth)
            .frame(minHeight: configuration.minimumContentHeight)

        let hostingController = NSHostingController(rootView: rootView)
        hostingController.view.frame = NSRect(origin: .zero, size: contentWindow.frame.size)
        contentViewController = hostingController

        contentWindow.setFrameAutosaveName(String(describing: Self.self))
        contentWindow.center()
    }
}

#endif
