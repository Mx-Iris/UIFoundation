//
//  QuickActionBarDemoViewController.swift
//  UIFoundationExample-macOS
//

import AppKit
import UIFoundation

/// A playground for `QuickActionBar` — the Spotlight-style command bar ported from
/// DSFQuickActionBar.
///
/// Every option `present(…)` takes adjusts live, and the search can be slowed down on purpose to
/// show the asynchronous path: the spinner, and answers for a query the user has already typed
/// past being dropped. Results come from a fixed list of fake commands, since the bar never
/// searches anything itself.
final class QuickActionBarDemoViewController: NSViewController {
    // MARK: - Fake results

    private struct Command: Hashable {
        let title: String
        let subtitle: String
        let symbolName: String
        let category: String
    }

    /// A row naming the category of the commands below it. Never selectable.
    private struct Heading: Hashable {
        let title: String
    }

    /// Ordered by category, so each category's commands sit together under one heading.
    private let commands: [Command] = [
        Command(title: "New Window", subtitle: "Open another window", symbolName: "macwindow.badge.plus", category: "File"),
        Command(title: "New Tab", subtitle: "Open a tab in this window", symbolName: "plus.rectangle.on.rectangle", category: "File"),
        Command(title: "Open…", subtitle: "Choose a file to open", symbolName: "folder", category: "File"),
        Command(title: "Open Recent", subtitle: "Reopen a recent document", symbolName: "clock.arrow.circlepath", category: "File"),
        Command(title: "Close Tab", subtitle: "Close the frontmost tab", symbolName: "xmark.rectangle", category: "File"),
        Command(title: "Save", subtitle: "Write the document to disk", symbolName: "square.and.arrow.down", category: "File"),
        Command(title: "Save As…", subtitle: "Write a copy somewhere else", symbolName: "square.and.arrow.down.on.square", category: "File"),
        Command(title: "Export as PDF…", subtitle: "Render the document to PDF", symbolName: "doc.richtext", category: "File"),
        Command(title: "Print…", subtitle: "Send the document to a printer", symbolName: "printer", category: "File"),
        Command(title: "Undo", subtitle: "Step backwards through the edit history", symbolName: "arrow.uturn.backward.circle", category: "Edit"),
        Command(title: "Redo", subtitle: "Step forwards through the edit history", symbolName: "arrow.uturn.forward.circle", category: "Edit"),
        Command(title: "Cut", subtitle: "Move the selection to the clipboard", symbolName: "scissors", category: "Edit"),
        Command(title: "Copy", subtitle: "Copy the selection to the clipboard", symbolName: "doc.on.doc", category: "Edit"),
        Command(title: "Paste", subtitle: "Insert the clipboard contents", symbolName: "clipboard", category: "Edit"),
        Command(title: "Paste and Match Style", subtitle: "Insert without the source formatting", symbolName: "clipboard.fill", category: "Edit"),
        Command(title: "Find in Document…", subtitle: "Open the find bar", symbolName: "magnifyingglass", category: "Edit"),
        Command(title: "Find and Replace…", subtitle: "Open the find bar with replacement", symbolName: "text.magnifyingglass", category: "Edit"),
        Command(title: "Toggle Sidebar", subtitle: "Show or hide the source list", symbolName: "sidebar.left", category: "View"),
        Command(title: "Toggle Inspector", subtitle: "Show or hide the trailing pane", symbolName: "sidebar.right", category: "View"),
        Command(title: "Enter Full Screen", subtitle: "Fill the display", symbolName: "arrow.up.left.and.arrow.down.right", category: "View"),
        Command(title: "Zoom In", subtitle: "Increase the magnification", symbolName: "plus.magnifyingglass", category: "View"),
        Command(title: "Zoom Out", subtitle: "Decrease the magnification", symbolName: "minus.magnifyingglass", category: "View"),
        Command(title: "Actual Size", subtitle: "Reset the magnification to 100%", symbolName: "1.magnifyingglass", category: "View"),
        Command(title: "Minimize", subtitle: "Send the window to the Dock", symbolName: "minus.square", category: "Window"),
        Command(title: "Zoom Window", subtitle: "Fit the window to its content", symbolName: "plus.square", category: "Window"),
        Command(title: "Bring All to Front", subtitle: "Raise every window of this app", symbolName: "macwindow.on.rectangle", category: "Window"),
        Command(title: "Settings…", subtitle: "Open the settings window", symbolName: "gearshape", category: "Application"),
        Command(title: "Check for Updates…", subtitle: "Ask the update feed", symbolName: "arrow.down.circle", category: "Application"),
        Command(title: "Quit", subtitle: "Terminate the application", symbolName: "power", category: "Application"),
    ]

