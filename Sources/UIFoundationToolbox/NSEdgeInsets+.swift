#if canImport(AppKit) && !targetEnvironment(macCatalyst)

import AppKit
import FrameworkToolbox

extension FrameworkToolbox where Base == NSEdgeInsets {
    @inlinable
    public static var zero: NSEdgeInsets { NSEdgeInsetsZero }
}

extension NSEdgeInsets: FrameworkToolboxCompatible, FrameworkToolboxDynamicMemberLookup {}

extension NSEdgeInsets: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(left)
        hasher.combine(top)
        hasher.combine(bottom)
        hasher.combine(right)
    }

    public static func == (lhs: NSEdgeInsets, rhs: NSEdgeInsets) -> Bool {
        lhs.left == rhs.left && lhs.top == rhs.top && lhs.right == rhs.right && lhs.bottom == rhs.bottom
    }
}

#endif
