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
    private var currentDemoViewController: NSViewController?

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
            // View first, then the parenting: taking the view out of the window is what drives the
            // appearance callbacks, and an already-orphaned view controller never receives them. A
            // demo that lends the app something while it is on screen — a menu item, say — relies on
            // `viewWillDisappear()` to take it back.
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
