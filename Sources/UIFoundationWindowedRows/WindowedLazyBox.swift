import Foundation

/// A value computed at most once, the first time it is read, from any thread.
///
/// A windowed source usually needs the same expensive collection in two
/// closures — the row count and the row fetch — and must not build it before a
/// table actually shows the source. Capture one box in both closures and read
/// ``value``: the resolver runs on the first read, and every later read returns
/// the stored result.
///
/// Fetches run on background tasks, several windows at once, so concurrent first
/// reads are normal. A lock guards both the slot and the resolver call, so the
/// resolver runs exactly once whatever the concurrency.
///
/// Once resolved, the box keeps only the value and drops the resolver, so
/// whatever the resolver captured is freed with it: an unsorted input array, the
/// collection a count expression read. Keeping the resolver kept both alive for
/// as long as the box lived — 8 MB for the 45,707 exports of one dyld shared
/// cache image in MachOKitUI.
public final class WindowedLazyBox<Value>: @unchecked Sendable {
    private enum State {
        case pending(() -> Value)
        case resolved(Value)
    }

    private let lock = NSLock()
    private var state: State

    public init(_ resolver: @escaping () -> Value) {
        state = .pending(resolver)
    }

    /// The value, computed by the resolver on the first read.
    public var value: Value {
        lock.lock()
        defer { lock.unlock() }
        switch state {
        case .resolved(let resolvedValue):
            return resolvedValue
        case .pending(let resolver):
            let resolvedValue = resolver()
            state = .resolved(resolvedValue)
            return resolvedValue
        }
    }
}
