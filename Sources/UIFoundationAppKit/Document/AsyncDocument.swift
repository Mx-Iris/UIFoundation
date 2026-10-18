#if canImport(AppKit) && !targetEnvironment(macCatalyst)

import AppKit
import OSToolbox

/// An `NSDocument` whose contents are read and written by `async` code off the main thread.
///
/// The main actor only copies values out of the document and puts values back into it;
/// everything that touches the disk runs on the global concurrent executor. A subclass
/// implements four methods:
///
/// | When | Method | Runs |
/// |---|---|---|
/// | Saving | ``snapshot(ofType:for:)`` | main actor, synchronous |
/// | Saving | ``write(_:to:context:)`` | off the main actor, `async` |
/// | Opening, reverting | ``readSnapshot(from:ofType:)`` | off the main actor, `async` |
/// | Opening, reverting | ``apply(_:ofType:)`` | main actor, synchronous |
///
/// ```swift
/// final class NoteDocument: AsyncDocument<String> {
///     var text = ""
///
///     override class var autosavesInPlace: Bool { true }
///
///     override func snapshot(ofType typeName: String, for saveOperation: SaveOperationType) throws -> String {
///         text
///     }
///
///     nonisolated override func write(_ snapshot: String, to url: URL, context: WriteContext) async throws {
///         try Data(snapshot.utf8).write(to: url)
///     }
///
///     nonisolated override func readSnapshot(from url: URL, ofType typeName: String) async throws -> String {
///         String(decoding: try Data(contentsOf: url), as: UTF8.self)
///     }
///
///     override func apply(_ snapshot: String, ofType typeName: String) throws {
///         text = snapshot
///     }
/// }
/// ```
///
/// ## When the snapshot is taken
///
/// NSDocument takes its change-count token on the main thread, then asks
/// ``canAsynchronouslyWrite(to:ofType:for:)``, then blocks the main thread until the writer calls
/// `unblockUserInteraction()`. The snapshot is taken inside that question, so no user event can
/// fall between the token and the snapshot, and the writer releases the main thread as soon as it
/// starts: an edit made while the file is being written is neither in the file nor marked saved.
///
/// A document that does not autosave in place gets no token at all, and NSDocument then marks
/// every edit made before the save completes as saved. For those documents this class answers
/// `false` and NSDocument writes synchronously: ``write(_:to:context:)`` still runs off the main
/// actor, but the main thread waits for it, exactly as it does for a plain `NSDocument`. Override
/// `autosavesInPlace` to `true` to save without making the user wait.
///
/// ## Contracts
///
/// - ``write(_:to:context:)`` and ``readSnapshot(from:ofType:)`` must never hop to the main actor.
///   On several of NSDocument's paths -- reverting, duplicating, saving a document that does not
///   autosave in place, waiting for file access -- the main thread is the one waiting for them,
///   and the hop never completes.
/// - ``snapshot(ofType:for:)`` runs while NSDocument blocks user input. Copy values; encode them in
///   ``write(_:to:context:)``.
/// - When `NSDocumentController` opens documents concurrently, the initializer runs on its
///   "NSDocumentController Opening" queue, not on the main thread. See ``init()``.
///
/// NSDocument's own data and file-wrapper hooks are sealed: this class never calls them, and
/// `final` turns an override carried over from a plain `NSDocument` subclass into a compile error
/// instead of dead code.
///
/// The guide, with the full list of contracts and the measurements behind them, is
/// `Documentations/AsyncDocument.md`.
@MainActor
open class AsyncDocument<Snapshot: Sendable>: NSDocument {
    /// What ``write(_:to:context:)`` needs to know besides the snapshot.
    public struct WriteContext: Sendable {
        /// The type to write, as `write(to:ofType:for:originalContentsURL:)` received it.
        public let typeName: String
        /// The kind of save in progress.
        public let saveOperation: NSDocument.SaveOperationType
        /// Where the document's current contents are, for writers that reuse unchanged parts of a
        /// package. `nil` when the document has never been saved.
        public let originalContentsURL: URL?
    }