    /// Replaces the magnifying glass when "Use a custom search image" is on. Drawn large, because
    /// the bar rasterises whatever it is given at 64 points before scaling it down.
    private let customSearchImage = NSImage(systemSymbolName: "command", accessibilityDescription: nil)?
        .withSymbolConfiguration(NSImage.SymbolConfiguration(pointSize: 48, weight: .regular))

    // MARK: - The bar

    private let quickActionBar = QuickActionBar()

    // MARK: - Presentation controls

    private let barWidthSlider = NSSlider(value: 640, minValue: 400, maxValue: 1000, target: nil, action: nil)
    private let barWidthValueField = NSTextField(labelWithString: "")

    private let resultsHeightSlider = NSSlider(value: 320, minValue: 160, maxValue: 600, target: nil, action: nil)
    private let resultsHeightValueField = NSTextField(labelWithString: "")

    private let placeholderTextField = NSTextField(string: "Search commands")

    private let centersOnWindowCheckbox = NSButton(
        checkboxWithTitle: "Centre on this window instead of the screen",
        target: nil,
        action: nil
    )
    private let showsKeyboardShortcutsCheckbox = NSButton(
        checkboxWithTitle: "Label the first ten selectable rows ↩ and ⌘1–⌘9",
        target: nil,
        action: nil
    )
    private let activatesOnSingleClickCheckbox = NSButton(
        checkboxWithTitle: "Activate a row with a single click (default: double)",
        target: nil,
        action: nil
    )
    private let usesCustomSearchImageCheckbox = NSButton(
        checkboxWithTitle: "Use a custom search image",
        target: nil,
        action: nil
    )

    // MARK: - Search controls

    private let searchLatencySlider = NSSlider(value: 0, minValue: 0, maxValue: 1.5, target: nil, action: nil)
    private let searchLatencyValueField = NSTextField(labelWithString: "")

    private let groupsUnderHeadingsCheckbox = NSButton(
        checkboxWithTitle: "Group results under headings the list cannot select",
        target: nil,
        action: nil
    )
    private let listsEverythingForEmptyQueryCheckbox = NSButton(
        checkboxWithTitle: "List every command while the query is empty",
        target: nil,
        action: nil
    )

    // MARK: - Output

    private let eventLogTextView = NSTextView()
    private let statusField = NSTextField(labelWithString: "")

    // MARK: - Lifecycle

    override func loadView() {
        view = NSView()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        quickActionBar.contentSource = self

        centersOnWindowCheckbox.state = .on
        showsKeyboardShortcutsCheckbox.state = .on
        groupsUnderHeadingsCheckbox.state = .on

        buildUserInterface()
        wireUpControls()
        reloadValueFields()
        reloadStatusField()
    }

    // MARK: - User interface

