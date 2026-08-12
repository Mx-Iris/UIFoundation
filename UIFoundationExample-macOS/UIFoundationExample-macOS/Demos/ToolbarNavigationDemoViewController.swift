//
//  ToolbarNavigationDemoViewController.swift
//  UIFoundationExample-macOS
//
//  A browser-shaped playground for `NSToolbar.Navigation`.
//
//  The item lives in a real toolbar, so the demo opens its own window rather
//  than borrowing the browser's detail pane. That window is also where the one
//  thing no unit test can reach gets checked by hand: **press and hold** either
//  chevron and a history menu should drop down, while an ordinary click should
//  move exactly one step. If a click opens the menu instead, the control has
//  lost its action; if an empty direction still opens a blank box, an empty menu
//  is being attached where none should be.
//
//  The window controller here is also the worked example of the data source: it
//  keeps a plain visit list plus a cursor, and answers three questions from it.
//  Note what it never does — there is no "tell the toolbar the history changed"
//  call anywhere. The item pulls on the toolbar's own validation cycle.
//

import AppKit
import UIFoundation

// MARK: - The pretend site

/// One page of the imaginary documentation site being browsed.
private struct BrowsablePage {
    let identifier: String
    let title: String
    let symbolName: String
    let linkedPageIdentifiers: [String]
}

private enum BrowsableSite {
    static let pages: [BrowsablePage] = [
        BrowsablePage(
            identifier: "home",
            title: "Home",
            symbolName: "house",
            linkedPageIdentifiers: ["guides", "reference", "releases"]
        ),
        BrowsablePage(
            identifier: "guides",
            title: "Guides",
            symbolName: "book",
            linkedPageIdentifiers: ["home", "layout", "toolbars"]
        ),
        BrowsablePage(
            identifier: "layout",
            title: "Layout",
            symbolName: "square.grid.2x2",
            linkedPageIdentifiers: ["guides", "toolbars", "reference"]
        ),
        BrowsablePage(
            identifier: "toolbars",
            title: "Toolbars",
            symbolName: "hammer",
            linkedPageIdentifiers: ["guides", "reference", "home"]
        ),
        BrowsablePage(
            identifier: "reference",
            title: "Reference",
            symbolName: "list.bullet.rectangle",
            linkedPageIdentifiers: ["home", "layout", "releases"]
        ),
        BrowsablePage(
            identifier: "releases",
            title: "Releases",
            symbolName: "shippingbox",
            linkedPageIdentifiers: ["home", "reference"]
        ),
    ]

    static func page(withIdentifier identifier: String) -> BrowsablePage {
        pages.first { $0.identifier == identifier } ?? pages[0]
    }
}

// MARK: - The browser window