    /// The snapshot ``canAsynchronouslyWrite(to:ofType:for:)`` took for the save in flight,
    /// waiting for the background writer to collect it.
    private nonisolated let pendingSnapshot = Mutex<Result<Snapshot, any Error>?>(nil)

    /// Creates an empty document.
    ///
    /// Nonisolated because AppKit calls it off the main thread: when it opens documents
    /// concurrently (see ``canConcurrentlyReadDocuments(ofType:)``), `NSDocumentController` creates
    /// them on its "NSDocumentController Opening" queue. NSDocument's own `init()` is imported as
    /// main-actor isolated, and in the Swift 6 language mode an initializer that inherits that
    /// isolation gets a main-thread assertion in its Objective-C entry point -- the entry AppKit
    /// uses. Declared here, a subclass's `init()`, written out or synthesized, inherits
    /// `nonisolated` instead and has no assertion (checked in SILGen output, Swift 6.4.2).
    ///
    /// The call to `super.init()` below warns, and nothing silences it: in the Swift 5 language
    /// mode the call is an error downgraded to a warning, which neither `@preconcurrency` nor
    /// `@diagnose(ActorIsolatedCall, as: ignored)` (SE-0522) reaches.
    public nonisolated override init() {
        super.init()
    }

    // MARK: - Subclass hooks

    /// Copies out everything a save writes.
    ///
    /// Main actor, synchronous, called while NSDocument blocks user input. Keep it to copying
    /// values; do the encoding in ``write(_:to:context:)``. A thrown error fails the save.
    open func snapshot(ofType typeName: String, for saveOperation: SaveOperationType) throws -> Snapshot {
        throw Self.missingOverride("snapshot(ofType:for:)")
    }

    /// Writes `snapshot` to `url`.
    ///
    /// Runs off the main actor and must never hop to it. `url` is usually a temporary location
    /// NSDocument moves into place afterwards, not the document's `fileURL`.
    nonisolated open func write(_ snapshot: Snapshot, to url: URL, context: WriteContext) async throws {
        throw Self.missingOverride("write(_:to:context:)")
    }

    /// Reads a snapshot from `url`.
    ///
    /// Runs off the main actor and must never hop to it.
    nonisolated open func readSnapshot(from url: URL, ofType typeName: String) async throws -> Snapshot {
        throw Self.missingOverride("readSnapshot(from:ofType:)")
    }

    /// Replaces the document's contents with `snapshot`.
    ///
    /// Main actor, synchronous. A thrown error fails the open or the revert that read the snapshot.
    open func apply(_ snapshot: Snapshot, ofType typeName: String) throws {
        throw Self.missingOverride("apply(_:ofType:)")
    }

    // MARK: - Policy

    /// `true`: documents are created and read on `NSDocumentController`'s opening queue, and only
    /// ``apply(_:ofType:)`` comes to the main thread.
    ///
    /// Overriding this is safe -- reading works on either thread. Answer `false` when the
    /// document's initializer cannot run off the main thread, or to keep the Versions browser from
    /// preloading versions in the background (a known, unreproduced risk; see the guide).
    open override class func canConcurrentlyReadDocuments(ofType typeName: String) -> Bool {
        true
    }

    // MARK: - NSDocument plumbing

    /// Takes the snapshot for the save NSDocument is about to dispatch, and answers whether the
    /// write may run while the user keeps editing -- only for documents that autosave in place.
    public final override func canAsynchronouslyWrite(
        to url: URL,
        ofType typeName: String,
        for saveOperation: SaveOperationType
    ) -> Bool {
        guard type(of: self).autosavesInPlace else { return false }
        // Taken before locking: the subclass's code must never run with the lock held.
        let snapshotResult = Result { try snapshot(ofType: typeName, for: saveOperation) }
        pendingSnapshot.withLock { $0 = snapshotResult }
        return true
    }

    /// Writes the save's snapshot through ``write(_:to:context:)``.
    nonisolated public final override func write(
        to url: URL,
        ofType typeName: String,
        for saveOperation: SaveOperationType,
        originalContentsURL absoluteOriginalContentsURL: URL?
    ) throws {
        let snapshot = try takeSnapshot(ofType: typeName, for: saveOperation)
        // The snapshot is all the write needs from the main thread. A no-op when NSDocument is
        // writing synchronously.
        unblockUserInteraction()
        let context = WriteContext(
            typeName: typeName,
            saveOperation: saveOperation,
            originalContentsURL: absoluteOriginalContentsURL
        )
        try AsyncDocumentBridge.runDetachedAndWait {
            try await self.write(snapshot, to: url, context: context)
        }
    }

