#if canImport(AppKit) && !targetEnvironment(macCatalyst)

import AppKit
import FrameworkToolbox

extension FrameworkToolbox where Base: NSPathControl {
    @inlinable
    public var pathCell: NSPathCell? { typedCell() }
}


#endif