/// A window whose toolbar carries one ``NSToolbar/Navigation`` item, driven by a
/// visit list this controller owns.
private final class NavigationToolbarDemoWindowController: NSWindowController,
    NSToolbar.Navigation.DataSource,
    NSToolbar.Navigation.Delegate {

    /// Every page visited, oldest first, plus where in it we currently are.
    /// This is the entire history model — the toolbar item keeps none of its own.
    private var visitedPageIdentifiers: [String] = ["home"]
    private var currentHistoryIndex = 0

    private let navigationItem = NSToolbar.Navigation()
    private let pageTitleLabel = NSTextField(labelWithString: "")
    private let pageIconView = NSImageView()
    private let linkStackView = NSStackView()
    private let historyLabel = NSTextField(labelWithString: "")

    /// Called with a one-line description of everything the delegate receives, so
    /// the demo pane can show what the item reported and when.
    var eventLogger: ((String) -> Void)?

    init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 560, height: 380),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Documentation"
        if #available(macOS 11.0, *) {
            window.toolbarStyle = .unified
        }
        super.init(window: window)

        window.contentViewController = makeContentViewController()
        installToolbar(on: window)
        showCurrentPage()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: Toolbar

    private func installToolbar(on window: NSWindow) {
        navigationItem.dataSource = self
        navigationItem.delegate = self
        navigationItem.label = "Navigation"

        let toolbar = NSToolbar(allowsUserCustomization: false) {
            navigationItem
            NSToolbar.box.flexibleSpace
        }
        window.toolbar = toolbar
    }

    // MARK: Content

    private func makeContentViewController() -> NSViewController {
        pageTitleLabel.font = .systemFont(ofSize: 28, weight: .semibold)
        pageIconView.imageScaling = .scaleProportionallyUpOrDown
        pageIconView.contentTintColor = .controlAccentColor

        historyLabel.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        historyLabel.textColor = .secondaryLabelColor
        historyLabel.lineBreakMode = .byTruncatingHead

        let headerStackView = NSStackView(views: [pageIconView, pageTitleLabel])
        headerStackView.orientation = .horizontal
        headerStackView.spacing = 12

        linkStackView.orientation = .vertical
        linkStackView.alignment = .leading
        linkStackView.spacing = 8

        let hintLabel = NSTextField(
            wrappingLabelWithString: """
            Click a link to go deeper, then use the chevrons to move through the \
            history. Press and hold a chevron to jump several steps at once — and \
            note that a direction with nothing in it has no menu to open at all, \
            rather than an empty one.
            """
        )
        hintLabel.font = .systemFont(ofSize: 11)
        hintLabel.textColor = .secondaryLabelColor
        hintLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        let contentStackView = NSStackView(views: [headerStackView, linkStackView, hintLabel, historyLabel])
        contentStackView.orientation = .vertical
        contentStackView.alignment = .leading
        contentStackView.spacing = 16
        contentStackView.edgeInsets = NSEdgeInsets(top: 24, left: 24, bottom: 24, right: 24)
        contentStackView.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            pageIconView.widthAnchor.constraint(equalToConstant: 32),
            pageIconView.heightAnchor.constraint(equalToConstant: 32),
        ])

        let viewController = NSViewController()
        viewController.view = contentStackView
        return viewController
    }

    private var currentPage: BrowsablePage {
        BrowsableSite.page(withIdentifier: visitedPageIdentifiers[currentHistoryIndex])
    }

    private func showCurrentPage() {
        let page = currentPage
        pageTitleLabel.stringValue = page.title
        if #available(macOS 11.0, *) {
            pageIconView.image = NSImage(systemSymbolName: page.symbolName, accessibilityDescription: page.title)
        }
        window?.title = page.title

        linkStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        for linkedIdentifier in page.linkedPageIdentifiers {
            let linkedPage = BrowsableSite.page(withIdentifier: linkedIdentifier)
            let button = NSButton(title: "→ \(linkedPage.title)", target: self, action: #selector(followLink(_:)))
            button.bezelStyle = .inline
            button.identifier = NSUserInterfaceItemIdentifier(linkedIdentifier)
            linkStackView.addArrangedSubview(button)
        }

        let trail = visitedPageIdentifiers.enumerated().map { index, identifier in
            index == currentHistoryIndex ? "[\(identifier)]" : identifier
        }
        historyLabel.stringValue = trail.joined(separator: " › ")
    }

    @objc private func followLink(_ sender: NSButton) {
        guard let identifier = sender.identifier?.rawValue else { return }
        // A new visit truncates whatever was ahead, exactly like a browser.
        visitedPageIdentifiers.removeSubrange((currentHistoryIndex + 1)...)
        visitedPageIdentifiers.append(identifier)
        currentHistoryIndex = visitedPageIdentifiers.count - 1
        showCurrentPage()
        eventLogger?("Followed a link to \(BrowsableSite.page(withIdentifier: identifier).title)")
        // Nothing tells the toolbar item about any of this. It asks.
    }

    // MARK: NSToolbar.Navigation.DataSource

    /// How many entries lie in that direction — the count only, because this runs
    /// on every validation pass.
    private func historyDepth(in direction: NSToolbar.Navigation.Direction) -> Int {
        switch direction {
        case .backward: currentHistoryIndex
        case .forward: visitedPageIdentifiers.count - 1 - currentHistoryIndex
        }
    }

    /// Nearest first: index 0 is the page a single click would land on.
    private func historyIndex(forEntryAt entryIndex: Int, in direction: NSToolbar.Navigation.Direction) -> Int {
        switch direction {
        case .backward: currentHistoryIndex - 1 - entryIndex
        case .forward: currentHistoryIndex + 1 + entryIndex
        }
    }

    func navigationToolbarItem(
        _ item: NSToolbar.Navigation,
        canNavigateIn direction: NSToolbar.Navigation.Direction
    ) -> Bool {
        historyDepth(in: direction) > 0
    }

    func navigationToolbarItem(
        _ item: NSToolbar.Navigation,
        numberOfHistoryEntriesIn direction: NSToolbar.Navigation.Direction
    ) -> Int {
        historyDepth(in: direction)
    }

    func navigationToolbarItem(
        _ item: NSToolbar.Navigation,
        historyEntryAt index: Int,
        in direction: NSToolbar.Navigation.Direction
    ) -> NSToolbar.Navigation.HistoryEntry {
        let page = BrowsableSite.page(withIdentifier: visitedPageIdentifiers[historyIndex(forEntryAt: index, in: direction)])
        // Resolving an icon per row is exactly the cost that must not land on
        // the validation cycle — which is why rows are pulled here and not there.
        let image: NSImage? = if #available(macOS 11.0, *) {
            NSImage(systemSymbolName: page.symbolName, accessibilityDescription: nil)
        } else {
            nil
        }
        return .init(title: page.title, image: image)
    }

    // MARK: NSToolbar.Navigation.Delegate

    func navigationToolbarItem(
        _ item: NSToolbar.Navigation,
        didNavigateIn direction: NSToolbar.Navigation.Direction
    ) {
        currentHistoryIndex = historyIndex(forEntryAt: 0, in: direction)
        showCurrentPage()
        eventLogger?("Stepped \(direction == .backward ? "back" : "forward") to \(currentPage.title)")
    }

    func navigationToolbarItem(
        _ item: NSToolbar.Navigation,
        didSelectHistoryEntryAt index: Int,
        in direction: NSToolbar.Navigation.Direction
    ) {
        currentHistoryIndex = historyIndex(forEntryAt: index, in: direction)
        showCurrentPage()
        eventLogger?("Jumped \(index + 1) \(direction == .backward ? "back" : "forward") to \(currentPage.title)")
    }
}

