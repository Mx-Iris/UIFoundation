#if Navigation && os(macOS)

import Testing
import AppKit
@testable import UIFoundationAppKit

/// The numbers behind the navigation push / pop, asserted without standing up a window.
///
/// Everything here is reproduced from the macOS App Store's own implementation; the addresses
/// each value was read from are in `Researchs/AppStore-Custom-Navigation-Internals.md`.
@Suite("Navigation transition geometry")
struct NavigationTransitionGeometryTests {

    private let referenceRect = CGRect(x: 0, y: 0, width: 400, height: 300)

    // MARK: Reference rectangle

    @Test("With no insets the reference rectangle is the container's bounds")
    func referenceRectWithoutInsets() {
        let bounds = CGRect(x: 0, y: 0, width: 400, height: 300)
        let rect = NavigationTransitionGeometry.referenceRect(
            containerBounds: bounds,
            contentInsets: NSEdgeInsets(),
            isFlipped: false
        )
        #expect(rect == bounds)
    }

    @Test("Insets eat the container's bounds, with `top` following the container's y axis")
    func referenceRectWithInsets() {
        let bounds = CGRect(x: 0, y: 0, width: 400, height: 300)
        let insets = NSEdgeInsets(top: 10, left: 20, bottom: 30, right: 40)

        let unflipped = NavigationTransitionGeometry.referenceRect(
            containerBounds: bounds,
            contentInsets: insets,
            isFlipped: false
        )
        // y grows upwards, so `bottom` lifts the origin and `top` trims the height.
        #expect(unflipped == CGRect(x: 20, y: 30, width: 340, height: 260))

        let flipped = NavigationTransitionGeometry.referenceRect(
            containerBounds: bounds,
            contentInsets: insets,
            isFlipped: true
        )
        #expect(flipped == CGRect(x: 20, y: 10, width: 340, height: 260))
    }

    @Test("Insets larger than the container collapse the rectangle instead of inverting it")
    func referenceRectWithOversizedInsets() {
        let rect = NavigationTransitionGeometry.referenceRect(
            containerBounds: CGRect(x: 0, y: 0, width: 100, height: 100),
            contentInsets: NSEdgeInsets(top: 90, left: 80, bottom: 90, right: 80),
            isFlipped: false
        )
        #expect(rect.width == 0)
        #expect(rect.height == 0)
    }

    // MARK: Parallax

    @Test("The parallax shift is the floor of 25.27 % of the width")
    func parallaxShiftIsFloored() {
        // 400 × 0.2527 = 101.08 — the App Store floors rather than rounds.
        #expect(
            NavigationTransitionGeometry.parallaxShift(referenceRect: referenceRect, parallaxFactor: 0.2527) == 101
        )
        #expect(
            NavigationTransitionGeometry.parallaxShift(
                referenceRect: CGRect(x: 0, y: 0, width: 1000, height: 10),
                parallaxFactor: 0.2527
            ) == 252
        )
    }

    @Test("The underlying view drifts against the incoming one")
    func parallaxRectDirection() {
        let leftToRight = NavigationTransitionGeometry.parallaxRect(
            referenceRect: referenceRect,
            parallaxFactor: 0.2527,
            layoutDirection: .leftToRight
        )
        #expect(leftToRight == CGRect(x: -101, y: 0, width: 400, height: 300))

        let rightToLeft = NavigationTransitionGeometry.parallaxRect(
            referenceRect: referenceRect,
            parallaxFactor: 0.2527,
            layoutDirection: .rightToLeft
        )
        #expect(rightToLeft == CGRect(x: 101, y: 0, width: 400, height: 300))
    }

    @Test("A zero parallax factor leaves the underlying view where it is")
    func parallaxRectWithZeroFactor() {
        let rect = NavigationTransitionGeometry.parallaxRect(
            referenceRect: referenceRect,
            parallaxFactor: 0,
            layoutDirection: .leftToRight
        )
        #expect(rect == referenceRect)
    }

    // MARK: Off-screen staging

    @Test("The incoming view starts one full width beyond the trailing edge")
    func offscreenRectDirection() {
        let leftToRight = NavigationTransitionGeometry.offscreenRect(
            referenceRect: referenceRect,
            layoutDirection: .leftToRight
        )
        #expect(leftToRight == CGRect(x: 400, y: 0, width: 400, height: 300))

        let rightToLeft = NavigationTransitionGeometry.offscreenRect(
            referenceRect: referenceRect,
            layoutDirection: .rightToLeft
        )
        #expect(rightToLeft == CGRect(x: -400, y: 0, width: 400, height: 300))
    }

    @Test("Off-screen staging is measured from the inset rectangle, not the raw bounds")
    func offscreenRectHonoursInsets() {
        let inset = NavigationTransitionGeometry.referenceRect(
            containerBounds: CGRect(x: 0, y: 0, width: 400, height: 300),
            contentInsets: NSEdgeInsets(top: 0, left: 50, bottom: 0, right: 50),
            isFlipped: false
        )
        let offscreen = NavigationTransitionGeometry.offscreenRect(
            referenceRect: inset,
            layoutDirection: .leftToRight
        )
        #expect(inset == CGRect(x: 50, y: 0, width: 300, height: 300))
        #expect(offscreen == CGRect(x: 350, y: 0, width: 300, height: 300))
    }
}

@Suite("Navigation timing")
struct NavigationTimingTests {

    private let tolerance: CGFloat = 1e-4