    private func buildUserInterface() {
        let presentationSection = makeSection(title: "Presentation", rows: [
            makeRow(label: "Bar width", control: barWidthSlider, value: barWidthValueField),
            makeRow(label: "Results height", control: resultsHeightSlider, value: resultsHeightValueField),
            makeRow(label: "Placeholder", control: placeholderTextField),
            centersOnWindowCheckbox,
            showsKeyboardShortcutsCheckbox,
            activatesOnSingleClickCheckbox,
            usesCustomSearchImageCheckbox,
        ])

        let searchSection = makeSection(title: "Search", rows: [
            makeRow(label: "Answer after", control: searchLatencySlider, value: searchLatencyValueField),
            groupsUnderHeadingsCheckbox,
            listsEverythingForEmptyQueryCheckbox,
        ])

        let openButton = NSButton(title: "Open Bar", target: self, action: #selector(openBar))
        openButton.bezelStyle = .rounded
        openButton.keyEquivalent = "\r"

        let openWithQueryButton = NSButton(
            title: "Open with “zoom”",
            target: self,
            action: #selector(openBarWithQuery)
        )
        openWithQueryButton.bezelStyle = .rounded

        let reverseButton = NSButton(
            title: "Demonstrate mid-dismissal reversal",
            target: self,
            action: #selector(demonstrateReversal)
        )
        reverseButton.bezelStyle = .rounded

        statusField.font = .systemFont(ofSize: 11)
        statusField.textColor = .secondaryLabelColor

        let actionRow = NSStackView(views: [openButton, openWithQueryButton, reverseButton])
        actionRow.orientation = .horizontal
        actionRow.spacing = 8

        let outerStackView = NSStackView(views: [
            makeIntroduction(),
            presentationSection,
            searchSection,
            makeSection(title: "Actions", rows: [actionRow, statusField]),
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
        let titleField = NSTextField(labelWithString: "Quick Action Bar Playground")
        titleField.font = .systemFont(ofSize: 20, weight: .semibold)

        let bodyField = NSTextField(wrappingLabelWithString: """
        `QuickActionBar` is a Spotlight-style command bar: a query field that grows downwards into \
        a result list. It does not search anything — the thirty-odd commands below come from this \
        demo through `QuickActionBarContentSource`. Adjust anything, then press Open Bar (or ⏎). \
        Presentation options apply to the next presentation; search options apply to the next \
        keystroke.
        """)
        bodyField.font = .systemFont(ofSize: 12)
        bodyField.textColor = .secondaryLabelColor
        bodyField.preferredMaxLayoutWidth = 660
        bodyField.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        let stackView = NSStackView(views: [titleField, bodyField])
        stackView.orientation = .vertical
        stackView.alignment = .leading
        stackView.spacing = 6
        return stackView
    }

    private func makeEventLogSection() -> NSView {
        eventLogTextView.isEditable = false
        eventLogTextView.drawsBackground = false
        eventLogTextView.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        eventLogTextView.textColor = .secondaryLabelColor
        eventLogTextView.string = "Content source callbacks appear here.\n"
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
        scrollView.heightAnchor.constraint(equalToConstant: 140).isActive = true
        scrollView.widthAnchor.constraint(equalToConstant: 440).isActive = true

        let clearButton = NSButton(title: "Clear", target: self, action: #selector(clearEventLog))
        clearButton.bezelStyle = .rounded

        return makeSection(title: "Event log", rows: [scrollView, clearButton])
    }

    private func makeHumanChecksSection() -> NSView {
        let checksField = NSTextField(wrappingLabelWithString: """
        1.  Escape clears before it closes. Type a letter, then press Escape: the query empties \
        and the results collapse along a spring that overshoots a little (unless "List every \
        command while the query is empty" is on, which keeps them). A second Escape closes the bar \
        and the log reports didCancel.
        2.  Only the bottom edge moves. When results appear the query field stays where it was; \
        the bar grows downwards.
        3.  Headings are skipped. With headings on, ↑ and ↓ jump over the category rows, and the \
        ↩ / ⌘1–⌘9 labels count only the rows you can select.
        4.  ⌘1–⌘9 activate the row they label, whichever row is selected; the log names it in \
        didActivateItem.
        5.  ← leaves the list. With double-click activation, click a row once to give the list \
        the focus; ← puts the focus back in the query field.
        6.  Slow answers are dropped, not shown. Set "Answer after" to a second and type slowly: \
        the spinner appears after a quarter of a second, and every answer for a query you have \
        already typed past is logged as dropped.
        7.  Clicking outside cancels. Click an empty part of this window while the bar is up: \
        the log reports didCancel, then didClose. Activating a row reports didActivateItem and no didCancel.
        8.  Reopening mid-dismissal reverses it rather than restarting. Press the button above, \
        or press Escape on an empty query and immediately hit ⏎ here.
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
        for slider in [barWidthSlider, resultsHeightSlider, searchLatencySlider] {
            slider.target = self
            slider.action = #selector(controlDidChange)
            slider.isContinuous = true
        }
    }

    @objc private func controlDidChange() {
        reloadValueFields()
    }

    private func reloadValueFields() {
        barWidthValueField.stringValue = String(format: "%.0f", barWidthSlider.doubleValue)
        resultsHeightValueField.stringValue = String(format: "%.0f", resultsHeightSlider.doubleValue)
        searchLatencyValueField.stringValue = searchLatency == 0
            ? "at once"
            : String(format: "%.2f s", searchLatency)
    }

    /// Rounded to a twentieth of a second, so the slider can land on exactly zero.
    private var searchLatency: TimeInterval {
        (searchLatencySlider.doubleValue * 20).rounded() / 20
    }

    private func reloadStatusField() {
        let query = quickActionBar.currentSearchText ?? ""
        statusField.stringValue = quickActionBar.isPresenting
            ? "Presenting   ·   query “\(query)”"
            : "Not presenting"
    }

    // MARK: - Actions

    /// Reverses a dismissal still in flight, the way a host's own shortcut should, and presents
    /// a new bar otherwise.
    @objc private func openBar() {
        if quickActionBar.resumePresentation() {
            appendToEventLog("resumePresentation() — reopened mid-dismissal")
            return
        }
        presentBar(initialSearchText: nil)
        appendToEventLog("present()")
    }

    @objc private func openBarWithQuery() {
        presentBar(initialSearchText: "zoom")
        appendToEventLog("present(initialSearchText: \"zoom\")")
    }

    private func presentBar(initialSearchText: String?) {
        quickActionBar.requiredClickCount = activatesOnSingleClickCheckbox.state == .on ? .single : .double
        quickActionBar.present(
            parentWindow: centersOnWindowCheckbox.state == .on ? view.window : nil,
            placeholderText: placeholderTextField.stringValue,
            searchImage: usesCustomSearchImageCheckbox.state == .on ? customSearchImage : nil,
            initialSearchText: initialSearchText,
            width: CGFloat(barWidthSlider.doubleValue),
            height: CGFloat(resultsHeightSlider.doubleValue),
            showKeyboardShortcuts: showsKeyboardShortcutsCheckbox.state == .on,
            didClose: { [weak self] in
                self?.appendToEventLog("didClose")
            }
        )
    }

    /// Presents, cancels, then resumes before the dismissal has finished.
    ///
    /// Doing this by hand needs two keystrokes inside half a second, which is why the button
    /// exists: the bar should turn round from wherever the dismissal had got to rather than
    /// snapping back and starting over, and no didCancel or didClose should be logged.
    @objc private func demonstrateReversal() {
        presentBar(initialSearchText: nil)
        appendToEventLog("present() — reversal demo starting")

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) { [weak self] in
            guard let self else { return }
            self.quickActionBar.cancel()
            self.appendToEventLog("cancel() — resuming in 120 ms")

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { [weak self] in
                guard let self else { return }
                let didResume = self.quickActionBar.resumePresentation()
                self.appendToEventLog("resumePresentation() → \(didResume)")
            }
        }
    }

    @objc private func clearEventLog() {
        eventLogTextView.string = ""
    }

    private func appendToEventLog(_ message: String) {
        eventLogTextView.string.append("\(message)\n")
        eventLogTextView.scrollToEndOfDocument(nil)
        reloadStatusField()
    }

    // MARK: - Searching

    private func results(for searchTerm: String) -> [AnyHashable] {
        let matchingCommands: [Command]
        if searchTerm.isEmpty {
            matchingCommands = listsEverythingForEmptyQueryCheckbox.state == .on ? commands : []
        } else {
            matchingCommands = commands.filter {
                $0.title.localizedCaseInsensitiveContains(searchTerm)
                    || $0.subtitle.localizedCaseInsensitiveContains(searchTerm)
            }
        }

        guard groupsUnderHeadingsCheckbox.state == .on else {
            return matchingCommands.map { AnyHashable($0) }
        }

        var groupedResults: [AnyHashable] = []
        var currentCategory: String?
        for command in matchingCommands {
            if command.category != currentCategory {
                groupedResults.append(AnyHashable(Heading(title: command.category)))
                currentCategory = command.category
            }
            groupedResults.append(AnyHashable(command))
        }
        return groupedResults
    }

    // MARK: - Rows

    private func makeCommandRow(for command: Command, searchTerm: String) -> NSView {
        let imageView = NSImageView()
        imageView.image = NSImage(systemSymbolName: command.symbolName, accessibilityDescription: nil)
        imageView.contentTintColor = .labelColor
        imageView.setContentHuggingPriority(.required, for: .horizontal)
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.widthAnchor.constraint(equalToConstant: 22).isActive = true

        let titleLabel = NSTextField(labelWithAttributedString: highlightedTitle(command.title, matching: searchTerm))

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
        rowStackView.edgeInsets = NSEdgeInsets(top: 4, left: 22, bottom: 4, right: 22)
        return rowStackView
    }

    private func makeHeadingRow(for heading: Heading) -> NSView {
        let headingLabel = NSTextField(labelWithString: heading.title.uppercased())
        headingLabel.font = .systemFont(ofSize: 11, weight: .semibold)
        headingLabel.textColor = .tertiaryLabelColor

        let rowStackView = NSStackView(views: [headingLabel])
        rowStackView.orientation = .horizontal
        rowStackView.edgeInsets = NSEdgeInsets(top: 6, left: 22, bottom: 0, right: 22)
        return rowStackView
    }

    /// The title with the part the query matched set in bold — what `searchTerm` is passed to
    /// `viewForItem` for.
    private func highlightedTitle(_ title: String, matching searchTerm: String) -> NSAttributedString {
        let attributedTitle = NSMutableAttributedString(
            string: title,
            attributes: [
                .font: NSFont.systemFont(ofSize: 14),
                .foregroundColor: NSColor.labelColor,
            ]
        )
        if !searchTerm.isEmpty, let matchedRange = title.range(of: searchTerm, options: .caseInsensitive) {
            attributedTitle.addAttribute(
                .font,
                value: NSFont.systemFont(ofSize: 14, weight: .bold),
                range: NSRange(matchedRange, in: title)
            )
        }
        return attributedTitle
    }
}

// MARK: - Content source

extension QuickActionBarDemoViewController: QuickActionBarContentSource {
    func quickActionBar(_ quickActionBar: QuickActionBar, itemsForSearchTermTask task: QuickActionBar.SearchTask) {
        let searchTerm = task.searchTerm
        let latency = searchLatency
        guard latency > 0 else {
            task.complete(with: results(for: searchTerm))
            return
        }

        appendToEventLog("search “\(searchTerm)” — answering in \(String(format: "%.2f", latency)) s")
        DispatchQueue.main.asyncAfter(deadline: .now() + latency) { [weak self] in
            // A demo that has gone away must not answer: the bar traps when results arrive for a
            // content source that no longer exists.
            guard let self else { return }
            if task.isCancelled {
                self.appendToEventLog("search “\(searchTerm)” — dropped, the query moved on")
            } else {
                task.complete(with: self.results(for: searchTerm))
                self.appendToEventLog("search “\(searchTerm)” — answered")
            }
        }
    }

    func quickActionBar(_ quickActionBar: QuickActionBar, viewForItem item: AnyHashable, searchTerm: String) -> NSView? {
        if let heading = item.base as? Heading {
            return makeHeadingRow(for: heading)
        }
        guard let command = item.base as? Command else { return nil }
        return makeCommandRow(for: command, searchTerm: searchTerm)
    }

    func quickActionBar(_ quickActionBar: QuickActionBar, canSelectItem item: AnyHashable) -> Bool {
        !(item.base is Heading)
    }

    func quickActionBar(_ quickActionBar: QuickActionBar, didSelectItem item: AnyHashable) {
        guard let command = item.base as? Command else { return }
        appendToEventLog("didSelectItem — \(command.title)")
    }

    func quickActionBar(_ quickActionBar: QuickActionBar, didActivateItem item: AnyHashable) {
        guard let command = item.base as? Command else { return }
        appendToEventLog("didActivateItem — \(command.title)")
    }

    func quickActionBarDidCancel(_ quickActionBar: QuickActionBar) {
        appendToEventLog("didCancel — closed without activating")
    }
}
