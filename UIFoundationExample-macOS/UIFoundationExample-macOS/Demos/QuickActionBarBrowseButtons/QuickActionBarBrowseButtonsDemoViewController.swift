//
//  QuickActionBarBrowseButtonsDemoViewController.swift
//  UIFoundationExample-macOS
//

import AppKit
import UIFoundation

/// Three ways a host can use the round browse buttons beside the Quick Action Bar's search field
/// (macOS 26 and later).
///
/// Each example owns its bar and is its bar's content source, in a file of its own:
///
/// - ``LauncherBrowseExample`` lists a category the way Spotlight does, and then searches inside it.
/// - ``NotesBrowseExample`` acts at once: a click closes the bar and does the work.
/// - ``TagsBrowseExample`` draws custom images and replaces its buttons while the bar is open.
///
/// The Quick Action Bar playground is the place to compare the buttons' animation with Spotlight's.
final class QuickActionBarBrowseButtonsDemoViewController: NSViewController {
    // MARK: - Examples

    private lazy var launcherExample = LauncherBrowseExample(
        log: { [weak self] message in
            self?.appendToEventLog(message)
        },
        clearEventLog: { [weak self] in
            self?.clearEventLog()
        }
    )

    private lazy var notesExample = NotesBrowseExample(log: { [weak self] message in
        self?.appendToEventLog(message)
    })

    private lazy var tagsExample = TagsBrowseExample(log: { [weak self] message in
        self?.appendToEventLog(message)
    })

    // MARK: - Output

    private let notesListField = NSTextField(wrappingLabelWithString: "")
    private let eventLogTextView = NSTextView()

    // MARK: - Lifecycle

    override func loadView() {
        view = NSView()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        notesExample.notesDidChange = { [weak self] in
            self?.reloadNotesList()
        }
        buildUserInterface()
        reloadNotesList()
    }

    // MARK: - User interface

    private func buildUserInterface() {
        notesListField.font = .systemFont(ofSize: 12)
        notesListField.textColor = .secondaryLabelColor
        notesListField.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        let outerStackView = NSStackView(views: [
            makeIntroduction(),
            makeExampleSection(
                title: "1 · Browse a category, as Spotlight does",
                body: """
                Spotlight's four buttons. A click lists the whole category in the bar — the example \
                pushes it with `provideResultIdentifiers(_:)` — and the circles draw back into the \
                field as the list grows. Typing then searches only that category; once the query is \
                empty again the example answers with nothing, the list collapses and the buttons come \
                back out. Applications are the ones on this Mac, and activating one opens it. Files \
                are made up. Actions work on this window once the bar has gone. Clipboard copies a \
                snippet.
                """,
                buttonTitle: "Open Launcher",
                action: #selector(openLauncher)
            ),
            makeExampleSection(
                title: "2 · Act at once",
                body: """
                A click need not browse anything. Both buttons close the bar with `cancel()` and then \
                add a note to the list below; the bar's own search finds the notes already there. Two \
                buttons leave the search field more of its width than four.
                """,
                buttonTitle: "Open Notes",
                action: #selector(openNotes),
                extraRows: [notesListField]
            ),
            makeExampleSection(
                title: "3 · Custom images, replaced while the bar is open",
                body: """
                Any image works: these dots are drawn in the colours of Finder's tags at their own \
                size, and they are not template images, so nothing tints them. Six colours do not fit \
                four buttons, so More Tags assigns the next set to `browseItems` from its own action — \
                the buttons on screen draw back into the field and the new ones bud out — and Back \
                brings the first set back. A colour lists the documents carrying that tag.
                """,
                buttonTitle: "Open Tags",
                action: #selector(openTags)
            ),
            makeEventLogSection(),
            makeHumanChecksSection(),
        ])
        outerStackView.orientation = .vertical
        outerStackView.alignment = .leading
        outerStackView.spacing = 18
        outerStackView.edgeInsets = NSEdgeInsets(top: 20, left: 20, bottom: 20, right: 20)
        outerStackView.translatesAutoresizingMaskIntoConstraints = false

        // Flipped, so the page opens at its top: a stack view is not, and would open at its bottom.
        let scrollView = NSScrollView.box.makeFlipped()
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
        let titleField = NSTextField(labelWithString: "Browse Buttons")
        titleField.font = .systemFont(ofSize: 20, weight: .semibold)

        let bodyField = makeWrappingLabel("""
        The round buttons beside the Quick Action Bar's search field, put to work three ways. They \
        bud out about half a second after a bar appears, only while its query is empty and it lists \
        no results; a click calls the item's `action` with the bar and leaves the bar open. Each \
        example below has its own bar and content source, in a file of its own under \
        Demos/QuickActionBarBrowseButtons.
        """)

        let stackView = NSStackView(views: [titleField, bodyField])
        stackView.orientation = .vertical
        stackView.alignment = .leading
        stackView.spacing = 6
        return stackView
    }

