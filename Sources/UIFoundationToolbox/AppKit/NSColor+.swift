#if canImport(AppKit) && !targetEnvironment(macCatalyst)

import AppKit
import FrameworkToolbox

extension FrameworkToolbox where Base: NSColor {
    #if canImport(CoreImage)
    public var ciColor: CIColor {
        CIColor(cgColor: base.cgColor)
    }
    #endif
}

#endif
