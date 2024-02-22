#if canImport(AppKit) && !targetEnvironment(macCatalyst)
import AppKit
#endif

#if canImport(UIKit)
import UIKit
#endif

open class BallPulseSyncIndicator: Indicator {
    open override func setupAnimation(in layer: CALayer, size: CGSize) {
        let circleSpacing: CGFloat = 2
        let circleSize = (size.width - circleSpacing * 2) / 3
        let x = (layer.bounds.size.width - size.width) / 2
        let y = (layer.bounds.size.height - circleSize) / 2
        let deltaY = (size.height / 2 - circleSize / 2) / 2
        let duration: CFTimeInterval = 0.6
        let beginTime = CACurrentMediaTime()
        let beginTimes: [CFTimeInterval] = [0.07, 0.14, 0.21]
        #if swift(>=4.2)
        let timingFunciton = CAMediaTimingFunction(name: .easeInEaseOut)
        #else
        let timingFunciton = CAMediaTimingFunction(name: kCAMediaTimingFunctionEaseInEaseOut)
        #endif

        // Animation
        let animation = CAKeyframeAnimation(keyPath: "transform.translation.y")

        animation.keyTimes = [0, 0.33, 0.66, 1]
        animation.timingFunctions = [timingFunciton, timingFunciton, timingFunciton]
        animation.values = [0, deltaY, -deltaY, 0]
        animation.duration = duration
        animation.repeatCount = HUGE
        animation.isRemovedOnCompletion = false

        // Draw circles
        for i in 0 ..< 3 {
            let circle = NVActivityIndicatorShape.circle.layerWith(size: CGSize(width: circleSize, height: circleSize), color: color)
            let frame = CGRect(
                x: x + circleSize * CGFloat(i) + circleSpacing * CGFloat(i),
                y: y,
                width: circleSize,
                height: circleSize
            )

            animation.beginTime = beginTime + beginTimes[i]
            circle.frame = frame
            circle.add(animation, forKey: "animation")
            layer.addSublayer(circle)
        }
    }
}
