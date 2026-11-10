import Combine
import Foundation
@testable import UIFoundationWindowedRows

/// A row whose content says which source row it is.
struct NumberedRow: Sendable, Equatable {
    let index: Int
    let text: String

    init(index: Int) {
        self.index = index
        self.text = "row \(index)"
    }

    init(index: Int, text: String) {
        self.index = index
        self.text = text
    }

    static let placeholder = NumberedRow(index: -1, text: "")
}

/// Records every range a source was asked for, and on which thread.
final class FetchRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var storedRanges: [Range<Int>] = []
    private var storedMainThreadFetchCount = 0

    func record(_ range: Range<Int>) {
        lock.lock()
        defer { lock.unlock() }
        storedRanges.append(range)
        if Thread.isMainThread {
            storedMainThreadFetchCount += 1
        }
    }

    var ranges: [Range<Int>] {
        lock.lock()
        defer { lock.unlock() }
        return storedRanges
    }

    var mainThreadFetchCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return storedMainThreadFetchCount
    }
}

/// A source of `rowCount` numbered rows that records its fetches.
func makeNumberedSource(
    rowCount: Int,
    recorder: FetchRecorder? = nil,
    isPrewarmCandidate: Bool = false,
    text: @escaping @Sendable (Int) -> String = { "row \($0)" }
) -> WindowedRowSource<NumberedRow> {
    WindowedRowSource(
        totalCount: rowCount,
        fetch: { range in
            recorder?.record(range)
            return range.map { NumberedRow(index: $0, text: text($0)) }
        },
        isPrewarmCandidate: isPrewarmCandidate
    )
}

/// A scheduler whose time only moves when a test advances it.
final class ManualTestScheduler: WindowedRowsScheduler, @unchecked Sendable {
    private struct ScheduledWork {
        let identifier: Int
        let dueAtMilliseconds: Int
        let work: @MainActor () -> Void
        var isCancelled = false
    }

    private final class Token: Cancellable {
        private weak var scheduler: ManualTestScheduler?
        private let identifier: Int

        init(scheduler: ManualTestScheduler, identifier: Int) {
            self.scheduler = scheduler
            self.identifier = identifier
        }

        func cancel() {
            scheduler?.cancelWork(identifier: identifier)
        }
    }

    private let lock = NSLock()
    private var nowMilliseconds = 0
    private var nextIdentifier = 0
    private var scheduledWork: [ScheduledWork] = []

    @discardableResult
    func schedule(afterMilliseconds milliseconds: Int, _ work: @escaping @MainActor () -> Void) -> any Cancellable {
        lock.lock()
        defer { lock.unlock() }
        let identifier = nextIdentifier
        nextIdentifier += 1
        scheduledWork.append(ScheduledWork(
            identifier: identifier,
            dueAtMilliseconds: nowMilliseconds + max(0, milliseconds),
            work: work
        ))
        return Token(scheduler: self, identifier: identifier)
    }

    /// Moves time forward and runs the work that has fallen due, earliest first.
    @MainActor
    func advance(byMilliseconds milliseconds: Int) {
        lock.lock()
        nowMilliseconds += max(0, milliseconds)
        let now = nowMilliseconds
        let dueWork = scheduledWork
            .filter { !$0.isCancelled && $0.dueAtMilliseconds <= now }
            .sorted { $0.dueAtMilliseconds == $1.dueAtMilliseconds ? $0.identifier < $1.identifier : $0.dueAtMilliseconds < $1.dueAtMilliseconds }
        let dueIdentifiers = Set(dueWork.map(\.identifier))
        scheduledWork.removeAll { dueIdentifiers.contains($0.identifier) }
        lock.unlock()
        for item in dueWork {
            item.work()
        }
    }

    var pendingWorkCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return scheduledWork.filter { !$0.isCancelled }.count
    }

    fileprivate func cancelWork(identifier: Int) {
        lock.lock()
        defer { lock.unlock() }
        if let position = scheduledWork.firstIndex(where: { $0.identifier == identifier }) {
            scheduledWork[position].isCancelled = true
        }
    }
}

/// Waits, without blocking the main actor, until `condition` holds; returns
/// whether it did within the timeout.
@MainActor
func waitUntil(timeoutMilliseconds: Int = 5_000, _ condition: @MainActor () -> Bool) async -> Bool {
    let deadline = ProcessInfo.processInfo.systemUptime + Double(timeoutMilliseconds) / 1_000
    while !condition() {
        if ProcessInfo.processInfo.systemUptime >= deadline {
            return false
        }
        try? await Task.sleep(nanoseconds: 1_000_000)
    }
    return true
}
