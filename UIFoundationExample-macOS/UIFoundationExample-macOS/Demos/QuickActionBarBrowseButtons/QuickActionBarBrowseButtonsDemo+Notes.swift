//
//  QuickActionBarBrowseButtonsDemo+Notes.swift
//  UIFoundationExample-macOS
//

import AppKit
import UIFoundation

/// Example 2: buttons that act at once.
///
/// A click need not browse anything. Each button here closes the bar with `cancel()` and then does
/// its work — it adds a note to the list on the page — while the bar's search finds the notes
/// already there. With two buttons the search field keeps more of its width than with four.
final class NotesBrowseExample: NSObject {
    struct Note: Hashable {
        enum Kind {
            case note
            case checklist
        }

        let title: String
        let kind: Kind
    }

    let quickActionBar = QuickActionBar()

    private(set) var notes: [Note] = [
        Note(title: "Groceries", kind: .checklist),
        Note(title: "Trip Ideas", kind: .note),
        Note(title: "Design Review", kind: .note),
        Note(title: "Packing List", kind: .checklist),
    ]

    /// The note activated last in the bar, which the page marks.
    private(set) var lastOpenedNote: Note?

    /// Called when a note is added or opened.
    var notesDidChange: (() -> Void)?

    private let log: (String) -> Void

    init(log: @escaping (String) -> Void) {
        self.log = log
        super.init()
        quickActionBar.contentSource = self
        quickActionBar.browseItems = [
            QuickActionBar.BrowseItem(
                title: "New Note",
                image: BrowseExample.symbol("square.and.pencil", title: "New Note")
            ) { [weak self] quickActionBar in
                // Close first: the work shows on the page, which the bar would otherwise cover.
                quickActionBar.cancel()
                self?.addNote(of: .note)
            },
            QuickActionBar.BrowseItem(
                title: "New Checklist",
                image: BrowseExample.symbol("checklist", title: "New Checklist")
            ) { [weak self] quickActionBar in
                quickActionBar.cancel()
                self?.addNote(of: .checklist)
            },
        ]
    }

    func present(over window: NSWindow?) {
        // A dismissal still in flight turns round rather than starting over.
        if quickActionBar.resumePresentation() {
            return
        }
        quickActionBar.present(
            parentWindow: window,
            placeholderText: "Search notes",
            width: 520,
            height: 260
        )
    }

    /// Appends a note named like Notes names a new one: the plain name first, then numbered.
    private func addNote(of kind: Note.Kind) {
        let baseTitle = kind == .note ? "Untitled Note" : "Untitled Checklist"
        let existingCount = notes.filter { $0.title == baseTitle || $0.title.hasPrefix("\(baseTitle) ") }.count
        let title = existingCount == 0 ? baseTitle : "\(baseTitle) \(existingCount + 1)"
        notes.append(Note(title: title, kind: kind))
        log("Notes — the bar closed, then “\(title)” was added")
        notesDidChange?()
    }
}

// MARK: - Content source

extension NotesBrowseExample: QuickActionBarContentSource {
    func quickActionBar(_ quickActionBar: QuickActionBar, itemsForSearchTermTask task: QuickActionBar.SearchTask) {
        // Nothing for an empty query, so the buttons come out.
        guard !task.searchTerm.isEmpty else {
            task.complete(with: [])
            return
        }
        let matchingNotes = notes.filter { $0.title.localizedCaseInsensitiveContains(task.searchTerm) }
        task.complete(with: matchingNotes.map { AnyHashable($0) })
    }

    func quickActionBar(_ quickActionBar: QuickActionBar, viewForItem item: AnyHashable, searchTerm: String) -> NSView? {
        guard let note = item.base as? Note else { return nil }
        switch note.kind {
        case .note:
            return BrowseExample.row(
                icon: BrowseExample.symbol("note.text", title: "Note"),
                title: note.title,
                detail: "Note",
                searchTerm: searchTerm
            )
        case .checklist:
            return BrowseExample.row(
                icon: BrowseExample.symbol("checklist", title: "Checklist"),
                title: note.title,
                detail: "Checklist",
                searchTerm: searchTerm
            )
        }
    }

    func quickActionBar(_ quickActionBar: QuickActionBar, didActivateItem item: AnyHashable) {
        guard let note = item.base as? Note else { return }
        lastOpenedNote = note
        log("Notes — opened “\(note.title)”")
        notesDidChange?()
    }
}
