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
///
/// Use ``navigator`` to open the window on a particular page, or to drive the
/// back / forward navigation from the host's own menu:
///
/// ```swift
/// controller.navigator.currentPageID = "updates"
/// controller.showWindow(nil)
/// ```
@available(macOS 14.0, *)
open class SettingsWindowController: XiblessWindowController<SettingsWindow> {
    /// Which page is on screen, and the history behind the back / forward
    /// buttons. Safe to read and write before the window has ever been shown.
    public let navigator: SettingsNavigator

    private let pages: [SettingsPage]
    private let windowTitle: String
    private let contentWidth: CGFloat
    private let minimumContentHeight: CGFloat
    private let showsNavigationControls: Bool

    /// - Parameters:
    ///   - title: Window title. Defaults to `"Settings"`; localize it yourself.
    ///   - contentWidth: Fixed content width. System Settings-style windows do
    ///     not resize horizontally, and neither does this one by default.
    ///   - minimumContentHeight: Floor for the resizable height.
    ///   - navigator: Drives the selection and history. Defaults to a fresh one
    ///     starting on the first page; either way it is published as
    ///     ``navigator``.
    ///   - showsNavigationControls: Whether to show the back / forward buttons.
    ///     Hiding them leaves ``navigator`` working — only the buttons go away.
    ///   - pages: Sidebar entries, in order. The first is selected initially.
    public init(
        title: String = "Settings",
        contentWidth: CGFloat = 715,
        minimumContentHeight: CGFloat = 400,
        navigator: SettingsNavigator? = nil,
        showsNavigationControls: Bool = true,
        @SettingsPageBuilder pages: () -> [SettingsPage]
    ) {
        let resolvedPages = pages()
        self.pages = resolvedPages
        self.windowTitle = title
        self.contentWidth = contentWidth
        self.minimumContentHeight = minimumContentHeight
        self.showsNavigationControls = showsNavigationControls
        self.navigator = navigator ?? SettingsNavigator(initialPageID: resolvedPages.first?.id)

        super.init(
            windowGenerator: SettingsWindow(
                contentRect: NSRect(x: 0, y: 0, width: contentWidth, height: minimumContentHeight),
                styleMask: [.titled, .miniaturizable, .closable, .resizable, .fullSizeContentView],
                backing: .buffered,
                defer: false
            )
        )
    }

    override open func windowDidLoad() {
        super.windowDidLoad()

        contentWindow.title = windowTitle
        // A settings window has no business going full screen.
        contentWindow.collectionBehavior.insert(.fullScreenNone)

        let rootView = SettingsRootView(
            navigator: navigator,
            showsNavigationControls: showsNavigationControls,
            pages: { pages }
        )
            .frame(minWidth: contentWidth, maxWidth: contentWidth)
            .frame(minHeight: minimumContentHeight)

        let hostingController = NSHostingController(rootView: rootView)
        hostingController.view.frame = NSRect(origin: .zero, size: contentWindow.frame.size)
        contentViewController = hostingController

        contentWindow.setFrameAutosaveName(String(describing: Self.self))
        contentWindow.center()
    }
}

#endif
