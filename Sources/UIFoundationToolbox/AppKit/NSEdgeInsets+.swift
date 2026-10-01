#if canImport(AppKit) && !targetEnvironment(macCatalyst)

import AppKit
import FrameworkToolbox
#if AppKitPlus && canImport(AppKitPlus)
import AppKitPlus
#endif

extension FrameworkToolbox where Base == NSEdgeInsets {
    @inlinable
    public static var zero: NSEdgeInsets { NSEdgeInsetsZero }
}

extension NSEdgeInsets: @retroactive FrameworkToolboxCompatible, @retroactive FrameworkToolboxDynamicMemberLookup {}

// AppKitPlus declares this conformance and its `==` itself, as UIKit does for
// UIEdgeInsets. A second copy here would make `==` ambiguous in every module that
// imports both, so it is compiled only when AppKitPlus is not linked.
#if !(AppKitPlus && canImport(AppKitPlus))
extension NSEdgeInsets: @retroactive Equatable {
    public static func == (lhs: NSEdgeInsets, rhs: NSEdgeInsets) -> Bool {
        lhs.left == rhs.left && lhs.top == rhs.top && lhs.right == rhs.right && lhs.bottom == rhs.bottom
    }
}
#endif

extension NSEdgeInsets: @retroactive Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(left)
        hasher.combine(top)
        hasher.combine(bottom)
        hasher.combine(right)
    }
}

#endif
