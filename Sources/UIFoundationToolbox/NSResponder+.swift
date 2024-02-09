//
//  NSResponder+.swift
//
//
//  Created by Florian Zand on 14.11.22.
//

#if os(macOS)
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
