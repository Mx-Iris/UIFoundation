#if canImport(CoreGraphics)

import CoreGraphics
import FrameworkToolbox

extension CGSize: FrameworkToolboxCompatible {}

extension FrameworkToolbox where Base == CGSize {
    public static var max: CGSize {
        .init(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
    }
}

#endif
