#if os(macOS)

import AppKit
import Testing
@testable import UIFoundationAppKit

// Pressing, dragging, the springs and the frames that draw them. The tests call the cell's tracking
// methods — what AppKit calls, through its gesture recognizers with the macOS 27 SDK and through
// its tracking loop before — and run the springs on a test clock. They post no real clicks: on macOS
// 27.2 a test runner started from a terminal that starts handling window events is ended a moment
// later, exit status 0 and no results. So AppKit's own share is not covered here — that a continuous
// slider sends its action on the press, for every reported movement and once more after the release.

extension PlaybackSliderTestSuites {
@MainActor
@Suite("PlaybackSlider: pressing, springs and frames")
struct PlaybackSliderTrackingTests {
    let window = makePlaybackSliderTestWindow()
    let clock = PlaybackSliderTestClock()

    private func cell(of slider: PlaybackSlider) throws -> PlaybackSliderCell {
        try #require(slider.cell as? PlaybackSliderCell)
    }

    // MARK: Pressing and dragging

    /// The value is the pointer's share of the whole width (MediaCoreUI 0x2596863DC, with Music's zero
    /// drag margin and insets): a press at 86.4 points of 288 is 30 %, where a plain slider would allow
    /// for its knob and give 29. The delegate hears of the press with the value already moved.
    @Test func aPressMovesTheValueToThePointer() throws {
        let slider = makePlaybackSlider(value: 50, in: window)
        let recorder = PlaybackSliderTestRecorder.recording(slider)

        _ = try cell(of: slider).startTracking(at: playbackSliderPoint(86.4), in: slider)

        #expect(recorder.events == ["begin 30.0"])
        #expect(playbackSliderValue(slider.doubleValue, isCloseTo: 30, tolerance: 0.0001))
    }

    /// A drag moves the value only while the pointer is at least 3 points to either side of the press
    /// (MediaCoreUI 0x259686A48: `|translation.width| >= 3`), checked on every movement: coming back
    /// within 3 points stops it again.
    @Test func aDragFollowsThePointerOnlyThreePointsOrMoreFromThePress() throws {
        let slider = makePlaybackSlider(value: 50, in: window)
        let cell = try cell(of: slider)
        _ = cell.startTracking(at: playbackSliderPoint(144), in: slider)
        var values: [Double] = []

        for (lastX, currentX) in [(144.0, 146.0), (146.0, 147.0), (147.0, 145.0), (145.0, 201.6)] {
            _ = cell.continueTracking(last: playbackSliderPoint(lastX), current: playbackSliderPoint(currentX), in: slider)
            values.append((slider.doubleValue * 10).rounded() / 10)
        }

        #expect(values == [50, 51, 51, 70], "146 is 2 points from the press, 147 is 3, 145 is 1 again and 201.6 is 70 % of the way")
    }

    @Test func aDragTellsTheDelegateOnceAtEachEnd() throws {
        let slider = makePlaybackSlider(value: 50, in: window)
        let recorder = PlaybackSliderTestRecorder.recording(slider)
        let cell = try cell(of: slider)

        _ = cell.startTracking(at: playbackSliderPoint(86.4), in: slider)
        _ = cell.continueTracking(last: playbackSliderPoint(86.4), current: playbackSliderPoint(144), in: slider)
        _ = cell.continueTracking(last: playbackSliderPoint(144), current: playbackSliderPoint(230.4), in: slider)
        cell.stopTracking(last: playbackSliderPoint(230.4), current: playbackSliderPoint(230.4), in: slider, mouseIsUp: true)

        #expect(recorder.events == ["begin 30.0", "end 80.0"])
    }

    /// Music lays its time slider out left to right whatever the language (`MacTimeControlView`,
    /// MediaCoreUI 0x2596D27E0).
    @Test func theBarRunsLeftToRightInARightToLeftLayout() throws {
        let slider = makePlaybackSlider(value: 30, in: window)
        slider.userInterfaceLayoutDirection = .rightToLeft

        let bitmap = renderPlaybackSliderTestView(slider)
        _ = try cell(of: slider).startTracking(at: playbackSliderPoint(230.4), in: slider)

        #expect(bitmap.playbackSliderPixel(x: 40, yFromTop: 8).isWhite(opacity: 0.45))
        #expect(bitmap.playbackSliderPixel(x: 150, yFromTop: 8).isWhite(opacity: 0.18))
        #expect(playbackSliderValue(slider.doubleValue, isCloseTo: 80, tolerance: 0.0001))
    }

    // MARK: The pressed bar

