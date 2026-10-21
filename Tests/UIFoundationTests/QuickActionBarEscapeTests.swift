#if QuickActionBar && os(macOS)

import AppKit
import Carbon.HIToolbox
import Testing
@testable import UIFoundationAppKit

/// Escape, the way Spotlight handles it on macOS 27.2: a query is cleared first, which collapses
/// the results it produced, and only an Escape on an empty field closes the bar.
///
/// Escape in the search field and Tab are real key-down events sent into the bar's window, so the
/// field editor itself turns them into commands and AppKit routes them along the responder chain.
/// From the results list the test starts one step later, at the `cancelOperation:` the window
/// derives from Escape (see that test); the table then hands it to every responder above it that
/// implements it. `resumePresentation()` is the observable for "a dismissal started": it only
/// answers `true` while the bar is on its way out.
///
/// These live in the presentation suite rather than a suite of their own because that one is
/// serialized: presenting a bar makes it key, and a bar closes when it stops being key, so two
/// suites presenting bars side by side would close each other's.
@MainActor
extension QuickActionBarPresentationTests {
    @Test("Escape with a query clears it and keeps the bar presented")
    func escapeClearsQuery() throws {
        guard NSScreen.main != nil else { return }

        let contentSource = RecordingContentSource.make()
        let actionBar = makeActionBar(contentSource: contentSource, initialSearchText: "xcode")
        defer { actionBar.cancel() }
        let window = try #require(actionBar.quickActionBarWindow)

        window.sendEvent(keyDownEvent(.escape, in: window))

        #expect(actionBar.currentSearchText == "")
        #expect(contentSource.searchedTerms.last == "")
        #expect(!actionBar.resumePresentation())
    }

    @Test("Escape on an empty query starts closing the bar")
    func escapeOnEmptyQueryCloses() throws {
        guard NSScreen.main != nil else { return }

        let actionBar = makeActionBar(contentSource: RecordingContentSource.make(), initialSearchText: nil)
        defer { actionBar.cancel() }
        let window = try #require(actionBar.quickActionBarWindow)

        window.sendEvent(keyDownEvent(.escape, in: window))

        #expect(actionBar.resumePresentation())
    }

    @Test("Escape from the results list clears the query and gives the search field its focus back")
    func escapeFromResultsList() throws {
        guard NSScreen.main != nil else { return }

        let actionBar = makeActionBar(contentSource: RecordingContentSource.make(), initialSearchText: "xcode")
        defer { actionBar.cancel() }
        let window = try #require(actionBar.quickActionBarWindow)
        actionBar.provideResultIdentifiers(["alpha", "beta"])

        window.sendEvent(keyDownEvent(.tab, in: window))
        let resultsTable = try #require(window.firstResponder as? NSTableView)

        // Escape is a key-down only for a text view. For any other first responder the window
        // derives `cancelOperation:` from it, in `-[NSWindow keyDown:]`'s keyboard-UI step — which
        // does nothing in this process: a key-down Escape sent to the table here changes nothing at
        // all (measured; the bar is never key and the app never active). So the test sends the
        // derived command to the table itself, and the walk from the table to the bar's window is
        // AppKit's own.
        resultsTable.doCommand(by: #selector(NSResponder.cancelOperation(_:)))

        #expect(actionBar.currentSearchText == "")
        #expect((window.firstResponder as? NSTextView)?.isFieldEditor == true)
    }

    // MARK: - Helpers

    private func makeActionBar(
        contentSource: RecordingContentSource,
        initialSearchText: String?
    ) -> QuickActionBar {
        _ = NSApplication.shared
        let actionBar = QuickActionBar()
        actionBar.contentSource = contentSource
        actionBar.present(initialSearchText: initialSearchText, width: 480, height: 240)
        return actionBar
    }

    private enum Key {
        case escape
        case tab

        var characters: String {
            switch self {
            case .escape: "\u{1B}"
            case .tab: "\t"
            }
        }

        var keyCode: UInt16 {
            switch self {
            case .escape: UInt16(kVK_Escape)
            case .tab: UInt16(kVK_Tab)
            }
        }
    }

    private func keyDownEvent(_ key: Key, in window: NSWindow) -> NSEvent {
        NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: [],
            timestamp: ProcessInfo.processInfo.systemUptime,
            windowNumber: window.windowNumber,
            context: nil,
            characters: key.characters,
            charactersIgnoringModifiers: key.characters,
            isARepeat: false,
            keyCode: key.keyCode
        )!
    }
}

/// Answers every non-empty query with two rows and an empty one with none, the way StarLight and
/// RuntimeViewer do, and remembers each term it was asked for.
///
/// Every instance is kept alive for the rest of the run. The bar holds its content source weakly
/// and delivers results on a later main-queue turn, after a test has returned; its results view
/// traps if the content source is gone by then, so a source released with its test would crash the
/// run instead of failing an expectation.
private final class RecordingContentSource: NSObject, QuickActionBarContentSource {
    @MainActor private static var everyInstance: [RecordingContentSource] = []

    @MainActor static func make() -> RecordingContentSource {
        let contentSource = RecordingContentSource()
        everyInstance.append(contentSource)
        return contentSource
    }

    private(set) var searchedTerms: [String] = []

    func quickActionBar(_ quickActionBar: QuickActionBar, itemsForSearchTermTask task: QuickActionBar.SearchTask) {
        searchedTerms.append(task.searchTerm)
        task.complete(with: task.searchTerm.isEmpty ? [] : ["alpha", "beta"])
    }

    func quickActionBar(_ quickActionBar: QuickActionBar, viewForItem item: AnyHashable, searchTerm: String) -> NSView? {
        NSTextField(labelWithString: "\(item)")
    }

    func quickActionBar(_ quickActionBar: QuickActionBar, didActivateItem item: AnyHashable) {}
}

#endif
