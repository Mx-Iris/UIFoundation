//
//  QuickActionBar+Spring.swift
//  UIFoundation
//

#if QuickActionBar && os(macOS)

import Foundation
import QuartzCore

extension QuickActionBar {
    /// A damped spring with SwiftUI's `Spring(duration:bounce:)` parameters, evaluated in closed
    /// form the way SwiftUI evaluates it: unit mass, a natural frequency of 2π / `duration`, and a
    /// damping ratio of 1 − `bounce` (1 / (1 + `bounce`) for a negative bounce).
    ///
    /// Spotlight describes every one of its animations this way, so the bar's animations quote
    /// Spotlight's numbers directly instead of tuning stiffness and damping by eye.
    struct Spring: Equatable {
        let duration: CGFloat
        let bounce: CGFloat

        init(duration: CGFloat, bounce: CGFloat) {
            self.duration = duration
            self.bounce = bounce
        }

        var naturalFrequency: CGFloat {
            2 * .pi / duration
        }

        var dampingRatio: CGFloat {
            bounce >= 0 ? 1 - bounce : 1 / (1 + bounce)
        }

        /// The value `time` seconds after the spring is released at `start` with `initialVelocity`,
        /// pulling towards `target`.
        func value(from start: CGFloat, to target: CGFloat, initialVelocity: CGFloat = 0, time: CGFloat) -> CGFloat {
            target + displacement(fromInitialDisplacement: start - target, initialVelocity: initialVelocity, time: time)
        }

        /// The rate of change of ``value(from:to:initialVelocity:time:)`` at `time`.
        func velocity(from start: CGFloat, to target: CGFloat, initialVelocity: CGFloat = 0, time: CGFloat) -> CGFloat {
            velocity(fromInitialDisplacement: start - target, initialVelocity: initialVelocity, time: time)
        }

        private func displacement(fromInitialDisplacement initialDisplacement: CGFloat, initialVelocity: CGFloat, time: CGFloat) -> CGFloat {
            let frequency = naturalFrequency
            let ratio = dampingRatio
            if ratio < 1 {
                let decayRate = ratio * frequency
                let dampedFrequency = frequency * (1 - ratio * ratio).squareRoot()
                let sineCoefficient = (initialVelocity + decayRate * initialDisplacement) / dampedFrequency
                return exp(-decayRate * time) * (initialDisplacement * cos(dampedFrequency * time) + sineCoefficient * sin(dampedFrequency * time))
            } else if ratio == 1 {
                let linearCoefficient = initialVelocity + frequency * initialDisplacement
                return (initialDisplacement + linearCoefficient * time) * exp(-frequency * time)
            } else {
                let spread = frequency * (ratio * ratio - 1).squareRoot()
                let slowRate = -ratio * frequency + spread
                let fastRate = -ratio * frequency - spread
                let slowCoefficient = (initialVelocity - fastRate * initialDisplacement) / (slowRate - fastRate)
                let fastCoefficient = initialDisplacement - slowCoefficient
                return slowCoefficient * exp(slowRate * time) + fastCoefficient * exp(fastRate * time)
            }
        }

        private func velocity(fromInitialDisplacement initialDisplacement: CGFloat, initialVelocity: CGFloat, time: CGFloat) -> CGFloat {
            let frequency = naturalFrequency
            let ratio = dampingRatio
            if ratio < 1 {
                let decayRate = ratio * frequency
                let dampedFrequency = frequency * (1 - ratio * ratio).squareRoot()
                let sineCoefficient = (frequency * frequency * initialDisplacement + decayRate * initialVelocity) / dampedFrequency
                return exp(-decayRate * time) * (initialVelocity * cos(dampedFrequency * time) - sineCoefficient * sin(dampedFrequency * time))
            } else if ratio == 1 {
                let linearCoefficient = initialVelocity + frequency * initialDisplacement
                return (initialVelocity - frequency * linearCoefficient * time) * exp(-frequency * time)
            } else {
                let spread = frequency * (ratio * ratio - 1).squareRoot()
                let slowRate = -ratio * frequency + spread
                let fastRate = -ratio * frequency - spread
                let slowCoefficient = (initialVelocity - fastRate * initialDisplacement) / (slowRate - fastRate)
                let fastCoefficient = initialDisplacement - slowCoefficient
                return slowCoefficient * slowRate * exp(slowRate * time) + fastCoefficient * fastRate * exp(fastRate * time)
            }
        }
    }

    /// One number moved by springs and retargeted the way SwiftUI retargets a spring: a new
    /// target takes over from the current value and velocity, so an interrupted animation turns
    /// around without a jump.
    ///
    /// The bar keeps its animated values in this form, measured on a 0…1 progress scale, so a
    /// single pair of thresholds says when any of them has come to rest.
    struct SpringAnimatedValue: Equatable {
        /// Where the value is heading.
        private(set) var target: CGFloat
        private var startValue: CGFloat
        private var startVelocity: CGFloat
        private var spring: Spring?
        private var startTime: CFTimeInterval = 0

        private static let positionThreshold: CGFloat = 0.0005
        private static let velocityThreshold: CGFloat = 0.01

        /// A value at rest.
        init(_ value: CGFloat) {
            self.target = value
            self.startValue = value
            self.startVelocity = 0
            self.spring = nil
        }

        func value(at time: CFTimeInterval) -> CGFloat {
            guard let spring else { return target }
            guard time >= startTime else { return startValue }
            return spring.value(from: startValue, to: target, initialVelocity: startVelocity, time: CGFloat(time - startTime))
        }

        func velocity(at time: CFTimeInterval) -> CGFloat {
            guard let spring, time >= startTime else { return 0 }
            return spring.velocity(from: startValue, to: target, initialVelocity: startVelocity, time: CGFloat(time - startTime))
        }

        /// Whether the value has come to rest on its target. A value still waiting out a delay
        /// is not at rest.
        func isSettled(at time: CFTimeInterval) -> Bool {
            guard spring != nil else { return true }
            guard time >= startTime else { return false }
            return abs(value(at: time) - target) < Self.positionThreshold && abs(velocity(at: time)) < Self.velocityThreshold
        }

        /// Starts moving towards `newTarget` along `spring` from wherever the value is at `time`,
        /// keeping its velocity. With a delay the value holds still until the delay has passed,
        /// and then starts from rest, as a delayed SwiftUI animation does.
        mutating func animate(to newTarget: CGFloat, with newSpring: Spring, delay: CFTimeInterval = 0, at time: CFTimeInterval) {
            let currentValue = value(at: time)
            let currentVelocity = delay > 0 ? 0 : velocity(at: time)
            startValue = currentValue
            startVelocity = currentVelocity
            target = newTarget
            spring = newSpring
            startTime = time + delay
        }

        /// Moves the value to `newValue` at once and leaves it there at rest.
        mutating func jump(to newValue: CGFloat) {
            self = SpringAnimatedValue(newValue)
        }
    }
}

#endif
