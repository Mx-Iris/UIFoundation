#if canImport(AppKit) && !targetEnvironment(macCatalyst)

import AppKit
import FrameworkToolbox

extension FrameworkToolbox where Base: NSSegmentedControl {
    @inlinable
    public var segmentedCell: NSSegmentedCell? { typedCell() }
}


#endif
