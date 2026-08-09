//
//  Ported from the macOS App Store's own navigation stack.
//  Reverse-engineering notes: Researchs/AppStore-Custom-Navigation-Internals.md
//

#if Navigation && os(macOS)

import AppKit
import QuartzCore

/// An easing curve, expressed either as explicit cubic-bezier control points or as one of
/// CoreAnimation's named curves.
///
/// The type exists because a transition needs the same curve in two forms: as a
/// `CAMediaTimingFunction` to hand to `NSAnimationContext`, and as something it can *evaluate*
/// per frame while a gesture drives the transition by hand. `CAMediaTimingFunction` only lets you
/// read its control points back, so ``solvedProgress(forFraction:)`` solves the curve here.
public enum TimingCurve: Hashable, Sendable {
    case controlPoints(Float, Float, Float, Float)
    case easeInOut
    case easeIn
    case easeOut
    case linear

    /// The curve the macOS App Store uses for **both** its push and its pop —
    /// `cubic-bezier(0.1878, 0.0023, 0.5399, 0.9629)`.
    ///
    /// Heavily front-loaded: it is already ~63 % of the way through the motion at half the time,
    /// then crawls. AppStoreKit also ships the reversed form of this curve, but nothing in the App
    /// Store ever calls it, and the two transitions' timing getters are byte-identical (the linker
    /// folded them into one function). Pop really does share the un-reversed curve — see
    /// ``reversed`` if you want the other one.
    public static let appStoreNavigation: TimingCurve = .controlPoints(0.1878, 0.0023, 0.5399, 0.9629)

    /// The curve as CoreAnimation sees it.
    public var caMediaTimingFunction: CAMediaTimingFunction {
        switch self {
        case let .controlPoints(firstX, firstY, secondX, secondY):
            CAMediaTimingFunction(controlPoints: firstX, firstY, secondX, secondY)
        case .easeInOut:
            CAMediaTimingFunction(name: .easeInEaseOut)
        case .easeIn:
            CAMediaTimingFunction(name: .easeIn)
        case .easeOut:
            CAMediaTimingFunction(name: .easeOut)
        case .linear:
            CAMediaTimingFunction(name: .linear)
        }
    }

    /// The first control point, read back from ``caMediaTimingFunction`` so the named curves
    /// report whatever CoreAnimation actually uses rather than a hard-coded copy of it.
    public var controlPoint1: CGPoint { controlPoint(atIndex: 1) }

    /// The second control point. See ``controlPoint1``.
    public var controlPoint2: CGPoint { controlPoint(atIndex: 2) }

    /// The curve mirrored through the diagonal: `(1 − p2.x, 1 − p2.y, 1 − p1.x, 1 − p1.y)`.
    ///
    /// An ease-in becomes an ease-out. Useful when you want a pop to decelerate the way its push
    /// accelerated; note that the App Store itself does *not* do this (see ``navigation``).
    public var reversed: TimingCurve {
        let firstPoint = controlPoint1
        let secondPoint = controlPoint2
        return .controlPoints(
            Float(1 - secondPoint.x),
            Float(1 - secondPoint.y),
            Float(1 - firstPoint.x),
            Float(1 - firstPoint.y)
        )
    }

    /// Evaluates the curve: maps a linear `0...1` fraction of elapsed time onto the eased
    /// `0...1` fraction of the animation.
    ///
    /// Inputs outside `0...1` are clamped — unlike ``Interpolatable``, which extrapolates. An
    /// eased fraction is only defined on the curve's own domain.
    public func solvedProgress(forFraction fraction: CGFloat) -> CGFloat {
        if case .linear = self { return min(max(fraction, 0), 1) }
        return UnitBezierSolver(controlPoint1: controlPoint1, controlPoint2: controlPoint2)
            .solve(forHorizontalPosition: fraction)
    }

