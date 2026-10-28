#if os(macOS)

import AppKit
import Testing
@testable import UIFoundationAppKit

// PlaybackSlider against what the time slider of Music's full-screen player does on macOS 26.6:
// MediaCoreUI's `ContentBelowSliderStyle`, `CapsuleProgress` and `DraggableViewModifier`. Ported from
// AppKitPlus's NSPlaybackSliderTests; the addresses beside the numbers are into the 26.6 dyld shared
// cache. Pressing, springs and frames are in PlaybackSliderTrackingTests.

extension PlaybackSliderTestSuites {
@MainActor
@Suite("PlaybackSlider: defaults, geometry and drawing")
struct PlaybackSliderTests {
    let window = makePlaybackSliderTestWindow()
    let clock = PlaybackSliderTestClock()

    // MARK: Defaults and drawing path

    @Test func aNewSliderIsAContinuousLinearSlider() {
        let slider = PlaybackSlider(frame: .zero)

        #expect(type(of: slider.cell!) == PlaybackSliderCell.self)
        #expect(slider.isContinuous)
        #expect(slider.sliderType == .linear)
        #expect(slider.scrubbingDelegate == nil)
    }

    /// A cell that overrides `drawBar(inside:flipped:)` and the rest makes AppKit drop the subviews
    /// a plain slider draws with.
    @Test func itDrawsThroughItsCellInsteadOfAppKitsSubviews() throws {
        let plainSlider = NSSlider(frame: NSRect(x: 20, y: 50, width: 288, height: 16))
        window.contentView?.addSubview(plainSlider)
        let slider = makePlaybackSlider(value: 30, in: window)

        _ = renderPlaybackSliderTestView(try #require(window.contentView))

        #expect(plainSlider.subviews.count > 0, "a plain slider drew without subviews here, so the comparison says nothing")
        #expect(slider.subviews.isEmpty)
    }

    // MARK: Geometry

    /// Music's row is a 7-point capsule with 4.5 points of padding above and below it (MediaCoreUI
    /// 0x259688318), and the time labels sit 6 points below the row, so the row is what lines up
    /// with its neighbours.
    @Test func theSliderIsSixteenPointsTallAndAlignsByItsFrame() {
        let slider = PlaybackSlider(frame: .zero)
        slider.translatesAutoresizingMaskIntoConstraints = false
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 300, height: 60))
        container.addSubview(slider)
        NSLayoutConstraint.activate([
            slider.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            slider.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            slider.topAnchor.constraint(equalTo: container.topAnchor, constant: 20),
        ])
        container.layoutSubtreeIfNeeded()

        #expect(Double(slider.intrinsicContentSize.height) == 16)
        #expect(Double(slider.intrinsicContentSize.width) == Double(NSView.noIntrinsicMetric))
        #expect(Double(slider.frame.height) == 16)
        let insets = slider.alignmentRectInsets
        #expect(Double(insets.top) == 0)
        #expect(Double(insets.left) == 0)
        #expect(Double(insets.bottom) == 0)
        #expect(Double(insets.right) == 0)
    }

    /// The control size changes nothing: AppKit's own slider is 12 points tall at the mini size, the
    /// bar's row is 16.
    @Test(arguments: [NSControl.ControlSize.mini, .small, .regular, .large])
    func sizingToFitMakesTheSliderSixteenPointsTallAtEveryControlSize(controlSize: NSControl.ControlSize) {
        let slider = PlaybackSlider(frame: NSRect(x: 0, y: 0, width: 200, height: 40))
        slider.controlSize = controlSize

        slider.sizeToFit()

        #expect(Double(slider.frame.height) == 16)
        #expect(Double(slider.cell!.cellSize.height) == 16)
        #expect(Double(slider.intrinsicContentSize.height) == 16)
    }

