#if QuickActionBar && os(macOS)

import AppKit
import SwiftUI
import Testing
@testable import UIFoundationAppKit

/// The closed-form spring behind every QuickActionBar animation.
///
/// Spotlight states its animations as SwiftUI `Spring(duration:bounce:)` values, so the expected
/// numbers come from SwiftUI's own implementation of the same spring, never from the formula
/// under test.
@Suite("QuickActionBar spring")
struct QuickActionBarSpringTests {
    struct SpringCase: CustomTestStringConvertible, Sendable {
        let duration: Double
        let bounce: Double
        let initialVelocity: Double

        var testDescription: String {
            "duration \(duration), bounce \(bounce), initial velocity \(initialVelocity)"
        }
    }

    /// Spotlight's browse button springs, plus the critically damped and overdamped shapes and a
    /// spring released while already moving.
    static let springCases: [SpringCase] = [
        SpringCase(duration: 0.71, bounce: 0.01, initialVelocity: 0),
        SpringCase(duration: 0.39, bounce: 0.39, initialVelocity: 0),
        SpringCase(duration: 0.35, bounce: 0.43, initialVelocity: 0),
        SpringCase(duration: 0.49, bounce: 0.15, initialVelocity: 0),
        SpringCase(duration: 0.20, bounce: 0.05, initialVelocity: 0),
        SpringCase(duration: 0.41, bounce: 0.12, initialVelocity: 0),
        SpringCase(duration: 0.30, bounce: 0.20, initialVelocity: 3.5),
        SpringCase(duration: 0.41, bounce: 0.12, initialVelocity: -2),
        SpringCase(duration: 0.50, bounce: 0, initialVelocity: 1.5),
        SpringCase(duration: 0.50, bounce: -0.3, initialVelocity: 0),
        SpringCase(duration: 0.50, bounce: -0.3, initialVelocity: 2),
    ]

    static let sampleTimes: [Double] = [0, 0.016, 0.05, 0.1, 0.2, 0.3, 0.45, 0.7, 1.2]

    @Test("Moves like SwiftUI's Spring", arguments: springCases)
    func valueFollowsSwiftUI(springCase: SpringCase) {
        let swiftUISpring = SwiftUI.Spring(duration: springCase.duration, bounce: springCase.bounce)
        let spring = QuickActionBar.Spring(duration: CGFloat(springCase.duration), bounce: CGFloat(springCase.bounce))

        for time in Self.sampleTimes {
            let expectedValue = swiftUISpring.value(target: 1.0, initialVelocity: springCase.initialVelocity, time: time)
            let value = Double(spring.value(from: 0, to: 1, initialVelocity: CGFloat(springCase.initialVelocity), time: CGFloat(time)))
            #expect(abs(value - expectedValue) < 0.0001, "at \(time) s")
        }
    }

    /// The expected velocity is the slope of SwiftUI's own curve, not SwiftUI's `velocity(…)`:
    /// for a negative bounce that method returns the slope plus the target (measured on macOS 27.2,
    /// off by exactly 1.0 at every time after 0 for a target of 1), while `value(…)` is right.
    @Test("Moves at the slope of SwiftUI's Spring", arguments: springCases)
    func velocityFollowsSwiftUI(springCase: SpringCase) {
        let swiftUISpring = SwiftUI.Spring(duration: springCase.duration, bounce: springCase.bounce)
        let spring = QuickActionBar.Spring(duration: CGFloat(springCase.duration), bounce: CGFloat(springCase.bounce))
        let step = 0.000001

        for time in Self.sampleTimes.dropFirst() {
            let later = swiftUISpring.value(target: 1.0, initialVelocity: springCase.initialVelocity, time: time + step)
            let earlier = swiftUISpring.value(target: 1.0, initialVelocity: springCase.initialVelocity, time: time - step)
            let expectedVelocity = (later - earlier) / (2 * step)
            let velocity = Double(spring.velocity(from: 0, to: 1, initialVelocity: CGFloat(springCase.initialVelocity), time: CGFloat(time)))
            #expect(abs(velocity - expectedVelocity) < 0.001, "at \(time) s")
        }
    }

