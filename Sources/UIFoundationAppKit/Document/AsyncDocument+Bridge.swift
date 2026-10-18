#if canImport(AppKit) && !targetEnvironment(macCatalyst)

import AppKit
import OSToolbox

/// How `AsyncDocument` runs `async` code from NSDocument's synchronous hooks.
///
/// NSDocument calls its reading and writing hooks synchronously and expects them to have finished
/// when they return, so every bridge below parks the calling thread and lets a task -- or a block
/// on the main thread -- fill in the outcome. Producer and consumer are never the same thread,
/// hence the `Mutex`.
enum AsyncDocumentBridge {
    /// Runs `operation` on the global concurrent executor and blocks the calling thread until it
    /// finishes.
    ///
    /// Safe on any thread, the main thread included, **as long as `operation` never needs the
    /// thread being blocked**: a nonisolated operation that hops to the main actor while the main
    /// thread waits here never finishes. That is the contract `AsyncDocument` states for
    /// `write(_:to:context:)` and `readSnapshot(from:ofType:)`.
    static func runDetachedAndWait<Value: Sendable>(
        _ operation: @escaping @Sendable () async throws -> Value
    ) throws -> Value {
        let outcome = Mutex<Result<Value, any Error>?>(nil)
        let semaphore = DispatchSemaphore(value: 0)
        Task.detached(priority: Task.currentPriority) {
            let result: Result<Value, any Error>
            do {
                result = .success(try await operation())
            } catch {
                result = .failure(error)
            }
            outcome.withLock { $0 = result }
            semaphore.signal()
        }
        semaphore.wait()
        return try outcome.withLock { $0.take() }!.get()
    }

    /// Runs `work` on the main thread and blocks the calling (non-main) thread until it returns.
    ///
    /// Goes through `continueAsynchronousWorkOnMainThread(_:)` rather than the main queue: that is
    /// the one channel NSDocument keeps serviced while it holds the main thread inside its own
    /// synchronous waits (file access, activities). The main queue -- and with it every
    /// `@MainActor` job -- is not serviced there. See
    /// `Researchs/AppKit-NSDocument-AsyncReadingAndWriting-Internals.md`.
    ///
    /// There is no time limit: the main thread is either free, or inside one of NSDocument's waits
    /// that run this block. The one wait known to do neither is the Versions browser's, covered in
    /// the guide.
    static func performOnMainThreadAndWait<Value: Sendable>(
        for document: NSDocument,
        _ work: @escaping @MainActor () throws -> Value
    ) throws -> Value {
        let outcome = Mutex<Result<Value, any Error>?>(nil)
        let semaphore = DispatchSemaphore(value: 0)
        document.continueAsynchronousWorkOnMainThread {
            let result = Result { try MainActor.assumeIsolated(work) }
            outcome.withLock { $0 = result }
            semaphore.signal()
        }
        semaphore.wait()
        return try outcome.withLock { $0.take() }!.get()
    }
}

#endif
