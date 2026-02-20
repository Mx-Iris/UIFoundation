#if canImport(AppKit) && !targetEnvironment(macCatalyst)

import AppKit
import FrameworkToolbox

extension FrameworkToolbox where Base: NSDatePicker {
    @inlinable
    public var datePickerCell: NSDatePickerCell? { typedCell() }
}


#endif
