#if canImport(AppKit) && !targetEnvironment(macCatalyst)

import AppKit
import FrameworkToolbox

extension FrameworkToolbox where Base: NSAnimationContext {
    /// Runs the changes of the specified block non-animated.
    public static func performWithoutAnimation(_ changes: () -> Void) {
        Base.runAnimationGroup { context in
            context.duration = 0.0
            context.allowsImplicitAnimation = true
            changes()
        }
    }

    /// Runs the animation group.
    ///
    /// - Parameters:
    ///   - duration: The duration of the animations, measured in seconds. If you specify a value of `0, the changes are made without animating them. The default value is `0.25`.
    ///   - timingFunction: An optional timing function for the animations. The default value is `nil`.
    ///   - allowsImplicitAnimation: A Boolean value that indicates whether animations are enabled for animations that occur as a result of another property change.. The default value is `false`.
    ///   - animations: A block containing the changes to animate.
    ///   - completionHandler: An optional completion block that is called when the animations have completed. The default value is `nil`.
    ///
    public static func runAnimations(duration: TimeInterval = 0.25, timingFunction: CAMediaTimingFunction? = nil, allowsImplicitAnimation: Bool = false, changes: () -> Void, completionHandler: (() -> Void)? = nil) {
        NSAnimationContext.runAnimationGroup { context in
            context.duration = duration
            context.timingFunction = timingFunction
            context.allowsImplicitAnimation = allowsImplicitAnimation
            context.completionHandler = completionHandler
            changes()
        }
    }
}

#endif
