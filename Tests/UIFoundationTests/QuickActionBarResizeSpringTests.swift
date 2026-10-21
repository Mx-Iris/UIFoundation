#if QuickActionBar && os(macOS)

import AppKit
import SwiftUI
import Testing
@testable import UIFoundationAppKit

/// The curve the bar's window follows when its results expand or collapse.
///
/// Spotlight's own resize curve on macOS 27.2 is `Spring(duration: 0.3, bounce: 0.2)`, so the
/// expected values come from SwiftUI's implementation of that spring rather than from the formula
/// under test.
@Suite("QuickActionBar resize spring")
struct QuickActionBarResizeSpringTests {
    @Test(
        "Follows SwiftUI's Spring(duration: 0.3, bounce: 0.2)",
        arguments: [0.02, 0.05, 0.1, 0.15, 0.2, 0.25, 0.3, 0.4, 0.5, 0.7]
    )
    func followsSpotlightsSpring(elapsed: Double) {
        let spotlightSpring = SwiftUI.Spring(duration: 0.3, bounce: 0.2)
        let expectedPosition = spotlightSpring.value(target: 1.0, initialVelocity: 0.0, time: elapsed)

        let position = Double(QuickActionBar.ResizeSpring.position(at: CGFloat(elapsed)))

        #expect(abs(position - expectedPosition) < 0.0001)
    }

    @Test("Overshoots by about one and a half percent before settling")
    func overshootsSlightly() {
        // A damping ratio of 0.8 peaks at 1 + e^(−0.8π / 0.6) ≈ 1.0152, a quarter second in.
        let peak = QuickActionBar.ResizeSpring.position(at: 0.25)

        #expect(abs(peak - 1.0152) < 0.0005)
    }

    @Test("Comes to rest on the target")
    func settlesOnTheTarget() {
        #expect(!QuickActionBar.ResizeSpring.isSettled(at: 0.25))
        #expect(QuickActionBar.ResizeSpring.isSettled(at: 1))
    }
}

#endif
