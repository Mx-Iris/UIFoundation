#if os(macOS)

import AppKit
import Testing
@testable import UIFoundationAppKit

// The fixtures of the PlaybackSlider tests, ported from AppKitPlus's NSPlaybackSliderTests. The
// expectations there are the numbers read from MediaCoreUI on macOS 26.6, the framework that draws
// the time slider of Music's full-screen player.

/// The PlaybackSlider suites, run one test at a time. The timer tests run the main run loop, which
/// would let other main-actor tests interleave with them; and a display link or timer a test leaves
/// running would fire into the next one.
@Suite(.serialized)
enum PlaybackSliderTestSuites {}

/// The clock the tests run a slider's springs on. Every test starts it at 1000 seconds.
@MainActor
final class PlaybackSliderTestClock {
    var now: CFTimeInterval = 1000

    /// Makes `slider`'s springs run on this clock. The slider holds the clock: a display link or timer
    /// can still fire into the slider after the test that made it has ended.
    func drive(_ slider: PlaybackSlider) {
        slider.mediaTimeProvider = { self.now }
    }
}

/// Key without being made key, so that clicks reach the slider without activating the test process.
final class PlaybackSliderTestWindow: NSWindow {
    override var isKeyWindow: Bool { true }
    override var canBecomeKey: Bool { true }
}

/// A borderless window far off screen, in the dark appearance Music's player draws in, with a
/// 400 × 100 content view.
@MainActor
func makePlaybackSliderTestWindow() -> PlaybackSliderTestWindow {
    let window = PlaybackSliderTestWindow(
        contentRect: NSRect(x: -4000, y: -4000, width: 400, height: 100),
        styleMask: .borderless,
        backing: .buffered,
        defer: false
    )
    window.isReleasedWhenClosed = false
    window.contentView = NSView(frame: NSRect(x: 0, y: 0, width: 400, height: 100))
    window.appearance = NSAppearance(named: .darkAqua)
    return window
}

/// A slider 288 points wide — Music's mini player's width, for numbers that are easy to check — at
/// its own height, valued 0 to 100, in `window`.
@MainActor
func makePlaybackSlider(value: Double, in window: NSWindow) -> PlaybackSlider {
    let slider = PlaybackSlider(frame: NSRect(x: 20, y: 20, width: 288, height: 16))
    slider.minValue = 0
    slider.maxValue = 100
    slider.doubleValue = value
    window.contentView?.addSubview(slider)
    return slider
}

/// The middle of the row at `x` points along `slider`, where the tests press and drag.
@MainActor
func playbackSliderPoint(_ x: CGFloat) -> NSPoint {
    NSPoint(x: x, y: 8)
}

// MARK: - Pixels

/// One rendered pixel, as 8-bit sRGB with premultiplied alpha.
struct PlaybackSliderTestPixel: Equatable, CustomStringConvertible {
    var red: Int
    var green: Int
    var blue: Int
    var alpha: Int

    var description: String { "(\(red), \(green), \(blue), \(alpha))" }

    /// Whether this is white at `opacity`, give or take a step of rounding.
    func isWhite(opacity: Double) -> Bool {
        let expectedAlpha = Int((opacity * 255).rounded())
        return abs(alpha - expectedAlpha) <= 1 && red == alpha && green == alpha && blue == alpha
    }

    /// Whether the two differ by no more than two steps in any channel.
    func matches(_ expectedPixel: PlaybackSliderTestPixel) -> Bool {
        abs(red - expectedPixel.red) <= 2 && abs(green - expectedPixel.green) <= 2
            && abs(blue - expectedPixel.blue) <= 2 && abs(alpha - expectedPixel.alpha) <= 2
    }
}

let playbackSliderTestScale: CGFloat = 2

/// An empty sRGB bitmap twice `size`, so pixels compare as numbers whatever the display is.
func makePlaybackSliderTestBitmap(_ size: NSSize) -> NSBitmapImageRep {
    let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: Int(size.width * playbackSliderTestScale),
        pixelsHigh: Int(size.height * playbackSliderTestScale),
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .calibratedRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    )!
    return bitmap.retagging(with: .sRGB)!
}

/// `view` drawn at twice its size.
@MainActor
func renderPlaybackSliderTestView(_ view: NSView) -> NSBitmapImageRep {
    let size = view.bounds.size
    let bitmap = makePlaybackSliderTestBitmap(size)
    bitmap.size = size
    view.cacheDisplay(in: view.bounds, to: bitmap)
    return bitmap
}

