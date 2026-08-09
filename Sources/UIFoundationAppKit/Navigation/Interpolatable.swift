//
//  Ported from the macOS App Store's own navigation stack.
//  Reverse-engineering notes: Researchs/AppStore-Custom-Navigation-Internals.md
//

#if Navigation && os(macOS)

import AppKit

/// A value that can be blended with another value of the same type.
///
/// Conformers are the property types a ``ViewTransition`` animates — a frame, an opacity, a
/// point. The single requirement takes an already-eased input, so implementations are plain
/// linear blends and never apply a timing curve themselves.
public protocol Interpolatable {
    /// Blends `startValue` towards `endValue`.
    ///
    /// - Parameter input: Normally `0...1`, but implementations must extrapolate rather than
    ///   clamp: a rubber-banding gesture legitimately drives this past either end.
    static func solvedValue(between startValue: Self, and endValue: Self, forInput input: CGFloat) -> Self
}

extension CGFloat: Interpolatable {
    public static func solvedValue(between startValue: CGFloat, and endValue: CGFloat, forInput input: CGFloat) -> CGFloat {
        startValue + (endValue - startValue) * input
    }
}

extension Double: Interpolatable {
    public static func solvedValue(between startValue: Double, and endValue: Double, forInput input: CGFloat) -> Double {
        startValue + (endValue - startValue) * Double(input)
    }
}

extension CGPoint: Interpolatable {
    public static func solvedValue(between startValue: CGPoint, and endValue: CGPoint, forInput input: CGFloat) -> CGPoint {
        CGPoint(
            x: CGFloat.solvedValue(between: startValue.x, and: endValue.x, forInput: input),
            y: CGFloat.solvedValue(between: startValue.y, and: endValue.y, forInput: input)
        )
    }
}

extension CGSize: Interpolatable {
    public static func solvedValue(between startValue: CGSize, and endValue: CGSize, forInput input: CGFloat) -> CGSize {
        CGSize(
            width: CGFloat.solvedValue(between: startValue.width, and: endValue.width, forInput: input),
            height: CGFloat.solvedValue(between: startValue.height, and: endValue.height, forInput: input)
        )
    }
}

extension CGRect: Interpolatable {
    public static func solvedValue(between startValue: CGRect, and endValue: CGRect, forInput input: CGFloat) -> CGRect {
        CGRect(
            origin: CGPoint.solvedValue(between: startValue.origin, and: endValue.origin, forInput: input),
            size: CGSize.solvedValue(between: startValue.size, and: endValue.size, forInput: input)
        )
    }
}

#endif
