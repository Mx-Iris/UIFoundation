#if canImport(AppKit) && !targetEnvironment(macCatalyst)

import AppKit
import FrameworkToolbox

extension FrameworkToolbox where Base: NSStepper {
    @inlinable
    public var stepperCell: NSStepperCell? { typedCell() }
}


#endif
