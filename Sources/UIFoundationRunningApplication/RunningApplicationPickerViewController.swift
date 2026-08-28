#if RunningApplication && os(macOS)

import AppKit
import UIFoundationToolbox

@available(macOS 11.0, *)
final class RunningApplicationPickerViewController: RunningItemPickerViewController<RunningApplication> {
    typealias Column = RunningPickerTabViewController.ApplicationField
    typealias Configuration = RunningPickerTabViewController.ApplicationConfiguration

    @MainActor protocol Delegate: AnyObject {
        func runningApplicationPickerViewController(_ viewController: RunningApplicationPickerViewController, shouldSelectApplication application: RunningApplication) -> Bool
        func runningApplicationPickerViewController(_ viewController: RunningApplicationPickerViewController, didSelectApplication application: RunningApplication)
        func runningApplicationPickerViewController(_ viewController: RunningApplicationPickerViewController, didConfirmApplication application: RunningApplication)
        func runningApplicationPickerViewControllerWasCancelled(_ viewController: RunningApplicationPickerViewController)
    }

    weak var delegate: Delegate?

    private let workspace = NSWorkspace.shared

    private var runningApplicationObservation: NSKeyValueObservation?
    private var applicationCache: [pid_t: RunningApplication] = [:]
    private var cachedItemPIDs: [pid_t] = []
    private let backgroundQueue = DispatchQueue(label: "com.runningapplicationkit.application-picker", qos: .userInitiated)

    private(set) var configuration: Configuration

