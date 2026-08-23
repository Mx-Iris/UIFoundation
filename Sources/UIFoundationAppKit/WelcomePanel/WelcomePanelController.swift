#if WelcomePanel && os(macOS)

import AppKit
import UIFoundationShared
import UIFoundationToolbox
import UIFoundationUtilities

/// The Xcode-style welcome window: the app icon, its name and version above a short action list on
/// the left, a recent-project list on the right.
///
/// Three ``Style`` cases imitate three Xcode generations. The panel *pulls* its project list from
/// the data source — on `showWindow(_:)`, when the window becomes visible, and when the data source
/// is assigned — so a host that keeps its own list rarely needs to call ``reloadData()``.
///
/// ```swift
/// let panel = WelcomePanelController(configuration: .init(style: .xcode26))
/// panel.dataSource = self
/// panel.delegate = self
/// panel.showWindow(nil)
/// ```
///
/// Ported from `Mx-Iris/WelcomeKit`; see `Documentations/WelcomePanel.md`.
@available(macOS 11.0, *)
public final class WelcomePanelController: NSWindowController {
    public weak var dataSource: (any DataSource)? {
        didSet {
            reloadData()
        }
    }

    public weak var delegate: (any Delegate)?

    public let configuration: Configuration

    private lazy var contentWindow = Window(contentRect: configuration.style.windowRect, styleMask: [], backing: .buffered, defer: true).then {
        $0.titlebarAppearsTransparent = true
        $0.titleVisibility = .hidden
        $0.center()
        $0.isMovableByWindowBackground = true
        $0.delegate = self
    }

    // Internal rather than private because the tests reach for them; a host cannot see either
    // way, since both types are module-internal.
    lazy var welcomeViewController = WelcomeViewController(configuration: configuration)

    lazy var projectsViewController = ProjectsViewController(configuration: configuration)

    @available(*, unavailable)
    public override var window: NSWindow? {
        set {
            super.window = newValue
        }
        get {
            super.window
        }
    }

    @available(*, unavailable)
    public override var contentViewController: NSViewController? {
        set {
            super.contentViewController = newValue
        }
        get {
            super.contentViewController
        }
    }

    public init(configuration: Configuration = .init()) {
        self.configuration = configuration
        super.init(window: nil)
    }

    public override var windowNibName: NSNib.Name? { "" }

    public override func loadWindow() {
        super.window = contentWindow
    }

    public override func windowDidLoad() {
        super.windowDidLoad()

        contentWindow.styleMask = configuration.style.windowStyleMask
        contentWindow.collectionBehavior = [.moveToActiveSpace]
        contentWindow.isMovable = true
        contentWindow.isMovableByWindowBackground = true
        contentWindow.backgroundColor = .clear
        contentWindow.hasShadow = true

        if configuration.style == .xcode15 {
            contentWindow.backgroundColor = .clear
        }

        let contentViewController = XiblessViewController<LayerBackedView>().then {
            $0.contentView.frame = configuration.style.windowRect
            $0.contentView.cornerRadius = configuration.style.windowCornerRadius
            // The original painted `masksToBounds = cornerRadius != 0` from its own
            // `updateLayer()`; the library's renderer reads `clipsToBounds` instead, whose default
            // is `false` for anything linked against macOS 14 or later. Without this the
            // borderless rounded styles show square content in the corners.
            $0.contentView.clipsToBounds = configuration.style.windowCornerRadius != 0
        }

        contentViewController.do {
            $0.view.addSubview(welcomeViewController.view)
            $0.view.addSubview(projectsViewController.view)
            $0.addChild(welcomeViewController)
            $0.addChild(projectsViewController)
        }

        super.contentViewController = contentViewController

        welcomeViewController.view.makeConstraints { make in
            make.topAnchor.constraint(equalTo: contentViewController.view.topAnchor)
            make.leftAnchor.constraint(equalTo: contentViewController.view.leftAnchor)
            make.bottomAnchor.constraint(equalTo: contentViewController.view.bottomAnchor)
            make.rightAnchor.constraint(equalTo: projectsViewController.view.leftAnchor)
        }

        projectsViewController.view.makeConstraints { make in
            make.widthAnchor.constraint(equalToConstant: configuration.style.projectViewWidth)
            make.topAnchor.constraint(equalTo: contentViewController.view.topAnchor)
            make.bottomAnchor.constraint(equalTo: contentViewController.view.bottomAnchor)
            make.rightAnchor.constraint(equalTo: contentViewController.view.rightAnchor)
        }

        welcomeViewController.didCheckShowOnLaunchCheckbox = { [weak self] button in
            guard let self else { return }
            delegate?.welcomePanel(self, didCheckShowPanelWhenLaunch: button.state == .on)
        }

        projectsViewController.didSelect = { [weak self] index in
            guard let self else { return }
            delegate?.welcomePanel(self, didSelectProjectAtIndex: index)
        }

        projectsViewController.didDoubleClick = { [weak self] index in
            guard let self else { return }
            delegate?.welcomePanel(self, didDoubleClickProjectAtIndex: index)
        }
    }

    @available(*, unavailable)
    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// Re-asks the data source for the project list and repaints both sides.
    public func reloadData() {
        guard let dataSource else { return }

        if dataSource.welcomePanelUsesRecentDocumentURLs(self) {
            projectsViewController.usesRecentDocumentURLs = true
        } else {
            var numberOfProjects = dataSource.numberOfProjects(in: self)
            if numberOfProjects < 0 {
                numberOfProjects = 0
            }
            let projectURLs = (0 ..< numberOfProjects).map {
                dataSource.welcomePanel(self, urlForProjectAtIndex: $0)
            }
            projectsViewController.usesRecentDocumentURLs = false
            projectsViewController.recentProjectURLs = projectURLs
        }
        welcomeViewController.reloadData()
        projectsViewController.reloadData()
    }

    public override func showWindow(_ sender: Any?) {
        reloadData()
        super.showWindow(sender)
    }
}

@available(macOS 11.0, *)
extension WelcomePanelController: NSWindowDelegate {
    public func windowDidChangeOcclusionState(_ notification: Notification) {
        if contentWindow.occlusionState.contains(.visible) {
            reloadData()
        }
    }
}

@available(macOS 11.0, *)
extension WelcomePanelController {
    /// A borderless window still has to be able to become key, or the panel's controls stay dead.
    final class Window: NSWindow {
        override var canBecomeKey: Bool {
            true
        }
    }
}

#endif