    /// While the slider is pressed, `ContentBelowSliderStyle` draws with a second style (MediaCoreUI
    /// 0x259688614): a 16-point capsule with no padding — the whole row — whose elapsed part is plain white.
    @Test func whilePressedTheBarFillsTheRowAndTheElapsedPartIsWhite() throws {
        let slider = makePlaybackSlider(value: 50, in: window)
        clock.drive(slider)

        _ = try cell(of: slider).startTracking(at: playbackSliderPoint(86.4), in: slider)
        clock.now += 2
        let bitmap = renderPlaybackSliderTestView(slider)

        #expect(bitmap.playbackSliderPixel(x: 40, yFromTop: 8).isWhite(opacity: 1))
        #expect(bitmap.playbackSliderPixel(x: 150, yFromTop: 0.25).isWhite(opacity: 0.18))
        #expect(bitmap.playbackSliderPixel(x: 150, yFromTop: 15.75).isWhite(opacity: 0.18))
        #expect(bitmap.playbackSliderPixel(x: 0.25, yFromTop: 0.25).alpha == 0, "the ends are half circles 8 points across")
    }

    @Test func lettingGoShrinksTheBarBackToRest() throws {
        let slider = makePlaybackSlider(value: 50, in: window)
        clock.drive(slider)
        let cell = try cell(of: slider)

        _ = cell.startTracking(at: playbackSliderPoint(86.4), in: slider)
        clock.now += 2
        cell.stopTracking(last: playbackSliderPoint(86.4), current: playbackSliderPoint(86.4), in: slider, mouseIsUp: true)
        clock.now += 2
        let bitmap = renderPlaybackSliderTestView(slider)

        #expect(bitmap.playbackSliderPixel(x: 40, yFromTop: 8).isWhite(opacity: 0.45))
        #expect(bitmap.playbackSliderPixel(x: 150, yFromTop: 0.25).alpha == 0)
        #expect(bitmap.playbackSliderPixel(x: 150, yFromTop: 4.25).alpha == 0)
        #expect(bitmap.playbackSliderPixel(x: 150, yFromTop: 4.75).isWhite(opacity: 0.18))
    }

    // MARK: Springs

    /// `.animation(.interpolatingSpring(mass: 1, stiffness: 350, damping: 40), value: isDragging)`
    /// (MediaCoreUI 0x2595C8094, used from 0x259682BE8). The expected values are that spring's closed
    /// form: a little over-damped, so no overshoot.
    @Test func theBarGrowsWithMusicsSpring() throws {
        let slider = makePlaybackSlider(value: 50, in: window)
        clock.drive(slider)
        let cell = try cell(of: slider)

        _ = cell.startTracking(at: playbackSliderPoint(144), in: slider)

        #expect(playbackSliderValue(Double(cell.presentedExpansion), isCloseTo: 0, tolerance: 1e-6))
        let expansionByTime: [(time: Double, expansion: Double)] = [(0.016, 0.036335), (0.05, 0.233296), (0.1, 0.535600), (0.2, 0.859860), (0.4, 0.989154)]
        for (time, expansion) in expansionByTime {
            clock.now = 1000 + time
            #expect(playbackSliderValue(Double(cell.presentedExpansion), isCloseTo: expansion, tolerance: 1e-5), "\(time) s after the press")
        }
    }

    /// 0.1 s after the press the bar has grown 53.56 % of the way: 11.82 points tall, so its top edge
    /// is 2.09 points down, and the elapsed part is white at 0.45 + 0.55 × 0.5356 = 74.5 %.
    @Test func theDrawnBarFollowsTheSpring() throws {
        let slider = makePlaybackSlider(value: 50, in: window)
        clock.drive(slider)

        _ = try cell(of: slider).startTracking(at: playbackSliderPoint(86.4), in: slider)
        clock.now += 0.1
        let bitmap = renderPlaybackSliderTestView(slider)

        #expect(bitmap.playbackSliderPixel(x: 150, yFromTop: 1.75).alpha == 0)
        #expect(bitmap.playbackSliderPixel(x: 150, yFromTop: 2.75).isWhite(opacity: 0.18))
        #expect(bitmap.playbackSliderPixel(x: 40, yFromTop: 8).isWhite(opacity: 0.45 + 0.55 * 0.5356))
    }

    @Test func lettingGoShrinksTheBarWithTheSameSpring() throws {
        let slider = makePlaybackSlider(value: 50, in: window)
        clock.drive(slider)
        let cell = try cell(of: slider)

        _ = cell.startTracking(at: playbackSliderPoint(144), in: slider)
        clock.now = 1002
        cell.stopTracking(last: playbackSliderPoint(144), current: playbackSliderPoint(144), in: slider, mouseIsUp: true)

        clock.now = 1002.05
        #expect(playbackSliderValue(Double(cell.presentedExpansion), isCloseTo: 0.766704, tolerance: 1e-5))
        clock.now = 1002.1
        #expect(playbackSliderValue(Double(cell.presentedExpansion), isCloseTo: 0.464400, tolerance: 1e-5))
    }