    @Test("Starts at the velocity it was released with", arguments: springCases)
    func startsAtInitialVelocity(springCase: SpringCase) {
        let spring = QuickActionBar.Spring(duration: CGFloat(springCase.duration), bounce: CGFloat(springCase.bounce))
        let velocity = spring.velocity(from: 0, to: 1, initialVelocity: CGFloat(springCase.initialVelocity), time: 0)
        #expect(abs(velocity - CGFloat(springCase.initialVelocity)) < 0.000001)
    }

    @Test("Scales to any start and target")
    func scalesToStartAndTarget() {
        // 640 → 384 is the search field collapsing beside four browse buttons.
        let swiftUISpring = SwiftUI.Spring(duration: 0.39, bounce: 0.39)
        let spring = QuickActionBar.Spring(duration: 0.39, bounce: 0.39)

        for time in Self.sampleTimes {
            let expectedWidth = 640 + swiftUISpring.value(target: -256.0, time: time)
            let width = Double(spring.value(from: 640, to: 384, time: CGFloat(time)))
            #expect(abs(width - expectedWidth) < 0.01, "at \(time) s")
        }
    }

    @Test("A new target takes over from the current value and velocity")
    func retargetingIsContinuous() {
        let showSpring = QuickActionBar.Spring(duration: 0.39, bounce: 0.39)
        let hideSpring = QuickActionBar.Spring(duration: 0.41, bounce: 0.12)
        var animatedValue = QuickActionBar.SpringAnimatedValue(0)
        animatedValue.animate(to: 1, with: showSpring, at: 10)

        let interruptionTime: CFTimeInterval = 10.12
        let valueBefore = animatedValue.value(at: interruptionTime)
        let velocityBefore = animatedValue.velocity(at: interruptionTime)
        animatedValue.animate(to: 0, with: hideSpring, at: interruptionTime)

        #expect(animatedValue.target == 0)
        #expect(abs(animatedValue.value(at: interruptionTime) - valueBefore) < 0.000001)
        #expect(abs(animatedValue.velocity(at: interruptionTime) - velocityBefore) < 0.000001)
        // Still heading out when interrupted, so it keeps going briefly before turning back.
        #expect(velocityBefore > 0)
        #expect(animatedValue.value(at: interruptionTime + 0.01) > valueBefore)
        #expect(animatedValue.isSettled(at: interruptionTime + 2))
        #expect(abs(animatedValue.value(at: interruptionTime + 2)) < 0.001)
    }

    @Test("A delayed animation holds still, then starts from rest")
    func delayHoldsTheValue() {
        let spring = QuickActionBar.Spring(duration: 0.49, bounce: 0.15)
        var animatedValue = QuickActionBar.SpringAnimatedValue(0)
        animatedValue.animate(to: 1, with: spring, delay: 0.17, at: 5)

        #expect(animatedValue.value(at: 5.1) == 0)
        #expect(animatedValue.velocity(at: 5.1) == 0)
        #expect(!animatedValue.isSettled(at: 5.1))

        let expectedValue = SwiftUI.Spring(duration: 0.49, bounce: 0.15).value(target: 1.0, time: 0.1)
        #expect(abs(Double(animatedValue.value(at: 5.27)) - expectedValue) < 0.0001)
    }

    @Test("A value that was never animated is at rest")
    func restingValue() {
        var animatedValue = QuickActionBar.SpringAnimatedValue(0.4)
        #expect(animatedValue.value(at: 3) == 0.4)
        #expect(animatedValue.isSettled(at: 3))

        animatedValue.jump(to: 1)
        #expect(animatedValue.value(at: 3) == 1)
        #expect(animatedValue.target == 1)
        #expect(animatedValue.isSettled(at: 3))
    }
}

#endif
