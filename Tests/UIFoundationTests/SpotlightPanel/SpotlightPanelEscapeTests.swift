#if SpotlightPanel && os(macOS)

import AppKit
import Testing
@testable import UIFoundationAppleInternal

/// Escape, the way Spotlight handles it on macOS 27.2: a query is cleared first, which collapses
/// the results it produced, and only an Escape on an empty field dismisses the panel.
///
/// The panel comes up through the public `present()`; the tests reach for nothing internal but
/// the window it opened — to send keys into it and to read `isDismissing`, the observable for "a
/// dismissal started". Escape in the query field and Tab are real key-down events. From the
/// results list the test starts one step later, at the `cancelOperation:` the window derives from
/// Escape: in a test process a key-down Escape sent to a table changes nothing (measured with the
/// quick action bar, whose window is never key here either), and the table then hands the command
/// to every responder above it that implements it.
@Suite("SpotlightPanel Escape", .serialized)
@MainActor
struct SpotlightPanelEscapeTests {
    @Test("Escape with a query clears it and keeps the panel up")
    func escapeClearsQuery() throws {
        guard NSScreen.main != nil else { return }

        let host = RecordingHost()
        let spotlightPanel = SpotlightPanel()
        let panel = try present(spotlightPanel, for: host)
        defer { spotlightPanel.dismiss() }
        spotlightPanel.searchTerm = "xcode"

        panel.sendEvent(.keyDown(.escape, in: panel))

        #expect(spotlightPanel.searchTerm == "")
        #expect(host.searchTermChanges.last == "")
        #expect(!panel.isDismissing)
    }

    @Test("Escape on an empty query dismisses the panel")
    func escapeOnEmptyQueryDismisses() throws {
        guard NSScreen.main != nil else { return }

        let host = RecordingHost()
        let spotlightPanel = SpotlightPanel()
        let panel = try present(spotlightPanel, for: host)
        defer { spotlightPanel.dismiss() }

        panel.sendEvent(.keyDown(.escape, in: panel))

        #expect(panel.isDismissing)
    }

    @Test("Escape from the results list clears the query and gives the query field its focus back")
    func escapeFromResultsList() throws {
        guard NSScreen.main != nil else { return }

        let host = RecordingHost()
        let spotlightPanel = SpotlightPanel()
        let panel = try present(spotlightPanel, for: host)
        defer { spotlightPanel.dismiss() }
        spotlightPanel.searchTerm = "xcode"

        panel.sendEvent(.keyDown(.tab, in: panel))
        let resultsTable = try #require(panel.firstResponder as? NSTableView)

        resultsTable.doCommand(by: #selector(NSResponder.cancelOperation(_:)))

        #expect(spotlightPanel.searchTerm == "")
        #expect((panel.firstResponder as? NSTextView)?.isFieldEditor == true)
    }

    // MARK: - Helpers

    /// Presents `spotlightPanel` and returns the window it opened.
    private func present(_ spotlightPanel: SpotlightPanel, for host: RecordingHost) throws -> SpotlightPanel.Panel {
        _ = NSApplication.shared
        spotlightPanel.dataSource = host
        spotlightPanel.delegate = host

        let windowsBefore = Set(NSApp.windows.map(ObjectIdentifier.init))
        spotlightPanel.present()
        let openedWindow = NSApp.windows.first { !windowsBefore.contains(ObjectIdentifier($0)) }
        return try #require(openedWindow as? SpotlightPanel.Panel)
    }
}

/// Answers every non-empty query with two rows and an empty one with none, and remembers each
/// search term the panel reports.
private final class RecordingHost: SpotlightPanelDataSource, SpotlightPanelDelegate {
    private(set) var searchTermChanges: [String] = []

    func spotlightPanel(_ spotlightPanel: SpotlightPanel, itemsForSearchTask searchTask: SpotlightPanel.SearchTask) {
        searchTask.complete(with: searchTask.searchTerm.isEmpty ? [] : ["alpha", "beta"])
    }

    func spotlightPanel(_ spotlightPanel: SpotlightPanel, viewForItem item: AnyHashable, searchTerm: String) -> NSView? {
        NSTextField(labelWithString: "\(item)")
    }

    func spotlightPanel(_ spotlightPanel: SpotlightPanel, searchTermDidChange searchTerm: String) {
        searchTermChanges.append(searchTerm)
    }
}

#endif
