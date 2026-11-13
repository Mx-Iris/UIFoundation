#if QuickActionBar && os(macOS)

import AppKit
import SwiftUI
import Testing
@testable import UIFoundationAppKit

/// The browse buttons' choreography, against the numbers read off macOS 27.2 Spotlight.
///
/// Expected positions are Spotlight's geometry worked out by hand for a 640-point bar with a
/// 56-point search row (the bar's default): 54-point buttons 10 points apart, a 384-point field.
/// Expected motion is SwiftUI's own `Spring` evaluated with Spotlight's durations and bounces, so
/// neither comes from the code under test.
@Suite("QuickActionBar browse button choreography")
struct QuickActionBarMitosisTests {
    static let barWidth: CGFloat = 640
    static let collapsedHeight: CGFloat = 56
    static let showTime: CFTimeInterval = 100

    /// Each button's spring as it moves out and as it grows, per Spotlight's tables.
    static let showSprings: [(translation: SwiftUI.Spring, scale: SwiftUI.Spring)] = [
        (SwiftUI.Spring(duration: 0.35, bounce: 0.43), SwiftUI.Spring(duration: 0.41, bounce: 0.394)),
        (SwiftUI.Spring(duration: 0.45, bounce: 0.39), SwiftUI.Spring(duration: 0.55, bounce: 0.35)),
        (SwiftUI.Spring(duration: 0.55, bounce: 0.35), SwiftUI.Spring(duration: 0.65, bounce: 0.32)),
        (SwiftUI.Spring(duration: 0.60, bounce: 0.31), SwiftUI.Spring(duration: 0.71, bounce: 0.274)),
    ]

    /// How far each button's centre travels past the collapsed field's 384-point edge.
    static let travelDistances: [CGFloat] = [37, 101, 165, 229]

    private func shownAnimation(buttonCount: Int = 4) -> QuickActionBar.MitosisAnimation {
        var animation = QuickActionBar.MitosisAnimation(buttonCount: buttonCount)
        animation.show(at: Self.showTime)
        return animation
    }

    private func layout(of animation: QuickActionBar.MitosisAnimation, secondsAfterShow seconds: CFTimeInterval) -> QuickActionBar.MitosisLayout {
        animation.layout(at: Self.showTime + seconds, barWidth: Self.barWidth, collapsedHeight: Self.collapsedHeight)
    }

    @Test("Out and settled: a 384-point field and four 54-point buttons 10 points apart")
    func settledGeometry() {
        let layout = layout(of: shownAnimation(), secondsAfterShow: 5)

        #expect(abs(layout.fieldWidth - 384) < 0.01)
        #expect(layout.smoothness < 0.01)
        #expect(layout.buttons.map { (($0.center.x * 100).rounded() / 100) } == [421, 485, 549, 613])
        #expect(layout.buttons.allSatisfy { $0.center.y == 28 && $0.diameter == 54 })
        #expect(layout.buttons.allSatisfy { abs($0.scale - 1) < 0.001 && abs($0.iconOpacity - 1) < 0.001 && $0.iconBlurRadius < 0.01 })
        #expect(abs(layout.buttons[3].glassFrame.maxX - 640) < 0.01)
    }

    @Test("At the start every button is a blurred dot on the collapsed field's edge, inside the full-width field")
    func startingGeometry() {
        let layout = layout(of: shownAnimation(), secondsAfterShow: 0)

        #expect(layout.fieldWidth == 640)
        #expect(layout.smoothness == 100)
        #expect(layout.buttons.allSatisfy { $0.center.x == 384 })
        #expect(layout.buttons.allSatisfy { abs($0.glassFrame.width - 5.4) < 0.001 })
        #expect(layout.buttons.allSatisfy { $0.iconOpacity == 0 && $0.iconBlurRadius == 10 })
    }

    @Test("The field narrows on Spotlight's 0.39 / 0.39 spring, and the union separates on 0.71 / 0.01")
    func fieldAndUnionFollowTheirSprings() {
        let animation = shownAnimation()
        for seconds in [0.05, 0.1, 0.2, 0.35] {
            let layout = layout(of: animation, secondsAfterShow: seconds)
            let fieldProgress = SwiftUI.Spring(duration: 0.39, bounce: 0.39).value(target: 1.0, time: seconds)
            let separation = SwiftUI.Spring(duration: 0.71, bounce: 0.01).value(target: 1.0, time: seconds)
            #expect(abs(Double(layout.fieldWidth) - (640 - 256 * fieldProgress)) < 0.01, "at \(seconds) s")
            #expect(abs(Double(layout.smoothness) - max(100 * (1 - separation), 0)) < 0.01, "at \(seconds) s")
        }
    }

