#if canImport(AppKit) && !targetEnvironment(macCatalyst)

import AppKit
import Testing
@testable import UIFoundationAppKit

@Suite("AsyncDocument", .serialized)
@MainActor
struct AsyncDocumentTests {
    init() {
        _ = NSApplication.shared
    }

    // MARK: - Opening

    @Test("a document created and read off the main thread, as concurrent opening does, reads off it and applies on it")
    func concurrentOpening() async throws {
        let url = asyncDocumentTemporaryFileURL()
        defer { try? FileManager.default.removeItem(at: url) }
        try AsyncDocumentSampleFile.data(for: "hello").write(to: url)

        // NSDocumentController's opening queue runs `-init` and then `-readFromURL:ofType:error:`.
        // The sample's initializer is `nonisolated`, inherited from `AsyncDocument.init()`, so this
        // closure reaches it without hopping to the main actor. Take `nonisolated` off that
        // initializer and this line stops compiling ("main actor-isolated initializer 'init()'
        // cannot be called from outside of the actor") -- checked with Swift 6.4.2.
        let document = try await Task.detached {
            let document = AsyncDocumentSample()
            try document.read(from: url, ofType: asyncDocumentSampleType)
            return document
        }.value

        #expect(document.text == "hello")
        #expect(document.readSnapshotRanOnMainThread == false)
        #expect(document.applyRanOnMainThread == true)
    }

    @Test("an apply error fails a concurrent open")
    func applyErrorFailsConcurrentOpen() async throws {
        let url = asyncDocumentTemporaryFileURL()
        defer { try? FileManager.default.removeItem(at: url) }
        try AsyncDocumentSampleFile.data(for: "hello").write(to: url)

        let document = AsyncDocumentSample()
        document.applyError = CocoaError(.fileReadCorruptFile)
        let readError = await Task.detached { () -> (any Error)? in
            do {
                try document.read(from: url, ofType: asyncDocumentSampleType)
                return nil
            } catch {
                return error
            }
        }.value

        #expect((readError as? CocoaError)?.code == .fileReadCorruptFile)
        #expect(document.text == "")
    }

    // MARK: - Saving

    @Test("a save writes the snapshot, and the saved file opens again")
    func roundTrip() async throws {
        let url = asyncDocumentTemporaryFileURL()
        defer { try? FileManager.default.removeItem(at: url) }

        let document = AutosavingAsyncDocumentSample()
        document.text = "hello"
        try await document.save(to: url, ofType: asyncDocumentSampleType, for: .saveToOperation)

        let reopened = try AsyncDocumentSample(contentsOf: url, ofType: asyncDocumentSampleType)
        #expect(reopened.text == "hello")
    }

    @Test("an edit made while the file is being written stays out of the file")
    func editDuringSave() async throws {
        let url = asyncDocumentTemporaryFileURL()
        defer { try? FileManager.default.removeItem(at: url) }

        let document = AutosavingAsyncDocumentSample()
        let gate = AsyncDocumentGate()
        document.text = "first"
        document.duringWrite = { await gate.passThrough() }

        let save = Task {
            try await document.save(to: url, ofType: asyncDocumentSampleType, for: .saveToOperation)
        }
        let writerArrived = await gate.waitForArrival()
        #expect(writerArrived, "the writer never reached the middle of the file")
        // The main thread is free while the writer runs: this edit is a keystroke.
        document.text = "second edit"
        await gate.open()
        try await save.value

        let file = try AsyncDocumentSampleFile.parse(Data(contentsOf: url))
        #expect(file.isConsistent)
        #expect(file.body == "first")
    }

