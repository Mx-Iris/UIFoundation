//
//  SystemHUDDemoViewController.swift
//  UIFoundationExample-macOS
//
//  Interactive playground for `SystemHUD`.
//
//  The controls on the left compose a `SystemHUD.Configuration`; "Show HUD"
//  pushes it onto a private `SystemHUD` instance and displays the panel below
//  the centre of the active screen. "Show twice quickly" fires a second show
//  while the first panel is still fading out, which is what exercises the
//  fade-interruption path.
//

import AppKit
import UIFoundation

final class SystemHUDDemoViewController: NSViewController {

    // MARK: - HUD

    /// A private instance rather than `SystemHUD.default`, so the playground cannot leave the
    /// shared HUD in a strange state for other demos.
    private let systemHUD = SystemHUD(configuration: .init(title: "Build Succeeded"))

    // MARK: - Controls

    private let titleTextField = NSTextField(string: "Build Succeeded")

    private let symbolPopUpButton = NSPopUpButton(frame: .zero, pullsDown: false)
    private let symbolPointSizeSlider = NSSlider(value: 80, minValue: 24, maxValue: 140, target: nil, action: nil)
    private let symbolPointSizeValueField = NSTextField(labelWithString: "")

    private let imageSpacingSlider = NSSlider(value: 15, minValue: 0, maxValue: 48, target: nil, action: nil)
    private let imageSpacingValueField = NSTextField(labelWithString: "")

    private let titleFontSizeSlider = NSSlider(value: 18, minValue: 10, maxValue: 40, target: nil, action: nil)
    private let titleFontSizeValueField = NSTextField(labelWithString: "")
    private let titleFontWeightPopUpButton = NSPopUpButton(frame: .zero, pullsDown: false)

    private let verticalOffsetSlider = NSSlider(value: 0, minValue: -60, maxValue: 60, target: nil, action: nil)
    private let verticalOffsetValueField = NSTextField(labelWithString: "")

    private let cornerRadiusSlider = NSSlider(value: 15, minValue: 0, maxValue: 60, target: nil, action: nil)
    private let cornerRadiusValueField = NSTextField(labelWithString: "")

    private let minimumSizeSlider = NSSlider(value: 200, minValue: 100, maxValue: 320, target: nil, action: nil)
    private let minimumSizeValueField = NSTextField(labelWithString: "")

    private let contentInsetSlider = NSSlider(value: 20, minValue: 0, maxValue: 60, target: nil, action: nil)
    private let contentInsetValueField = NSTextField(labelWithString: "")

    private let displayDelaySlider = NSSlider(value: 1.2, minValue: 0.2, maxValue: 4, target: nil, action: nil)
    private let displayDelayValueField = NSTextField(labelWithString: "")

    private let dismissDurationSlider = NSSlider(value: 1, minValue: 0.1, maxValue: 3, target: nil, action: nil)
    private let dismissDurationValueField = NSTextField(labelWithString: "")

    /// The SF Symbol behind each entry of ``symbolPopUpButton``; an empty name means "no image".
    private let symbolNames = [
        "checkmark.circle",
        "xmark.octagon",
        "speaker.wave.3.fill",
        "sun.max.fill",
        "hammer.fill",
        "",
    ]

    private let titleFontWeights: [(name: String, weight: NSFont.Weight)] = [
        ("Regular", .regular),
        ("Medium", .medium),
        ("Semibold", .semibold),
        ("Bold", .bold),
    ]

