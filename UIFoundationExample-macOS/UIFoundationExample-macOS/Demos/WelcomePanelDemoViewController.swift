//
//  WelcomePanelDemoViewController.swift
//  UIFoundationExample-macOS
//
//  A launcher for `WelcomePanelController` in each of its three styles.
//
//  The panel is a window of its own, so this demo opens one rather than
//  borrowing the browser's detail pane — and the panel deliberately hides its
//  `window` property, so it can only be shown through `showWindow(_:)`.
//
//  This is also where the things no headless test can judge get checked by
//  hand: the two known `.xcode26` gaps the port carried over verbatim (see
//  Evolution 0011), and whether the borderless styles actually clip their
//  rounded corners.
//

import AppKit
import UIFoundation

final class WelcomePanelDemoViewController: NSViewController {

    // MARK: - State

    private var panelControllers: [WelcomePanelController.Style: WelcomePanelController] = [:]

    private var sampleProjectURLs: [URL] = WelcomePanelDemoViewController.defaultSampleProjectURLs()

    private var usesRecentDocumentURLs = false

    private let eventLogTextView = NSTextView()

    private lazy var recentDocumentsCheckbox = NSButton(
        checkboxWithTitle: "Take the list from NSDocumentController.recentDocumentURLs",
        target: self,
        action: #selector(toggleRecentDocumentURLs(_:))
    )

    // MARK: - Layout