    @Test("a document that does not autosave in place keeps a keystroke made during a save unsaved")
    func keystrokeDuringNonAutosavingSave() async throws {
        let url = asyncDocumentTemporaryFileURL()
        defer { try? FileManager.default.removeItem(at: url) }

        let document = AsyncDocumentSample()
        document.text = "first"
        document.updateChangeCount(.changeDone)
        document.duringWrite = {
            // Queued while the write runs; it can only run once the main thread is free again.
            DispatchQueue.main.async {
                MainActor.assumeIsolated {
                    document.text += " + keystroke"
                    document.updateChangeCount(.changeDone)
                }
            }
            try await Task.sleep(nanoseconds: 300_000_000)
        }

        try await document.save(to: url, ofType: asyncDocumentSampleType, for: .saveAsOperation)
        // Let anything still queued on the main thread run.
        try await Task.sleep(nanoseconds: 200_000_000)

        let file = try AsyncDocumentSampleFile.parse(Data(contentsOf: url))
        #expect(file.isConsistent)
        #expect(file.body == "first")
        #expect(document.text == "first + keystroke")
        #expect(document.isDocumentEdited, "the keystroke is not in the file, so the document must still be edited")
    }

    @Test("a save finishes while the main thread waits for the document's file")
    func saveWhileMainThreadWaitsForFile() async throws {
        let url = asyncDocumentTemporaryFileURL()
        defer { try? FileManager.default.removeItem(at: url) }

        let document = AutosavingAsyncDocumentSample()
        let gate = AsyncDocumentGate()
        document.text = "first"
        document.duringWrite = { await gate.passThrough() }

        let save = Task {
            try await document.save(to: url, ofType: asyncDocumentSampleType, for: .saveToOperation)
        }
        let writerArrived = await gate.waitForArrival()
        #expect(writerArrived, "the writer never reached the middle of the file")

        Task.detached {
            try? await Task.sleep(nanoseconds: 100_000_000)
            await gate.open()
        }
        // NSDocument waits like this itself around reverting, autosaving and more. Sent as an
        // Objective-C message rather than called from Swift: when it has to wait,
        // `-performSynchronousFileAccessUsingBlock:` keeps the block past returning despite its
        // NS_NOESCAPE annotation, and Swift's escape check then traps ("closure argument passed as
        // @noescape to Objective-C has escaped"). Observed on macOS 27.2.
        let waitForFile: @convention(block) () -> Void = {}
        let start = Date()
        document.perform(#selector(NSDocument.performSynchronousFileAccess(_:)), with: waitForFile)
        let secondsMainThreadWaited = Date().timeIntervalSince(start)

        try await save.value
        #expect(secondsMainThreadWaited < 1)
    }

    @Test("a write NSDocument runs on the main thread takes a fresh snapshot, not one left by an earlier save")
    func mainThreadWriteTakesFreshSnapshot() throws {
        let url = asyncDocumentTemporaryFileURL()
        defer { try? FileManager.default.removeItem(at: url) }

        let document = AutosavingAsyncDocumentSample()
        document.text = "stale"
        // A save that asked, then never reached its write -- which NSDocument does when it fails
        // to preserve the previous version first.
        _ = document.canAsynchronouslyWrite(to: url, ofType: asyncDocumentSampleType, for: .saveToOperation)
        document.text = "fresh"

        // Duplicating and sharing write like this: synchronously, on the main thread.
        try document.writeSafely(to: url, ofType: asyncDocumentSampleType, for: .saveToOperation)

        #expect(try AsyncDocumentSampleFile.parse(Data(contentsOf: url)).body == "fresh")
    }

    // MARK: - Reverting

    @Test("reverting from a menu action holds the main thread until the file is applied")
    func revertFromMenuAction() async throws {
        let outcome = try await revert(calledFrom: .menuAction)
        #expect(outcome.error == nil)
        #expect(outcome.textAfterRevert == "on disk")
        #expect(!outcome.otherMainThreadWorkRanDuringRevert)
    }

    @Test("reverting from Swift main-actor code works the same")
    func revertFromMainActorCode() async throws {
        let outcome = try await revert(calledFrom: .mainActorCode)
        #expect(outcome.error == nil)
        #expect(outcome.textAfterRevert == "on disk")
        #expect(!outcome.otherMainThreadWorkRanDuringRevert)
    }

    private enum RevertCaller {
        /// From the main run loop, outside any main-queue block -- how AppKit delivers a menu
        /// action such as File > Revert To > Last Saved.
        case menuAction
        /// From a `@MainActor` function -- a `Task`, an `async` method -- which always runs inside
        /// a main-queue block.
        case mainActorCode
    }

    private struct RevertOutcome {
        let error: (any Error)?
        let textAfterRevert: String
        let otherMainThreadWorkRanDuringRevert: Bool
    }

    private final class MainQueueProbe {
        var isReverting = false
        var ranDuringRevert = false
    }

    /// Reverts a document from a file that takes a moment to read, with a block -- standing in for
    /// a click, a timer, another document's work -- waiting on the main queue the whole time.
    private func revert(calledFrom caller: RevertCaller) async throws -> RevertOutcome {
        let url = asyncDocumentTemporaryFileURL()
        defer { try? FileManager.default.removeItem(at: url) }
        try AsyncDocumentSampleFile.data(for: "on disk").write(to: url)

        let document = AutosavingAsyncDocumentSample()
        document.text = "in memory"
        document.beforeRead = { try await Task.sleep(nanoseconds: 200_000_000) }

        let probe = MainQueueProbe()
        let revertDocument: @MainActor () -> (any Error)? = {
            DispatchQueue.main.async {
                MainActor.assumeIsolated {
                    probe.ranDuringRevert = probe.isReverting
                }
            }
            probe.isReverting = true
            defer { probe.isReverting = false }
            do {
                try document.revert(toContentsOf: url, ofType: asyncDocumentSampleType)
                return nil
            } catch {
                return error
            }
        }

        let error: (any Error)?
        switch caller {
        case .menuAction:
            error = await performAsMenuAction(revertDocument)
        case .mainActorCode:
            error = revertDocument()
        }
        return RevertOutcome(
            error: error,
            textAfterRevert: document.text,
            otherMainThreadWorkRanDuringRevert: probe.ranDuringRevert
        )
    }

    // MARK: - Errors

    @Test("a snapshot error fails the save and nothing is written")
    func snapshotErrorFailsSave() async throws {
        let url = asyncDocumentTemporaryFileURL()
        defer { try? FileManager.default.removeItem(at: url) }

        let document = AutosavingAsyncDocumentSample()
        document.text = "unsaved"
        document.snapshotError = CocoaError(.fileWriteInapplicableStringEncoding)

        await #expect {
            try await document.save(to: url, ofType: asyncDocumentSampleType, for: .saveToOperation)
        } throws: { error in
            (error as? CocoaError)?.code == .fileWriteInapplicableStringEncoding
        }
        #expect(!FileManager.default.fileExists(atPath: url.path))
    }