    // MARK: - Lifecycle

    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 720, height: 620))
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        buildUserInterface()
        reloadConfiguration()
    }

    // MARK: - User interface

    private func buildUserInterface() {
        let contentSection = makeSection(title: "Content", rows: [
            makeRow(label: "Title", control: titleTextField),
            makeRow(label: "Symbol", control: symbolPopUpButton),
            makeRow(label: "Symbol size", control: symbolPointSizeSlider, value: symbolPointSizeValueField),
            makeRow(label: "Image spacing", control: imageSpacingSlider, value: imageSpacingValueField),
            makeRow(label: "Title size", control: titleFontSizeSlider, value: titleFontSizeValueField),
            makeRow(label: "Title weight", control: titleFontWeightPopUpButton),
        ])

        let geometrySection = makeSection(title: "Geometry", rows: [
            makeRow(label: "Vertical offset", control: verticalOffsetSlider, value: verticalOffsetValueField),
            makeRow(label: "Corner radius", control: cornerRadiusSlider, value: cornerRadiusValueField),
            makeRow(label: "Minimum size", control: minimumSizeSlider, value: minimumSizeValueField),
            makeRow(label: "Content inset", control: contentInsetSlider, value: contentInsetValueField),
        ])

        let timingSection = makeSection(title: "Timing", rows: [
            makeRow(label: "Display delay", control: displayDelaySlider, value: displayDelayValueField),
            makeRow(label: "Fade duration", control: dismissDurationSlider, value: dismissDurationValueField),
        ])

        let showButton = NSButton(title: "Show HUD", target: self, action: #selector(showHUD))
        showButton.bezelStyle = .rounded
        showButton.keyEquivalent = "\r"

        let showTwiceButton = NSButton(title: "Show twice quickly", target: self, action: #selector(showHUDTwice))
        showTwiceButton.bezelStyle = .rounded

        let longTitleButton = NSButton(title: "Show over-long title", target: self, action: #selector(showLongTitle))
        longTitleButton.bezelStyle = .rounded

        let actionRow = NSStackView(views: [showButton, showTwiceButton, longTitleButton])
        actionRow.orientation = .horizontal
        actionRow.spacing = 8

        let outerStackView = NSStackView(views: [
            makeIntroduction(),
            contentSection,
            geometrySection,
            timingSection,
            actionRow,
        ])
        outerStackView.orientation = .vertical
        outerStackView.alignment = .leading
        outerStackView.spacing = 18
        outerStackView.edgeInsets = NSEdgeInsets(top: 20, left: 20, bottom: 20, right: 20)
        outerStackView.translatesAutoresizingMaskIntoConstraints = false

        let scrollView = NSScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.drawsBackground = false
        scrollView.documentView = outerStackView

        view.addSubview(scrollView)
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            outerStackView.widthAnchor.constraint(equalTo: scrollView.contentView.widthAnchor),
        ])

        configureSymbolPopUpButton()
        configureTitleFontWeightPopUpButton()
        wireUpControls()
    }

    private func makeIntroduction() -> NSView {
        let titleField = NSTextField(labelWithString: "System HUD Playground")
        titleField.font = .systemFont(ofSize: 20, weight: .semibold)

        let bodyField = NSTextField(wrappingLabelWithString: """
        `SystemHUD` is the volume-HUD-shaped panel: a vibrancy backdrop with an optional glyph above a single line of text, shown below the centre of the active screen and faded out after a delay. Edit the controls, then press Show HUD (or ⏎). The panel sizes itself to its content but never shrinks below the minimum size, and a title too wide for the display truncates instead of pushing the panel off screen.
        """)
        bodyField.font = .systemFont(ofSize: 12)
        bodyField.textColor = .secondaryLabelColor
        bodyField.preferredMaxLayoutWidth = 660

        let stackView = NSStackView(views: [titleField, bodyField])
        stackView.orientation = .vertical
        stackView.alignment = .leading
        stackView.spacing = 6
        return stackView
    }

    private func makeSection(title: String, rows: [NSView]) -> NSView {
        let headingField = NSTextField(labelWithString: title.uppercased())
        headingField.font = .systemFont(ofSize: 11, weight: .semibold)
        headingField.textColor = .secondaryLabelColor

        let stackView = NSStackView(views: [headingField] + rows)
        stackView.orientation = .vertical
        stackView.alignment = .leading
        stackView.spacing = 8
        return stackView
    }

    private func makeRow(label: String, control: NSView, value: NSTextField? = nil) -> NSView {
        let labelField = NSTextField(labelWithString: label)
        labelField.font = .systemFont(ofSize: 12)
        labelField.alignment = .right
        labelField.translatesAutoresizingMaskIntoConstraints = false
        labelField.widthAnchor.constraint(equalToConstant: 110).isActive = true

        control.translatesAutoresizingMaskIntoConstraints = false
        control.widthAnchor.constraint(equalToConstant: 260).isActive = true

        var views: [NSView] = [labelField, control]
        if let value {
            value.font = .monospacedDigitSystemFont(ofSize: 11, weight: .regular)
            value.textColor = .secondaryLabelColor
            value.translatesAutoresizingMaskIntoConstraints = false
            value.widthAnchor.constraint(equalToConstant: 60).isActive = true
            views.append(value)
        }

        let stackView = NSStackView(views: views)
        stackView.orientation = .horizontal
        stackView.spacing = 10
        stackView.alignment = .centerY
        return stackView
    }

    private func configureSymbolPopUpButton() {
        for symbolName in symbolNames {
            symbolPopUpButton.addItem(withTitle: symbolName.isEmpty ? "None (title only)" : symbolName)
        }
        symbolPopUpButton.selectItem(at: 0)
    }

    private func configureTitleFontWeightPopUpButton() {
        for titleFontWeight in titleFontWeights {
            titleFontWeightPopUpButton.addItem(withTitle: titleFontWeight.name)
        }
        titleFontWeightPopUpButton.selectItem(at: 0)
    }

    private func wireUpControls() {
        let sliders = [
            symbolPointSizeSlider, imageSpacingSlider, titleFontSizeSlider,
            verticalOffsetSlider, cornerRadiusSlider, minimumSizeSlider,
            contentInsetSlider, displayDelaySlider, dismissDurationSlider,
        ]
        for slider in sliders {
            slider.target = self
            slider.action = #selector(controlDidChange)
            slider.isContinuous = true
        }

        for popUpButton in [symbolPopUpButton, titleFontWeightPopUpButton] {
            popUpButton.target = self
            popUpButton.action = #selector(controlDidChange)
        }

        titleTextField.delegate = self
    }

    // MARK: - Configuration

    @objc private func controlDidChange() {
        reloadConfiguration()
    }

    private func reloadConfiguration() {
        let contentInset = CGFloat(contentInsetSlider.doubleValue)
        let minimumSideLength = CGFloat(minimumSizeSlider.doubleValue)

        var configuration = SystemHUD.Configuration(title: titleTextField.stringValue)
        configuration.image = makeSymbolImage()
        configuration.imageSpacing = CGFloat(imageSpacingSlider.doubleValue)
        configuration.titleFontSize = CGFloat(titleFontSizeSlider.doubleValue)
        configuration.titleFontWeight = titleFontWeights[titleFontWeightPopUpButton.indexOfSelectedItem].weight
        configuration.offset = CGPoint(x: 0, y: CGFloat(verticalOffsetSlider.doubleValue))
        configuration.cornerRadius = CGFloat(cornerRadiusSlider.doubleValue)
        configuration.minimumSize = CGSize(width: minimumSideLength, height: minimumSideLength)
        configuration.contentInsets = NSEdgeInsets(top: contentInset, left: contentInset, bottom: contentInset, right: contentInset)
        configuration.dismissAnimationDuration = dismissDurationSlider.doubleValue
        systemHUD.configuration = configuration

        symbolPointSizeValueField.stringValue = String(format: "%.0f pt", symbolPointSizeSlider.doubleValue)
        imageSpacingValueField.stringValue = String(format: "%.0f pt", imageSpacingSlider.doubleValue)
        titleFontSizeValueField.stringValue = String(format: "%.0f pt", titleFontSizeSlider.doubleValue)
        verticalOffsetValueField.stringValue = String(format: "%.0f pt", verticalOffsetSlider.doubleValue)
        cornerRadiusValueField.stringValue = String(format: "%.0f pt", cornerRadiusSlider.doubleValue)
        minimumSizeValueField.stringValue = String(format: "%.0f pt", minimumSizeSlider.doubleValue)
        contentInsetValueField.stringValue = String(format: "%.0f pt", contentInsetSlider.doubleValue)
        displayDelayValueField.stringValue = String(format: "%.1f s", displayDelaySlider.doubleValue)
        dismissDurationValueField.stringValue = String(format: "%.1f s", dismissDurationSlider.doubleValue)
    }

    private func makeSymbolImage() -> NSImage? {
        let symbolName = symbolNames[symbolPopUpButton.indexOfSelectedItem]
        guard !symbolName.isEmpty else { return nil }

        let symbolConfiguration = NSImage.SymbolConfiguration(
            pointSize: CGFloat(symbolPointSizeSlider.doubleValue),
            weight: .regular
        )
        let symbolImage = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil)?
            .withSymbolConfiguration(symbolConfiguration)
        // Template rendering lets the glyph pick up the HUD material's label color.
        symbolImage?.isTemplate = true
        return symbolImage
    }

    // MARK: - Actions

    @objc private func showHUD() {
        systemHUD.show(delay: displayDelaySlider.doubleValue)
    }

    /// Shows, then shows again while the first panel is mid-fade — the second call must snap the
    /// panel back to full opacity rather than letting the first fade finish and order it out.
    @objc private func showHUDTwice() {
        systemHUD.show(delay: 0.2)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
            guard let self else { return }
            systemHUD.show(delay: displayDelaySlider.doubleValue)
        }
    }

    /// Drops an over-long title into the field and shows it: the panel widens up to the screen
    /// margin and the title truncates from there.
    @objc private func showLongTitle() {
        titleTextField.stringValue = "A title far too long to fit inside a two-hundred-point panel, which is exactly the point of this button"
        reloadConfiguration()
        systemHUD.show(delay: displayDelaySlider.doubleValue)
    }
}

// MARK: - NSTextFieldDelegate

extension SystemHUDDemoViewController: NSTextFieldDelegate {
    func controlTextDidChange(_ notification: Notification) {
        reloadConfiguration()
    }
}