    @Test("Each button moves and grows on its own spring", arguments: 0..<4)
    func buttonsFollowTheirOwnSprings(index: Int) {
        let animation = shownAnimation()
        let springs = Self.showSprings[index]
        for seconds in [0.05, 0.1, 0.2, 0.4] {
            let button = layout(of: animation, secondsAfterShow: seconds).buttons[index]
            let expectedCenter = 384 + Double(Self.travelDistances[index]) * springs.translation.value(target: 1.0, time: seconds)
            let expectedScale = 0.1 + 0.9 * springs.scale.value(target: 1.0, time: seconds)
            #expect(abs(Double(button.center.x) - expectedCenter) < 0.01, "at \(seconds) s")
            #expect(abs(Double(button.scale) - expectedScale) < 0.0001, "at \(seconds) s")
        }
    }

    @Test("Icons wait 0.17 s, then sharpen and fade in on a 0.49 / 0.15 spring")
    func iconsWaitThenAppear() {
        let animation = shownAnimation()

        let waiting = layout(of: animation, secondsAfterShow: 0.16)
        #expect(waiting.buttons.allSatisfy { $0.iconOpacity == 0 && $0.iconBlurRadius == 10 })

        let visibility = SwiftUI.Spring(duration: 0.49, bounce: 0.15).value(target: 1.0, time: 0.1)
        let appearing = layout(of: animation, secondsAfterShow: 0.27)
        for button in appearing.buttons {
            #expect(abs(Double(button.iconOpacity) - visibility) < 0.0001)
            #expect(abs(Double(button.iconBlurRadius) - 10 * (1 - visibility)) < 0.001)
        }
    }

    @Test("Drawing back in: icons blur out on 0.20 / 0.05, everything else returns on 0.41 / 0.12")
    func hideFollowsSpotlightsSprings() {
        var animation = shownAnimation()
        let hideTime = Self.showTime + 5
        animation.hide(at: hideTime)

        let atHide = animation.layout(at: hideTime, barWidth: Self.barWidth, collapsedHeight: Self.collapsedHeight)
        #expect(atHide.smoothness == 0)

        let seconds = 0.1
        let layout = animation.layout(at: hideTime + seconds, barWidth: Self.barWidth, collapsedHeight: Self.collapsedHeight)
        let movement = SwiftUI.Spring(duration: 0.41, bounce: 0.12).value(target: 1.0, time: seconds)
        let fade = SwiftUI.Spring(duration: 0.20, bounce: 0.05).value(target: 1.0, time: seconds)

        #expect(abs(Double(layout.fieldWidth) - (384 + 256 * movement)) < 0.01)
        #expect(abs(Double(layout.smoothness) - 100 * movement) < 0.01)
        #expect(abs(Double(layout.buttons[3].center.x) - (384 + 229 * (1 - movement))) < 0.01)
        #expect(abs(Double(layout.buttons[3].scale) - (0.1 + 0.9 * (1 - movement))) < 0.0001)
        #expect(abs(Double(layout.buttons[0].iconOpacity) - min(max(1 - fade, 0), 1)) < 0.0001)

        #expect(animation.isSettled(at: hideTime + 3))
        let settled = animation.layout(at: hideTime + 3, barWidth: Self.barWidth, collapsedHeight: Self.collapsedHeight)
        #expect(abs(settled.fieldWidth - 640) < 0.01)
        #expect(abs(settled.smoothness - 100) < 0.01)
    }

    @Test("A fifth button takes Spotlight's fallback springs, past its four-row tables")
    func fifthButtonUsesTheFallback() {
        let animation = shownAnimation(buttonCount: 5)
        let seconds = 0.2
        let button = layout(of: animation, secondsAfterShow: seconds).buttons[4]
        // 640 − 5 × 64 = 320 for the field; the fifth centre travels 10 + 27 + 4 × 64 = 293.
        let expectedCenter = 320 + 293 * SwiftUI.Spring(duration: 0.85, bounce: 0.23).value(target: 1.0, time: seconds)
        let expectedScale = 0.1 + 0.9 * SwiftUI.Spring(duration: 0.81, bounce: 0.234).value(target: 1.0, time: seconds)

        #expect(abs(Double(button.center.x) - expectedCenter) < 0.01)
        #expect(abs(Double(button.scale) - expectedScale) < 0.0001)
    }

    @Test("Showing twice or hiding while in changes nothing")
    func repeatedRequestsAreIgnored() {
        var animation = shownAnimation()
        let before = animation
        animation.show(at: Self.showTime + 0.1)
        #expect(animation == before)

        var hidden = QuickActionBar.MitosisAnimation(buttonCount: 4)
        let untouched = hidden
        hidden.hide(at: Self.showTime)
        #expect(hidden == untouched)
    }

    @Test("Buttons smaller than Spotlight's search row stay 54 points")
    func buttonDiameterHasAFloor() {
        #expect(QuickActionBar.Mitosis.buttonDiameter(collapsedHeight: 56) == 54)
        #expect(QuickActionBar.Mitosis.buttonDiameter(collapsedHeight: 64) == 62)
        #expect(QuickActionBar.Mitosis.buttonDiameter(collapsedHeight: 40) == 54)
    }
}

#endif