    override func loadView() {
        let styleButtons = NSStackView(views: [
            makeOpenButton(title: "Xcode 14 Style", style: .xcode14, isDefault: true),
            makeOpenButton(title: "Xcode 15 Style", style: .xcode15, isDefault: false),
            makeOpenButton(title: "Xcode 26 Style", style: .xcode26, isDefault: false),
        ])
        styleButtons.orientation = .horizontal
        styleButtons.spacing = 8

        let addProjectButton = NSButton(
            title: "Add Project…",
            target: self,
            action: #selector(addProject)
        )
        addProjectButton.bezelStyle = .push

        let listControls = NSStackView(views: [recentDocumentsCheckbox, addProjectButton])
        listControls.orientation = .horizontal
        listControls.spacing = 12

        let checklistLabel = NSTextField(
            wrappingLabelWithString: """
            What to check by hand, because no headless test can see it:

            1.  Under Xcode 15 / 26 the window is borderless with an 8 pt \
            radius — the corners must be clipped, not square. That clipping now \
            rides on `clipsToBounds`, which defaults to off on modern SDKs.
            2.  Under Xcode 14 the close button and the "show on launch" \
            checkbox fade in on hover and out again when the pointer leaves.
            3.  KNOWN GAP (ported verbatim): under Xcode 26 the close button has \
            no icon at all, and pressing an action row gives no highlight. Both \
            work under Xcode 15. Fixing either one means updating \
            Documentations/WelcomePanel.md and the two canary tests.
            4.  Double-click a project row to fire didDoubleClick; right-click \
            one for "Show in Finder".
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

        let stackView = NSStackView(views: [styleButtons, listControls, checklistLabel, logScrollView])
        stackView.orientation = .vertical
        stackView.alignment = .leading
        stackView.spacing = 16
        stackView.edgeInsets = NSEdgeInsets(top: 20, left: 20, bottom: 20, right: 20)
        stackView.translatesAutoresizingMaskIntoConstraints = false
        logScrollView.widthAnchor.constraint(equalTo: stackView.widthAnchor, constant: -40).isActive = true

        view = stackView
    }

    override func viewWillDisappear() {
        super.viewWillDisappear()

        // Leaving a floating panel behind after switching demos is only confusing.
        panelControllers.values.forEach { $0.close() }
        panelControllers.removeAll()
    }

    private func makeOpenButton(title: String, style: WelcomePanelController.Style, isDefault: Bool) -> NSButton {
        let button = NSButton(title: title, target: self, action: #selector(openPanel(_:)))
        button.bezelStyle = .push
        button.tag = Self.tag(for: style)
        if isDefault {
            button.keyEquivalent = "\r"
        }
        return button
    }

    // MARK: - Actions

    @objc private func openPanel(_ sender: NSButton) {
        let style = Self.style(forTag: sender.tag)
        let controller = panelControllers[style] ?? makePanelController(style: style)
        panelControllers[style] = controller
        // The panel hides `window` on purpose: `showWindow(_:)` is the only door.
        controller.showWindow(nil)
        appendToEventLog("Opened the \(Self.name(for: style)) panel")
    }

    @objc private func toggleRecentDocumentURLs(_ sender: NSButton) {
        usesRecentDocumentURLs = sender.state == .on
        reloadOpenPanels()
        appendToEventLog(usesRecentDocumentURLs ? "Switched to NSDocumentController's recent documents" : "Switched back to the sample list")
    }

    @objc private func addProject() {
        let openPanel = NSOpenPanel()
        openPanel.canChooseDirectories = true
        openPanel.canChooseFiles = true
        openPanel.allowsMultipleSelection = true
        openPanel.prompt = "Add"
        openPanel.begin { [weak self] response in
            guard let self, response == .OK, !openPanel.urls.isEmpty else { return }
            sampleProjectURLs.insert(contentsOf: openPanel.urls, at: 0)
            reloadOpenPanels()
            appendToEventLog("Added \(openPanel.urls.count) project(s) to the sample list")
        }
    }

    private func makePanelController(style: WelcomePanelController.Style) -> WelcomePanelController {
        var configuration = WelcomePanelController.Configuration(style: style)
        configuration.welcomeLabelText = style == .xcode14 ? "Welcome to UIFoundation" : "UIFoundation"
        configuration.versionLabelText = "Version \(Self.name(for: style))"

        if style == .xcode14 {
            configuration.primaryAction = .init(
                image: NSImage(systemSymbolName: "plus.square", accessibilityDescription: nil),
                imageTintColor: .controlAccentColor,
                title: "Create a new project",
                subtitle: "Start something from one of the built-in templates.",
                action: { [weak self] _ in self?.appendToEventLog("Action: create a new project") }
            )
            configuration.secondaryAction = .init(
                image: NSImage(systemSymbolName: "square.and.arrow.down.on.square", accessibilityDescription: nil),
                imageTintColor: .controlAccentColor,
                title: "Clone an existing project",
                subtitle: "Start working on something from a Git repository.",
                action: { [weak self] _ in self?.appendToEventLog("Action: clone an existing project") }
            )
            configuration.tertiaryAction = .init(
                image: NSImage(systemSymbolName: "folder", accessibilityDescription: nil),
                imageTintColor: .controlAccentColor,
                title: "Open a project or file",
                subtitle: "Open an existing project or file on your Mac.",
                action: { [weak self] _ in self?.appendToEventLog("Action: open a project or file") }
            )
        } else {
            configuration.primaryAction = .init(
                image: NSImage(systemSymbolName: "plus.square", accessibilityDescription: nil),
                title: "Create New File…",
                action: { [weak self] _ in self?.appendToEventLog("Action: create new file") }
            )
            configuration.secondaryAction = .init(
                image: NSImage(systemSymbolName: "square.and.arrow.down.on.square", accessibilityDescription: nil),
                title: "Clone Git Repository…",
                action: { [weak self] _ in self?.appendToEventLog("Action: clone git repository") }
            )
            configuration.tertiaryAction = .init(
                image: NSImage(systemSymbolName: "folder", accessibilityDescription: nil),
                title: "Open File or Folder…",
                action: { [weak self] _ in self?.appendToEventLog("Action: open file or folder") }
            )
        }

        let controller = WelcomePanelController(configuration: configuration)
        controller.dataSource = self
        controller.delegate = self
        return controller
    }

    private func reloadOpenPanels() {
        panelControllers.values.forEach { $0.reloadData() }
    }

    private func appendToEventLog(_ message: String) {
        eventLogTextView.string += (eventLogTextView.string.isEmpty ? "" : "\n") + message
        eventLogTextView.scrollToEndOfDocument(nil)
    }

    // MARK: - Style ↔ tag

    private static func tag(for style: WelcomePanelController.Style) -> Int {
        switch style {
        case .xcode14: 14
        case .xcode15: 15
        case .xcode26: 26
        }
    }

    private static func style(forTag tag: Int) -> WelcomePanelController.Style {
        switch tag {
        case 15: .xcode15
        case 26: .xcode26
        default: .xcode14
        }
    }

    private static func name(for style: WelcomePanelController.Style) -> String {
        switch style {
        case .xcode14: "Xcode 14"
        case .xcode15: "Xcode 15"
        case .xcode26: "Xcode 26"
        }
    }

    /// A handful of URLs a sandboxed example app can always resolve a name and icon for.
    /// Use **Add Project…** to put real ones in front of them.
    private static func defaultSampleProjectURLs() -> [URL] {
        var urls = [Bundle.main.bundleURL, FileManager.default.temporaryDirectory]
        if let resourceURL = Bundle.main.resourceURL {
            urls.append(resourceURL)
        }
        urls.append(contentsOf: FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask))
        return urls
    }
}

// MARK: - WelcomePanelController.DataSource

extension WelcomePanelDemoViewController: WelcomePanelController.DataSource {
    func welcomePanelUsesRecentDocumentURLs(_ welcomePanel: WelcomePanelController) -> Bool {
        usesRecentDocumentURLs
    }

    func numberOfProjects(in welcomePanel: WelcomePanelController) -> Int {
        sampleProjectURLs.count
    }

    func welcomePanel(_ welcomePanel: WelcomePanelController, urlForProjectAtIndex index: Int) -> URL {
        sampleProjectURLs[index]
    }
}

// MARK: - WelcomePanelController.Delegate

extension WelcomePanelDemoViewController: WelcomePanelController.Delegate {
    func welcomePanel(_ welcomePanel: WelcomePanelController, didCheckShowPanelWhenLaunch isCheck: Bool) {
        appendToEventLog("Show on launch: \(isCheck ? "on" : "off")")
    }

    func welcomePanel(_ welcomePanel: WelcomePanelController, didSelectProjectAtIndex index: Int) {
        appendToEventLog("Selected row \(index)")
    }

    func welcomePanel(_ welcomePanel: WelcomePanelController, didDoubleClickProjectAtIndex index: Int) {
        appendToEventLog("Double-clicked row \(index)")
    }
}
