#if canImport(AppKit) && !targetEnvironment(macCatalyst)

import AppKit
import FrameworkToolbox

extension FrameworkToolbox where Base: NSBrowser {
    @inlinable
    public var browserCell: NSBrowserCell? { typedCell() }
}


#endif