/// The focus ring mask `view` draws when AppKit asks it for one, in black at twice its size, laid
/// out as `renderPlaybackSliderTestView(_:)` lays out a rendering.
@MainActor
func renderPlaybackSliderFocusRingMask(_ view: NSView) -> NSBitmapImageRep {
    let size = view.bounds.size
    let bitmap = makePlaybackSliderTestBitmap(size)
    let context = NSGraphicsContext(bitmapImageRep: bitmap)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = context
    if view.isFlipped {
        context.cgContext.translateBy(x: 0, y: size.height * playbackSliderTestScale)
        context.cgContext.scaleBy(x: playbackSliderTestScale, y: -playbackSliderTestScale)
    } else {
        context.cgContext.scaleBy(x: playbackSliderTestScale, y: playbackSliderTestScale)
    }
    NSColor.black.setFill()
    view.drawFocusRingMask()
    NSGraphicsContext.restoreGraphicsState()
    return bitmap
}

extension NSBitmapImageRep {
    /// The pixel under the point `x`, `yFromTop` of the rendered view.
    func playbackSliderPixel(x: CGFloat, yFromTop: CGFloat) -> PlaybackSliderTestPixel {
        let column = Int((x * playbackSliderTestScale).rounded(.down))
        let row = Int((yFromTop * playbackSliderTestScale).rounded(.down))
        let pixel = bitmapData! + row * bytesPerRow + column * 4
        return PlaybackSliderTestPixel(red: Int(pixel[0]), green: Int(pixel[1]), blue: Int(pixel[2]), alpha: Int(pixel[3]))
    }
}

/// `color` as `appearance` resolves it, as the pixel it draws over nothing.
@MainActor
func playbackSliderTestPixel(of color: NSColor, in appearance: NSAppearance) -> PlaybackSliderTestPixel {
    var resolvedColor = NSColor.clear
    appearance.performAsCurrentDrawingAppearance {
        resolvedColor = color.usingColorSpace(.sRGB) ?? .clear
    }
    let alpha = resolvedColor.alphaComponent
    func channel(_ component: CGFloat) -> Int { Int((component * alpha * 255).rounded()) }
    return PlaybackSliderTestPixel(
        red: channel(resolvedColor.redComponent),
        green: channel(resolvedColor.greenComponent),
        blue: channel(resolvedColor.blueComponent),
        alpha: Int((alpha * 255).rounded())
    )
}

/// Whether `value` is within `tolerance` of `expected`. Both are `Double`: a `CGFloat` compared with
/// a `Double` inside `#expect` passes whatever the values are.
func playbackSliderValue(_ value: Double, isCloseTo expected: Double, tolerance: Double) -> Bool {
    abs(value - expected) <= tolerance
}

// MARK: - Recording

/// Records the delegate's callbacks and the slider's actions in the order they arrive, each with
/// the value it saw.
@MainActor
final class PlaybackSliderTestRecorder: NSObject, PlaybackSliderDelegate {
    private(set) var events: [String] = []

    /// A recorder that `slider`'s delegate, target and action report to.
    static func recording(_ slider: PlaybackSlider) -> PlaybackSliderTestRecorder {
        let recorder = PlaybackSliderTestRecorder()
        slider.scrubbingDelegate = recorder
        slider.target = recorder
        slider.action = #selector(sliderDidChangeValue(_:))
        return recorder
    }

    func playbackSliderDidBeginScrubbing(_ playbackSlider: PlaybackSlider) {
        events.append("begin " + Self.format(playbackSlider.doubleValue))
    }

    func playbackSliderDidEndScrubbing(_ playbackSlider: PlaybackSlider) {
        events.append("end " + Self.format(playbackSlider.doubleValue))
    }

    @objc func sliderDidChangeValue(_ sender: NSSlider) {
        events.append("action " + Self.format(sender.doubleValue))
    }

    private static func format(_ value: Double) -> String {
        String(format: "%.1f", value)
    }
}

/// Counts the scroll events that reach it — through the responder chain from a subview that passes
/// them on.
final class PlaybackSliderTestScrollRecorderView: NSView {
    private(set) var scrollWheelEventCount = 0

    override func scrollWheel(with event: NSEvent) {
        scrollWheelEventCount += 1
    }
}

/// A scroll as two fingers on a trackpad send it: points, with positive deltas scrolling up and left.
func makePlaybackSliderTrackpadScrollEvent(vertical verticalDelta: Int32, horizontal horizontalDelta: Int32) -> NSEvent {
    let scrollEvent = CGEvent(
        scrollWheelEvent2Source: nil,
        units: .pixel,
        wheelCount: 2,
        wheel1: verticalDelta,
        wheel2: horizontalDelta,
        wheel3: 0
    )!
    scrollEvent.setIntegerValueField(.scrollWheelEventScrollPhase, value: Int64(CGScrollPhase.changed.rawValue))
    return NSEvent(cgEvent: scrollEvent)!
}

#endif
