#if canImport(AppKit) && !targetEnvironment(macCatalyst)

import AppKit
import FrameworkToolbox

extension FrameworkToolbox where Base: NSTokenField {
    @inlinable
    public var tokenFieldCell: NSTokenFieldCell? { typedCell() }
}


#endif
