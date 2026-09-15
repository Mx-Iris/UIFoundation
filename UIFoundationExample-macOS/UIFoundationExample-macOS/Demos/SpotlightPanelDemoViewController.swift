//
//  SpotlightPanelDemoViewController.swift
//  UIFoundationExample-macOS
//

import AppKit
import UIFoundation

/// A playground for `SpotlightPanel` — the macOS 26 Spotlight replica.
///
/// Geometry, the platter's sizing rules and the timing all adjust live; the measured animation
/// recipe is shown read-only, because changing it would stop the panel being a replica. Results
/// come from a fixed list of fake commands, since the component never searches anything itself.
final class SpotlightPanelDemoViewController: NSViewController {
    // MARK: - Fake results

    private struct Command: Hashable {
        let title: String
        let subtitle: String
        let symbolName: String
    }

    private let commands: [Command] = [
        Command(title: "New Window", subtitle: "Open another window", symbolName: "macwindow.badge.plus"),
        Command(title: "New Tab", subtitle: "Open a tab in this window", symbolName: "plus.rectangle.on.rectangle"),
        Command(title: "New Document from Template…", subtitle: "Pick a starting point", symbolName: "doc.badge.plus"),
        Command(title: "Open…", subtitle: "Choose a file to open", symbolName: "folder"),
        Command(title: "Open Recent", subtitle: "Reopen a recent document", symbolName: "clock.arrow.circlepath"),
        Command(title: "Close Tab", subtitle: "Close the frontmost tab", symbolName: "xmark.rectangle"),
        Command(title: "Close Window", subtitle: "Close the frontmost window", symbolName: "xmark.square"),
        Command(title: "Save", subtitle: "Write the document to disk", symbolName: "square.and.arrow.down"),
        Command(title: "Save As…", subtitle: "Write a copy somewhere else", symbolName: "square.and.arrow.down.on.square"),
        Command(title: "Revert to Saved", subtitle: "Discard every unsaved change", symbolName: "arrow.uturn.backward"),
        Command(title: "Export as PDF…", subtitle: "Render the document to PDF", symbolName: "doc.richtext"),
        Command(title: "Export as Image…", subtitle: "Render the document to PNG", symbolName: "photo"),
        Command(title: "Print…", subtitle: "Send the document to a printer", symbolName: "printer"),
        Command(title: "Undo", subtitle: "Step backwards through the edit history", symbolName: "arrow.uturn.backward.circle"),
        Command(title: "Redo", subtitle: "Step forwards through the edit history", symbolName: "arrow.uturn.forward.circle"),
        Command(title: "Cut", subtitle: "Move the selection to the clipboard", symbolName: "scissors"),
        Command(title: "Copy", subtitle: "Copy the selection to the clipboard", symbolName: "doc.on.doc"),
        Command(title: "Paste", subtitle: "Insert the clipboard contents", symbolName: "clipboard"),
        Command(title: "Paste and Match Style", subtitle: "Insert without the source formatting", symbolName: "clipboard.fill"),
        Command(title: "Find in Document…", subtitle: "Open the find bar", symbolName: "magnifyingglass"),
        Command(title: "Find and Replace…", subtitle: "Open the find bar with replacement", symbolName: "text.magnifyingglass"),
        Command(title: "Replace All", subtitle: "Substitute every match at once", symbolName: "arrow.2.squarepath"),
        Command(title: "Jump to Selection", subtitle: "Scroll the selection into view", symbolName: "scope"),
        Command(title: "Toggle Sidebar", subtitle: "Show or hide the source list", symbolName: "sidebar.left"),
        Command(title: "Toggle Inspector", subtitle: "Show or hide the trailing pane", symbolName: "sidebar.right"),
        Command(title: "Enter Full Screen", subtitle: "Fill the display", symbolName: "arrow.up.left.and.arrow.down.right"),
        Command(title: "Zoom In", subtitle: "Increase the magnification", symbolName: "plus.magnifyingglass"),
        Command(title: "Zoom Out", subtitle: "Decrease the magnification", symbolName: "minus.magnifyingglass"),
        Command(title: "Actual Size", subtitle: "Reset the magnification to 100%", symbolName: "1.magnifyingglass"),
        Command(title: "Settings…", subtitle: "Open the settings window", symbolName: "gearshape"),
        Command(title: "Check for Updates…", subtitle: "Ask the update feed", symbolName: "arrow.down.circle"),
        Command(title: "Quit", subtitle: "Terminate the application", symbolName: "power"),
    ]

