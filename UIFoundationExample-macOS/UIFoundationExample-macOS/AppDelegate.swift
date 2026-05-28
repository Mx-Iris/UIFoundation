//
//  AppDelegate.swift
//  UIFoundationExample-macOS
//
//  Created by JH on 2023/11/5.
//

import Cocoa
import UIFoundation

final class C: Control {}


@main
class AppDelegate: NSObject, NSApplicationDelegate {

    var textFinderDemoWindow: NSWindow?
    var insetsLabelDemoWindow: NSWindow?
    var layerBackgroundDemoWindow: NSWindow?

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        if #available(macOS 12.0, *) {
            showTextFinderDemo()
        }
        showInsetsLabelDemo()
        showLayerBackgroundDemo()
    }

    @available(macOS 12.0, *)
    private func showTextFinderDemo() {
        let viewController = TextFinderDemoViewController()
        let window = NSWindow(contentViewController: viewController)
        window.title = "TextFinder Demo — Cmd+F to search"
        window.setContentSize(NSSize(width: 600, height: 450))
        window.center()
        window.makeKeyAndOrderFront(nil)
        textFinderDemoWindow = window
    }

    private func showInsetsLabelDemo() {
        let viewController = InsetsLabelDemoViewController()
        let window = NSWindow(contentViewController: viewController)
        window.title = "InsetsTextFieldCell / RoundedBorderLabel Demo"
        window.setContentSize(NSSize(width: 720, height: 560))
        window.center()
        window.makeKeyAndOrderFront(nil)
        insetsLabelDemoWindow = window
    }

    private func showLayerBackgroundDemo() {
        let viewController = LayerBackgroundDemoViewController()
        let window = NSWindow(contentViewController: viewController)
        window.title = "LayerBackgroundRenderer / LayerBackgroundProviding Demo"
        window.setContentSize(NSSize(width: 760, height: 620))
        window.center()
        window.makeKeyAndOrderFront(nil)
        layerBackgroundDemoWindow = window
    }

    func applicationWillTerminate(_ aNotification: Notification) {}

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }
}

// MARK: - InsetsLabelDemoViewController

/// Tests that InsetsTextFieldCell no longer triggers NSTextField's
/// `_cellOverridesDrawingMethods` flag, and that RoundedBorderLabel renders
/// correctly. Also verifies the double-inset bug is fixed.
final class InsetsLabelDemoViewController: NSViewController {

