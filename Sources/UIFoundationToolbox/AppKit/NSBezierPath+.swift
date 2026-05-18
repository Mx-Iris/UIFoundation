#if canImport(AppKit) && !targetEnvironment(macCatalyst)

import AppKit

extension FrameworkToolbox where Base: NSBezierPath {
    public var cgPath: CGPath {
        if #available(macOS 14.0, *) {
            return base.cgPath
        } else {
            let path = CGMutablePath()
            var points = [CGPoint](repeating: .zero, count: 3)
            for i in 0 ..< base.elementCount {
                let type = base.element(at: i, associatedPoints: &points)
                switch type {
                case .moveTo: path.move(to: points[0])
                case .lineTo: path.addLine(to: points[0])
                case .curveTo: path.addCurve(to: points[2], control1: points[0], control2: points[1])
                case .closePath: path.closeSubpath()
                case .cubicCurveTo, .quadraticCurveTo:
                    // Unreachable: these element types were introduced in macOS 14, where the
                    // `if #available(macOS 14.0, *)` branch above already delegates to the system
                    // `cgPath`. On macOS < 14 `NSBezierPath` can only produce moveTo/lineTo/curveTo/closePath.
                    fatalError("Unreachable: cubicCurveTo / quadraticCurveTo are macOS 14+ only and handled by the system cgPath branch")
                @unknown default:
                    break
                }
            }
            return path
        }
    }
}

#endif
