#if Settings && os(macOS)

import SwiftUI

/// The settings window's content: a sidebar of pages beside the selected page.
///
/// Usually reached through ``SettingsWindowController``; use this directly only
/// when hosting the settings UI somewhere other than its own window.
///
/// ```swift
/// SettingsRootView {
///     SettingsPage("General", symbol: "gearshape") { GeneralPage() }
///     SettingsPage("Updates", symbol: "arrow.down.circle") { UpdatesPage() }
/// }
/// ```
///
/// Which page is on screen lives in a ``SettingsNavigator``, which also backs
/// the back / forward buttons. Pass one in to drive the view from code; leave
/// it out and the view keeps its own.
///
/// The three regions are separate `View` types rather than computed properties
/// on this one, so that each invalidates on its own. Everything this body reads
/// is either stored on the view or a reference — no observed property of the
/// navigator is touched here, so navigating does not re-run the root at all: it
/// re-runs the sidebar (selection moved), the detail pane (different page), and
/// the toolbar controls (availability flipped), each on its own account.
@available(macOS 14.0, *)
public struct SettingsRootView: View {
    private let pages: [SettingsPage]

    /// Precomputed in `init` rather than derived in `body`: `.onChange` needs an
    /// `Equatable` witness for the page list, and mapping the array on every
    /// body evaluation allocates once per pass for a value that only changes
    /// when the view is rebuilt with different pages.
    private let pageIdentifiers: [SettingsPage.ID]

    private let sidebarWidth: CGFloat
    private let showsNavigationControls: Bool

    private let providedNavigator: SettingsNavigator?

    /// Used when the caller does not supply a navigator. `@State` so it
    /// survives the view value being rebuilt — a plain `let` would hand out a
    /// fresh navigator, and an empty history, on every re-render.
    @State private var ownNavigator: SettingsNavigator

    /// - Parameters:
    ///   - navigator: Drives the selection and history. Defaults to one of the
    ///     view's own, starting on the first page.
    ///   - showsNavigationControls: Whether to show the back / forward buttons.
    ///     Hiding them leaves `navigator` working — only the buttons go away.
    ///   - sidebarWidth: Width of the page list.
    ///   - pages: Sidebar entries, in order.
    @MainActor
    public init(
        navigator: SettingsNavigator? = nil,
        showsNavigationControls: Bool = true,
        sidebarWidth: CGFloat = 185,
        @SettingsPageBuilder pages: () -> [SettingsPage]
    ) {
        let resolvedPages = pages()
        self.pages = resolvedPages
        self.pageIdentifiers = resolvedPages.map(\.id)
        self.sidebarWidth = sidebarWidth
        self.showsNavigationControls = showsNavigationControls
        self.providedNavigator = navigator
        _ownNavigator = State(initialValue: SettingsNavigator(initialPageID: resolvedPages.first?.id))
    }

    private var navigator: SettingsNavigator { providedNavigator ?? ownNavigator }

    public var body: some View {
        NavigationSplitView {
            SettingsSidebar(pages: pages, navigator: navigator, width: sidebarWidth)
        } detail: {
            SettingsDetailPane(
                pages: pages,
                navigator: navigator,
                showsNavigationControls: showsNavigationControls
            )
        }
        .settingsWindowChrome()
        .onChange(of: pageIdentifiers, initial: true) { _, availablePageIDs in
            navigator.pruneHistory(keeping: Set(availablePageIDs))
            if navigator.currentPageID == nil {
                navigator.currentPageID = availablePageIDs.first
            }
        }
    }
}

/// The page list.
@available(macOS 14.0, *)
private struct SettingsSidebar: View {
    let pages: [SettingsPage]
    let navigator: SettingsNavigator
    let width: CGFloat

    var body: some View {
        // A key-path binding into the navigator rather than a hand-written
        // `Binding(get:set:)`: no closure is allocated per body evaluation, and
        // the pair compares equal across updates.
        @Bindable var boundNavigator = navigator

        // `List(_:selection:)` tags each row with the element's `id` already,
        // so no explicit `.tag` is needed.
        List(pages, selection: $boundNavigator.currentPageID) { page in
            Label {
                Text(page.title)
            } icon: {
                SettingsPageIcon(page.icon)
            }
        }
        .navigationSplitViewColumnWidth(width)
    }
}

/// The selected page, plus the toolbar it carries.
@available(macOS 14.0, *)
private struct SettingsDetailPane: View {
    let pages: [SettingsPage]
    let navigator: SettingsNavigator
    let showsNavigationControls: Bool

    var body: some View {
        // The `Group` is load-bearing: it lets `.toolbar` apply whether or not
        // a page resolved. This is not the single-child case — the content is a
        // conditional, not one concrete view.
        Group {
            if let selectedPage {
                selectedPage.content
                    .navigationTitle(selectedPage.title)
            }
        }
        .toolbar {
            if showsNavigationControls {
                ToolbarItem(placement: .navigation) {
                    // A child view, so that reading `canGoBack` / `canGoForward`
                    // happens in *its* body. Reading them here would make the
                    // whole detail pane — the settings page itself — re-run
                    // every time a button's availability flipped.
                    SettingsNavigationControls(navigator: navigator)
                }
            }
        }
    }

    private var selectedPage: SettingsPage? {
        pages.first { $0.id == navigator.currentPageID } ?? pages.first
    }
}

/// The back / forward pair, in the leading slot of the detail pane — the same
/// place Xcode and System Settings put theirs.
///
/// **One toolbar item holding a `ControlGroup` in the `.navigation` style**,
/// which is exactly what Xcode's settings window does. Verified against a
/// view-hierarchy capture of Xcode's own window: both produce
///
/// ```
/// NSToolbarItemViewer
///  < ToolbarItemHostingView<_ViewList_View>
///   < AppKitPlatformViewHost<PlatformViewRepresentableAdaptor<AppKitSegmentedControlAdaptor>>
///    < SwiftUISegmentedControl
/// ```
///
/// with the same `segmentCount` (2), `trackingMode` (`.momentary`),
/// `segmentStyle` (`.separated`), `controlSize` (`.extraLarge`) and fitting size
/// (73 × 36).
///
/// Two things this rules out, both measured: two adjacent `ToolbarItem`s are two
/// toolbar items drawing as two separate controls, and a `ControlGroup` *without*
/// `.navigation` resolves to a native item with no hosting view at all. Only this
/// spelling lands on the segmented control.
@available(macOS 14.0, *)
private struct SettingsNavigationControls: View {
    let navigator: SettingsNavigator

    var body: some View {
        ControlGroup {
            Button {
                navigator.goBack()
            } label: {
                // `bundle: #bundle` is required inside a package: without it the
                // lookup goes to `Bundle.main`, misses, and silently renders the
                // key.
                Label {
                    Text("Back", bundle: #bundle, comment: "Settings window toolbar button that returns to the previously visited page.")
                } icon: {
                    Image(systemName: "chevron.backward")
                }
            }
            .disabled(!navigator.canGoBack)
            .keyboardShortcut("[", modifiers: .command)

            Button {
                navigator.goForward()
            } label: {
                Label {
                    Text("Forward", bundle: #bundle, comment: "Settings window toolbar button that returns to the page visited before going back.")
                } icon: {
                    Image(systemName: "chevron.forward")
                }
            }
            .disabled(!navigator.canGoForward)
            .keyboardShortcut("]", modifiers: .command)
        }
        .controlGroupStyle(.navigation)
    }
}

#endif