    private func makeExampleSection(
        title: String,
        body: String,
        buttonTitle: String,
        action: Selector,
        extraRows: [NSView] = []
    ) -> NSView {
        let openButton = NSButton(title: buttonTitle, target: self, action: action)
        openButton.bezelStyle = .rounded
        return makeSection(title: title, rows: [makeWrappingLabel(body), openButton] + extraRows)
    }

    private func makeEventLogSection() -> NSView {
        eventLogTextView.isEditable = false
        eventLogTextView.drawsBackground = false
        eventLogTextView.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        eventLogTextView.textColor = .secondaryLabelColor
        eventLogTextView.string = "What the examples do appears here.\n"
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

        let clearButton = NSButton(title: "Clear", target: self, action: #selector(clearEventLogButtonPressed))
        clearButton.bezelStyle = .rounded

        return makeSection(title: "Event log", rows: [scrollView, clearButton])
    }

    private func makeHumanChecksSection() -> NSView {
        let checksField = makeWrappingLabel("""
        1.  In every example the buttons bud out about half a second after the bar appears, and \
        only while the query is empty and nothing is listed.
        2.  Launcher: click Applications. The applications on this Mac fill the list under an \
        Applications heading while the four circles shrink back into the widening field. Type a \
        few letters: only applications are searched. Escape clears the query and the buttons come \
        out again; a second Escape closes the bar.
        3.  Launcher: Escape straight after clicking a category closes the bar. Spotlight would \
        leave the category first, but the bar has no browse mode, so this is expected.
        4.  Launcher: type without clicking a button. Every category is searched, at most five rows \
        each, each under its heading. An action runs only after the bar has gone; a copied snippet \
        moves to the top of Clipboard.
        5.  Notes: click New Note. The bar closes, then Untitled Note joins the list on this page. \
        Reopen and type its name: the bar finds it, and activating it marks it ▸ in the list.
        6.  Tags: the dots keep their colours in both appearances, and fade in and sharpen as the \
        symbols do. More Tags draws all four buttons back into the field, then Back and three \
        new colours bud out; Back reverses it. A colour lists the documents with that tag.
        """, fontSize: 11)

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

    /// Wraps at 660 points, and gives way rather than holding the window wide.
    private func makeWrappingLabel(_ text: String, fontSize: CGFloat = 12) -> NSTextField {
        let label = NSTextField(wrappingLabelWithString: text)
        label.font = .systemFont(ofSize: fontSize)
        label.textColor = .secondaryLabelColor
        label.preferredMaxLayoutWidth = 660
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return label
    }

    private func reloadNotesList() {
        notesListField.stringValue = notesExample.notes.map { note in
            let marker = note == notesExample.lastOpenedNote ? "▸" : "•"
            let kind = note.kind == .note ? "note" : "checklist"
            return "\(marker) \(note.title) — \(kind)"
        }.joined(separator: "\n")
    }

    // MARK: - Actions

    @objc private func openLauncher() {
        launcherExample.present(over: view.window)
    }

    @objc private func openNotes() {
        notesExample.present(over: view.window)
    }

    @objc private func openTags() {
        tagsExample.present(over: view.window)
    }

    @objc private func clearEventLogButtonPressed() {
        clearEventLog()
    }

    private func clearEventLog() {
        eventLogTextView.string = ""
    }

    private func appendToEventLog(_ message: String) {
        eventLogTextView.string.append("\(message)\n")
        eventLogTextView.scrollToEndOfDocument(nil)
    }
}
