//
//  TabsControlDemoViewController.swift
//  UIFoundationExample-macOS
//
//  Showcases TabsControl: style switching, add / close / reorder / rename,
//  and a live event log driven by the data source & delegate.
//

import AppKit
import UIFoundation

final class TabsControlDemoViewController: NSViewController {

    /// Backing model for a single tab. A reference type so the control's data
    /// source / delegate can hand the same identity back and forth.
    private final class TabModel: NSObject {
        var title: String
        init(title: String) { self.title = title }
    }

    private var tabs: [TabModel] = [
        TabModel(title: "Overview"),
        TabModel(title: "Activity"),
        TabModel(title: "Settings"),
    ]
    private var nextTabNumber = 4

    /// Which tab the *demo* considers active.
    ///
    /// A real host keeps the selection in its own model and pushes it into the control, rather than
    /// reading it back out: the tab bar is one of several views onto that model, and commands like
    /// ⌘W act on the model. The control learns about it through `selectItemAtIndex(_:)`, and every
    /// user-driven change comes back through `tabsControlDidChangeSelection`.
    private var activeTabIndex = 0

    /// Set while a model-driven snapshot is being pushed into the control, so the selection the
    /// control reports back is not mistaken for the user picking a tab.
    private var isApplyingSnapshot = false

    private let tabsControl = TabsControl()
    private let styleSwitcher = NSSegmentedControl()
    private let eventLogTextView = NSTextView()

    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 720, height: 480))
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        buildUserInterface()

        tabsControl.dataSource = self
        tabsControl.delegate = self
        tabsControl.style = TabsControl.DefaultStyle()
        applySnapshot(animated: false)

        log("loaded \(tabs.count) tabs")
    }

    // MARK: - UI

    private func buildUserInterface() {
        styleSwitcher.segmentCount = 4
        styleSwitcher.setLabel("Default", forSegment: 0)
        styleSwitcher.setLabel("Chrome", forSegment: 1)
        styleSwitcher.setLabel("Safari", forSegment: 2)
        styleSwitcher.setLabel("System", forSegment: 3)
        styleSwitcher.trackingMode = .selectOne
        styleSwitcher.selectedSegment = 0
        styleSwitcher.target = self
        styleSwitcher.action = #selector(changeStyle(_:))

        let addButton = NSButton(title: "Add Tab", target: self, action: #selector(addTab(_:)))
        addButton.bezelStyle = .rounded

        let hintLabel = NSTextField(labelWithString: "⌘T new tab · ⌘W close tab · double-click to rename · drag to reorder · try “System” for Liquid Glass")
        hintLabel.font = .systemFont(ofSize: 11)
        hintLabel.textColor = .tertiaryLabelColor

        let toolbar = NSStackView(views: [styleSwitcher, addButton, hintLabel])
        toolbar.orientation = .horizontal
        toolbar.spacing = 12
        toolbar.alignment = .centerY
        toolbar.translatesAutoresizingMaskIntoConstraints = false

        tabsControl.translatesAutoresizingMaskIntoConstraints = false

        let logLabel = NSTextField(labelWithString: "Event log")
        logLabel.font = .systemFont(ofSize: 11, weight: .semibold)
        logLabel.textColor = .secondaryLabelColor
        logLabel.translatesAutoresizingMaskIntoConstraints = false

        let logScrollView = NSScrollView()
        logScrollView.hasVerticalScroller = true
        logScrollView.borderType = .bezelBorder
        logScrollView.translatesAutoresizingMaskIntoConstraints = false
        eventLogTextView.isEditable = false
        eventLogTextView.drawsBackground = true
        eventLogTextView.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        eventLogTextView.textContainerInset = NSSize(width: 6, height: 6)
        logScrollView.documentView = eventLogTextView

        view.addSubview(toolbar)
        view.addSubview(tabsControl)
        view.addSubview(logLabel)
        view.addSubview(logScrollView)

        NSLayoutConstraint.activate([
            toolbar.topAnchor.constraint(equalTo: view.topAnchor, constant: 8),
            toolbar.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            toolbar.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -16),

            tabsControl.topAnchor.constraint(equalTo: toolbar.bottomAnchor, constant: 16),
            tabsControl.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tabsControl.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tabsControl.heightAnchor.constraint(equalToConstant: 26),

            logLabel.topAnchor.constraint(equalTo: tabsControl.bottomAnchor, constant: 20),
            logLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),

            logScrollView.topAnchor.constraint(equalTo: logLabel.bottomAnchor, constant: 6),
            logScrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            logScrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            logScrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -16),
        ])
    }

    // MARK: - Actions

    @objc private func changeStyle(_ sender: NSSegmentedControl) {
        switch sender.selectedSegment {
        case 1:
            tabsControl.style = TabsControl.ChromeStyle()
            log("style → Chrome")
        case 2:
            tabsControl.style = TabsControl.SafariStyle()
            log("style → Safari")
        case 3:
            tabsControl.style = TabsControl.SystemStyle()
            log("style → System")
        default:
            tabsControl.style = TabsControl.DefaultStyle()
            log("style → Default")
        }
    }

    /// ⌘T and ⌘W. Both reach this demo wherever the focus is, because the browser's split view
    /// controller nominates it — see `DemoBrowserSplitViewController.supplementalTarget(forAction:sender:)`.
    /// Closing the last tab hands `performClose(_:)` back to the window, the way Safari does.
    @objc func newTab(_ sender: Any?) {
        addTab(sender)
    }

    @objc func performClose(_ sender: Any?) {
        guard tabs.count > 1 else {
            view.window?.performClose(sender)
            return
        }
        closeTab(at: activeTabIndex)
    }

    @objc private func addTab(_ sender: Any?) {
        // Opened next to the current tab, the way a browser opens one, rather than always at the end —
        // which is also what exercises inserting into the middle of the strip.
        let insertionIndex = tabs.isEmpty ? 0 : activeTabIndex + 1
        tabs.insert(TabModel(title: "Tab \(nextTabNumber)"), at: insertionIndex)
        nextTabNumber += 1
        activeTabIndex = insertionIndex
        applySnapshot(animated: true)
        log("added tab at \(insertionIndex) (\(tabs.count) total)")
        verifySelectionAgreement()
    }

    /// Removes the tab at `index` and activates its *right* neighbour, the way Safari and Chrome
    /// do — closing a tab moves you on, not back.
    private func closeTab(at index: Int) {
        guard tabs.indices.contains(index), tabs.count > 1 else { return }
        let closedTheActiveTab = index == activeTabIndex
        let closedTitle = tabs[index].title
        tabs.remove(at: index)
        if closedTheActiveTab {
            activeTabIndex = min(index, tabs.count - 1)
        } else if index < activeTabIndex {
            activeTabIndex -= 1
        }
        applySnapshot(animated: true)
        log("closed \(closedTitle) → active \(tabs[activeTabIndex].title) (\(tabs.count) left)")
        verifySelectionAgreement()
    }

    /// Pushes the model into the control: the reload brings the tabs, `selectItemAtIndex` brings the
    /// selection.
    private func applySnapshot(animated: Bool) {
        isApplyingSnapshot = true
        tabsControl.reloadTabs(animated: animated)
        if tabs.indices.contains(activeTabIndex) {
            tabsControl.selectItemAtIndex(activeTabIndex)
        }
        isApplyingSnapshot = false
    }

    /// The bar and the model have to end up naming the same tab: ⌘W closes whatever the *model*
    /// calls active, while the user aims with whatever the *bar* highlights. Checked one runloop
    /// turn later, once every follow-up selection has settled.
    private func verifySelectionAgreement() {
        DispatchQueue.main.async { [self] in
            guard tabsControl.selectedButtonIndex != activeTabIndex else { return }
            log("⚠️ bar highlights \(title(at: tabsControl.selectedButtonIndex)), model says \(title(at: activeTabIndex))")
        }
    }

    private func title(at index: Int?) -> String {
        guard let index, tabs.indices.contains(index) else { return "none" }
        return tabs[index].title
    }

    private func log(_ message: String) {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: 11, weight: .regular),
            .foregroundColor: NSColor.labelColor,
        ]
        eventLogTextView.textStorage?.append(NSAttributedString(string: message + "\n", attributes: attributes))
        eventLogTextView.scrollToEndOfDocument(nil)
    }
}

