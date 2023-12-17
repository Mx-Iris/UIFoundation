//
//  CATransaction.swift
//  SegmentedControl
//
//  Created by John on 30/03/2021.
//

import QuartzCore
import FrameworkToolbox

extension FrameworkToolbox where Base: CATransaction {
    public static func withAnimation(duration: TimeInterval, timing: CAMediaTimingFunctionName? = nil, _ actions: () throws -> Void, _ completion: (() -> Void)? = nil) rethrows {
        CATransaction.begin()
        CATransaction.setAnimationDuration(duration)
        if let functionName = timing {
            CATransaction.setAnimationTimingFunction(CAMediaTimingFunction(name: functionName))
        }
        CATransaction.setCompletionBlock(completion)
        try actions()
        CATransaction.commit()
    }

    public static func withoutAnimation(_ actions: () throws -> Void, _ completion: (() -> Void)? = nil) rethrows {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        CATransaction.setCompletionBlock(completion)
        try actions()
        CATransaction.commit()
    }
}