    /// Reads through ``readSnapshot(from:ofType:)``, then applies on the main thread through
    /// ``apply(_:ofType:)``.
    nonisolated public final override func read(from url: URL, ofType typeName: String) throws {
        let snapshot = try AsyncDocumentBridge.runDetachedAndWait {
            try await self.readSnapshot(from: url, ofType: typeName)
        }
        if Thread.isMainThread {
            // Reverting, or opening without concurrency: NSDocument holds the main thread and
            // expects the document to be up to date when this returns.
            try MainActor.assumeIsolated { try apply(snapshot, ofType: typeName) }
        } else {
            try AsyncDocumentBridge.performOnMainThreadAndWait(for: self) {
                try self.apply(snapshot, ofType: typeName)
            }
        }
    }

    private nonisolated func takeSnapshot(ofType typeName: String, for saveOperation: SaveOperationType) throws -> Snapshot {
        if Thread.isMainThread {
            // A synchronous write: `canAsynchronouslyWrite` answered `false`, or a path such as
            // duplicating or sharing never asked. Nothing has run since the save began, so take a
            // fresh one; a snapshot left by a save that never reached its write must not be written
            // by this one.
            _ = pendingSnapshot.withLock { $0.take() }
            return try MainActor.assumeIsolated { try snapshot(ofType: typeName, for: saveOperation) }
        }
        if let pending = pendingSnapshot.withLock({ $0.take() }) {
            return try pending.get()
        }
        // Not reachable through NSDocument's own save path, which always asks
        // `canAsynchronouslyWrite` right before dispatching the writer. The main thread may be
        // blocked until this writer releases it, so release it before asking it for anything.
        unblockUserInteraction()
        return try AsyncDocumentBridge.performOnMainThreadAndWait(for: self) {
            try self.snapshot(ofType: typeName, for: saveOperation)
        }
    }

    // MARK: - Sealed NSDocument hooks

    /// Sealed: never called. This class reads through ``readSnapshot(from:ofType:)``.
    nonisolated public final override func read(from data: Data, ofType typeName: String) throws {
        throw Self.sealedHook("read(from:ofType:) with Data", replacement: "readSnapshot(from:ofType:)")
    }

    /// Sealed: never called. This class reads through ``readSnapshot(from:ofType:)``.
    nonisolated public final override func read(from fileWrapper: FileWrapper, ofType typeName: String) throws {
        throw Self.sealedHook("read(from:ofType:) with FileWrapper", replacement: "readSnapshot(from:ofType:)")
    }

    /// Sealed: never called. This class writes through ``write(_:to:context:)``.
    public final override func data(ofType typeName: String) throws -> Data {
        throw Self.sealedHook("data(ofType:)", replacement: "write(_:to:context:)")
    }

    /// Sealed: never called. This class writes through ``write(_:to:context:)``.
    public final override func fileWrapper(ofType typeName: String) throws -> FileWrapper {
        throw Self.sealedHook("fileWrapper(ofType:)", replacement: "write(_:to:context:)")
    }

    /// Sealed: never called. This class writes through ``write(_:to:context:)``.
    nonisolated public final override func write(to url: URL, ofType typeName: String) throws {
        throw Self.sealedHook("write(to:ofType:)", replacement: "write(_:to:context:)")
    }

    // MARK: - Errors

    private nonisolated static func missingOverride(_ method: String) -> CocoaError {
        CocoaError(.featureUnsupported, userInfo: [
            NSDebugDescriptionErrorKey: "\(Self.self) must override \(method).",
        ])
    }

    private nonisolated static func sealedHook(_ method: String, replacement: String) -> CocoaError {
        CocoaError(.featureUnsupported, userInfo: [
            NSDebugDescriptionErrorKey: "AsyncDocument does not use \(method); override \(replacement) instead.",
        ])
    }
}

#endif
