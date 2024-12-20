#if canImport(QuartzCore)

import QuartzCore
import FrameworkToolbox

extension FrameworkToolbox where Base: CATransaction {
    public static func performWithAnimation(duration: TimeInterval, timing: CAMediaTimingFunctionName? = nil, _ actions: () throws -> Void, _ completion: (() -> Void)? = nil) rethrows {
        CATransaction.begin()
        CATransaction.setAnimationDuration(duration)
        if let functionName = timing {
            CATransaction.setAnimationTimingFunction(CAMediaTimingFunction(name: functionName))
        }
        CATransaction.setCompletionBlock(completion)
        try actions()
        CATransaction.commit()
    }

    public static func performWithoutAnimation(_ actions: () throws -> Void, _ completion: (() -> Void)? = nil) rethrows {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        CATransaction.setCompletionBlock(completion)
        try actions()
        CATransaction.commit()
    }
}


#endif
