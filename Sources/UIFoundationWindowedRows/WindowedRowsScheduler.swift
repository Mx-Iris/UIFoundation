import Combine
import Foundation

/// Runs main-actor work after a delay; what a ``WindowedRowsController`` uses to
/// debounce keywords, merge visible-range reports and delay its loading
/// indicator.
///
/// The controller takes one so tests can replace time: a test scheduler that
/// runs the due work when the test advances a manual clock makes every timing
/// rule checkable without waiting.
public protocol WindowedRowsScheduler: Sendable {
    /// Runs `work` on the main actor after `milliseconds`, unless the returned
    /// token is cancelled first. `0` runs it on the next turn of the main actor.
    @discardableResult
    func schedule(afterMilliseconds milliseconds: Int, _ work: @escaping @MainActor () -> Void) -> any Cancellable
}

/// The scheduler a ``WindowedRowsController`` uses unless told otherwise: a task
/// that sleeps for the delay, then runs the work on the main actor.
public struct MainActorTaskScheduler: WindowedRowsScheduler {
    public init() {}

    @discardableResult
    public func schedule(afterMilliseconds milliseconds: Int, _ work: @escaping @MainActor () -> Void) -> any Cancellable {
        let token = TaskCancellationToken()
        let task = Task<Void, Never> {
            if milliseconds > 0 {
                do {
                    try await Task.sleep(nanoseconds: UInt64(milliseconds) * 1_000_000)
                } catch {
                    return
                }
            }
            if Task.isCancelled { return }
            await MainActor.run {
                work()
            }
        }
        token.task = task
        return token
    }
}

/// Cancels the task behind a scheduled piece of work.
private final class TaskCancellationToken: Cancellable, @unchecked Sendable {
    private let lock = NSLock()
    private var storedTask: Task<Void, Never>?

    var task: Task<Void, Never>? {
        get {
            lock.lock()
            defer { lock.unlock() }
            return storedTask
        }
        set {
            lock.lock()
            defer { lock.unlock() }
            storedTask = newValue
        }
    }

    func cancel() {
        task?.cancel()
    }
}