    @Test("The App Store's curve is cubic-bezier(0.1878, 0.0023, 0.5399, 0.9629)")
    func navigationCurveControlPoints() {
        let curve = TimingCurve.appStoreNavigation
        #expect(abs(curve.controlPoint1.x - 0.1878) < tolerance)
        #expect(abs(curve.controlPoint1.y - 0.0023) < tolerance)
        #expect(abs(curve.controlPoint2.x - 0.5399) < tolerance)
        #expect(abs(curve.controlPoint2.y - 0.9629) < tolerance)
    }

    @Test("Reversing mirrors the control points through the diagonal")
    func reversedCurve() {
        // AppStoreKit computes its (unused) pop curve exactly this way.
        let reversed = TimingCurve.appStoreNavigation.reversed
        #expect(abs(reversed.controlPoint1.x - 0.4601) < tolerance)
        #expect(abs(reversed.controlPoint1.y - 0.0371) < tolerance)
        #expect(abs(reversed.controlPoint2.x - 0.8122) < tolerance)
        #expect(abs(reversed.controlPoint2.y - 0.9977) < tolerance)
    }

    @Test("Reversing twice is the identity")
    func reversedTwice() {
        let original = TimingCurve.appStoreNavigation
        let roundTripped = original.reversed.reversed
        #expect(abs(roundTripped.controlPoint1.x - original.controlPoint1.x) < tolerance)
        #expect(abs(roundTripped.controlPoint2.y - original.controlPoint2.y) < tolerance)
    }

    @Test("Every curve pins both endpoints", arguments: [
        TimingCurve.appStoreNavigation, .easeInOut, .easeIn, .easeOut, .linear,
    ])
    func curveEndpoints(curve: TimingCurve) {
        #expect(abs(curve.solvedProgress(forFraction: 0)) < tolerance)
        #expect(abs(curve.solvedProgress(forFraction: 1) - 1) < tolerance)
    }

    @Test("Out-of-range fractions clamp rather than extrapolate")
    func curveClampsInput() {
        #expect(TimingCurve.appStoreNavigation.solvedProgress(forFraction: -0.5) == 0)
        #expect(TimingCurve.appStoreNavigation.solvedProgress(forFraction: 1.5) == 1)
    }

    @Test("A linear curve is the identity")
    func linearCurveIsIdentity() {
        for fraction in stride(from: CGFloat(0), through: 1, by: 0.1) {
            #expect(abs(TimingCurve.linear.solvedProgress(forFraction: fraction) - fraction) < tolerance)
        }
    }

    @Test("Solving is monotonic")
    func curveIsMonotonic() {
        var previous = CGFloat(-1)
        for step in 0 ... 100 {
            let solved = TimingCurve.appStoreNavigation.solvedProgress(forFraction: CGFloat(step) / 100)
            #expect(solved >= previous)
            previous = solved
        }
    }

    @Test("The navigation curve front-loads its motion")
    func navigationCurveShape() {
        // Control point 1 sits at x = 0.19 with y ≈ 0, control point 2 at x = 0.54 with y ≈ 0.96:
        // the curve is past its own halfway point well before half the time has elapsed.
        #expect(TimingCurve.appStoreNavigation.solvedProgress(forFraction: 0.5) > 0.5)
    }

    @Test("Timing scales to the distance left to travel")
    func timingScaling() {
        let timing = AnimationTiming.appStoreNavigation
        #expect(timing.duration == 0.35)
        #expect(abs(timing.scaled(toRemaining: 0.5).duration - 0.175) < 1e-9)
        #expect(timing.scaled(toRemaining: 0).duration == 0)
        // A gesture past the end must not stretch the tail beyond a full run.
        #expect(timing.scaled(toRemaining: 2).duration == 0.35)
        #expect(timing.scaled(toRemaining: -1).duration == 0)
    }
}

@Suite("Navigation interpolation")
struct NavigationInterpolationTests {

    @Test("A linear interpolator blends each component")
    func rectInterpolation() {
        let interpolator = Interpolator(
            fromValue: CGRect(x: 0, y: 10, width: 100, height: 200),
            toValue: CGRect(x: 100, y: 20, width: 200, height: 400),
            curve: .linear
        )
        #expect(interpolator.value(forInput: 0) == CGRect(x: 0, y: 10, width: 100, height: 200))
        #expect(interpolator.value(forInput: 0.5) == CGRect(x: 50, y: 15, width: 150, height: 300))
        #expect(interpolator.value(forInput: 1) == CGRect(x: 100, y: 20, width: 200, height: 400))
    }

    @Test("The curve is applied inside the interpolator, not by the caller")
    func interpolatorAppliesItsOwnCurve() {
        let eased = Interpolator(fromValue: CGFloat(0), toValue: 100, curve: .appStoreNavigation)
        let linear = Interpolator(fromValue: CGFloat(0), toValue: 100, curve: .linear)
        #expect(eased.value(forInput: 0.5) != linear.value(forInput: 0.5))
        #expect(linear.value(forInput: 0.5) == 50)
    }

    @Test("Reversing an interpolator swaps the ends and mirrors the curve")
    func reversedInterpolator() {
        let interpolator = Interpolator(fromValue: CGFloat(10), toValue: 20, curve: .appStoreNavigation)
        let reversed = interpolator.reversed
        #expect(reversed.fromValue == 20)
        #expect(reversed.toValue == 10)
        #expect(reversed.value(forInput: 0) == 20)
        #expect(abs(reversed.value(forInput: 1) - 10) < 1e-6)
    }

    @Test("Blending extrapolates past the ends so a rubber-banding gesture keeps moving")
    func interpolatableExtrapolates() {
        #expect(CGFloat.solvedValue(between: 0, and: 100, forInput: 1.5) == 150)
        #expect(CGFloat.solvedValue(between: 0, and: 100, forInput: -0.5) == -50)
    }
}

#endif
