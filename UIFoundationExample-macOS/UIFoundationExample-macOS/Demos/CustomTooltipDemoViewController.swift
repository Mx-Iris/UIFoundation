//
//  CustomTooltipDemoViewController.swift
//  UIFoundationExample-macOS
//
//  Interactive playground for `CustomToolTipManager`.
//
//  Left column: live controls (color wells / sliders / popup) that build a
//  single `ToolTipStyle` and push it onto the right-column target view as a
//  per-view override. The target is hovered to display the actual system
//  tooltip rendered through the customized pipeline. A second "system control"
//  target is provided to visually compare with the unmodified system tooltip.
//
//  Two buttons at the bottom of the controls let you promote the playground
//  style to `CustomToolTipManager.shared.globalStyle` or reset everything
//  back to the unmodified system look.
//
//  Install is done once at app launch in AppDelegate.
//

import AppKit
import UIFoundation

final class CustomTooltipDemoViewController: NSViewController {

    // MARK: - Style state

    private var playgroundStyle: ToolTipStyle = .default {
        didSet { applyPlaygroundStyle() }
    }

    // MARK: - Controls

    private let fontSizeSlider = NSSlider(value: 12, minValue: 9, maxValue: 20, target: nil, action: nil)
    private let fontSizeValueField = NSTextField(labelWithString: "")

    private let fontWeightPopUp = NSPopUpButton(frame: .zero, pullsDown: false)

    private let textColorWell = NSColorWell()
    private let backgroundColorWell = NSColorWell()

    private let contentMarginWidthSlider = NSSlider(value: 8, minValue: 0, maxValue: 24, target: nil, action: nil)
    private let contentMarginHeightSlider = NSSlider(value: 4, minValue: 0, maxValue: 16, target: nil, action: nil)
    private let contentMarginValueField = NSTextField(labelWithString: "")

    private let yOffsetSlider = NSSlider(value: 18, minValue: 0, maxValue: 60, target: nil, action: nil)
    private let yOffsetValueField = NSTextField(labelWithString: "")

    private let cornerRadiusSlider = NSSlider(value: 6, minValue: 0, maxValue: 24, target: nil, action: nil)
    private let cornerRadiusValueField = NSTextField(labelWithString: "")

    private let borderWidthSlider = NSSlider(value: 1, minValue: 0, maxValue: 4, target: nil, action: nil)
    private let borderWidthValueField = NSTextField(labelWithString: "")
    private let borderColorWell = NSColorWell()

    private let shadowColorWell = NSColorWell()
    private let shadowOffsetXSlider = NSSlider(value: 0, minValue: -8, maxValue: 8, target: nil, action: nil)
    private let shadowOffsetYSlider = NSSlider(value: -1, minValue: -12, maxValue: 8, target: nil, action: nil)
    private let shadowOffsetValueField = NSTextField(labelWithString: "")
    private let shadowRadiusSlider = NSSlider(value: 3, minValue: 0, maxValue: 16, target: nil, action: nil)
    private let shadowRadiusValueField = NSTextField(labelWithString: "")

    private let initialDelayPopUp = NSPopUpButton(frame: .zero, pullsDown: false)

    private let tooltipStringField = NSTextField(string: "Playground tooltip — edit the controls on the left and hover the box on the right.")

    // MARK: - Hover targets

    private let playgroundTarget = LayerBackedView()
    private let systemTarget = LayerBackedView()

