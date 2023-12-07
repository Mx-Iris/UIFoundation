#if canImport(AppKit) && !targetEnvironment(macCatalyst)

import AppKit
import FrameworkToolbox

extension FrameworkToolbox where Base == NSRect {
    public func inset(by insets: NSEdgeInsets) -> NSRect {
        return NSRect(
            x: base.origin.x + insets.left,
            y: base.origin.y + insets.top,
            width: base.width - (insets.left + insets.right),
            height: base.height - (insets.top + insets.bottom)
        )
    }
}

extension NSRect: FrameworkToolboxCompatible {}

#endif
