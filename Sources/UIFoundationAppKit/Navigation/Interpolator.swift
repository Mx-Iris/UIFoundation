//
//  Ported from the macOS App Store's own navigation stack.
//  Reverse-engineering notes: Researchs/AppStore-Custom-Navigation-Internals.md
//

#if Navigation && os(macOS)

import AppKit

/// A start value, an end value, and the curve that joins them.
///
/// Every interpolator carries **its own** curve. That is deliberate and load-bearing:
/// ``ViewPropertyInterpolator/apply(_:)`` passes the raw, un-eased fraction to each
/// transformation, so a gesture-driven transition lands on exactly the same eased values the
/// automatic animation would have produced. Ease once, here, and nowhere else.
public struct Interpolator<Value: Interpolatable> {
    public let fromValue: Value
    public let toValue: Value
    public let curve: TimingCurve

    public init(fromValue: Value, toValue: Value, curve: TimingCurve) {
        self.fromValue = fromValue
        self.toValue = toValue
        self.curve = curve
    }

    /// The value at `input`, with the curve applied.
    ///
    /// The App Store overloads this for `CGFloat`, `Double` and `Float`. Here there is only the
    /// one: three overloads make every float-literal call site ambiguous, and `Double` reaches
    /// this one implicitly anyway.
    public func value(forInput input: CGFloat) -> Value {
        Value.solvedValue(
            between: fromValue,
            and: toValue,
            forInput: curve.solvedProgress(forFraction: input)
        )
    }

    /// The same interpolation walked backwards.
    public var reversed: Interpolator<Value> {
        Interpolator(fromValue: toValue, toValue: fromValue, curve: curve.reversed)
    }
}

extension Interpolator: Sendable where Value: Sendable {}

#endif
