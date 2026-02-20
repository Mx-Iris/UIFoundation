#if canImport(AppKit) && !targetEnvironment(macCatalyst)

import AppKit
import FrameworkToolbox

extension FrameworkToolbox where Base: NSSlider {
    @inlinable
    public var sliderCell: NSSliderCell? { typedCell() }
}


#endif