    private let consoleTextView = NSTextView()

    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 720, height: 560))
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        buildUI()
        runDiagnostics()
    }

    // MARK: UI

    private func buildUI() {
        // Stack for visual samples (top half)
        let sampleStack = NSStackView()
        sampleStack.orientation = .vertical
        sampleStack.alignment = .leading
        sampleStack.spacing = 14
        sampleStack.translatesAutoresizingMaskIntoConstraints = false

        // 1. Plain Label with different insets (verifies double-inset fix)
        sampleStack.addArrangedSubview(sectionHeader("Label + contentInsets (single vs double inset test)"))

        let insets0 = makeInsetsLabel(text: "insets = 0", insets: .init(top: 0, left: 0, bottom: 0, right: 0))
        let insets10 = makeInsetsLabel(text: "insets = 10", insets: .init(top: 10, left: 10, bottom: 10, right: 10))
        let insetsAsym = makeInsetsLabel(text: "insets = (t:4 l:20 b:4 r:20)", insets: .init(top: 4, left: 20, bottom: 4, right: 20))
        sampleStack.addArrangedSubview(row([insets0, insets10, insetsAsym]))

        // 2. RoundedBorderLabel with different styling
        sampleStack.addArrangedSubview(sectionHeader("RoundedBorderLabel"))

        let pill1 = makeRoundedLabel(text: "  Hello  ", borderColor: .systemBlue, borderWidth: 1)
        let pill2 = makeRoundedLabel(text: "  Warning  ", borderColor: .systemOrange, borderWidth: 2)
        let pill3 = makeRoundedLabel(text: "  Error  ", borderColor: .systemRed, borderWidth: 3)
        sampleStack.addArrangedSubview(row([pill1, pill2, pill3]))

        // 3. Diagnostics console
        sampleStack.addArrangedSubview(sectionHeader("Runtime Diagnostics"))

        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.borderType = .bezelBorder
        scrollView.translatesAutoresizingMaskIntoConstraints = false

        consoleTextView.isEditable = false
        consoleTextView.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        consoleTextView.autoresizingMask = [.width]
        consoleTextView.textContainer?.widthTracksTextView = true
        scrollView.documentView = consoleTextView

        view.addSubview(sampleStack)
        view.addSubview(scrollView)

        NSLayoutConstraint.activate([
            sampleStack.topAnchor.constraint(equalTo: view.topAnchor, constant: 16),
            sampleStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            sampleStack.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -16),

            scrollView.topAnchor.constraint(equalTo: sampleStack.bottomAnchor, constant: 12),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -16),
            scrollView.heightAnchor.constraint(greaterThanOrEqualToConstant: 220),
        ])
    }

    private func sectionHeader(_ title: String) -> NSTextField {
        let label = NSTextField(labelWithString: title)
        label.font = .systemFont(ofSize: 13, weight: .semibold)
        label.textColor = .secondaryLabelColor
        return label
    }

    private func row(_ subviews: [NSView]) -> NSStackView {
        let stack = NSStackView(views: subviews)
        stack.orientation = .horizontal
        stack.spacing = 12
        stack.alignment = .centerY
        return stack
    }

    private func makeInsetsLabel(text: String, insets: NSEdgeInsets) -> InsetsTextField {
        let label = Label()
        label.stringValue = text
        label.contentInsets = insets
        label.wantsLayer = true
        // Visualize the frame with a subtle gray background on the layer
        label.layer?.backgroundColor = NSColor.quaternaryLabelColor.cgColor
        label.layer?.cornerRadius = 4
        return label
    }

    private func makeRoundedLabel(text: String, borderColor: NSColor, borderWidth: CGFloat) -> RoundedBorderLabel {
        let label = RoundedBorderLabel()
        label.stringValue = text
        label.borderColor = borderColor
        label.borderWidth = borderWidth
        label.contentInsets = NSEdgeInsets(top: 6, left: 14, bottom: 6, right: 14)
        return label
    }

    // MARK: Diagnostics

    private func runDiagnostics() {
        var lines: [String] = []

        lines.append("=== InsetsTextFieldCell override detection ===")
        lines.append(diagnoseCellOverrides(InsetsTextFieldCell.self))
        lines.append(diagnoseCellOverrides(LabelCell.self))

        lines.append("")
        lines.append("=== View subclass drawRect: override detection ===")
        lines.append(diagnoseViewDrawOverride(Label.self))
        lines.append(diagnoseViewDrawOverride(RoundedBorderLabel.self))

        lines.append("")
        lines.append("=== wantsUpdateLayer at runtime ===")

        let plainTextField = NSTextField(labelWithString: "plain NSTextField")
        let plainLabel = Label()
        plainLabel.stringValue = "UIFoundation Label"
        let roundedLabel = RoundedBorderLabel()
        roundedLabel.stringValue = "RoundedBorderLabel"
        roundedLabel.borderWidth = 1
        roundedLabel.borderColor = .systemBlue

        // Force view tree / layer creation
        let host = NSView(frame: NSRect(x: 0, y: 0, width: 400, height: 200))
        host.wantsLayer = true
        host.addSubview(plainTextField)
        host.addSubview(plainLabel)
        host.addSubview(roundedLabel)
        plainTextField.frame = NSRect(x: 10, y: 10, width: 200, height: 24)
        plainLabel.frame = NSRect(x: 10, y: 40, width: 200, height: 24)
        roundedLabel.frame = NSRect(x: 10, y: 70, width: 200, height: 24)
        _ = host.layer  // ensure layer-backed tree

        lines.append("  plain NSTextField.wantsUpdateLayer = \(plainTextField.wantsUpdateLayer)")
        lines.append("  Label.wantsUpdateLayer              = \(plainLabel.wantsUpdateLayer)")
        lines.append("  RoundedBorderLabel.wantsUpdateLayer = \(roundedLabel.wantsUpdateLayer)")

        lines.append("")
        lines.append("=== Double-inset regression check ===")
        lines.append(diagnoseInsetBehavior())

        lines.append("")
        lines.append("=== Cell drawingRect vs cellFrame ===")
        lines.append(diagnoseDrawingRect())

        let output = lines.joined(separator: "\n")
        consoleTextView.string = output
        // Mirror diagnostics to stderr (unbuffered) so it's visible
        // when the app is launched from a terminal and piped to a file.
        FileHandle.standardError.write(("\n" + output + "\n").data(using: .utf8) ?? Data())
    }

    private func diagnoseViewDrawOverride(_ viewClass: NSView.Type) -> String {
        let baseClass: AnyClass = NSTextField.self
        let drawRectSel = #selector(NSView.draw(_:))
        let baseDrawRect = class_getMethodImplementation(baseClass, drawRectSel)
        let subDrawRect = class_getMethodImplementation(viewClass, drawRectSel)
        let overrides = (subDrawRect != baseDrawRect)
        let name = NSStringFromClass(viewClass)
        return """
          \(name):
            draw(_:) overridden vs NSTextField = \(overrides)
            → _textFieldOverridesDrawingMethods would be = \(overrides ? "YES (forces drawRect path)" : "NO (allows updateLayer path)")
        """
    }

    private func diagnoseCellOverrides(_ cellClass: NSTextFieldCell.Type) -> String {
        // Replicate AppKit's `_NSSubclassOverridesSelector(NSTextFieldCell, cellClass, sel)` check.
        let baseClass: AnyClass = NSTextFieldCell.self
        let drawInteriorSel = #selector(NSTextFieldCell.drawInterior(withFrame:in:))
        let drawSel = #selector(NSTextFieldCell.draw(withFrame:in:))

        let baseDrawInterior = class_getMethodImplementation(baseClass, drawInteriorSel)
        let cellDrawInterior = class_getMethodImplementation(cellClass, drawInteriorSel)
        let baseDraw = class_getMethodImplementation(baseClass, drawSel)
        let cellDraw = class_getMethodImplementation(cellClass, drawSel)

        let overridesDrawInterior = (cellDrawInterior != baseDrawInterior)
        let overridesDraw = (cellDraw != baseDraw)
        let flagged = overridesDrawInterior || overridesDraw

        let name = NSStringFromClass(cellClass)
        return """
          \(name):
            drawInterior(withFrame:in:) overridden = \(overridesDrawInterior)
            draw(withFrame:in:)         overridden = \(overridesDraw)
            → _cellOverridesDrawingMethods would be = \(flagged ? "YES (forces drawRect path)" : "NO (allows updateLayer path)")
        """
    }

    private func diagnoseInsetBehavior() -> String {
        // Create an InsetsTextFieldCell with contentInsets = 10 and check
        // whether drawingRect inset is applied once, not twice.
        let cell = InsetsTextFieldCell(textCell: "test")
        cell.contentInsets = NSEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)
        let fullBounds = NSRect(x: 0, y: 0, width: 200, height: 50)
        let drawingRect = cell.drawingRect(forBounds: fullBounds)
        let expectedAfterOneInset = NSRect(x: 10, y: 10, width: 180, height: 30)

        // NSTextFieldCell's default drawingRect may not exactly equal our inset rect
        // because it also applies its own padding. The key sanity check is whether
        // our contentInsets are applied only once. We compare the diffs:
        //
        // Call super once manually to get the "no-inset" baseline:
        class PassthroughCell: NSTextFieldCell {
            override func drawingRect(forBounds rect: NSRect) -> NSRect {
                return super.drawingRect(forBounds: rect)
            }
        }
        let baseCell = PassthroughCell(textCell: "test")
        let baseRect = baseCell.drawingRect(forBounds: fullBounds)

        func insetRect(_ rect: NSRect, by insets: NSEdgeInsets) -> NSRect {
            NSRect(
                x: rect.origin.x + insets.left,
                y: rect.origin.y + insets.top,
                width: rect.size.width - insets.left - insets.right,
                height: rect.size.height - insets.top - insets.bottom
            )
        }

        // Single-inset expected: baseCell.drawingRect(forBounds: inset once)
        let insetOnce = insetRect(fullBounds, by: cell.contentInsets)
        let singleInsetExpected = baseCell.drawingRect(forBounds: insetOnce)

        // Double-inset hypothetical: baseCell.drawingRect(forBounds: inset twice)
        let insetTwice = insetRect(insetOnce, by: cell.contentInsets)
        let doubleInsetExpected = baseCell.drawingRect(forBounds: insetTwice)

        let singleMatch = NSEqualRects(drawingRect, singleInsetExpected)
        let doubleMatch = NSEqualRects(drawingRect, doubleInsetExpected)

        return """
          fullBounds                          = \(NSStringFromRect(fullBounds))
          baseline drawingRect (no insets)    = \(NSStringFromRect(baseRect))
          expected (after single inset)       = \(NSStringFromRect(singleInsetExpected))
          expected (after double inset)       = \(NSStringFromRect(doubleInsetExpected))
          actual InsetsTextFieldCell result   = \(NSStringFromRect(drawingRect))
          matches single-inset? \(singleMatch ? "YES ✓" : "NO")
          matches double-inset? \(doubleMatch ? "YES (BUG!)" : "NO ✓")
          (approx expected single after inset: \(NSStringFromRect(expectedAfterOneInset)))
        """
    }

    private func diagnoseDrawingRect() -> String {
        let cell = InsetsTextFieldCell(textCell: "sample")
        cell.contentInsets = NSEdgeInsets(top: 5, left: 15, bottom: 5, right: 15)
        let bounds = NSRect(x: 0, y: 0, width: 240, height: 40)
        let drawingRect = cell.drawingRect(forBounds: bounds)
        let titleRect = cell.titleRect(forBounds: bounds)
        let cellSize = cell.cellSize(forBounds: bounds)

        return """
          contentInsets       = (5, 15, 5, 15)
          bounds              = \(NSStringFromRect(bounds))
          drawingRect(bounds) = \(NSStringFromRect(drawingRect))
          titleRect(bounds)   = \(NSStringFromRect(titleRect))
          cellSize(bounds)    = \(NSStringFromSize(cellSize))
        """
    }
}

// MARK: - LayerBackgroundDemoViewController

/// Showcases the layer-background pipeline two ways:
///
/// 1. `LayerBackedView` used directly — top row of preset cards.
/// 2. `NSTableCellView` composed with `LayerBackgroundProviding` — the table
///    below. The cell declares no renderer of its own; the protocol's
///    `@AssociatedObject` storage installs one on first access.
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
        attachToSelf()

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
        updateLayerBackground()
    }

    override func layout() {
        super.layout()
        layoutLayerBackground()
    }
}
