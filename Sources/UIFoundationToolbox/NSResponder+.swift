#if canImport(AppKit) && !targetEnvironment(macCatalyst)

import AppKit
import FrameworkToolbox

extension FrameworkToolbox where Base: NSResponder {
    /// Returns the respnder chain including itself.
    public func responderChain() -> [NSResponder] {
        var current: NSResponder = base
        var chain: [NSResponder] = [base]
        while let nextResponder = current.nextResponder {
            chain.append(nextResponder)
            current = nextResponder
        }
        return chain
    }
}

#endif
