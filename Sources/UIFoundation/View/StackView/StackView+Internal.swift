#if canImport(AppKit) && !targetEnvironment(macCatalyst)
import AppKit
#endif

#if canImport(UIKit)
import UIKit
#endif



extension NSUILayoutPriority {
    @inlinable static func valueOrNil(_ value: Float?) -> NSUILayoutPriority? {
        guard let v = value else { return nil }
        return NSUILayoutPriority(rawValue: v)
    }
}

extension NSUIEdgeInsets {
    @inlinable init(edgeInset: CGFloat) {
        self.init(top: edgeInset, left: edgeInset, bottom: edgeInset, right: edgeInset)
    }
}