    /// An interpolating spring adds onto one still running instead of replacing it, so a release
    /// before the bar has finished growing leaves it growing a little longer before it turns: the
    /// growth's step response minus the shrink's.
    @Test func lettingGoMidwayCarriesTheBarsMovementOn() throws {
        let slider = makePlaybackSlider(value: 50, in: window)
        clock.drive(slider)
        let cell = try cell(of: slider)

        _ = cell.startTracking(at: playbackSliderPoint(144), in: slider)
        clock.now = 1000.05
        cell.stopTracking(last: playbackSliderPoint(144), current: playbackSliderPoint(144), in: slider, mouseIsUp: true)

        clock.now = 1000.1
        #expect(playbackSliderValue(Double(cell.presentedExpansion), isCloseTo: 0.302304, tolerance: 1e-5), "still above the 0.233 it was let go at")
        clock.now = 1000.2
        #expect(playbackSliderValue(Double(cell.presentedExpansion), isCloseTo: 0.119363, tolerance: 1e-5))
    }

    /// The press moves the value inside `withAnimation(.spring(response: 0.15, dampingFraction: 1))`
    /// (MediaCoreUI 0x259686BC4, 0x259686B04): the value is the pointer's at once, and the elapsed part
    /// slides there, critically damped.
    @Test func thePressSlidesTheElapsedPartToThePointer() throws {
        let slider = makePlaybackSlider(value: 50, in: window)
        clock.drive(slider)
        let cell = try cell(of: slider)

        _ = cell.startTracking(at: playbackSliderPoint(86.4), in: slider)

        #expect(playbackSliderValue(slider.doubleValue, isCloseTo: 30, tolerance: 1e-9))
        #expect(playbackSliderValue(cell.presentedFraction, isCloseTo: 0.5, tolerance: 1e-6))
        let fractionByTime: [(time: Double, fraction: Double)] = [(0.016, 0.470897), (0.05, 0.376212), (0.1, 0.315737), (1.0, 0.3)]
        for (time, fraction) in fractionByTime {
            clock.now = 1000 + time
            #expect(playbackSliderValue(cell.presentedFraction, isCloseTo: fraction, tolerance: 1e-5), "\(time) s after the press")
        }
    }

    /// The drag sets the value without an animation, so the elapsed part is drawn where the value is
    /// at once, even when the press's slide is still running.
    @Test func aDragDuringTheSlideIsDrawnAtOnce() throws {
        let slider = makePlaybackSlider(value: 50, in: window)
        clock.drive(slider)
        let cell = try cell(of: slider)

        _ = cell.startTracking(at: playbackSliderPoint(86.4), in: slider)
        clock.now = 1000.02
        _ = cell.continueTracking(last: playbackSliderPoint(86.4), current: playbackSliderPoint(230.4), in: slider)

        #expect(playbackSliderValue(cell.presentedFraction, isCloseTo: 0.8, tolerance: 1e-6))
    }

    /// A press while the elapsed part is still sliding to the last one retargets the running
    /// `.spring`, as SwiftUI does: the part goes on from where it is at the speed it has, not from a
    /// standstill, which would give 0.249210 and 0.536049. 0.03 s into the slide from 0 to 30 % the part
    /// is at 0.107322, moving at 4.494374 widths a second.
    @Test func aPressDuringTheSlideSendsTheElapsedPartOnAtTheSpeedItHas() throws {
        let slider = makePlaybackSlider(value: 0, in: window)
        clock.drive(slider)
        let cell = try cell(of: slider)
        _ = cell.startTracking(at: playbackSliderPoint(86.4), in: slider)
        cell.stopTracking(last: playbackSliderPoint(86.4), current: playbackSliderPoint(86.4), in: slider, mouseIsUp: true)
        clock.now = 1000.03

        _ = cell.startTracking(at: playbackSliderPoint(230.4), in: slider)

        #expect(playbackSliderValue(cell.presentedFraction, isCloseTo: 0.107322, tolerance: 1e-5), "no jump at the second press")
        let fractionByTime: [(time: Double, fraction: Double)] = [(0.02, 0.288102), (0.05, 0.563722)]
        for (time, fraction) in fractionByTime {
            clock.now = 1000.03 + time
            #expect(playbackSliderValue(cell.presentedFraction, isCloseTo: fraction, tolerance: 1e-5), "\(time) s after the second press")
        }
    }

