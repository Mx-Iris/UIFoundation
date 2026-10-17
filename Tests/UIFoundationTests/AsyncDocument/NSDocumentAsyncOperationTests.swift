#if canImport(AppKit) && !targetEnvironment(macCatalyst)

import AppKit
import Testing
import UIFoundationToolbox
@testable import UIFoundationAppKit

/// The `.box` operations that run without presenting anything. The others -- the save panel,
/// page layout, printing, error sheets -- need a person to dismiss what they present, and share
/// the callback plumbing exercised here.
@Suite("NSDocument.box async operations", .serialized)
@MainActor
struct NSDocumentAsyncOperationTests {
    init() {
        _ = NSApplication.shared
    }

    @Test("canClose() answers true for a document without changes")
    func canCloseUnedited() async throws {
        let document = AsyncDocumentSample()
        #expect(await document.box.canClose())
    }

    @Test("canClose() autosaves an edited document that autosaves in place, then answers true")
    func canCloseAutosaves() async throws {
        let url = asyncDocumentTemporaryFileURL()
        defer { try? FileManager.default.removeItem(at: url) }
        try AsyncDocumentSampleFile.data(for: "on disk").write(to: url)

        let document = try AutosavingAsyncDocumentSample(contentsOf: url, ofType: asyncDocumentSampleType)
        document.text = "edited"
        document.updateChangeCount(.changeDone)

        #expect(await document.box.canClose())
        #expect(try AsyncDocumentSampleFile.parse(Data(contentsOf: url)).body == "edited")
    }

    @Test("save() saves an edited document to its file and answers true")
    func saveInPlace() async throws {
        let url = asyncDocumentTemporaryFileURL()
        defer { try? FileManager.default.removeItem(at: url) }
        try AsyncDocumentSampleFile.data(for: "on disk").write(to: url)

        let document = try AsyncDocumentSample(contentsOf: url, ofType: asyncDocumentSampleType)
        document.text = "edited"
        document.updateChangeCount(.changeDone)

        #expect(await document.box.save())
        #expect(try AsyncDocumentSampleFile.parse(Data(contentsOf: url)).body == "edited")
        #expect(!document.isDocumentEdited)
    }

    @Test("shouldCloseWindowController(_:) answers like canClose() for the document's only window controller")
    func shouldCloseOnlyWindowController() async throws {
        let document = AsyncDocumentSample()
        let windowController = NSWindowController(window: NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 200, height: 100),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: true
        ))
        document.addWindowController(windowController)
        defer { document.removeWindowController(windowController) }

        #expect(await document.box.shouldCloseWindowController(windowController))
    }
}

#endif
