//
//  Ported from the macOS App Store's own navigation stack.
//  Reverse-engineering notes: Researchs/AppStore-Custom-Navigation-Internals.md
//

#if Navigation && os(macOS)

import AppKit

/// One property being driven from a start value to an end value.
///
/// A transition is nothing more than a list of these plus the three views they act on, which is
/// what lets the same description be either animated by CoreAnimation or stepped by hand from a
/// gesture.
@MainActor
public protocol Transformation {
    /// Writes the value for `fraction`.
    ///
    /// - Parameter fraction: The **un-eased** progress. Easing belongs to the transformation's
    ///   own ``Interpolator``, not to the caller.
    func apply(_ fraction: CGFloat)
}

/// Drives a property identified by a key path.
public struct KeyPathTransformation<Target: AnyObject, Value: Interpolatable>: Transformation {
    public let target: Target
    public let property: ReferenceWritableKeyPath<Target, Value>
    public let interpolator: Interpolator<Value>

    public init(
        target: Target,
        property: ReferenceWritableKeyPath<Target, Value>,
        interpolator: Interpolator<Value>
    ) {
        self.target = target
        self.property = property
        self.interpolator = interpolator
    }

    public func apply(_ fraction: CGFloat) {
        target[keyPath: property] = interpolator.value(forInput: fraction)
    }
}

/// Drives anything a key path cannot reach — a computed setter, several properties at once, or a
/// value that has to be routed through a method call.
public struct ClosureTransformation<Value: Interpolatable>: Transformation {
    public let interpolator: Interpolator<Value>
    public let body: (Value) -> Void

    public init(interpolator: Interpolator<Value>, body: @escaping (Value) -> Void) {
        self.interpolator = interpolator
        self.body = body
    }

    public func apply(_ fraction: CGFloat) {
        body(interpolator.value(forInput: fraction))
    }
}

/// A bundle of transformations that move together.
public struct ViewPropertyInterpolator {
    public var transformations: [any Transformation]

    /// The curve the transition as a whole is described with.
    ///
    /// It is carried for reference — ``apply(_:)`` does **not** use it. Each transformation eases
    /// through its own ``Interpolator``; applying the curve here as well would ease twice.
    public var curve: TimingCurve

    public init(transformations: [any Transformation] = [], curve: TimingCurve) {
        self.transformations = transformations
        self.curve = curve
    }

    public mutating func append(_ transformation: some Transformation) {
        transformations.append(transformation)
    }

    /// Applies every transformation at `fraction`, passing it through un-eased.
    @MainActor
    public func apply(_ fraction: CGFloat) {
        for transformation in transformations {
            transformation.apply(fraction)
        }
    }
}

#endif
