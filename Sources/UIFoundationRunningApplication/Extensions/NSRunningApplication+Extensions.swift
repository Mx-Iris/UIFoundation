#if RunningApplication && os(macOS)

import AppKit

extension NSRunningApplication {
    var architecture: Architecture? {
        BSDProcess.architecture(for: processIdentifier)
    }
    
    var isSandboxed: Bool {
        BSDProcess.isSandboxed(pid: processIdentifier)
    }
}

#endif
