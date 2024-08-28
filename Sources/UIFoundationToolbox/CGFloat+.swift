import Foundation
import CoreGraphics
import FrameworkToolbox

extension FrameworkToolbox where Base: BinaryInteger {
    @inlinable
    public var cgFloat: CGFloat { .init(base) }
}

extension FrameworkToolbox where Base: BinaryFloatingPoint {
    @inlinable
    public var cgFloat: CGFloat { .init(base) }
}
