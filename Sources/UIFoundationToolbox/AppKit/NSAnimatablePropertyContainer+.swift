#if canImport(AppKit) && !targetEnvironment(macCatalyst)

import AppKit
import FrameworkToolbox

extension FrameworkToolbox where Base: NSAnimatablePropertyContainer {
    /// Returns either a proxy object for the receiver for animation or the receiver.
    ///
    /// - Parameter animated: A Boolean value that indicates whether to return the animator proxy object or the receiver.
    public func animator(_ animate: Bool) -> Base {
        animate ? base.animator() : base
    }
}


#endif
