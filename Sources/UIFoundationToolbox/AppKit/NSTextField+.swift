#if canImport(AppKit) && !targetEnvironment(macCatalyst)

import AppKit
import FrameworkToolbox

extension FrameworkToolbox where Base: NSTextField {
    @inlinable
    public var textFieldCell: NSTextFieldCell? { typedCell() }
}


#endif
