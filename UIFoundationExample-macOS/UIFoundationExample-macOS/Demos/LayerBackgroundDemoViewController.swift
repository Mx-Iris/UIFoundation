//
//  LayerBackgroundDemoViewController.swift
//  UIFoundationExample-macOS
//
//  Showcases the layer-background pipeline two ways:
//
//  1. `LayerBackedView` used directly — top row of preset cards.
//  2. `NSTableCellView` composed with `LayerBackgroundProviding` — the table
//     below. The cell declares no renderer of its own; the protocol's
//     `@AssociatedObject` storage installs one on first access.
//

import AppKit
import UIFoundation

final class LayerBackgroundDemoViewController: NSViewController {
    private struct DemoItem {
        let title: String
        let subtitle: String
        let accent: NSColor
    }

    private let items: [DemoItem] = [
        .init(title: "Engineering", subtitle: "Swift, AppKit, kernel",     accent: .systemBlue),
        .init(title: "Design",      subtitle: "HIG, motion, illustration", accent: .systemPink),
        .init(title: "Marketing",   subtitle: "Brand, campaigns, web",     accent: .systemOrange),
        .init(title: "Operations",  subtitle: "Logistics, supply chain",   accent: .systemGreen),
        .init(title: "Customer",    subtitle: "Support, success, advocacy", accent: .systemPurple),
        .init(title: "Finance",     subtitle: "Reporting, treasury, FP&A", accent: .systemTeal),
    ]

    private let tableView = NSTableView()

    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 760, height: 620))
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        buildUI()
    }

    private func buildUI() {
        // --- Section 1: LayerBackedView samples ---

        let topHeader = sectionHeader("LayerBackedView — direct subclass usage")
        let sampleRow = NSStackView(views: [
            makeSample(title: "Rounded fill", configure: { card in
                card.cornerRadius = 12
                card.backgroundColor = .systemBlue
            }),
            makeSample(title: "Inside border", configure: { card in
                card.cornerRadius = 8
                card.backgroundColor = .controlBackgroundColor
                card.borderPositions = .all
                card.borderColor = .separatorColor
                card.borderWidth = 1
                card.borderLocation = .inside
            }),
            makeSample(title: "Drop shadow", configure: { card in
                card.cornerRadius = 10
                card.backgroundColor = .controlBackgroundColor
                card.shadowColor = NSColor.black.withAlphaComponent(0.4)
                card.shadowOffset = NSSize(width: 0, height: -2)
                card.shadowRadius = 6
                card.shadowOpacity = 1
            }),
            makeSample(title: "Top/bottom only", configure: { card in
                card.backgroundColor = .controlBackgroundColor
                card.borderPositions = [.top, .bottom]
                card.borderColor = .systemRed
                card.borderWidth = 2
            }),
        ])
        sampleRow.orientation = .horizontal
        sampleRow.distribution = .fillEqually
        sampleRow.spacing = 16
        sampleRow.translatesAutoresizingMaskIntoConstraints = false

        // --- Section 2: LayerBackgroundProviding cell in NSTableView ---

        let tableHeader = sectionHeader("NSTableCellView + LayerBackgroundProviding — composition")

        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.rowHeight = 64
        tableView.headerView = nil
        tableView.style = .plain
        tableView.intercellSpacing = NSSize(width: 0, height: 10)
        tableView.backgroundColor = .clear
        tableView.selectionHighlightStyle = .regular
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("card"))
        column.width = 600
        tableView.addTableColumn(column)
        tableView.delegate = self
        tableView.dataSource = self

        let scrollView = NSScrollView()
        scrollView.documentView = tableView
        scrollView.hasVerticalScroller = true
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false

        topHeader.translatesAutoresizingMaskIntoConstraints = false
        tableHeader.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(topHeader)
        view.addSubview(sampleRow)
        view.addSubview(tableHeader)
        view.addSubview(scrollView)

        NSLayoutConstraint.activate([
            topHeader.topAnchor.constraint(equalTo: view.topAnchor, constant: 16),
            topHeader.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            topHeader.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -16),

            sampleRow.topAnchor.constraint(equalTo: topHeader.bottomAnchor, constant: 10),
            sampleRow.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            sampleRow.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            sampleRow.heightAnchor.constraint(equalToConstant: 88),

            tableHeader.topAnchor.constraint(equalTo: sampleRow.bottomAnchor, constant: 24),
            tableHeader.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            tableHeader.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -16),

            scrollView.topAnchor.constraint(equalTo: tableHeader.bottomAnchor, constant: 8),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -16),
        ])
    }

    private func sectionHeader(_ title: String) -> NSTextField {
        let label = NSTextField(labelWithString: title)
        label.font = .systemFont(ofSize: 13, weight: .semibold)
        label.textColor = .secondaryLabelColor
        return label
    }

    private func makeSample(title: String, configure: (LayerBackedView) -> Void) -> NSView {
        let container = NSStackView()
        container.orientation = .vertical
        container.spacing = 6
        container.alignment = .leading
        container.distribution = .fill

        let card = LayerBackedView()
        configure(card)
        card.translatesAutoresizingMaskIntoConstraints = false

        let titleLabel = NSTextField(labelWithString: title)
        titleLabel.font = .systemFont(ofSize: 11)
        titleLabel.textColor = .tertiaryLabelColor

        container.addArrangedSubview(card)
        container.addArrangedSubview(titleLabel)

        NSLayoutConstraint.activate([
            card.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            card.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            card.heightAnchor.constraint(equalToConstant: 64),
        ])

        return container
    }
}

