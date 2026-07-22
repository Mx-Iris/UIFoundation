//
//  DemoBrowserSplitViewController.swift
//  UIFoundationExample-macOS
//
//  Sidebar + detail. Selecting a demo in the sidebar swaps the detail content.
//

import AppKit

final class DemoBrowserSplitViewController: NSSplitViewController {

    private let sidebarViewController = DemoSidebarViewController()
    private let detailViewController = DemoDetailViewController()

    private var didSelectInitialDemo = false

    /// The demo on screen.
    var currentDemoViewController: NSViewController? { detailViewController.currentDemoViewController }

    /// Lets the demo on screen answer menu actions it declares, wherever the focus happens to be.
    ///
    /// A menu action is dispatched down the *key window's* responder chain, and that chain starts at
    /// the first responder — in this app usually the sidebar — so it runs sidebar → split view →
    /// window without ever passing through the detail pane. This is AppKit's hook for exactly that: a
    /// responder that cannot handle an action gets to nominate one that can, and this controller is on
    /// every chain because its view is the window's content view.
    ///
    /// It is what gives the tabs demo a real ⌘W: `performClose(_:)` is found on the demo before the
    /// search ever reaches the window, which is what would otherwise close the whole thing.
    override func supplementalTarget(forAction action: Selector, sender: Any?) -> Any? {
        if let currentDemoViewController, currentDemoViewController.responds(to: action) {
            return currentDemoViewController
        }
        return super.supplementalTarget(forAction: action, sender: sender)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        sidebarViewController.onSelectDemo = { [weak self] demo in
            self?.detailViewController.show(demo)
            self?.view.window?.title = "UIFoundation Examples — \(demo.title)"
        }

        let sidebarItem = NSSplitViewItem(sidebarWithViewController: sidebarViewController)
        sidebarItem.minimumThickness = 210
        sidebarItem.maximumThickness = 320
        sidebarItem.canCollapse = false

        let detailItem = NSSplitViewItem(viewController: detailViewController)
        detailItem.minimumThickness = 480

        addSplitViewItem(sidebarItem)
        addSplitViewItem(detailItem)
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        guard !didSelectInitialDemo else { return }
        didSelectInitialDemo = true
        sidebarViewController.selectFirstAvailableDemo()
    }
}

/// Hosts the currently selected demo as a child view controller.
final class DemoDetailViewController: NSViewController {

    private let summaryLabel = NSTextField(labelWithString: "")
    private let contentView = NSView()
    private(set) var currentDemoViewController: NSViewController?

    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 600, height: 600))
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        summaryLabel.font = .systemFont(ofSize: 12)
        summaryLabel.textColor = .secondaryLabelColor
        summaryLabel.lineBreakMode = .byWordWrapping
        summaryLabel.maximumNumberOfLines = 0
        summaryLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(summaryLabel)
        view.addSubview(contentView)

        NSLayoutConstraint.activate([
            summaryLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 10),
            summaryLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            summaryLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),

            contentView.topAnchor.constraint(equalTo: summaryLabel.bottomAnchor, constant: 10),
            contentView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }

    func show(_ demo: Demo) {
        _ = view  // force view load (loadViewIfNeeded() is macOS 14+)

        if let current = currentDemoViewController {
            // View first, then the parenting: losing the window is what drives the appearance
            // callbacks, and an already-orphaned view controller never receives them.
            current.view.removeFromSuperview()
            current.removeFromParent()
        }

        summaryLabel.stringValue = demo.summary

        let demoViewController = demo.makeViewController()
        addChild(demoViewController)

        let demoView = demoViewController.view
        demoView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(demoView)
        NSLayoutConstraint.activate([
            demoView.topAnchor.constraint(equalTo: contentView.topAnchor),
            demoView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            demoView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            demoView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
        ])

        currentDemoViewController = demoViewController
    }
}
