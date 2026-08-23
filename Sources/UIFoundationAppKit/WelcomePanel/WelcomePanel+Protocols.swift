#if WelcomePanel && os(macOS)

import AppKit

@available(macOS 11.0, *)
extension WelcomePanelController {
    /// Supplies the recent-project list shown on the panel's right-hand side.
    ///
    /// The panel *pulls*: it re-asks on `showWindow(_:)`, whenever the window becomes visible, and
    /// when the data source is first assigned. A host that changes its own list outside those
    /// moments calls ``WelcomePanelController/reloadData()``.
    public protocol DataSource: AnyObject {
        /// Return `true` to take the list straight from `NSDocumentController.shared.recentDocumentURLs`,
        /// in which case the two methods below are never called.
        func welcomePanelUsesRecentDocumentURLs(_ welcomePanel: WelcomePanelController) -> Bool
        func numberOfProjects(in welcomePanel: WelcomePanelController) -> Int
        func welcomePanel(_ welcomePanel: WelcomePanelController, urlForProjectAtIndex index: Int) -> URL
    }

    /// Receives the panel's user interactions.
    public protocol Delegate: AnyObject {
        /// Only the ``WelcomePanelController/Style/xcode14`` style shows the checkbox this reports;
        /// under the other styles it never fires.
        func welcomePanel(_ welcomePanel: WelcomePanelController, didCheckShowPanelWhenLaunch isCheck: Bool)
        func welcomePanel(_ welcomePanel: WelcomePanelController, didSelectProjectAtIndex index: Int)
        func welcomePanel(_ welcomePanel: WelcomePanelController, didDoubleClickProjectAtIndex index: Int)
    }
}

#endif
