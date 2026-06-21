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
        tabsControl.reloadTabs()
        tabsControl.selectItemAtIndex(0)

        log("loaded \(tabs.count) tabs")
    }

    // MARK: - UI

    private func buildUserInterface() {
        styleSwitcher.segmentCount = 3
        styleSwitcher.setLabel("Default", forSegment: 0)
        styleSwitcher.setLabel("Chrome", forSegment: 1)
        styleSwitcher.setLabel("Safari", forSegment: 2)
        styleSwitcher.trackingMode = .selectOne
        styleSwitcher.selectedSegment = 0
        styleSwitcher.target = self
        styleSwitcher.action = #selector(changeStyle(_:))

        let addButton = NSButton(title: "Add Tab", target: self, action: #selector(addTab(_:)))
        addButton.bezelStyle = .rounded

        let hintLabel = NSTextField(labelWithString: "Double-click to rename · drag to reorder · hover to reveal close")
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
            tabsControl.heightAnchor.constraint(equalToConstant: 36),

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
        default:
            tabsControl.style = TabsControl.DefaultStyle()
            log("style → Default")
        }
    }

    @objc private func addTab(_ sender: Any?) {
        tabs.append(TabModel(title: "Tab \(nextTabNumber)"))
        nextTabNumber += 1
        tabsControl.reloadTabs()
        tabsControl.selectItemAtIndex(tabs.count - 1)
        log("added tab (\(tabs.count) total)")
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
        .right
    }
}

// MARK: - TabsControl.Delegate

extension TabsControlDemoViewController: TabsControl.Delegate {
    func tabsControlDidChangeSelection(_ control: TabsControl, item: Any?) {
        log("selected: \((item as? TabModel)?.title ?? "none")")
    }

    func tabsControl(_ control: TabsControl, canSelectItem item: Any) -> Bool {
        true
    }

    func tabsControl(_ control: TabsControl, canReorderItem item: Any) -> Bool {
        true
    }

    func tabsControl(_ control: TabsControl, didReorderItems items: [Any]) {
        tabs = items.compactMap { $0 as? TabModel }
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
        if let model = item as? TabModel, let index = tabs.firstIndex(where: { $0 === model }) {
            tabs.remove(at: index)
        }
        log("closed (\(tabs.count) left)")
    }
}
