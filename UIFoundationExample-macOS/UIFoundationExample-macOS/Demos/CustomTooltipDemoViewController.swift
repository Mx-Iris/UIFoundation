//
//  CustomTooltipDemoViewController.swift
//  UIFoundationExample-macOS
//
//  Demonstrates `CustomToolTipManager` from `UIFoundationAppleInternal`:
//
//  - A "global style" picker lets you swap between System / Default / Solid /
//    Rounded layer-backed presets. Changes apply to every tooltip in the app.
//  - Four labelled boxes hover-trigger tooltips. The right two also carry
//    per-view overrides via `view.box.customTooltipStyle`, layering on top of
//    the global style.
//
//  Install is done once at app launch in AppDelegate.
//

import AppKit
import UIFoundation

final class CustomTooltipDemoViewController: NSViewController {

    private struct StylePreset {
        let title: String
        let style: ToolTipStyle
    }

    private let presets: [StylePreset] = [
        .init(
            title: "System (untouched)",
            style: .system
        ),
        .init(
            title: "Default preset",
            style: .default
        ),
        .init(
            title: "Solid (no blur)",
            style: ToolTipStyle(
                font: .systemFont(ofSize: 13, weight: .medium),
                textColor: .white,
                backgroundColor: NSColor(calibratedRed: 0.13, green: 0.13, blue: 0.16, alpha: 1.0),
                contentMargin: CGSize(width: 10, height: 6),
                cornerRadius: 8,
                shadowColor: NSColor.black.withAlphaComponent(0.35),
                shadowOffset: CGSize(width: 0, height: -2),
                shadowRadius: 6
            )
        ),
        .init(
            title: "Rounded card",
            style: ToolTipStyle(
                font: .systemFont(ofSize: 12),
                textColor: .labelColor,
                backgroundColor: .windowBackgroundColor,
                contentMargin: CGSize(width: 12, height: 8),
                cornerRadius: 10,
                borderColor: .separatorColor,
                borderWidth: 1,
                shadowColor: NSColor.black.withAlphaComponent(0.22),
                shadowOffset: CGSize(width: 0, height: -2),
                shadowRadius: 5
            )
        ),
    ]

