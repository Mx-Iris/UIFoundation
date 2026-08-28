//
//  RunningApplicationPickerDemoViewController.swift
//  UIFoundationExample-macOS
//
//  Demo for `RunningPickerTabViewController` from UIFoundationRunningApplication.
//

import AppKit
import UIFoundationRunningApplication

/// The running-application / process picker, with the two switches the original
/// package's own example app carried: skeleton vs. real content, and table vs. list.
///
/// Those four combinations are the manual half of this component's acceptance: the
/// geometry is pinned by tests, but whether a list row *reads* well — whether the badges
/// crowd the title, whether a long path truncates where it should — only a person can
/// judge. Keeping both switches side by side is what makes the comparison one click.
@available(macOS 11.0, *)
final class RunningApplicationPickerDemoViewController: NSViewController {
    private enum ContentMode: Int, CaseIterable {
        case skeleton
        case content

        var title: String {
            switch self {
            case .skeleton: "Skeleton"
            case .content: "Content"
            }
        }
    }

    private let picker = RunningPickerTabViewController()
    private let contentModeControl = NSSegmentedControl(
        labels: ContentMode.allCases.map(\.title),
        trackingMode: .selectOne,
        target: nil,
        action: nil
    )
    private let styleControl = NSSegmentedControl(
        labels: ["Table", "List"],
        trackingMode: .selectOne,
        target: nil,
        action: nil
    )
    private let selectionLabel = NSTextField(labelWithString: "Confirm a row to see it reported here.")

    override func loadView() {
        view = NSView()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        picker.delegate = self
        addChild(picker)

        contentModeControl.target = self
        contentModeControl.action = #selector(contentModeChanged(_:))
        contentModeControl.selectedSegment = ContentMode.content.rawValue

        styleControl.target = self
        styleControl.action = #selector(styleChanged(_:))
        styleControl.selectedSegment = 0

        selectionLabel.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        selectionLabel.textColor = .secondaryLabelColor
        selectionLabel.lineBreakMode = .byTruncatingTail
        // The browser window must stay shrinkable: a label that insists on its
        // single-line width becomes a hard floor for the whole window.
        selectionLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        let controlRow = NSStackView(views: [contentModeControl, styleControl])
        controlRow.orientation = .horizontal
        controlRow.spacing = 16

        let pickerView = picker.view
        // Same reason as the label: the picker asks for 800pt and would otherwise
        // dictate the browser window's minimum width.
        pickerView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        for subview in [controlRow, pickerView, selectionLabel] {
            subview.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(subview)
        }

        NSLayoutConstraint.activate([
            controlRow.topAnchor.constraint(equalTo: view.topAnchor),
            controlRow.centerXAnchor.constraint(equalTo: view.centerXAnchor),

            pickerView.topAnchor.constraint(equalTo: controlRow.bottomAnchor, constant: 8),
            pickerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            pickerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),

            selectionLabel.topAnchor.constraint(equalTo: pickerView.bottomAnchor, constant: 8),
            selectionLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            selectionLabel.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor),
            selectionLabel.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }

    @objc private func contentModeChanged(_ sender: NSSegmentedControl) {
        guard let mode = ContentMode(rawValue: sender.selectedSegment) else { return }
        picker.setSkeletonVisible(mode == .skeleton)
    }

    @objc private func styleChanged(_ sender: NSSegmentedControl) {
        picker.setStyle(sender.selectedSegment == 1 ? .list : .table)
    }

    private func report(_ text: String) {
        selectionLabel.stringValue = text
        selectionLabel.textColor = .labelColor
    }
}

// MARK: - RunningPickerTabViewController.Delegate

@available(macOS 11.0, *)
extension RunningApplicationPickerDemoViewController: RunningPickerTabViewController.Delegate {
    func runningPickerTabViewController(
        _ viewController: RunningPickerTabViewController,
        didConfirmApplication application: RunningApplication
    ) {
        report("""
        app  \(application.name)  ·  pid \(application.processIdentifier)  \
        ·  \(application.bundleIdentifier ?? "no bundle id")  \
        ·  \(application.architecture?.description ?? "unknown arch")  \
        ·  \(application.isSandboxed ? "sandboxed" : "not sandboxed")
        """)
    }

    func runningPickerTabViewController(
        _ viewController: RunningPickerTabViewController,
        didConfirmProcess process: RunningProcess
    ) {
        report("""
        proc \(process.name)  ·  pid \(process.processIdentifier)  \
        ·  \(process.platform?.description ?? "unknown platform")  \
        ·  \(process.executablePath ?? "no path")
        """)
    }

    func runningPickerTabViewControllerWasCancelled(_ viewController: RunningPickerTabViewController) {
        report("Cancelled.")
    }
}
