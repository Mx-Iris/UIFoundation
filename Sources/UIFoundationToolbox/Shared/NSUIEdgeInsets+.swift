#if canImport(UIKit)

import UIKit
import FrameworkToolbox

extension UIEdgeInsets: @retroactive FrameworkToolboxCompatible, @retroactive FrameworkToolboxDynamicMemberLookup {}

extension FrameworkToolbox where Base == UIEdgeInsets {
    /// Mirrors the AppKit side's `NSEdgeInsets.box.zero`.
    ///
    /// `UIEdgeInsets.zero` exists natively and `NSEdgeInsets.zero` does not, so
    /// cross-platform code written against `NSUIEdgeInsets` has no spelling
    /// that works on both -- unless it goes through `.box.zero`, which this
    /// makes available on the UIKit side too.
    @inlinable
    public static var zero: UIEdgeInsets { .zero }
}

#endif
