#if canImport(AppKit) && !targetEnvironment(macCatalyst)
import AppKit
#endif

#if canImport(UIKit)
import UIKit
#endif

import QuartzCore
import FrameworkToolbox
import UIFoundationTypealias

/// The `UIView.animate` family, available on both platforms.
///
/// On UIKit these forward to the real thing. On AppKit they are built out of
/// `NSAnimationContext`, which is close but not identical -- each divergence is
/// documented on the method that carries it.
///
/// **AppKit contract**: the views being animated must be layer-backed. AppKit
/// only animates plain property assignments inside the closure when
/// `allowsImplicitAnimation` is set *and* the view has a layer; otherwise the
/// assignment applies instantly and the animation is silently skipped. Reach
/// for `view.backingLayer` beforehand if the view might not be backed yet.
extension FrameworkToolbox where Base: NSUIView {

    public static func animate(
        withDuration duration: TimeInterval,
        delay: TimeInterval = 0,
        options: NSUIViewAnimationOptions = [],
        animations: @escaping () -> Void,
        completion: ((Bool) -> Void)? = nil
    ) {
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        runAppKitAnimation(
            duration: duration,
            delay: delay,
            timingFunction: options.timingFunction,
            animations: animations,
            completion: completion
        )
        #else
        NSUIView.animate(
            withDuration: duration,
            delay: delay,
            options: options,
            animations: animations,
            completion: completion
        )
        #endif
    }

    /// The damping-based spring overload.
    ///
    /// **AppKit divergence**: there is no spring driven by damping and initial
    /// velocity. The damping ratio is approximated with an overshooting cubic
    /// timing function and `initialSpringVelocity` is ignored. Motion reads
    /// close at low bounce and visibly differs from UIKit at high bounce.
    public static func animate(
        withDuration duration: TimeInterval,
        delay: TimeInterval = 0,
        usingSpringWithDamping dampingRatio: CGFloat,
        initialSpringVelocity: CGFloat,
        options: NSUIViewAnimationOptions = [],
        animations: @escaping () -> Void,
        completion: ((Bool) -> Void)? = nil
    ) {
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        runAppKitAnimation(
            duration: duration,
            delay: delay,
            timingFunction: springTimingFunction(bounce: 1 - dampingRatio),
            animations: animations,
            completion: completion
        )
        #else
        NSUIView.animate(
            withDuration: duration,
            delay: delay,
            usingSpringWithDamping: dampingRatio,
            initialSpringVelocity: initialSpringVelocity,
            options: options,
            animations: animations,
            completion: completion
        )
        #endif
    }

    /// The bounce-based spring overload introduced in iOS 17.
    ///
    /// Carries the same AppKit divergence as the damping-based overload.
    @available(iOS 17.0, tvOS 17.0, visionOS 1.0, *)
    public static func animate(
        springDuration duration: TimeInterval,
        bounce: CGFloat,
        initialSpringVelocity: CGFloat,
        delay: TimeInterval = 0,
        options: NSUIViewAnimationOptions = [],
        animations: @escaping () -> Void,
        completion: ((Bool) -> Void)? = nil
    ) {
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        runAppKitAnimation(
            duration: duration,
            delay: delay,
            timingFunction: springTimingFunction(bounce: bounce),
            animations: animations,
            completion: completion
        )
        #else
        NSUIView.animate(
            springDuration: duration,
            bounce: bounce,
            initialSpringVelocity: initialSpringVelocity,
            delay: delay,
            options: options,
            animations: animations,
            completion: completion
        )
        #endif
    }

    /// Runs the changes with animation suppressed.
    ///
    /// Named to match `UIView.performWithoutAnimation(_:)`. Not to be confused
    /// with `CATransaction.box.performWithoutAnimation(_:_:)`, which disables
    /// only Core Animation's implicit actions -- this also shuts down AppKit's
    /// animation context.
    public static func performWithoutAnimation(_ actionsWithoutAnimation: () -> Void) {
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        NSAnimationContext.beginGrouping()
        NSAnimationContext.current.duration = 0
        NSAnimationContext.current.allowsImplicitAnimation = false
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        actionsWithoutAnimation()
        CATransaction.commit()
        NSAnimationContext.endGrouping()
        #else
        NSUIView.performWithoutAnimation(actionsWithoutAnimation)
        #endif
    }

    #if canImport(AppKit) && !targetEnvironment(macCatalyst)

    private static func runAppKitAnimation(
        duration: TimeInterval,
        delay: TimeInterval,
        timingFunction: CAMediaTimingFunction,
        animations: @escaping () -> Void,
        completion: ((Bool) -> Void)?
    ) {
        let run = {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = duration
                context.timingFunction = timingFunction
                context.allowsImplicitAnimation = true
                animations()
            } completionHandler: {
                completion?(true)
            }
        }
        if delay > 0 {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: run)
        } else {
            run()
        }
    }

    /// Approximates a spring by overshooting past the end value and settling
    /// back. A `bounce` of 0 is a plain ease-out; higher values overshoot more.
    private static func springTimingFunction(bounce: CGFloat) -> CAMediaTimingFunction {
        let clampedBounce = Swift.min(Swift.max(bounce, 0), 1)
        guard clampedBounce > 0 else {
            return CAMediaTimingFunction(name: .easeOut)
        }
        // The second control point's y rises above 1 to overshoot the target.
        return CAMediaTimingFunction(
            controlPoints: 0.34,
            Float(1 + clampedBounce * 0.8),
            0.64,
            1
        )
    }

    #endif
}