    @Test func atRestTheBarIsASevenPointCapsuleCentredInTheRow() {
        let slider = makePlaybackSlider(value: 30, in: window)

        let bitmap = renderPlaybackSliderTestView(slider)

        #expect(bitmap.playbackSliderPixel(x: 150, yFromTop: 4.25).alpha == 0)
        #expect(bitmap.playbackSliderPixel(x: 150, yFromTop: 4.75).alpha > 0)
        #expect(bitmap.playbackSliderPixel(x: 150, yFromTop: 11.25).alpha > 0)
        #expect(bitmap.playbackSliderPixel(x: 150, yFromTop: 11.75).alpha == 0)
        // The ends are half circles 3.5 points across: the corner of the capsule's box stays empty.
        #expect(bitmap.playbackSliderPixel(x: 0.25, yFromTop: 4.75).alpha == 0)
        #expect(bitmap.playbackSliderPixel(x: 0.25, yFromTop: 8).alpha > 0)
    }

    /// `CapsuleProgress` clips to `Capsule(style: .continuous)`. The expected points are what SwiftUI's
    /// own `path(in:)` gave for the resting bar, 288 × 7, on macOS 27.2 — less the two zero-length lines
    /// it adds at the middle of the ends.
    @Test func theBarsOutlineIsSwiftUIsContinuousCapsule() {
        let path = PlaybackSliderCell.capsulePath(in: NSRect(x: 0, y: 0, width: 288, height: 7))
        let expectedElements: [[Double]] = [
            [288.0, 3.5],
            [288.0, 3.64, 288.0, 4.13, 287.7378, 4.7898],
            [287.4083, 5.6951, 286.6951, 6.4083, 285.7898, 6.7378],
            [284.9606, 7.0, 284.1903, 7.0, 282.6497, 7.0],
            [5.3503, 7.0],
            [3.8097, 7.0, 3.0394, 7.0, 2.2102, 6.7378],
            [1.3049, 6.4083, 0.5917, 5.6951, 0.2622, 4.7898],
            [0.0, 4.13, 0.0, 3.64, 0.0, 3.5],
            [0.0, 3.36, 0.0, 2.87, 0.2622, 2.2102],
            [0.5917, 1.3049, 1.3049, 0.5917, 2.2102, 0.2622],
            [3.0394, 0.0, 3.8097, 0.0, 5.3503, 0.0],
            [282.6497, 0.0],
            [284.1903, 0.0, 284.9606, 0.0, 285.7898, 0.2622],
            [286.6951, 0.5917, 287.4083, 1.3049, 287.7378, 2.2102],
            [288.0, 2.87, 288.0, 3.36, 288.0, 3.5],
            [],
        ]

        // AppKit follows the close with a move back to the start, one element more than SwiftUI's path.
        #expect(path.elementCount == expectedElements.count + 1)
        #expect(path.element(at: path.elementCount - 1) == .moveTo)
        for (elementIndex, expectedCoordinates) in expectedElements.enumerated() where elementIndex < path.elementCount {
            var points = [NSPoint](repeating: .zero, count: 3)
            path.element(at: elementIndex, associatedPoints: &points)
            for (coordinateIndex, expectedCoordinate) in expectedCoordinates.enumerated() {
                let point = points[coordinateIndex / 2]
                let coordinate = Double(coordinateIndex % 2 == 0 ? point.x : point.y)
                #expect(
                    playbackSliderValue(coordinate, isCloseTo: expectedCoordinate, tolerance: 0.0002),
                    "element \(elementIndex), coordinate \(coordinateIndex): \(coordinate)"
                )
            }
        }
    }

    /// The elapsed part is white at 45 % opacity and the rest of the bar white at 18 % (MediaCoreUI
    /// 0x2595F1EA0 and 0x2595F1EBC), side by side; the elapsed part takes the value's share of the whole
    /// width, with no inset at either end.
    @Test func theElapsedPartIsTheValuesShareOfTheWholeWidth() {
        let slider = makePlaybackSlider(value: 30, in: window)

        let bitmap = renderPlaybackSliderTestView(slider)

        #expect(bitmap.playbackSliderPixel(x: 1, yFromTop: 8).isWhite(opacity: 0.45))
        #expect(bitmap.playbackSliderPixel(x: 85.75, yFromTop: 8).isWhite(opacity: 0.45), "30 % of 288 points is 86.4")
        #expect(bitmap.playbackSliderPixel(x: 86.75, yFromTop: 8).isWhite(opacity: 0.18))
        #expect(bitmap.playbackSliderPixel(x: 286.75, yFromTop: 8).isWhite(opacity: 0.18))
    }

    @Test func theElapsedPartFillsTheBarAtTheMaximum() {
        let slider = makePlaybackSlider(value: 100, in: window)

        let bitmap = renderPlaybackSliderTestView(slider)

        #expect(bitmap.playbackSliderPixel(x: 1, yFromTop: 8).isWhite(opacity: 0.45))
        #expect(bitmap.playbackSliderPixel(x: 286.75, yFromTop: 8).isWhite(opacity: 0.45))
    }

    @Test func anEmptyRangeDrawsTheBarWithoutAnElapsedPart() {
        let slider = makePlaybackSlider(value: 0, in: window)
        slider.maxValue = 0

        let bitmap = renderPlaybackSliderTestView(slider)

        for x in stride(from: CGFloat(4), to: 284, by: 1) {
            #expect(bitmap.playbackSliderPixel(x: x, yFromTop: 8).isWhite(opacity: 0.18), "x = \(x)")
        }
    }

    // MARK: Contrast, enabling and blending

    /// Every colour is a `ContrastSensitiveShapeStyle` (MediaCoreUI 0x2595EE558): under Increase
    /// Contrast the elapsed part is system gray — `Color.primary` while pressed — and the rest of the
    /// bar system gray at 30 % (0x2595F1FA0, 0x2595F1FD8). The system hands out its high-contrast
    /// appearances only while the user's setting is on, so the test forces it.
    @Test func increasedContrastDrawsTheBarInSystemGray() throws {
        let appearance = try #require(window.appearance)
        let slider = makePlaybackSlider(value: 30, in: window)
        slider.increasedContrastOverride = true
        clock.drive(slider)

        let resting = renderPlaybackSliderTestView(slider)
        _ = slider.cell!.startTracking(at: playbackSliderPoint(86.4), in: slider)
        clock.now += 2
        let pressed = renderPlaybackSliderTestView(slider)

        let systemGray = playbackSliderTestPixel(of: .systemGray, in: appearance)
        let faintSystemGray = playbackSliderTestPixel(of: NSColor.systemGray.withAlphaComponent(0.3), in: appearance)
        let label = playbackSliderTestPixel(of: .labelColor, in: appearance)
        #expect(resting.playbackSliderPixel(x: 40, yFromTop: 8).matches(systemGray))
        #expect(resting.playbackSliderPixel(x: 150, yFromTop: 8).matches(faintSystemGray))
        #expect(pressed.playbackSliderPixel(x: 40, yFromTop: 8).matches(label))
        #expect(pressed.playbackSliderPixel(x: 150, yFromTop: 8).matches(faintSystemGray))
    }

    /// `CapsuleProgress` draws at the style's `disabledOpacity`, 0.25 in both of Music's (MediaCoreUI
    /// 0x259687128).
    @Test func aDisabledSliderIsDrawnAtAQuarterOfItsOpacity() {
        let slider = makePlaybackSlider(value: 30, in: window)
        slider.isEnabled = false

        let bitmap = renderPlaybackSliderTestView(slider)

        #expect(bitmap.playbackSliderPixel(x: 40, yFromTop: 8).isWhite(opacity: 0.45 * 0.25))
        #expect(bitmap.playbackSliderPixel(x: 150, yFromTop: 8).isWhite(opacity: 0.18 * 0.25))
    }

    #if AppleInternal
    /// Music draws the time slider with `.blendMode(.plusLighter)`, and with `.normal` under Increase
    /// Contrast (MediaCoreUI 0x2596D2668). Measured on macOS 27.2 by reading back a window's own image,
    /// SwiftUI's plus-lighter and Core Animation's "plusL" compositing filter give the same pixels
    /// (white at 45 % over 20 % gray: 181 both), while Core Image's addition filter gives 233. The
    /// window server applies the filter, which an offscreen rendering leaves out, so the filter on the
    /// slider's layer is what can be checked here.
    @Test func itsLayerAddsItsColoursOntoWhatIsBehindItExceptUnderIncreasedContrast() {
        let slider = makePlaybackSlider(value: 30, in: window)

        #expect(slider.wantsLayer)
        #expect(slider.layer?.compositingFilter as? String == "plusL")
        #expect(slider.compositingFilter == nil, "the view's own Core Image filter stays unused")

        slider.increasedContrastOverride = true
        #expect(slider.layer?.compositingFilter == nil)
        slider.increasedContrastOverride = nil
        #expect(slider.layer?.compositingFilter as? String == "plusL")
    }

    /// The windows stay off screen: on macOS 27.2 a test runner started from a terminal that puts a
    /// window on screen is ended a moment later.
    @Test func theLayersFilterSurvivesWhatAppKitDoesToTheLayer() throws {
        let slider = makePlaybackSlider(value: 30, in: window)
        _ = renderPlaybackSliderTestView(try #require(window.contentView))

        slider.frame = NSRect(x: 10, y: 30, width: 200, height: 16)
        slider.isHidden = true
        slider.isHidden = false
        window.appearance = NSAppearance(named: .aqua)
        slider.removeFromSuperview()
        let otherWindow = NSWindow(
            contentRect: NSRect(x: -4000, y: -4000, width: 300, height: 60),
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        otherWindow.isReleasedWhenClosed = false
        otherWindow.contentView?.addSubview(slider)
        slider.needsDisplay = true
        _ = renderPlaybackSliderTestView(try #require(otherWindow.contentView))

        #expect(slider.layer?.compositingFilter as? String == "plusL")
    }
    #else
    /// Without the `AppleInternal` trait the slider uses no private Core Animation filter: it draws
    /// with normal blending, a little darker on a dark backdrop than Music's bar.
    @Test func withoutTheAppleInternalTraitItsLayerBlendsNormally() {
        let slider = makePlaybackSlider(value: 30, in: window)

        #expect(slider.wantsLayer)
        #expect(slider.layer?.compositingFilter == nil)
        #expect(slider.compositingFilter == nil)
    }
    #endif

    /// With the setting off, an appearance asked for by its high-contrast name is the ordinary one
    /// (its `name` is `.darkAqua`, measured on macOS 27.2), and the bar is drawn for standard contrast.
    @Test(.enabled(if: !NSWorkspace.shared.accessibilityDisplayShouldIncreaseContrast, "Increase Contrast is on on this Mac"))
    func anAppearanceAskedForByAHighContrastNameCountsOnlyUnderTheSetting() throws {
        let highContrastAppearance = try #require(NSAppearance(named: .accessibilityHighContrastDarkAqua))
        let darkAppearance = try #require(NSAppearance(named: .darkAqua))

        #expect(!PlaybackSliderCell.appearanceIncreasesContrast(highContrastAppearance))
        #expect(!PlaybackSliderCell.appearanceIncreasesContrast(darkAppearance))
    }

    // MARK: Direction, scrolling and focus

    /// Only the bar inside runs left to right: in a right-to-left layout Auto Layout still places the
    /// slider by its leading edge, on the right, as it places any other view.
    @Test func autoLayoutPlacesTheSliderByItsLeadingEdgeInARightToLeftLayout() {
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 300, height: 40))
        container.userInterfaceLayoutDirection = .rightToLeft
        let slider = PlaybackSlider(frame: .zero)
        slider.userInterfaceLayoutDirection = .rightToLeft
        slider.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(slider)
        NSLayoutConstraint.activate([
            slider.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 20),
            slider.widthAnchor.constraint(equalToConstant: 100),
            slider.topAnchor.constraint(equalTo: container.topAnchor),
        ])

        container.layoutSubtreeIfNeeded()

        #expect(Double(slider.frame.minX) == 180)
    }

    @Test func theRightArrowKeyMovesTheValueUpInARightToLeftLayout() {
        let slider = makePlaybackSlider(value: 50, in: window)
        slider.userInterfaceLayoutDirection = .rightToLeft

        slider.moveRight(nil)

        #expect(slider.doubleValue > 50)
    }

    /// Music's time slider does nothing with the scroll wheel on macOS 26.6 (`DraggableViewModifier`
    /// has only a drag gesture), so a scroll goes on to the views behind it.
    @Test func aScrollGoesOnWithoutMovingTheValue() {
        let container = PlaybackSliderTestScrollRecorderView(frame: NSRect(x: 0, y: 0, width: 320, height: 40))
        window.contentView?.addSubview(container)
        let slider = PlaybackSlider(frame: NSRect(x: 0, y: 10, width: 288, height: 16))
        slider.minValue = 0
        slider.maxValue = 100
        slider.doubleValue = 50
        container.addSubview(slider)

        slider.scrollWheel(with: makePlaybackSliderTrackpadScrollEvent(vertical: 10, horizontal: 0))
        slider.scrollWheel(with: makePlaybackSliderTrackpadScrollEvent(vertical: 0, horizontal: 10))

        #expect(slider.doubleValue == 50)
        #expect(container.scrollWheelEventCount == 2)
    }

    /// A plain slider rings its knob; this bar has none, so the ring goes round the bar as it is drawn.
    @Test func theFocusRingGoesRoundTheBar() throws {
        let slider = makePlaybackSlider(value: 30, in: window)
        clock.drive(slider)
        let cell = try #require(slider.cell as? PlaybackSliderCell)

        #expect(cell.focusRingMaskBounds(forFrame: slider.bounds, in: slider) == NSRect(x: 0, y: 4.5, width: 288, height: 7))
        _ = cell.startTracking(at: playbackSliderPoint(86.4), in: slider)
        clock.now += 2
        #expect(cell.focusRingMaskBounds(forFrame: slider.bounds, in: slider) == NSRect(x: 0, y: 0, width: 288, height: 16))
    }

    /// The ring is the bar's own outline, the capsule, not the box round it: the box's corners stay
    /// out of the mask.
    @Test func theFocusRingFollowsTheCapsule() {
        let slider = makePlaybackSlider(value: 30, in: window)
        clock.drive(slider)

        let mask = renderPlaybackSliderFocusRingMask(slider)

        #expect(mask.playbackSliderPixel(x: 144, yFromTop: 8).alpha == 255, "the middle of the bar")
        #expect(mask.playbackSliderPixel(x: 1, yFromTop: 8).alpha == 255, "the round end, half way up")
        #expect(mask.playbackSliderPixel(x: 0, yFromTop: 4.5).alpha == 0, "the corner of the box round the bar")
        #expect(mask.playbackSliderPixel(x: 144, yFromTop: 2).alpha == 0, "the row above the bar")
    }

    // MARK: Accessibility

    /// AppKit makes a slider's cell the accessibility element and ignores the control.
    @Test func voiceOverSeesAppKitsOwnSliderThroughTheCell() throws {
        let slider = makePlaybackSlider(value: 50, in: window)
        let cell = try #require(slider.cell)

        #expect(cell.accessibilityRole() == .slider)
        #expect(cell.accessibilityValue() as? NSNumber == 50)
        slider.doubleValue = 70
        #expect(cell.accessibilityValue() as? NSNumber == 70)
        #expect(!slider.isAccessibilityElement())
    }

    // MARK: Lifecycle

    /// A window takes its views out of itself while it deallocates; nothing the slider does then may
    /// touch the window.
    @Test func aWindowHoldingTheSliderCanBeDeallocated() {
        autoreleasepool {
            var window: NSWindow? = NSWindow(
                contentRect: NSRect(x: -4000, y: -4000, width: 300, height: 40),
                styleMask: .borderless,
                backing: .buffered,
                defer: false
            )
            window?.isReleasedWhenClosed = false
            window?.contentView?.addSubview(PlaybackSlider(frame: NSRect(x: 10, y: 10, width: 200, height: 16)))
            window = nil
        }
    }
}
}

#endif
