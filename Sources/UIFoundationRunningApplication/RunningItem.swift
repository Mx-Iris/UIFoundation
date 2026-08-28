#if RunningApplication && os(macOS)

import AppKit

public protocol RunningItem: Hashable, Sendable {
    var processIdentifier: pid_t { get }
    var name: String { get }
    var icon: NSImage? { get }
    var architecture: Architecture? { get }
    var isSandboxed: Bool { get }
    /// The platform the item's binary was built for, or nil when it cannot be determined
    /// — typically a protected system process whose executable path is unreadable.
    var platform: Platform? { get }
}

public extension RunningItem {
    /// Defaulted so that adding this requirement does not break types outside the library
    /// that already conform. Both of the library's own conformers supply a real value.
    var platform: Platform? { nil }
}

#endif
