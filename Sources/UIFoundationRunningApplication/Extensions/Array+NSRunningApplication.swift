#if RunningApplication && os(macOS)

import AppKit

extension [NSRunningApplication] {
    public func contains(bundleID: String) -> Bool {
        return self.contains(where: { $0.bundleIdentifier == bundleID })
    }

    public func first(bundleID: String) -> NSRunningApplication? {
        return self.first(where: { $0.bundleIdentifier == bundleID })
    }
}

#endif