    private func controlPoint(atIndex index: Int) -> CGPoint {
        var components: [Float] = [0, 0]
        caMediaTimingFunction.getControlPoint(at: index, values: &components)
        return CGPoint(x: CGFloat(components[0]), y: CGFloat(components[1]))
    }
}

/// Solves `y` for a given `x` on a unit cubic bezier whose endpoints are `(0, 0)` and `(1, 1)`.
///
/// Newton-Raphson first, bisection as the fallback — the standard approach, because the curve is
/// parametric in `t` and CoreAnimation's curves are parameterised so that `x` and `t` diverge
/// noticeably wherever a control point sits near an edge (which is exactly the case for
/// ``TimingCurve/navigation``, whose first control point is at `x = 0.1878, y = 0.0023`).
struct UnitBezierSolver {
    private let horizontalCubicCoefficient: CGFloat
    private let horizontalQuadraticCoefficient: CGFloat
    private let horizontalLinearCoefficient: CGFloat
    private let verticalCubicCoefficient: CGFloat
    private let verticalQuadraticCoefficient: CGFloat
    private let verticalLinearCoefficient: CGFloat

    init(controlPoint1: CGPoint, controlPoint2: CGPoint) {
        horizontalLinearCoefficient = 3 * controlPoint1.x
        horizontalQuadraticCoefficient = 3 * (controlPoint2.x - controlPoint1.x) - horizontalLinearCoefficient
        horizontalCubicCoefficient = 1 - horizontalLinearCoefficient - horizontalQuadraticCoefficient

        verticalLinearCoefficient = 3 * controlPoint1.y
        verticalQuadraticCoefficient = 3 * (controlPoint2.y - controlPoint1.y) - verticalLinearCoefficient
        verticalCubicCoefficient = 1 - verticalLinearCoefficient - verticalQuadraticCoefficient
    }

    func solve(forHorizontalPosition horizontalPosition: CGFloat) -> CGFloat {
        let clampedPosition = min(max(horizontalPosition, 0), 1)
        return verticalPosition(atParameter: parameter(forHorizontalPosition: clampedPosition))
    }

    private func horizontalPosition(atParameter parameter: CGFloat) -> CGFloat {
        ((horizontalCubicCoefficient * parameter + horizontalQuadraticCoefficient) * parameter
            + horizontalLinearCoefficient) * parameter
    }

    private func verticalPosition(atParameter parameter: CGFloat) -> CGFloat {
        ((verticalCubicCoefficient * parameter + verticalQuadraticCoefficient) * parameter
            + verticalLinearCoefficient) * parameter
    }

    private func horizontalDerivative(atParameter parameter: CGFloat) -> CGFloat {
        (3 * horizontalCubicCoefficient * parameter + 2 * horizontalQuadraticCoefficient) * parameter
            + horizontalLinearCoefficient
    }

    private func parameter(forHorizontalPosition targetPosition: CGFloat) -> CGFloat {
        let tolerance: CGFloat = 1e-6

        var parameter = targetPosition
        for _ in 0 ..< 8 {
            let positionError = horizontalPosition(atParameter: parameter) - targetPosition
            if abs(positionError) < tolerance { return parameter }
            let derivative = horizontalDerivative(atParameter: parameter)
            if abs(derivative) < 1e-9 { break }
            parameter -= positionError / derivative
        }

        var lowerBound: CGFloat = 0
        var upperBound: CGFloat = 1
        parameter = targetPosition
        if parameter < lowerBound { return lowerBound }
        if parameter > upperBound { return upperBound }
        while lowerBound < upperBound {
            let position = horizontalPosition(atParameter: parameter)
            if abs(position - targetPosition) < tolerance { return parameter }
            if targetPosition > position {
                lowerBound = parameter
            } else {
                upperBound = parameter
            }
            let midpoint = (upperBound - lowerBound) * 0.5 + lowerBound
            if midpoint == parameter { break }
            parameter = midpoint
        }
        return parameter
    }
}

#endif
