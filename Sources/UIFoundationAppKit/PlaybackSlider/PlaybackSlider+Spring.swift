#if os(macOS)

import Foundation

/// A damped spring of unit mass.
struct PlaybackSliderSpring {
    let stiffness: Double
    let damping: Double

    /// `.interpolatingSpring(mass: 1, stiffness: 350, damping: 40)`, between the resting and the
    /// pressed bar (MediaCoreUI 0x2595C8094). A little over-damped: no overshoot.
    static let expansion = PlaybackSliderSpring(stiffness: 350, damping: 40)

    /// `.spring(response: 0.15, dampingFraction: 1)`, for the elapsed part's slide to a press
    /// (MediaCoreUI 0x259686BC4), as SwiftUI turns a response into a stiffness of (2π / response)² and
    /// a damping of 4π × fraction / response.
    static let slide: PlaybackSliderSpring = {
        let response = 0.15
        let angularFrequency = 2 * Double.pi / response
        return PlaybackSliderSpring(stiffness: angularFrequency * angularFrequency, damping: 4 * Double.pi / response)
    }()

    /// How close to its target, and how slow, a spring must be to count as at rest.
    private static let restingDistance = 1e-4
    private static let restingSpeed = 1e-2

    /// Where `motion` is, and how fast it moves, at `time`: the closed form of a critically or
    /// over-damped spring — both of Music's are — so a frame missed or drawn late still shows the
    /// right place.
    func evaluate(_ motion: PlaybackSliderSpringMotion, at time: CFTimeInterval) -> (position: Double, velocity: Double) {
        let elapsed = max(time - motion.startTime, 0)
        let startDisplacement = motion.startPosition - motion.target
        let undampedFrequency = stiffness.squareRoot()
        let dampingRatio = damping / (2 * undampedFrequency)
        let displacement: Double
        let displacementVelocity: Double
        if abs(dampingRatio - 1) < 1e-9 {
            let growth = motion.startVelocity + undampedFrequency * startDisplacement
            let decay = exp(-undampedFrequency * elapsed)
            displacement = (startDisplacement + growth * elapsed) * decay
            displacementVelocity = (growth - undampedFrequency * (startDisplacement + growth * elapsed)) * decay
        } else {
            let spread = undampedFrequency * (dampingRatio * dampingRatio - 1).squareRoot()
            let slowRate = -dampingRatio * undampedFrequency + spread
            let fastRate = -dampingRatio * undampedFrequency - spread
            let slowWeight = (motion.startVelocity - fastRate * startDisplacement) / (slowRate - fastRate)
            let fastWeight = startDisplacement - slowWeight
            let slowDecay = exp(slowRate * elapsed)
            let fastDecay = exp(fastRate * elapsed)
            displacement = slowWeight * slowDecay + fastWeight * fastDecay
            displacementVelocity = slowWeight * slowRate * slowDecay + fastWeight * fastRate * fastDecay
        }
        return (motion.target + displacement, displacementVelocity)
    }

    /// Whether `motion` has come to rest by `time`.
    func hasSettled(_ motion: PlaybackSliderSpringMotion, at time: CFTimeInterval) -> Bool {
        let (position, velocity) = evaluate(motion, at: time)
        return abs(position - motion.target) < Self.restingDistance && abs(velocity) < Self.restingSpeed
    }

    /// `motion` sent to `target` from wherever it is at `time`, keeping its speed: for these linear
    /// springs that is exactly what SwiftUI's adding of one interpolating spring onto another gives,
    /// and what its retargeting of `.spring` does.
    func retargeted(_ motion: PlaybackSliderSpringMotion, at time: CFTimeInterval, to target: Double) -> PlaybackSliderSpringMotion {
        let (position, velocity) = evaluate(motion, at: time)
        return PlaybackSliderSpringMotion(startTime: time, startPosition: position, startVelocity: velocity, target: target)
    }
}

/// A spring on its way from where it was at `startTime`, moving at `startVelocity`, to `target`.
struct PlaybackSliderSpringMotion {
    var startTime: CFTimeInterval
    var startPosition: Double
    var startVelocity: Double
    var target: Double

    /// At rest at zero, where a new cell's bar starts.
    static let atRest = PlaybackSliderSpringMotion(startTime: 0, startPosition: 0, startVelocity: 0, target: 0)
}

#endif
