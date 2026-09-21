#if canImport(AppKit) && !targetEnvironment(macCatalyst)
import AppKit
#endif

#if canImport(UIKit)
import UIKit
#endif

import QuartzCore

#if canImport(UIKit)

/// Cross-platform spelling of `UIView.AnimationOptions`.
public typealias NSUIViewAnimationOptions = UIView.AnimationOptions

#else

/// AppKit stand-in for `UIView.AnimationOptions`, carrying the cases that have
/// a meaning on both platforms.
///
/// `allowUserInteraction` and `layoutSubviews` are accepted and ignored: AppKit
/// animations never swallow events, and there is no analogue of animating a
/// `layoutSubviews()` pass.
public struct NSUIViewAnimationOptions: OptionSet, Sendable {
    public let rawValue: Int

    public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    public static let allowUserInteraction = NSUIViewAnimationOptions(rawValue: 1 << 0)
    public static let layoutSubviews = NSUIViewAnimationOptions(rawValue: 1 << 1)
    public static let curveLinear = NSUIViewAnimationOptions(rawValue: 1 << 2)
    public static let curveEaseIn = NSUIViewAnimationOptions(rawValue: 1 << 3)
    public static let curveEaseOut = NSUIViewAnimationOptions(rawValue: 1 << 4)
    public static let curveEaseInOut = NSUIViewAnimationOptions(rawValue: 1 << 5)
}

extension NSUIViewAnimationOptions {
    /// The Core Animation timing curve these options ask for.
    ///
    /// UIKit's default when no curve is named is ease-in-ease-out; this matches
    /// that rather than falling through to linear.
    public var timingFunction: CAMediaTimingFunction {
        if contains(.curveLinear) {
            CAMediaTimingFunction(name: .linear)
        } else if contains(.curveEaseIn) {
            CAMediaTimingFunction(name: .easeIn)
        } else if contains(.curveEaseOut) {
            CAMediaTimingFunction(name: .easeOut)
        } else {
            CAMediaTimingFunction(name: .easeInEaseOut)
        }
    }
}

#endif