    // MARK: - The panel

    private let spotlightPanel = SpotlightPanel()

    // MARK: - Geometry controls

    private let panelWidthSlider = NSSlider(value: 680, minValue: 360, maxValue: 1000, target: nil, action: nil)
    private let panelWidthValueField = NSTextField(labelWithString: "")

    private let collapsedHeightSlider = NSSlider(value: 56, minValue: 36, maxValue: 96, target: nil, action: nil)
    private let collapsedHeightValueField = NSTextField(labelWithString: "")

    private let cornerRadiusSlider = NSSlider(value: 28, minValue: 0, maxValue: 44, target: nil, action: nil)
    private let cornerRadiusValueField = NSTextField(labelWithString: "")

    private let standardExpandedHeightSlider = NSSlider(value: 430, minValue: 200, maxValue: 900, target: nil, action: nil)
    private let standardExpandedHeightValueField = NSTextField(labelWithString: "")

    private let animationPaddingSlider = NSSlider(value: 40, minValue: 0, maxValue: 90, target: nil, action: nil)
    private let animationPaddingValueField = NSTextField(labelWithString: "")

    private let horizontalContentInsetSlider = NSSlider(value: 20, minValue: 0, maxValue: 48, target: nil, action: nil)
    private let horizontalContentInsetValueField = NSTextField(labelWithString: "")

    private let searchFieldFontSizeSlider = NSSlider(value: 24, minValue: 13, maxValue: 40, target: nil, action: nil)
    private let searchFieldFontSizeValueField = NSTextField(labelWithString: "")

    // MARK: - Platter controls

    private let minimumHeightSlider = NSSlider(value: 120, minValue: 0, maxValue: 500, target: nil, action: nil)
    private let minimumHeightValueField = NSTextField(labelWithString: "")

    private let maximumHeightSlider = NSSlider(value: 520, minValue: 80, maxValue: 900, target: nil, action: nil)
    private let maximumHeightValueField = NSTextField(labelWithString: "")

    private let heightCanPersistCheckbox = NSButton(
        checkboxWithTitle: "Keep the height when the next response is shorter",
        target: nil,
        action: nil
    )
    private let collapsesForEmptyResponseCheckbox = NSButton(
        checkboxWithTitle: "Collapse when a response is empty",
        target: nil,
        action: nil
    )
    private let animatesResizeCheckbox = NSButton(
        checkboxWithTitle: "Animate the resize",
        target: nil,
        action: nil
    )

    // MARK: - Behaviour controls

    private let searchDebounceSlider = NSSlider(value: 0.2, minValue: 0, maxValue: 0.8, target: nil, action: nil)
    private let searchDebounceValueField = NSTextField(labelWithString: "")

    private let sizingDebounceSlider = NSSlider(value: 0.05, minValue: 0, maxValue: 0.4, target: nil, action: nil)
    private let sizingDebounceValueField = NSTextField(labelWithString: "")

    private let resizeDurationSlider = NSSlider(value: 0.2, minValue: 0, maxValue: 0.8, target: nil, action: nil)
    private let resizeDurationValueField = NSTextField(labelWithString: "")

    private let dismissesWhenResigningKeyCheckbox = NSButton(
        checkboxWithTitle: "Dismiss when the panel stops being key",
        target: nil,
        action: nil
    )

    // MARK: - Output

    private let eventLogTextView = NSTextView()
    private let expansionStateField = NSTextField(labelWithString: "")

