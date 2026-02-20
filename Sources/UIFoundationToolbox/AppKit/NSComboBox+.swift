#if canImport(AppKit) && !targetEnvironment(macCatalyst)

import AppKit
import FrameworkToolbox

extension FrameworkToolbox where Base: NSComboBox {
    @inlinable
    public var comboBoxCell: NSComboBoxCell? { typedCell() }
}


#endif
