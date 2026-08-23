#if WelcomePanel && os(macOS)

import AppKit
import UIFoundationShared
import UIFoundationToolbox
import UIFoundationUtilities

@available(macOS 11.0, *)
extension WelcomePanelController {
    /// The panel's right-hand side: the recent-project list over a vibrancy backdrop.
    final class ProjectsViewController: XiblessViewController<LayerBackedView>, NSTableViewDataSource, NSTableViewDelegate {
        let configuration: Configuration

        var recentProjectURLs: [URL] = []

        var usesRecentDocumentURLs: Bool = true

        var didSelect: (Int) -> Void = { _ in }

        var didDoubleClick: (Int) -> Void = { _ in }

        private var urls: [URL] {
            if usesRecentDocumentURLs {
                return NSDocumentController.shared.recentDocumentURLs
            } else {
                return recentProjectURLs
            }
        }

        lazy var visualEffectView = NSVisualEffectView().then {
            $0.blendingMode = .behindWindow
            $0.material = .underWindowBackground
        }

        lazy var scrollView: BackgroundScrollView = .init().then {
            $0.documentView = tableView
            $0.backgroundColor = configuration.style.projectViewBackgroundColor
            $0.automaticallyAdjustsContentInsets = false
        }

        lazy var tableView: NSTableView = .init().then {
            $0.addTableColumn(NSTableColumn(identifier: .init("DefalutTableColumn")))
            $0.headerView = nil
            $0.backgroundColor = .clear
            $0.intercellSpacing = .init(width: 10, height: 0)
            $0.style = .sourceList
            $0.rowHeight = 44
            $0.doubleAction = #selector(onDoubleClick)
            $0.menu = NSMenu().then {
                $0.addItem(withTitle: "Show in Finder", action: #selector(showInFinderAction(_:)), keyEquivalent: "")
            }
        }

        lazy var placeholderLabel = NSTextField(labelWithString: "No Recent Projects").then {
            $0.font = .systemFont(ofSize: 16.5)
            $0.textColor = .secondaryLabelColor
            $0.isHidden = true
        }

        init(configuration: Configuration) {
            self.configuration = configuration
            super.init()
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        @objc func showInFinderAction(_ sender: NSMenuItem) {
            let row = tableView.clickedRow
            guard row >= 0, row < urls.count else { return }
            NSWorkspace.shared.activateFileViewerSelecting([urls[row]])
        }

        override func loadView() {
            view = visualEffectView
            visualEffectView.box.addSubview(scrollView, fill: true)
        }

        override func viewDidLoad() {
            super.viewDidLoad()
            tableView.dataSource = self
            tableView.delegate = self
            tableView.addSubview(placeholderLabel)
            placeholderLabel.makeConstraints { make in
                make.centerXAnchor.constraint(equalTo: tableView.centerXAnchor)
                make.centerYAnchor.constraint(equalTo: tableView.centerYAnchor)
            }
        }

        @objc func onDoubleClick() {
            didDoubleClick(tableView.clickedRow)
        }

        func reloadData() {
            placeholderLabel.isHidden = !urls.isEmpty
            tableView.reloadData()
        }

        // MARK: - NSTableViewDataSource / NSTableViewDelegate

        func numberOfRows(in tableView: NSTableView) -> Int {
            urls.count
        }

        func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
            let cell = tableView.box.makeView(ofClass: ProjectCellView.self) {
                ProjectCellView(style: self.configuration.style)
            }
            let projectURL = urls[row]
            let properties = try? projectURL.resourceValues(forKeys: [.localizedNameKey, .effectiveIconKey])
            cell.iconImageView.image = properties?.effectiveIcon as? NSImage
            cell.titleLabel.stringValue = properties?.localizedName ?? ""
            cell.detailLabel.stringValue = projectURL.path
            return cell
        }

        func tableViewSelectionDidChange(_ notification: Notification) {
            didSelect(tableView.selectedRow)
        }
    }
}

#endif
