#if RunningApplication && os(macOS)

import Foundation

/// A dictionary guarded by a lock, for caches shared between the main actor and the
/// background queues that populate process data.
final class ThreadSafeCache<Key: Hashable, Value>: @unchecked Sendable {
    private var storage: [Key: Value] = [:]
    private let lock = NSLock()

    subscript(key: Key) -> Value? {
        get { lock.withLock { storage[key] } }
        set { lock.withLock { storage[key] = newValue } }
    }
}

#endif