// MARK: - The demo pane

final class ToolbarNavigationDemoViewController: NSViewController {

    private var browserWindowController: NavigationToolbarDemoWindowController?
    private let eventLogTextView = NSTextView()

    override func loadView() {
        let openButton = NSButton(
            title: "Open Browser Window",
            target: self,
            action: #selector(openBrowserWindow)
        )
        openButton.bezelStyle = .push
        openButton.keyEquivalent = "\r"

        let checklistLabel = NSTextField(
            wrappingLabelWithString: """
            What to check by hand, because no test can reach it:

            1.  A single click on a lit chevron moves exactly one step. If it \
            opens a menu instead, the control lost its action — the one AppKit \
            behaviour that turns a long-press menu into a click-to-open menu.
            2.  Press and hold a lit chevron and the history drops down, nearest \
            entry at the top, each with its page icon.
            3.  A dead chevron opens nothing at all on a long press. An empty \
            NSMenu would still pop as a blank box, which is why an empty \
            direction gets no menu rather than an empty one.
            4.  Neither chevron draws a pull-down arrow, menu attached or not.
            """
        )
        checklistLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        eventLogTextView.isEditable = false
        eventLogTextView.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        eventLogTextView.textContainerInset = NSSize(width: 8, height: 8)

        let logScrollView = NSScrollView()
        logScrollView.documentView = eventLogTextView
        logScrollView.hasVerticalScroller = true
        logScrollView.borderType = .bezelBorder
        logScrollView.translatesAutoresizingMaskIntoConstraints = false
        logScrollView.heightAnchor.constraint(greaterThanOrEqualToConstant: 140).isActive = true

        let stackView = NSStackView(views: [openButton, checklistLabel, logScrollView])
        stackView.orientation = .vertical
        stackView.alignment = .leading
        stackView.spacing = 16
        stackView.edgeInsets = NSEdgeInsets(top: 20, left: 20, bottom: 20, right: 20)
        stackView.translatesAutoresizingMaskIntoConstraints = false
        logScrollView.widthAnchor.constraint(equalTo: stackView.widthAnchor, constant: -40).isActive = true

        view = stackView
    }

    @objc private func openBrowserWindow() {
        if browserWindowController == nil {
            let controller = NavigationToolbarDemoWindowController()
            controller.eventLogger = { [weak self] message in
                self?.appendToEventLog(message)
            }
            browserWindowController = controller
        }
        browserWindowController?.showWindow(nil)
        browserWindowController?.window?.makeKeyAndOrderFront(nil)
    }

    private func appendToEventLog(_ message: String) {
        eventLogTextView.string += (eventLogTextView.string.isEmpty ? "" : "\n") + message
        eventLogTextView.scrollToEndOfDocument(nil)
    }
}