    @Test func aValueSetInCodeIsDrawnAtOnce() throws {
        let slider = makePlaybackSlider(value: 50, in: window)
        clock.drive(slider)

        slider.doubleValue = 70

        #expect(playbackSliderValue(try cell(of: slider).presentedFraction, isCloseTo: 0.7, tolerance: 1e-6))
    }

    // MARK: Frames

    /// A frame asks for a redraw on the slider's layer. The view's own `needsDisplay` says nothing
    /// here: a layer-backed view hands the request on to its layer and reads `false` at once.
    @Test func aPressRedrawsTheSliderEveryFrameUntilTheBarComesToRest() throws {
        let slider = makePlaybackSlider(value: 50, in: window)
        clock.drive(slider)
        let cell = try cell(of: slider)
        let layer = try #require(slider.layer)

        _ = cell.startTracking(at: playbackSliderPoint(86.4), in: slider)
        #expect(slider.isRunningAnimationFrames)
        layer.displayIfNeeded()
        try #require(!layer.needsDisplay(), "a layer that has just drawn")
        clock.now += 0.05
        slider.animationFrame(nil)
        #expect(layer.needsDisplay())
        #expect(slider.isRunningAnimationFrames)

        clock.now += 2
        slider.animationFrame(nil)
        #expect(!slider.isRunningAnimationFrames, "the bar is at rest, pressed")

        cell.stopTracking(last: playbackSliderPoint(86.4), current: playbackSliderPoint(86.4), in: slider, mouseIsUp: true)
        #expect(slider.isRunningAnimationFrames)
        clock.now += 2
        slider.animationFrame(nil)
        #expect(!slider.isRunningAnimationFrames, "the bar is at rest again")
    }

    @Test func takingTheSliderOutOfItsWindowStopsTheFrames() throws {
        let slider = makePlaybackSlider(value: 50, in: window)
        clock.drive(slider)
        _ = try cell(of: slider).startTracking(at: playbackSliderPoint(86.4), in: slider)

        slider.removeFromSuperview()
        #expect(!slider.isRunningAnimationFrames)

        window.contentView?.addSubview(slider)
        #expect(slider.isRunningAnimationFrames, "the bar is still growing when it comes back")
    }

    @Test func aSliderOutsideAWindowRunsNoFrames() throws {
        let slider = PlaybackSlider(frame: NSRect(x: 0, y: 0, width: 288, height: 16))
        clock.drive(slider)

        _ = try cell(of: slider).startTracking(at: playbackSliderPoint(86.4), in: slider)

        #expect(!slider.isRunningAnimationFrames)
    }

    @Test func aValueSetInCodeRunsNoFrames() {
        let slider = makePlaybackSlider(value: 50, in: window)

        slider.doubleValue = 70

        #expect(!slider.isRunningAnimationFrames)
    }

    /// macOS 12 and 13 have no view display links, so there the frames come from a timer; the switch
    /// sends this system down the same path. A display link never fires in a window off screen and a
    /// timer does, so here the frames really arrive, and only an arriving frame can find the bar at
    /// rest and stop them.
    @Test func onATimerTheFramesRunUntilTheBarComesToRest() throws {
        let slider = makePlaybackSlider(value: 50, in: window)
        clock.drive(slider)
        slider.animationFramesUseTimer = true

        _ = try cell(of: slider).startTracking(at: playbackSliderPoint(86.4), in: slider)
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.1))
        #expect(slider.isRunningAnimationFrames, "the test clock has not moved, so the bar is still growing")

        clock.now += 2
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.1))
        #expect(!slider.isRunningAnimationFrames, "a frame came, found the bar at rest and stopped the frames")
    }

    /// The timer holds the slider, so a slider leaving its window while the bar still moves has to
    /// stop it to be freed.
    @Test func onATimerASliderTakenOutOfItsWindowIsFreed() throws {
        weak var weakSlider: PlaybackSlider?
        try autoreleasepool {
            let slider = makePlaybackSlider(value: 50, in: window)
            clock.drive(slider)
            slider.animationFramesUseTimer = true
            let cell = try cell(of: slider)
            _ = cell.startTracking(at: playbackSliderPoint(86.4), in: slider)
            cell.stopTracking(last: playbackSliderPoint(86.4), current: playbackSliderPoint(86.4), in: slider, mouseIsUp: true)
            #expect(slider.isRunningAnimationFrames, "the bar is shrinking back")

            slider.removeFromSuperview()
            weakSlider = slider
        }
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.05))

        #expect(weakSlider == nil)
    }
}
}

#endif
