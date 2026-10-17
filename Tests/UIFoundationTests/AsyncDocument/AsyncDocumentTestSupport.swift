#if canImport(AppKit) && !targetEnvironment(macCatalyst)

import AppKit
@testable import UIFoundationAppKit

let asyncDocumentSampleType = "public.plain-text"

/// The sample document's file format: a header line recording the text's length, then the text.
///
/// A file whose header and body disagree was written from two different moments of the document,
/// which is what the save tests look for.
enum AsyncDocumentSampleFile {
    struct Contents {
        let declaredLength: Int
        let body: String

        var isConsistent: Bool { declaredLength == body.count }
    }

    static func header(for text: String) -> String {
        "length: \(text.count)"
    }

    static func data(header: String, body: String) -> Data {
        Data("\(header)\n\(body)".utf8)
    }

    static func data(for text: String) -> Data {
        data(header: header(for: text), body: text)
    }

    static func parse(_ data: Data) throws -> Contents {
        let string = String(decoding: data, as: UTF8.self)
        let prefix = "length: "
        guard string.hasPrefix(prefix),
              let newline = string.firstIndex(of: "\n"),
              let declaredLength = Int(string[string.index(string.startIndex, offsetBy: prefix.count)..<newline])
        else {
            throw CocoaError(.fileReadCorruptFile)
        }
        return Contents(declaredLength: declaredLength, body: String(string[string.index(after: newline)...]))
    }
}

/// A plain-text document written the way the guide tells subclasses to write one, plus hooks the
/// tests use to hold or fail each step.
class AsyncDocumentSample: AsyncDocument<String> {
    var text = ""

    /// Thrown by ``snapshot(ofType:for:)`` when set.
    var snapshotError: (any Error)?
    /// Thrown by ``apply(_:ofType:)`` when set.
    var applyError: (any Error)?
    /// Whether the last ``apply(_:ofType:)`` ran on the main thread.
    var applyRanOnMainThread: Bool?

    /// Awaited half way through writing -- after the header, before the body.
    nonisolated(unsafe) var duringWrite: (@Sendable () async throws -> Void)?
    /// Awaited before reading.
    nonisolated(unsafe) var beforeRead: (@Sendable () async throws -> Void)?
    /// Whether the last ``readSnapshot(from:ofType:)`` ran on the main thread.
    nonisolated(unsafe) var readSnapshotRanOnMainThread: Bool?

    override class var readableTypes: [String] { [asyncDocumentSampleType] }
    override class var writableTypes: [String] { [asyncDocumentSampleType] }
    override class func isNativeType(_ type: String) -> Bool { true }

    override func snapshot(ofType typeName: String, for saveOperation: SaveOperationType) throws -> String {
        if let snapshotError { throw snapshotError }
        return text
    }

    nonisolated override func write(_ snapshot: String, to url: URL, context: WriteContext) async throws {
        let header = AsyncDocumentSampleFile.header(for: snapshot)
        try await duringWrite?()
        try AsyncDocumentSampleFile.data(header: header, body: snapshot).write(to: url)
    }

    nonisolated override func readSnapshot(from url: URL, ofType typeName: String) async throws -> String {
        readSnapshotRanOnMainThread = isRunningOnMainThread()
        try await beforeRead?()
        return try AsyncDocumentSampleFile.parse(Data(contentsOf: url)).body
    }

    override func apply(_ snapshot: String, ofType typeName: String) throws {
        applyRanOnMainThread = Thread.isMainThread
        if let applyError { throw applyError }
        text = snapshot
    }
}

/// The same document, autosaving in place -- the configuration that saves asynchronously.
final class AutosavingAsyncDocumentSample: AsyncDocumentSample {
    override nonisolated class var autosavesInPlace: Bool { true }
    // Versions live in the system's revision store; nothing here is about them.
    override nonisolated class var preservesVersions: Bool { false }
}

/// `Thread.isMainThread`, callable from `async` code.
private func isRunningOnMainThread() -> Bool {
    Thread.isMainThread
}

/// Holds the code under test at a known point until the test releases it.
///
/// Both waits give up after five seconds, so code that never arrives, or a test that never opens
/// the gate, fails instead of hanging the run.
actor AsyncDocumentGate {
    private var isOpen = false
    private var hasArrival = false
    private var passageWaiters: [CheckedContinuation<Void, Never>] = []
    private var arrivalWaiters: [CheckedContinuation<Bool, Never>] = []

    /// Called by the code under test.
    func passThrough() async {
        hasArrival = true
        for waiter in arrivalWaiters {
            waiter.resume(returning: true)
        }
        arrivalWaiters.removeAll()
        guard !isOpen else { return }
        Task {
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            self.open()
        }
        await withCheckedContinuation { passageWaiters.append($0) }
    }

    /// Called by the test; `false` if the code under test never got there.
    func waitForArrival() async -> Bool {
        guard !hasArrival else { return true }
        Task {
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            self.stopWaitingForArrival()
        }
        return await withCheckedContinuation { arrivalWaiters.append($0) }
    }

    func open() {
        isOpen = true
        for waiter in passageWaiters {
            waiter.resume()
        }
        passageWaiters.removeAll()
    }

    private func stopWaitingForArrival() {
        for waiter in arrivalWaiters {
            waiter.resume(returning: false)
        }
        arrivalWaiters.removeAll()
    }
}

/// Runs `work` the way AppKit runs a menu action: from the main run loop, outside any main-queue
/// block.
@MainActor
func performAsMenuAction<Value>(_ work: @escaping @MainActor () -> Value) async -> Value {
    await withCheckedContinuation { continuation in
        RunLoop.main.perform(inModes: [.default]) {
            MainActor.assumeIsolated {
                continuation.resume(returning: work())
            }
        }
    }
}

func asyncDocumentTemporaryFileURL() -> URL {
    FileManager.default.temporaryDirectory
        .appendingPathComponent("AsyncDocumentTests-\(UUID().uuidString)")
        .appendingPathExtension("txt")
}

#endif
