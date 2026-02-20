#if canImport(AppKit) && !targetEnvironment(macCatalyst)

import AppKit
import FrameworkToolbox

extension FrameworkToolbox where Base: NSPopUpButton {
    @inlinable
    public var popUpButtonCell: NSPopUpButtonCell? { typedCell() }
}


#endif
