#if canImport(AppKit) && !targetEnvironment(macCatalyst)
import AppKit
#endif

#if canImport(UIKit)
import UIKit
#endif



extension _NSUILayoutPriority {
    @inlinable static func valueOrNil(_ value: Float?) -> _NSUILayoutPriority? {
        guard let v = value else { return nil }
        return _NSUILayoutPriority(rawValue: v)
    }
}

extension _NSUIEdgeInsets {
    @inlinable init(edgeInset: CGFloat) {
        self.init(top: edgeInset, left: edgeInset, bottom: edgeInset, right: edgeInset)
    }
}