// MARK: - TabsControl.DataSource

extension TabsControlDemoViewController: TabsControl.DataSource {
    func tabsControlNumberOfTabs(_ control: TabsControl) -> Int {
        tabs.count
    }

    func tabsControl(_ control: TabsControl, itemAtIndex index: Int) -> Any {
        tabs[index]
    }

    func tabsControl(_ control: TabsControl, titleForItem item: Any) -> String {
        (item as? TabModel)?.title ?? ""
    }

    func tabsControl(_ control: TabsControl, closeIconForItem item: Any) -> NSImage? {
        NSImage(systemSymbolName: "xmark.circle.fill", accessibilityDescription: "Close tab")
    }

    func tabsControl(_ control: TabsControl, closePositionForItem item: Any) -> TabsControl.ClosePosition {
        // The system window-tab bar puts the close button on the leading edge.
        .left
    }
}

// MARK: - TabsControl.Delegate

extension TabsControlDemoViewController: TabsControl.Delegate {
    func tabsControlDidChangeSelection(_ control: TabsControl, item: Any?) {
        guard !isApplyingSnapshot else { return }
        if let model = item as? TabModel, let index = tabs.firstIndex(where: { $0 === model }) {
            activeTabIndex = index
        }
        log("selected: \((item as? TabModel)?.title ?? "none")")
    }

    func tabsControl(_ control: TabsControl, canSelectItem item: Any) -> Bool {
        true
    }

    func tabsControl(_ control: TabsControl, canReorderItem item: Any) -> Bool {
        true
    }

    func tabsControl(_ control: TabsControl, didReorderItems items: [Any]) {
        // The active tab keeps its identity across a reorder, not its index.
        let activeModel = tabs.indices.contains(activeTabIndex) ? tabs[activeTabIndex] : nil
        tabs = items.compactMap { $0 as? TabModel }
        if let activeModel, let index = tabs.firstIndex(where: { $0 === activeModel }) {
            activeTabIndex = index
        }
        log("reordered: \(tabs.map(\.title).joined(separator: ", "))")
    }

    func tabsControl(_ control: TabsControl, canEditTitleOfItem item: Any) -> Bool {
        true
    }

    func tabsControl(_ control: TabsControl, setTitle newTitle: String, forItem item: Any) {
        (item as? TabModel)?.title = newTitle
        log("renamed → \(newTitle)")
    }

    func tabsControl(_ control: TabsControl, canCloseItem item: Any) -> Bool {
        tabs.count > 1
    }

    func tabsControl(_ control: TabsControl, didCloseItem item: Any) {
        guard let model = item as? TabModel, let index = tabs.firstIndex(where: { $0 === model }) else { return }
        closeTab(at: index)
    }
}
