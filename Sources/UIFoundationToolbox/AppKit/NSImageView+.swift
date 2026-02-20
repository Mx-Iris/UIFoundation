#if canImport(AppKit) && !targetEnvironment(macCatalyst)

import AppKit
import FrameworkToolbox

extension FrameworkToolbox where Base: NSImageView {
    @inlinable
    public var imageCell: NSImageCell? { typedCell() }
}


#endif