    // MARK: - Lifecycle

    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 880, height: 640))
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        buildUI()
        seedPlaygroundFromStyle()
        applyPlaygroundStyle()
    }

    // MARK: - UI construction

    private func buildUI() {
        let intro = makeIntro()
        let controls = makeControlsColumn()
        let targets = makeTargetsColumn()

        let split = NSStackView(views: [controls, targets])
        split.orientation = .horizontal
        split.spacing = 24
        split.alignment = .top
        split.distribution = .fill

        let outer = NSStackView(views: [intro, split])
        outer.orientation = .vertical
        outer.alignment = .leading
        outer.spacing = 18
        outer.edgeInsets = NSEdgeInsets(top: 20, left: 20, bottom: 20, right: 20)
        outer.translatesAutoresizingMaskIntoConstraints = false

        let scrollView = NSScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.drawsBackground = false
        scrollView.documentView = outer

        view.addSubview(scrollView)
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            outer.widthAnchor.constraint(equalTo: scrollView.contentView.widthAnchor),
        ])
    }

    private func makeIntro() -> NSView {
        let title = NSTextField(labelWithString: "Custom Tooltip Playground")
        title.font = .systemFont(ofSize: 20, weight: .semibold)

        let body = NSTextField(wrappingLabelWithString: """
        Edit the controls on the left to compose a `ToolTipStyle`, then hover the live target on the right to see the system tooltip rendered through `CustomToolTipManager`. The system control target keeps the unmodified style for comparison. "Promote to global" copies the current playground style onto `CustomToolTipManager.shared.globalStyle` so every tooltip in this window picks it up.
        """)
        body.font = .systemFont(ofSize: 12)
        body.textColor = .secondaryLabelColor
        body.preferredMaxLayoutWidth = 820

        let stack = NSStackView(views: [title, body])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 6
        return stack
    }

    private func makeControlsColumn() -> NSView {
        // Text
        let textSection = makeSection(title: "Text", controls: [
            makeRow(label: "Font size", control: fontSizeSlider, value: fontSizeValueField),
            makeRow(label: "Weight", control: fontWeightPopUp),
            makeRow(label: "Text color", control: textColorWell),
        ])

        // Background
        let backgroundSection = makeSection(title: "Background", controls: [
            makeRow(label: "Color", control: backgroundColorWell),
        ])

        // Geometry
        let geometrySection = makeSection(title: "Geometry", controls: [
            makeRow(label: "Margin W", control: contentMarginWidthSlider, value: contentMarginValueField),
            makeRow(label: "Margin H", control: contentMarginHeightSlider),
            makeRow(label: "Y offset", control: yOffsetSlider, value: yOffsetValueField),
            makeRow(label: "Initial delay", control: initialDelayPopUp),
        ])

        // Layer chrome
        let chromeSection = makeSection(title: "Corner / Border / Shadow", controls: [
            makeRow(label: "Corner radius", control: cornerRadiusSlider, value: cornerRadiusValueField),
            makeRow(label: "Border width", control: borderWidthSlider, value: borderWidthValueField),
            makeRow(label: "Border color", control: borderColorWell),
            makeRow(label: "Shadow color", control: shadowColorWell),
            makeRow(label: "Shadow X", control: shadowOffsetXSlider, value: shadowOffsetValueField),
            makeRow(label: "Shadow Y", control: shadowOffsetYSlider),
            makeRow(label: "Shadow radius", control: shadowRadiusSlider, value: shadowRadiusValueField),
        ])

        // Tooltip string + actions
        let stringLabel = NSTextField(labelWithString: "Tooltip text")
        stringLabel.font = .systemFont(ofSize: 11, weight: .medium)
        stringLabel.textColor = .secondaryLabelColor
        tooltipStringField.delegate = self
        tooltipStringField.translatesAutoresizingMaskIntoConstraints = false
        tooltipStringField.widthAnchor.constraint(greaterThanOrEqualToConstant: 320).isActive = true

        let stringSection = NSStackView(views: [stringLabel, tooltipStringField])
        stringSection.orientation = .vertical
        stringSection.alignment = .leading
        stringSection.spacing = 6

        let resetButton = NSButton(title: "Reset to .default", target: self, action: #selector(resetToDefault))
        resetButton.bezelStyle = .rounded

        let systemButton = NSButton(title: "Reset to .system", target: self, action: #selector(resetToSystem))
        systemButton.bezelStyle = .rounded

        let promoteButton = NSButton(title: "Promote to global", target: self, action: #selector(promoteToGlobal))
        promoteButton.bezelStyle = .rounded
        promoteButton.keyEquivalent = "\r"

        let demoteButton = NSButton(title: "Clear global", target: self, action: #selector(clearGlobal))
        demoteButton.bezelStyle = .rounded

        let actionRow1 = NSStackView(views: [resetButton, systemButton])
        actionRow1.orientation = .horizontal
        actionRow1.spacing = 8

        let actionRow2 = NSStackView(views: [promoteButton, demoteButton])
        actionRow2.orientation = .horizontal
        actionRow2.spacing = 8

        let stack = NSStackView(views: [
            textSection, backgroundSection, geometrySection, chromeSection,
            stringSection, actionRow1, actionRow2,
        ])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 14
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.widthAnchor.constraint(equalToConstant: 380).isActive = true

        configureFontWeightPopUp()
        configureInitialDelayPopUp()
        wireUpControls()

        return stack
    }

    private func makeTargetsColumn() -> NSView {
        configureHoverTarget(
            playgroundTarget,
            title: "Hover me",
            subtitle: "Uses the playground style via box.customTooltipStyle"
        )

        configureHoverTarget(
            systemTarget,
            title: "System control",
            subtitle: "Plain NSView.toolTip — no per-view override"
        )
        systemTarget.toolTip = "Unmodified system tooltip — used as a visual baseline."

        let stack = NSStackView(views: [
            sectionTitle("Live targets"),
            playgroundTarget,
            systemTarget,
        ])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 18
        return stack
    }

    private func configureHoverTarget(_ target: LayerBackedView, title: String, subtitle: String) {
        target.translatesAutoresizingMaskIntoConstraints = false
        target.cornerRadius = 12
        target.backgroundColor = .underPageBackgroundColor
        target.borderColor = .separatorColor
        target.borderPositions = .all
        target.borderWidth = 1

        let titleField = NSTextField(labelWithString: title)
        titleField.font = .systemFont(ofSize: 16, weight: .semibold)
        titleField.textColor = .labelColor

        let subtitleField = NSTextField(labelWithString: subtitle)
        subtitleField.font = .systemFont(ofSize: 11)
        subtitleField.textColor = .secondaryLabelColor

        let content = NSStackView(views: [titleField, subtitleField])
        content.orientation = .vertical
        content.alignment = .leading
        content.spacing = 4
        content.translatesAutoresizingMaskIntoConstraints = false
        target.addSubview(content)
        NSLayoutConstraint.activate([
            content.leadingAnchor.constraint(equalTo: target.leadingAnchor, constant: 18),
            content.trailingAnchor.constraint(equalTo: target.trailingAnchor, constant: -18),
            content.topAnchor.constraint(equalTo: target.topAnchor, constant: 18),
            content.bottomAnchor.constraint(equalTo: target.bottomAnchor, constant: -18),
            target.widthAnchor.constraint(greaterThanOrEqualToConstant: 320),
        ])
    }

    private func makeSection(title: String, controls: [NSView]) -> NSView {
        let header = sectionTitle(title)
        let stack = NSStackView(views: [header] + controls)
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 6
        return stack
    }

    private func sectionTitle(_ text: String) -> NSTextField {
        let field = NSTextField(labelWithString: text)
        field.font = .systemFont(ofSize: 11, weight: .semibold)
        field.textColor = .secondaryLabelColor
        return field
    }

    private func makeRow(label: String, control: NSView, value: NSView? = nil) -> NSView {
        let labelField = NSTextField(labelWithString: label)
        labelField.font = .systemFont(ofSize: 11)
        labelField.textColor = .labelColor
        labelField.translatesAutoresizingMaskIntoConstraints = false
        labelField.widthAnchor.constraint(equalToConstant: 96).isActive = true
        labelField.alignment = .right

        control.translatesAutoresizingMaskIntoConstraints = false
        if control is NSSlider {
            control.widthAnchor.constraint(equalToConstant: 180).isActive = true
        } else if control is NSPopUpButton {
            control.widthAnchor.constraint(greaterThanOrEqualToConstant: 180).isActive = true
        } else if control is NSColorWell {
            control.widthAnchor.constraint(equalToConstant: 50).isActive = true
            control.heightAnchor.constraint(equalToConstant: 22).isActive = true
        }

        var views: [NSView] = [labelField, control]
        if let value = value {
            value.translatesAutoresizingMaskIntoConstraints = false
            if let valueLabel = value as? NSTextField {
                valueLabel.font = .monospacedDigitSystemFont(ofSize: 11, weight: .regular)
                valueLabel.textColor = .secondaryLabelColor
            }
            views.append(value)
        }

        let row = NSStackView(views: views)
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 8
        return row
    }

    // MARK: - Control wiring

    private func configureFontWeightPopUp() {
        fontWeightPopUp.removeAllItems()
        fontWeightPopUp.addItems(withTitles: ["Regular", "Medium", "Semibold", "Bold"])
        fontWeightPopUp.target = self
        fontWeightPopUp.action = #selector(controlChanged)
    }

    private func configureInitialDelayPopUp() {
        initialDelayPopUp.removeAllItems()
        initialDelayPopUp.addItems(withTitles: ["System default", "0.1 s", "0.3 s", "0.5 s", "1.0 s", "2.0 s"])
        initialDelayPopUp.target = self
        initialDelayPopUp.action = #selector(controlChanged)
    }

    private func wireUpControls() {
        let sliders: [NSSlider] = [
            fontSizeSlider,
            contentMarginWidthSlider, contentMarginHeightSlider,
            yOffsetSlider,
            cornerRadiusSlider,
            borderWidthSlider,
            shadowOffsetXSlider, shadowOffsetYSlider, shadowRadiusSlider,
        ]
        for slider in sliders {
            slider.isContinuous = true
            slider.target = self
            slider.action = #selector(controlChanged)
        }
        let colorWells: [NSColorWell] = [
            textColorWell, backgroundColorWell, borderColorWell, shadowColorWell,
        ]
        for well in colorWells {
            well.target = self
            well.action = #selector(controlChanged)
        }
    }

    /// Pushes the current `playgroundStyle` defaults into every control so the
    /// UI starts in sync with `.default`.
    private func seedPlaygroundFromStyle() {
        let style = playgroundStyle
        fontSizeSlider.doubleValue = Double(style.font?.pointSize ?? 12)
        fontWeightPopUp.selectItem(at: 0)
        textColorWell.color = style.textColor ?? .labelColor
        backgroundColorWell.color = style.backgroundColor ?? .controlBackgroundColor
        contentMarginWidthSlider.doubleValue = Double(style.contentMargin?.width ?? 8)
        contentMarginHeightSlider.doubleValue = Double(style.contentMargin?.height ?? 4)
        yOffsetSlider.doubleValue = Double(style.yOffsetFromCursor ?? 18)
        cornerRadiusSlider.doubleValue = Double(style.cornerRadius ?? 6)
        borderWidthSlider.doubleValue = Double(style.borderWidth ?? 1)
        borderColorWell.color = style.borderColor ?? .separatorColor
        shadowColorWell.color = style.shadowColor ?? NSColor.black.withAlphaComponent(0.18)
        shadowOffsetXSlider.doubleValue = Double(style.shadowOffset?.width ?? 0)
        shadowOffsetYSlider.doubleValue = Double(style.shadowOffset?.height ?? -1)
        shadowRadiusSlider.doubleValue = Double(style.shadowRadius ?? 3)
        initialDelayPopUp.selectItem(at: 0)
        tooltipStringField.stringValue = "Playground tooltip — edit the controls on the left and hover the box on the right."
    }

    @objc private func controlChanged() {
        rebuildPlaygroundStyleFromControls()
    }

    private func rebuildPlaygroundStyleFromControls() {
        let weight: NSFont.Weight
        switch fontWeightPopUp.indexOfSelectedItem {
        case 1: weight = .medium
        case 2: weight = .semibold
        case 3: weight = .bold
        default: weight = .regular
        }
        let font = NSFont.systemFont(ofSize: CGFloat(fontSizeSlider.doubleValue), weight: weight)

        let initialDelay: TimeInterval?
        switch initialDelayPopUp.indexOfSelectedItem {
        case 1: initialDelay = 0.1
        case 2: initialDelay = 0.3
        case 3: initialDelay = 0.5
        case 4: initialDelay = 1.0
        case 5: initialDelay = 2.0
        default: initialDelay = nil
        }

        playgroundStyle = ToolTipStyle(
            font: font,
            textColor: textColorWell.color,
            backgroundColor: backgroundColorWell.color,
            contentMargin: CGSize(
                width: CGFloat(contentMarginWidthSlider.doubleValue),
                height: CGFloat(contentMarginHeightSlider.doubleValue)
            ),
            yOffsetFromCursor: CGFloat(yOffsetSlider.doubleValue),
            initialDelay: initialDelay,
            cornerRadius: CGFloat(cornerRadiusSlider.doubleValue),
            borderColor: borderColorWell.color,
            borderWidth: CGFloat(borderWidthSlider.doubleValue),
            shadowColor: shadowColorWell.color,
            shadowOffset: CGSize(
                width: CGFloat(shadowOffsetXSlider.doubleValue),
                height: CGFloat(shadowOffsetYSlider.doubleValue)
            ),
            shadowRadius: CGFloat(shadowRadiusSlider.doubleValue)
        )
    }

    private func applyPlaygroundStyle() {
        playgroundTarget.toolTip = tooltipStringField.stringValue
        playgroundTarget.box.customTooltipStyle = playgroundStyle

        // Reflect numeric values for sliders inline.
        fontSizeValueField.stringValue = String(format: "%.0f pt", fontSizeSlider.doubleValue)
        contentMarginValueField.stringValue = String(
            format: "%.0f × %.0f",
            contentMarginWidthSlider.doubleValue,
            contentMarginHeightSlider.doubleValue
        )
        yOffsetValueField.stringValue = String(format: "%.0f pt", yOffsetSlider.doubleValue)
        cornerRadiusValueField.stringValue = String(format: "%.0f pt", cornerRadiusSlider.doubleValue)
        borderWidthValueField.stringValue = String(format: "%.1f pt", borderWidthSlider.doubleValue)
        shadowOffsetValueField.stringValue = String(
            format: "(%.0f, %.0f)",
            shadowOffsetXSlider.doubleValue,
            shadowOffsetYSlider.doubleValue
        )
        shadowRadiusValueField.stringValue = String(format: "%.0f pt", shadowRadiusSlider.doubleValue)
    }

    // MARK: - Actions

    @objc private func resetToDefault() {
        playgroundStyle = .default
        seedPlaygroundFromStyle()
        applyPlaygroundStyle()
    }

    @objc private func resetToSystem() {
        playgroundStyle = .system
        // Re-sync controls to whatever a "blank" style maps to, but keep current
        // text so users can still hover and see the system tooltip render.
        textColorWell.color = .labelColor
        backgroundColorWell.color = .controlBackgroundColor
        contentMarginWidthSlider.doubleValue = 6
        contentMarginHeightSlider.doubleValue = 2
        yOffsetSlider.doubleValue = 18
        cornerRadiusSlider.doubleValue = 0
        borderWidthSlider.doubleValue = 0
        borderColorWell.color = .separatorColor
        shadowColorWell.color = .clear
        shadowOffsetXSlider.doubleValue = 0
        shadowOffsetYSlider.doubleValue = 0
        shadowRadiusSlider.doubleValue = 0
        initialDelayPopUp.selectItem(at: 0)
        // Clear the per-view override and the global so the target falls back
        // to fully system behaviour.
        playgroundTarget.box.customTooltipStyle = nil
        CustomToolTipManager.shared.globalStyle = .system
    }

    @objc private func promoteToGlobal() {
        CustomToolTipManager.shared.globalStyle = playgroundStyle
    }

    @objc private func clearGlobal() {
        CustomToolTipManager.shared.globalStyle = .system
    }
}

// MARK: - NSTextFieldDelegate

extension CustomTooltipDemoViewController: NSTextFieldDelegate {
    func controlTextDidChange(_ notification: Notification) {
        guard notification.object as AnyObject === tooltipStringField else { return }
        playgroundTarget.toolTip = tooltipStringField.stringValue
    }
}