    private let stylePopUp = NSPopUpButton(frame: .zero, pullsDown: false)

    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 680, height: 460))
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        buildUI()
        applyPreset(at: 1) // start on Default
    }

    private func buildUI() {
        let intro = makeIntro()
        let controlRow = makeControlRow()
        let grid = makeSampleGrid()

        let stack = NSStackView(views: [intro, controlRow, grid])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 20
        stack.edgeInsets = NSEdgeInsets(top: 24, left: 24, bottom: 24, right: 24)
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: view.topAnchor),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: view.bottomAnchor),
        ])
    }

    private func makeIntro() -> NSView {
        let textField = NSTextField(wrappingLabelWithString: """
        Hover any of the boxes below to see their tooltip. The global style applies to every tooltip in the app — switch presets from the picker on the right. The two boxes on the right carry per-view overrides via `view.box.customTooltipStyle`.
        """)
        textField.font = .systemFont(ofSize: 12)
        textField.textColor = .secondaryLabelColor
        textField.preferredMaxLayoutWidth = 620
        return textField
    }

    private func makeControlRow() -> NSView {
        let label = NSTextField(labelWithString: "Global style:")
        label.font = .systemFont(ofSize: 12, weight: .medium)

        stylePopUp.removeAllItems()
        stylePopUp.addItems(withTitles: presets.map { $0.title })
        stylePopUp.target = self
        stylePopUp.action = #selector(stylePresetChanged(_:))

        let stack = NSStackView(views: [label, stylePopUp])
        stack.orientation = .horizontal
        stack.spacing = 8
        return stack
    }

    private func makeSampleGrid() -> NSView {
        let plainOne = makeHoverBox(
            title: "Plain",
            subtitle: "Inherits the global style",
            tooltip: "I follow the global style picker.",
            perViewStyle: nil
        )

        let plainTwo = makeHoverBox(
            title: "Long string",
            subtitle: "Multi-line wrap, also inherits global",
            tooltip: "This tooltip carries a longer string so you can see how `toolTipContentMargin` and font wrapping behave under the active global preset.",
            perViewStyle: nil
        )

        let overrideOne = makeHoverBox(
            title: "Override — warning",
            subtitle: "Per-view: amber background, white text",
            tooltip: "Per-view tooltip style overrides the global preset.",
            perViewStyle: ToolTipStyle(
                font: .systemFont(ofSize: 13, weight: .semibold),
                textColor: .white,
                backgroundColor: NSColor.systemOrange.withAlphaComponent(0.95),
                contentMargin: CGSize(width: 10, height: 6),
                cornerRadius: 8,
                shadowColor: NSColor.black.withAlphaComponent(0.3),
                shadowOffset: CGSize(width: 0, height: -2),
                shadowRadius: 4
            )
        )

        let overrideTwo = makeHoverBox(
            title: "Override — info",
            subtitle: "Per-view: blue, larger Y offset",
            tooltip: "Sits further below the cursor than the system default.",
            perViewStyle: ToolTipStyle(
                font: .systemFont(ofSize: 12, weight: .regular),
                textColor: .white,
                backgroundColor: NSColor.systemBlue.withAlphaComponent(0.95),
                contentMargin: CGSize(width: 12, height: 7),
                yOffsetFromCursor: 32,
                cornerRadius: 10,
                shadowColor: NSColor.black.withAlphaComponent(0.3),
                shadowOffset: CGSize(width: 0, height: -2),
                shadowRadius: 4
            )
        )

        let leftColumn = NSStackView(views: [plainOne, plainTwo])
        leftColumn.orientation = .vertical
        leftColumn.spacing = 16
        leftColumn.alignment = .leading

        let rightColumn = NSStackView(views: [overrideOne, overrideTwo])
        rightColumn.orientation = .vertical
        rightColumn.spacing = 16
        rightColumn.alignment = .leading

        let row = NSStackView(views: [leftColumn, rightColumn])
        row.orientation = .horizontal
        row.spacing = 24
        row.alignment = .top
        return row
    }

    private func makeHoverBox(
        title: String,
        subtitle: String,
        tooltip: String,
        perViewStyle: ToolTipStyle?
    ) -> NSView {
        let container = LayerBackedView()
        container.translatesAutoresizingMaskIntoConstraints = false
        container.cornerRadius = 10
        container.backgroundColor = .underPageBackgroundColor
        container.borderColor = .separatorColor
        container.borderPositions = .all
        container.borderWidth = 1

        let titleField = NSTextField(labelWithString: title)
        titleField.font = .systemFont(ofSize: 14, weight: .semibold)
        titleField.textColor = .labelColor

        let subtitleField = NSTextField(labelWithString: subtitle)
        subtitleField.font = .systemFont(ofSize: 11)
        subtitleField.textColor = .secondaryLabelColor

        let stack = NSStackView(views: [titleField, subtitleField])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 4
        stack.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 14),
            stack.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -14),
            stack.topAnchor.constraint(equalTo: container.topAnchor, constant: 12),
            stack.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -12),
            container.widthAnchor.constraint(greaterThanOrEqualToConstant: 240),
        ])

        container.toolTip = tooltip
        container.box.customTooltipStyle = perViewStyle
        return container
    }

    @objc private func stylePresetChanged(_ sender: NSPopUpButton) {
        applyPreset(at: sender.indexOfSelectedItem)
    }

    private func applyPreset(at index: Int) {
        guard presets.indices.contains(index) else { return }
        stylePopUp.selectItem(at: index)
        CustomToolTipManager.shared.globalStyle = presets[index].style
    }
}
