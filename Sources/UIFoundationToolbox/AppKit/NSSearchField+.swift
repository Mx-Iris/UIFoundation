#if canImport(AppKit) && !targetEnvironment(macCatalyst)

import AppKit
import FrameworkToolbox

extension FrameworkToolbox where Base: NSSearchField {
    @inlinable
    public var searchFieldCell: NSSearchFieldCell? { typedCell() }
}


#endif