    init(configuration: Configuration = .init()) {
        self.configuration = configuration
        super.init()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func currentBaseConfiguration() -> BaseConfiguration {
        configuration.baseConfiguration
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        preferredContentSize = .init(width: 800, height: 600)
        setupObservation()
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        if applicationCache.isEmpty {
            refreshInBackground(animatingDifferences: false)
        }
    }

    /// Switch this tab between the table and list presentations at runtime.
    func updateStyle(_ style: RunningPickerTabViewController.Style) {
        guard configuration.style != style else { return }
        configuration.style = style
        applyStyleChange(baseConfiguration: configuration.baseConfiguration) { [weak self] in
            self?.configureColumns()
        }
    }

    // MARK: - Overrides

    override func loadItems() -> [RunningApplication] {
        // Return whatever has been prefetched so far. If prefetch() was called early
        // (by the parent tab view controller) this may already contain the full app list,
        // avoiding an empty-table flash. Otherwise refreshInBackground() populates the table asynchronously.
        cachedItemPIDs.compactMap { applicationCache[$0] }
    }

    override func configureColumns() {
        configureColumns(configuration.allowsFields)
    }

    override func makeCellView(for tableColumn: NSTableColumn, item: RunningApplication) -> NSView? {
        if let sharedView = makeSharedCellView(columnIdentifier: tableColumn.identifier.rawValue, item: item) {
            return sharedView
        }
        guard let column = Column(rawValue: tableColumn.identifier.rawValue) else { return nil }
        switch column {
        case .bundleIdentifier:
            let cell = tableView.box.makeView(ofClass: BundleIdentifierTableCellView.self)
            cell.string = item.bundleIdentifier
            return cell
        case .sandboxed:
            return makeSandboxedCellView(isSandboxed: item.isSandboxed, isLoading: !item.isSandboxResolved)
        default:
            return nil
        }
    }

    override func fieldValue(_ fieldIdentifier: String, for item: RunningApplication) -> String? {
        if fieldIdentifier == Column.bundleIdentifier.rawValue {
            return item.bundleIdentifier
        }
        return super.fieldValue(fieldIdentifier, for: item)
    }

    override func compareItems(_ lhs: RunningApplication, _ rhs: RunningApplication, columnIdentifier: String) -> ComparisonResult {
        if let sharedResult = compareSharedItems(lhs, rhs, columnIdentifier: columnIdentifier) {
            return sharedResult
        }
        guard let column = Column(rawValue: columnIdentifier) else { return .orderedSame }
        switch column {
        case .bundleIdentifier:
            return (lhs.bundleIdentifier ?? "").localizedCaseInsensitiveCompare(rhs.bundleIdentifier ?? "")
        default:
            return .orderedSame
        }
    }

    override func contextMenuItems(for item: RunningApplication) -> [NSMenuItem] {
        var items: [NSMenuItem] = [makeCopyPIDMenuItem(for: item)]

        if item.bundleIdentifier != nil {
            let copyBundleID = NSMenuItem(title: "Copy Bundle ID", action: #selector(copyBundleIDAction(_:)), keyEquivalent: "")
            copyBundleID.target = self
            copyBundleID.representedObject = item
            items.append(copyBundleID)
        }

        if item.bundleURL != nil {
            items.append(.separator())
            let showInFinder = NSMenuItem(title: "Show in Finder", action: #selector(showInFinderAction(_:)), keyEquivalent: "")
            showInFinder.target = self
            showInFinder.representedObject = item
            items.append(showInFinder)
        }
        return items
    }

    override func didCancel() {
        delegate?.runningApplicationPickerViewControllerWasCancelled(self)
    }

    override func didConfirm(item: RunningApplication) {
        delegate?.runningApplicationPickerViewController(self, didConfirmApplication: item)
    }

    override func didSelect(item: RunningApplication) {
        delegate?.runningApplicationPickerViewController(self, didSelectApplication: item)
    }

    override func shouldSelect(item: RunningApplication) -> Bool {
        delegate?.runningApplicationPickerViewController(self, shouldSelectApplication: item) ?? true
    }

    // MARK: - Prefetch & Background Refresh

    /// Start application enumeration early, before the view is loaded.
    /// Called by the parent tab view controller so data is ready when viewDidLoad runs.
    func prefetch() {
        refreshInBackground(animatingDifferences: false)
    }

    private func refreshInBackground(animatingDifferences: Bool) {
        // NSRunningApplication.icon / bundleURL / executableURL all hit LaunchServices via XPC
        // and can cost tens of milliseconds per call (icon alone is ~36ms across a typical app list).
        // Snapshot the running-app array on the main thread, then build RunningApplication values off-thread.
        let snapshot = workspace.runningApplications.filter { $0.processIdentifier > 0 }
        let knownPIDs = Set(applicationCache.keys)

        // NSRunningApplication is documented as thread-safe for property access, but is not Sendable under
        // Swift 6 strict concurrency. The unchecked box crosses the isolation boundary deliberately.
        let box = UncheckedSendableBox(value: snapshot)

        backgroundQueue.async { [weak self] in
            let runningApps = box.value
            let orderedPIDs = runningApps.map(\.processIdentifier)
            let currentPIDs = Set(orderedPIDs)
            let addedPIDs = currentPIDs.subtracting(knownPIDs)
            let removedPIDs = knownPIDs.subtracting(currentPIDs)

            let newApplications: [RunningApplication] = runningApps
                .filter { addedPIDs.contains($0.processIdentifier) }
                .map { RunningApplication(from: $0, resolveSandbox: false) }

            DispatchQueue.main.async {
                guard let self else { return }

                for pid in removedPIDs {
                    self.applicationCache.removeValue(forKey: pid)
                }
                for application in newApplications {
                    self.applicationCache[application.processIdentifier] = application
                }
                self.cachedItemPIDs = orderedPIDs

                let orderedItems = orderedPIDs.compactMap { self.applicationCache[$0] }
                self.updateItems(orderedItems, animatingDifferences: animatingDifferences)

                if !newApplications.isEmpty {
                    self.resolveSandboxStatusAsync(for: newApplications)
                }
            }
        }
    }

    // MARK: - Sandbox Resolution

    private func resolveSandboxStatusAsync(for applications: [RunningApplication]) {
        let pids = applications.map(\.processIdentifier)
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            var sandboxResults: [pid_t: Bool] = [:]
            for pid in pids {
                sandboxResults[pid] = BSDProcess.isSandboxed(pid: pid)
            }
            DispatchQueue.main.async {
                guard let self else { return }
                for (processIdentifier, isSandboxed) in sandboxResults {
                    if var application = self.applicationCache[processIdentifier] {
                        application.isSandboxed = isSandboxed
                        application.isSandboxResolved = true
                        self.applicationCache[processIdentifier] = application
                    }
                }
                let orderedItems = self.cachedItemPIDs.compactMap { self.applicationCache[$0] }
                self.updateItems(orderedItems, animatingDifferences: false)
            }
        }
    }

    // MARK: - Private

    private func setupObservation() {
        runningApplicationObservation = workspace.observe(\.runningApplications) { [weak self] _, _ in
            DispatchQueue.main.async {
                guard let self else { return }
                self.refreshInBackground(animatingDifferences: true)
            }
        }
    }

    @objc private func copyBundleIDAction(_ sender: NSMenuItem) {
        guard let item = sender.representedObject as? RunningApplication, let bundleID = item.bundleIdentifier else { return }
        copyToPasteboard(bundleID)
    }

    @objc private func showInFinderAction(_ sender: NSMenuItem) {
        guard let item = sender.representedObject as? RunningApplication, let bundleURL = item.bundleURL else { return }
        NSWorkspace.shared.activateFileViewerSelecting([bundleURL])
    }
}

@available(macOS 11.0, *)
extension RunningApplicationPickerViewController.Delegate {
    func runningApplicationPickerViewController(_ viewController: RunningApplicationPickerViewController, shouldSelectApplication application: RunningApplication) -> Bool { true }
    func runningApplicationPickerViewController(_ viewController: RunningApplicationPickerViewController, didSelectApplication application: RunningApplication) {}
    func runningApplicationPickerViewController(_ viewController: RunningApplicationPickerViewController, didConfirmApplication application: RunningApplication) {}
    func runningApplicationPickerViewControllerWasCancelled(_ viewController: RunningApplicationPickerViewController) {}
}

private struct UncheckedSendableBox<Value>: @unchecked Sendable {
    let value: Value
}

import SwiftUI

@available(macOS 14.0, *)
#Preview(traits: .fixedLayout(width: 800, height: 700)) {
    RunningApplicationPickerViewController()
}

#endif
