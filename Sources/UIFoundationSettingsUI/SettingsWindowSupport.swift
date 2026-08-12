#if Settings && os(macOS)

import AppKit
import SwiftUI

@available(macOS 14.0, *)
extension View {
    /// Makes a `NavigationSplitView` behave like a settings pane: its sidebar
    /// cannot be collapsed, and the toolbar toggle that would collapse it is
    /// hidden.
    ///
    /// Scoped to *this* split view. A host that embeds the settings UI inside
    /// its own split view keeps its own sidebar collapsible — see
    /// ``NSView/settingsSplitViewControllers()``.
    func settingsWindowChrome() -> some View {
        background(
            SettingsChromeConfigurator()
                .accessibilityHidden(true)
        )
    }
}

/// Applies the settings-pane chrome from inside the view hierarchy, retrying a
/// few turns while there is nothing to configure yet.
///
/// A hand-rolled stand-in for reaching AppKit through an introspection package.
@available(macOS 14.0, *)
private struct SettingsChromeConfigurator: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        ConfiguratorView()
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        (nsView as? ConfiguratorView)?.scheduleConfiguration()
    }

    private final class ConfiguratorView: NSView {
        /// Measured: SwiftUI's `NSSplitView` already exists by the time this
        /// view reaches the window, and the first main-queue turn after that
        /// finds it. The retries cover the delegate not being wired yet, and
        /// cost nothing when the first attempt succeeds.
        private static let maximumAttempts = 8

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            scheduleConfiguration()
        }

        func scheduleConfiguration(remainingAttempts: Int = maximumAttempts) {
            guard window != nil, remainingAttempts > 0 else { return }
            DispatchQueue.main.async { [weak self] in
                guard let self, self.window != nil else { return }
                guard self.applyChrome() else {
                    self.scheduleConfiguration(remainingAttempts: remainingAttempts - 1)
                    return
                }
            }
        }

        /// - Returns: Whether a split view controller was found to configure.
        private func applyChrome() -> Bool {
            let controllers = settingsSplitViewControllers()
            guard !controllers.isEmpty else { return false }

            for controller in controllers {
                for splitViewItem in controller.splitViewItems {
                    splitViewItem.canCollapse = false
                }
            }
            window?.hideNavigationSplitViewSidebarToggle()
            return true
        }
    }
}

@available(macOS 14.0, *)
extension NSView {
    /// The split view controllers belonging to the SwiftUI content this view is
    /// part of — and **only** those.
    ///
    /// Getting the scope right matters more than it looks. Two facts about
    /// where SwiftUI puts a `.background()` view, both measured:
    ///
    /// - It is **not** inside the `NavigationSplitView`'s own `NSSplitView`.
    ///   Its ancestor chain runs `AppKitPlatformViewHost` → `NSHostingView` →
    ///   whatever the host wrapped the hosting view in. So walking *up* to the
    ///   nearest `NSSplitView` finds the **host's** split view, never ours.
    /// - Searching the whole window downward finds both: ours *and* the host's.
    ///   Configuring everything it finds would lock the host's sidebar open —
    ///   which is exactly what happens when the settings UI is embedded in an
    ///   app that has a sidebar of its own.
    ///
    /// So: walk outward one ancestor at a time and search each one's subtree,
    /// stopping at the first level that yields a split view — while excluding
    /// any split view that is an ancestor of this view, since containing *us*
    /// is what makes a split view the host's rather than ours.
    fileprivate func settingsSplitViewControllers() -> [NSSplitViewController] {
        var ancestorChain: [NSView] = []
        var ancestorSplitViewIdentifiers: Set<ObjectIdentifier> = []

        var ancestor = superview
        while let currentAncestor = ancestor {
            ancestorChain.append(currentAncestor)
            if currentAncestor is NSSplitView {
                ancestorSplitViewIdentifiers.insert(ObjectIdentifier(currentAncestor))
            }
            ancestor = currentAncestor.superview
        }

        for container in ancestorChain {
            var found: [NSSplitViewController] = []

            func search(_ view: NSView) {
                if let splitView = view as? NSSplitView,
                   !ancestorSplitViewIdentifiers.contains(ObjectIdentifier(splitView)),
                   let controller = splitView.delegate as? NSSplitViewController,
                   !found.contains(where: { $0 === controller }) {
                    found.append(controller)
                }
                view.subviews.forEach(search)
            }
            search(container)

            if !found.isEmpty { return found }
        }

        return []
    }
}

@available(macOS 14.0, *)
extension NSWindow {
    /// Hides the sidebar toggle SwiftUI installs into the toolbar. With
    /// collapsing disabled the button would be inert, and an inert button is
    /// worse than no button.
    ///
    /// Matched by identifier, so a host's own toolbar items are untouched.
    ///
    /// Measured on macOS 26.5.2, in a window built the way
    /// ``SettingsWindowController`` builds one: SwiftUI does install a toolbar,
    /// the toggle is among its items by the time this runs, and hiding it
    /// sticks. The one case with nothing to find is the settings UI **embedded**
    /// in a host window — not being the window's `contentViewController`,
    /// SwiftUI owns no toolbar there and `window.toolbar` is `nil`.
    fileprivate func hideNavigationSplitViewSidebarToggle() {
        guard let toolbar else { return }
        let toggleIdentifier = "com.apple.SwiftUI.navigationSplitView.toggleSidebar"
        toolbar.items
            .first { $0.itemIdentifier.rawValue == toggleIdentifier }?
            .view?
            .isHidden = true
    }
}

#endif