    // MARK: - Lifecycle

    override func loadView() {
        view = NSView()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        spotlightPanel.dataSource = self
        spotlightPanel.delegate = self

        heightCanPersistCheckbox.state = .on
        collapsesForEmptyResponseCheckbox.state = .on
        animatesResizeCheckbox.state = .on
        dismissesWhenResigningKeyCheckbox.state = .on

        buildUserInterface()
        wireUpControls()
        reloadValueFields()
    }

    // MARK: - User interface

    private func buildUserInterface() {
        let geometrySection = makeSection(title: "Geometry", rows: [
            makeRow(label: "Panel width", control: panelWidthSlider, value: panelWidthValueField),
            makeRow(label: "Collapsed height", control: collapsedHeightSlider, value: collapsedHeightValueField),
            makeRow(label: "Corner radius", control: cornerRadiusSlider, value: cornerRadiusValueField),
            makeRow(label: "Anchor height", control: standardExpandedHeightSlider, value: standardExpandedHeightValueField),
            makeRow(label: "Animation padding", control: animationPaddingSlider, value: animationPaddingValueField),
            makeRow(label: "Content inset", control: horizontalContentInsetSlider, value: horizontalContentInsetValueField),
            makeRow(label: "Query font size", control: searchFieldFontSizeSlider, value: searchFieldFontSizeValueField),
        ])

        let platterSection = makeSection(title: "Results platter", rows: [
            makeRow(label: "Minimum height", control: minimumHeightSlider, value: minimumHeightValueField),
            makeRow(label: "Maximum height", control: maximumHeightSlider, value: maximumHeightValueField),
            heightCanPersistCheckbox,
            collapsesForEmptyResponseCheckbox,
            animatesResizeCheckbox,
        ])

        let behaviourSection = makeSection(title: "Behaviour", rows: [
            makeRow(label: "Search debounce", control: searchDebounceSlider, value: searchDebounceValueField),
            makeRow(label: "Sizing debounce", control: sizingDebounceSlider, value: sizingDebounceValueField),
            makeRow(label: "Resize duration", control: resizeDurationSlider, value: resizeDurationValueField),
            dismissesWhenResigningKeyCheckbox,
        ])

        let openButton = NSButton(title: "Open Panel", target: self, action: #selector(openPanel))
        openButton.bezelStyle = .rounded
        openButton.keyEquivalent = "\r"

        let openWithQueryButton = NSButton(
            title: "Open with “zoom”",
            target: self,
            action: #selector(openPanelWithQuery)
        )
        openWithQueryButton.bezelStyle = .rounded

        let reverseButton = NSButton(
            title: "Demonstrate mid-dismissal reversal",
            target: self,
            action: #selector(demonstrateReversal)
        )
        reverseButton.bezelStyle = .rounded

        let actionRow = NSStackView(views: [openButton, openWithQueryButton, reverseButton])
        actionRow.orientation = .horizontal
        actionRow.spacing = 8

        let outerStackView = NSStackView(views: [
            makeIntroduction(),
            geometrySection,
            platterSection,
            behaviourSection,
            makeMeasuredRecipeSection(),
            makeSection(title: "Actions", rows: [actionRow, expansionStateField]),
            makeEventLogSection(),
            makeHumanChecksSection(),
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
    }

    private func makeIntroduction() -> NSView {
        let titleField = NSTextField(labelWithString: "Spotlight Panel Playground")
        titleField.font = .systemFont(ofSize: 20, weight: .semibold)

        let bodyField = NSTextField(wrappingLabelWithString: """
        `SpotlightPanel` replicates macOS 26's Spotlight: placement, the present and dismiss \
        springs, the non-uniform scale and the content blur all come from measurements of \
        Spotlight's own binary. It does not search anything — the thirty-odd commands below are \
        supplied by this demo through the data source. Adjust anything, then press Open Panel \
        (or ⏎). Geometry and timing apply to the next presentation; the platter's sizing rules \
        apply to the next keystroke.
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

    /// The animation numbers are read-only on purpose: they are what makes this a replica.
    private func makeMeasuredRecipeSection() -> NSView {
        let recipeField = NSTextField(wrappingLabelWithString: """
        Present — scale \(formatRecipeValue(SpotlightPanel.AnimationState.dismissed.horizontalScale)) × \
        \(formatRecipeValue(SpotlightPanel.AnimationState.dismissed.verticalScale)) → 1.0, \
        spring(\(formatRecipeValue(SpotlightPanel.AnimationRecipe.presentPerceptualDuration)), bounce \
        \(formatRecipeValue(SpotlightPanel.AnimationRecipe.presentHorizontalBounce)) / \
        \(formatRecipeValue(SpotlightPanel.AnimationRecipe.presentVerticalBounce)))
        Dismiss — scale 1.0 → \(formatRecipeValue(SpotlightPanel.AnimationState.dismissed.horizontalScale)) × \
        \(formatRecipeValue(SpotlightPanel.AnimationState.dismissed.verticalScale)), \
        spring(\(formatRecipeValue(SpotlightPanel.AnimationRecipe.dismissPerceptualDuration)), bounce \
        \(formatRecipeValue(SpotlightPanel.AnimationRecipe.dismissBounce)))
        Opacity — spring(\(formatRecipeValue(SpotlightPanel.AnimationRecipe.opacityPerceptualDuration)), bounce \
        \(formatRecipeValue(SpotlightPanel.AnimationRecipe.opacityBounce))), both directions
        Content blur — 0 → \(formatRecipeValue(SpotlightPanel.AnimationState.dismissed.blurRadius)), \
        spring(\(formatRecipeValue(SpotlightPanel.AnimationRecipe.blurPerceptualDuration)), bounce \
        \(formatRecipeValue(SpotlightPanel.AnimationRecipe.blurBounce))), dismissal only
        """)
        recipeField.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        recipeField.textColor = .secondaryLabelColor
        recipeField.preferredMaxLayoutWidth = 660

        let environmentField = NSTextField(labelWithString: environmentSummary)
        environmentField.font = .systemFont(ofSize: 11)
        environmentField.textColor = SpotlightPanel.isContentBlurSupported && !prefersReducedMotion
            ? .secondaryLabelColor
            : .systemOrange

        return makeSection(title: "Measured animation (read-only)", rows: [recipeField, environmentField])
    }

    private var environmentSummary: String {
        var notes: [String] = []
        notes.append(
            SpotlightPanel.isContentBlurSupported
                ? "Content blur: available"
                : "Content blur: UNAVAILABLE on this system — dismissal will only scale and fade"
        )
        if prefersReducedMotion {
            notes.append("Reduce Motion is ON — both animations are skipped entirely")
        }
        return notes.joined(separator: "   ·   ")
    }

    private var prefersReducedMotion: Bool {
        NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
    }

    private func makeEventLogSection() -> NSView {
        eventLogTextView.isEditable = false
        eventLogTextView.drawsBackground = false
        eventLogTextView.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        eventLogTextView.textColor = .secondaryLabelColor
        eventLogTextView.string = "Delegate callbacks appear here.\n"
        eventLogTextView.minSize = CGSize(width: 0, height: 0)
        eventLogTextView.maxSize = CGSize(
            width: CGFloat.greatestFiniteMagnitude,
            height: CGFloat.greatestFiniteMagnitude
        )
        eventLogTextView.isVerticallyResizable = true
        eventLogTextView.isHorizontallyResizable = false
        eventLogTextView.autoresizingMask = [.width]
        eventLogTextView.textContainer?.widthTracksTextView = true

        let scrollView = NSScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.borderType = .bezelBorder
        scrollView.drawsBackground = false
        scrollView.documentView = eventLogTextView
        scrollView.heightAnchor.constraint(equalToConstant: 120).isActive = true
        scrollView.widthAnchor.constraint(equalToConstant: 440).isActive = true

        let clearButton = NSButton(title: "Clear", target: self, action: #selector(clearEventLog))
        clearButton.bezelStyle = .rounded

        return makeSection(title: "Event log", rows: [scrollView, clearButton])
    }

    private func makeHumanChecksSection() -> NSView {
        let checksField = NSTextField(wrappingLabelWithString: """
        1.  Dismissal blurs before it fades. The blur curve is nearly twice as slow as the \
        opacity curve, so the panel should go soft first and disappear second — not simply fade.
        2.  The dismissal scale is not uniform. On the way out the panel spreads sideways (1.12) \
        while getting slightly shorter (0.95).
        3.  The top edge does not move when results appear. The query field stays put; only the \
        bottom edge travels. Type a letter and watch the top of the panel.
        4.  Reopening mid-dismissal reverses it rather than restarting. Press the button above, \
        or press Escape and immediately hit ⏎ here.
        5.  Placement is anchored, not centred. With no results the panel sits above centre; \
        once expanded it lands in the middle. Drag "Anchor height" and reopen to see it move.
        """)
        checksField.font = .systemFont(ofSize: 11)
        checksField.textColor = .secondaryLabelColor
        checksField.preferredMaxLayoutWidth = 660
        checksField.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        return makeSection(title: "Checks only a human can make", rows: [checksField])
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
        labelField.widthAnchor.constraint(equalToConstant: 120).isActive = true

        control.translatesAutoresizingMaskIntoConstraints = false
        control.widthAnchor.constraint(equalToConstant: 250).isActive = true

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

    private func wireUpControls() {
        let sliders = [
            panelWidthSlider, collapsedHeightSlider, cornerRadiusSlider,
            standardExpandedHeightSlider, animationPaddingSlider, horizontalContentInsetSlider,
            searchFieldFontSizeSlider, minimumHeightSlider, maximumHeightSlider,
            searchDebounceSlider, sizingDebounceSlider, resizeDurationSlider,
        ]
        for slider in sliders {
            slider.target = self
            slider.action = #selector(controlDidChange)
            slider.isContinuous = true
        }
    }

    @objc private func controlDidChange() {
        reloadValueFields()
    }

    private func reloadValueFields() {
        panelWidthValueField.stringValue = format(panelWidthSlider.doubleValue)
        collapsedHeightValueField.stringValue = format(collapsedHeightSlider.doubleValue)
        cornerRadiusValueField.stringValue = format(cornerRadiusSlider.doubleValue)
        standardExpandedHeightValueField.stringValue = format(standardExpandedHeightSlider.doubleValue)
        animationPaddingValueField.stringValue = format(animationPaddingSlider.doubleValue)
        horizontalContentInsetValueField.stringValue = format(horizontalContentInsetSlider.doubleValue)
        searchFieldFontSizeValueField.stringValue = format(searchFieldFontSizeSlider.doubleValue)
        minimumHeightValueField.stringValue = format(minimumHeightSlider.doubleValue)
        maximumHeightValueField.stringValue = format(maximumHeightSlider.doubleValue)
        searchDebounceValueField.stringValue = "\(format(searchDebounceSlider.doubleValue, decimals: 2)) s"
        sizingDebounceValueField.stringValue = "\(format(sizingDebounceSlider.doubleValue, decimals: 2)) s"
        resizeDurationValueField.stringValue = "\(format(resizeDurationSlider.doubleValue, decimals: 2)) s"
    }

    private func format(_ value: Double, decimals: Int = 0) -> String {
        String(format: "%.\(decimals)f", value)
    }

    /// Formats a measured constant for display, keeping 1.12 as "1.12" and 25 as "25".
    private func formatRecipeValue(_ value: CGFloat) -> String {
        let rounded = (value * 100).rounded() / 100
        return rounded == rounded.rounded()
            ? String(format: "%.0f", Double(rounded))
            : String(format: "%g", Double(rounded))
    }

    // MARK: - Actions

    private func applyConfiguration() {
        var metrics = SpotlightPanel.Metrics.default
        metrics.standardWidth = CGFloat(panelWidthSlider.doubleValue)
        metrics.collapsedHeight = CGFloat(collapsedHeightSlider.doubleValue)
        metrics.cornerRadius = CGFloat(cornerRadiusSlider.doubleValue)
        metrics.standardExpandedHeight = CGFloat(standardExpandedHeightSlider.doubleValue)
        metrics.animationPadding = CGFloat(animationPaddingSlider.doubleValue)
        metrics.horizontalContentInset = CGFloat(horizontalContentInsetSlider.doubleValue)

        var configuration = SpotlightPanel.Configuration.default
        configuration.metrics = metrics
        configuration.placeholderText = "Search commands"
        configuration.searchFieldFontSize = CGFloat(searchFieldFontSizeSlider.doubleValue)
        configuration.searchDebounceDelay = searchDebounceSlider.doubleValue
        configuration.sizingDebounceDelay = sizingDebounceSlider.doubleValue
        configuration.resizeAnimationDuration = resizeDurationSlider.doubleValue
        configuration.dismissesWhenResigningKey = dismissesWhenResigningKeyCheckbox.state == .on

        spotlightPanel.configuration = configuration
    }

    @objc private func openPanel() {
        applyConfiguration()
        spotlightPanel.present()
        appendToEventLog("present()")
    }

    @objc private func openPanelWithQuery() {
        applyConfiguration()
        spotlightPanel.present(initialSearchTerm: "zoom")
        appendToEventLog("present(initialSearchTerm: \"zoom\")")
    }

    /// Presents, dismisses, then presents again before the dismissal has finished.
    ///
    /// Doing this by hand needs two keystrokes inside about a fifth of a second, which is why the
    /// button exists: the panel should resume from wherever the dismissal had got to rather than
    /// snapping back and starting over.
    @objc private func demonstrateReversal() {
        applyConfiguration()
        spotlightPanel.present()
        appendToEventLog("present() — reversal demo starting")

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) { [weak self] in
            guard let self else { return }
            self.spotlightPanel.dismiss()
            self.appendToEventLog("dismiss() — interrupting in 120 ms")

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { [weak self] in
                guard let self else { return }
                self.spotlightPanel.present()
                self.appendToEventLog("present() — should resume, not restart")
            }
        }
    }

    @objc private func clearEventLog() {
        eventLogTextView.string = ""
    }

    private func appendToEventLog(_ message: String) {
        eventLogTextView.string.append("\(message)\n")
        eventLogTextView.scrollToEndOfDocument(nil)
        expansionStateField.stringValue = "Expansion state: \(spotlightPanel.expansionState.rawValue)"
    }

    private func matches(_ command: Command, searchTerm: String) -> Bool {
        guard !searchTerm.isEmpty else { return true }
        return command.title.localizedCaseInsensitiveContains(searchTerm)
            || command.subtitle.localizedCaseInsensitiveContains(searchTerm)
    }
}

// MARK: - Data source

extension SpotlightPanelDemoViewController: SpotlightPanelDataSource {
    func spotlightPanel(_ spotlightPanel: SpotlightPanel, itemsForSearchTask searchTask: SpotlightPanel.SearchTask) {
        let matchingCommands = commands.filter { matches($0, searchTerm: searchTask.searchTerm) }
        searchTask.complete(with: matchingCommands.map { AnyHashable($0) })
    }

    func spotlightPanel(
        _ spotlightPanel: SpotlightPanel,
        viewForItem item: AnyHashable,
        searchTerm: String
    ) -> NSView? {
        guard let command = item.base as? Command else { return nil }

        let imageView = NSImageView()
        imageView.image = NSImage(systemSymbolName: command.symbolName, accessibilityDescription: nil)
        imageView.contentTintColor = .labelColor
        imageView.setContentHuggingPriority(.required, for: .horizontal)
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.widthAnchor.constraint(equalToConstant: 22).isActive = true

        let titleLabel = NSTextField(labelWithString: command.title)
        titleLabel.font = .systemFont(ofSize: 14, weight: .medium)

        let subtitleLabel = NSTextField(labelWithString: command.subtitle)
        subtitleLabel.font = .systemFont(ofSize: 11)
        subtitleLabel.textColor = .secondaryLabelColor

        let textStackView = NSStackView(views: [titleLabel, subtitleLabel])
        textStackView.orientation = .vertical
        textStackView.alignment = .leading
        textStackView.spacing = 1

        let rowStackView = NSStackView(views: [imageView, textStackView])
        rowStackView.orientation = .horizontal
        rowStackView.alignment = .centerY
        rowStackView.spacing = 10
        rowStackView.edgeInsets = NSEdgeInsets(
            top: 6,
            left: spotlightPanel.configuration.metrics.horizontalContentInset,
            bottom: 6,
            right: spotlightPanel.configuration.metrics.horizontalContentInset
        )
        return rowStackView
    }

    func spotlightPanel(
        _ spotlightPanel: SpotlightPanel,
        platterBehaviorForItems items: [AnyHashable],
        searchTerm: String
    ) -> SpotlightPanel.PlatterBehavior {
        SpotlightPanel.PlatterBehavior(
            minimumHeight: CGFloat(minimumHeightSlider.doubleValue),
            maximumHeight: CGFloat(maximumHeightSlider.doubleValue),
            heightCanPersist: heightCanPersistCheckbox.state == .on,
            collapsesForEmptyResponse: collapsesForEmptyResponseCheckbox.state == .on,
            isAnimated: animatesResizeCheckbox.state == .on
        )
    }
}

// MARK: - Delegate

extension SpotlightPanelDemoViewController: SpotlightPanelDelegate {
    func spotlightPanel(_ spotlightPanel: SpotlightPanel, didSelectItem item: AnyHashable) {
        guard let command = item.base as? Command else { return }
        appendToEventLog("didSelectItem — \(command.title)")
    }

    func spotlightPanel(_ spotlightPanel: SpotlightPanel, didActivateItem item: AnyHashable) -> Bool {
        guard let command = item.base as? Command else { return true }
        appendToEventLog("didActivateItem — \(command.title)")
        return true
    }

    func spotlightPanel(_ spotlightPanel: SpotlightPanel, didRequestCopyForItem item: AnyHashable) {
        guard let command = item.base as? Command else { return }
        appendToEventLog("⌘C — \(command.title)")
    }

    func spotlightPanel(_ spotlightPanel: SpotlightPanel, didRequestQuickLookForItem item: AnyHashable) {
        guard let command = item.base as? Command else { return }
        appendToEventLog("⌘Y — \(command.title)")
    }

    func spotlightPanel(_ spotlightPanel: SpotlightPanel, didPressTabForward isForward: Bool) -> Bool {
        appendToEventLog(isForward ? "Tab (unhandled — no filter bar yet)" : "Shift-Tab (unhandled)")
        return false
    }

    func spotlightPanel(_ spotlightPanel: SpotlightPanel, didRequestDrillDownForItem item: AnyHashable) -> Bool {
        guard let command = item.base as? Command else { return false }
        appendToEventLog("→ drill down — \(command.title) (unhandled — no navigation stack yet)")
        return false
    }

    func spotlightPanel(_ spotlightPanel: SpotlightPanel, searchTermDidChange searchTerm: String) {
        appendToEventLog("searchTermDidChange — “\(searchTerm)”")
    }

    func spotlightPanelDidCancel(_ spotlightPanel: SpotlightPanel) {
        appendToEventLog("didCancel — dismissed without activating")
    }

    func spotlightPanelDidDismiss(_ spotlightPanel: SpotlightPanel) {
        appendToEventLog("didDismiss")
    }
}