    @Test("a write error fails the save and leaves the file as it was")
    func writeErrorFailsSave() async throws {
        let url = asyncDocumentTemporaryFileURL()
        defer { try? FileManager.default.removeItem(at: url) }
        try AsyncDocumentSampleFile.data(for: "on disk").write(to: url)

        let document = AutosavingAsyncDocumentSample()
        document.text = "unsaved"
        document.duringWrite = { throw CocoaError(.fileWriteNoPermission) }

        await #expect {
            try await document.save(to: url, ofType: asyncDocumentSampleType, for: .saveToOperation)
        } throws: { error in
            (error as? CocoaError)?.code == .fileWriteNoPermission
        }
        #expect(try AsyncDocumentSampleFile.parse(Data(contentsOf: url)).body == "on disk")
    }

    @Test("a read error fails the revert and leaves the document as it was")
    func readErrorFailsRevert() async throws {
        let url = asyncDocumentTemporaryFileURL()
        defer { try? FileManager.default.removeItem(at: url) }
        try AsyncDocumentSampleFile.data(for: "on disk").write(to: url)

        let document = AutosavingAsyncDocumentSample()
        document.text = "in memory"
        document.beforeRead = { throw CocoaError(.fileReadNoPermission) }

        let readError = await performAsMenuAction { () -> (any Error)? in
            do {
                try document.revert(toContentsOf: url, ofType: asyncDocumentSampleType)
                return nil
            } catch {
                return error
            }
        }
        #expect((readError as? CocoaError)?.code == .fileReadNoPermission)
        #expect(document.text == "in memory")
    }
}

#endif
