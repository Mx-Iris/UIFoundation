#if canImport(AppKit) && !targetEnvironment(macCatalyst)

import AppKit
import FrameworkToolbox

extension FrameworkToolbox where Base: NSLevelIndicator {
    @inlinable
    public var levelIndicatorCell: NSLevelIndicatorCell? { typedCell() }
}


#endif