extension LayerBackgroundDemoViewController: NSTableViewDataSource, NSTableViewDelegate {
    func numberOfRows(in tableView: NSTableView) -> Int {
        items.count
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let identifier = NSUserInterfaceItemIdentifier("LayerBackgroundCell")
        let cell: LayerBackgroundCell = tableView.box.makeView(identifier: identifier) {
            let cell = LayerBackgroundCell()
            cell.identifier = identifier
            return cell
        }
        let item = items[row]
        cell.configure(title: item.title, subtitle: item.subtitle, accent: item.accent)
        return cell
    }

    func tableView(_ tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView? {
        // Suppress the default blue highlight; the cell renders its own selected state.
        let rowView = NSTableRowView()
        rowView.isEmphasized = false
        return rowView
    }
}

// MARK: - LayerBackgroundCell

/// Composition example: an `NSTableCellView` that opts into the layer-background
/// pipeline purely via protocol conformance. Note there is no `let
/// backgroundRenderer = …` — the renderer lives in associated-object storage.
final class LayerBackgroundCell: NSTableCellView, LayerBackgroundProviding {
    private let accentBadge = LayerBackedView()
    private let titleLabel = NSTextField(labelWithString: "")
    private let subtitleLabel = NSTextField(labelWithString: "")

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        commonInit()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    private func commonInit() {
        attachToSelfIfNeeded()

        cornerRadius = 10
        backgroundColor = .controlBackgroundColor
        borderPositions = .all
        borderColor = .separatorColor
        borderWidth = 1
        borderLocation = .inside

        accentBadge.cornerRadius = 6
        accentBadge.translatesAutoresizingMaskIntoConstraints = false
        addSubview(accentBadge)

        titleLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(titleLabel)

        subtitleLabel.font = .systemFont(ofSize: 11)
        subtitleLabel.textColor = .secondaryLabelColor
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(subtitleLabel)

        NSLayoutConstraint.activate([
            accentBadge.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            accentBadge.centerYAnchor.constraint(equalTo: centerYAnchor),
            accentBadge.widthAnchor.constraint(equalToConstant: 36),
            accentBadge.heightAnchor.constraint(equalToConstant: 36),

            titleLabel.leadingAnchor.constraint(equalTo: accentBadge.trailingAnchor, constant: 12),
            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),

            subtitleLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 2),
            subtitleLabel.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),
        ])
    }

    func configure(title: String, subtitle: String, accent: NSColor) {
        titleLabel.stringValue = title
        subtitleLabel.stringValue = subtitle
        accentBadge.backgroundColor = accent
    }

    override var backgroundStyle: NSView.BackgroundStyle {
        didSet {
            switch backgroundStyle {
            case .emphasized:
                backgroundColor = .selectedContentBackgroundColor
                borderColor = .selectedContentBackgroundColor
                titleLabel.textColor = .alternateSelectedControlTextColor
                subtitleLabel.textColor = NSColor.alternateSelectedControlTextColor.withAlphaComponent(0.8)
            default:
                backgroundColor = .controlBackgroundColor
                borderColor = .separatorColor
                titleLabel.textColor = .labelColor
                subtitleLabel.textColor = .secondaryLabelColor
            }
        }
    }

    override var wantsUpdateLayer: Bool { true }

    override func updateLayer() {
        super.updateLayer()
        updateLayerBackgroundIfNeeded()
    }

    override func layout() {
        super.layout()
        layoutLayerBackgroundIfNeeded()
    }
}
