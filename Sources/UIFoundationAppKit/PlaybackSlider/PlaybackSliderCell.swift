#if os(macOS)

import AppKit
import QuartzCore

/// The cell of a ``PlaybackSlider``: it draws the bar — the capsule, its elapsed part and the rest —
/// and tracks the press and the drag. Port of the drawing of MediaCoreUI's `CapsuleProgress` with the
/// two `CapsuleProgressStyle`s of `ContentBelowSliderStyle`, the springs between them and the
/// dragging of `DraggableViewModifier` (macOS 26.6; addresses are into its dyld shared cache), by way
/// of AppKitPlus's `NSPlaybackSliderCell`.
///
/// It draws one horizontal bar in Music's colours, left to right in every layout direction: tick
/// marks, a circular or vertical slider and `trackFillColor` are not supported. The control asks its
/// cell which way the arrow keys run, so they run left to right as well.
open class PlaybackSliderCell: NSSliderCell {
    /// The height of the row the bar sits in: the resting capsule and its padding, and the pressed capsule.
    static let rowHeight: CGFloat = 16
    /// The capsule's height at rest (MediaCoreUI 0x259688318).
    static let restingBarHeight: CGFloat = 7
    /// The opacity of the white the elapsed part is drawn in at rest (MediaCoreUI 0x2595F1EA0).
    static let restingElapsedOpacity: CGFloat = 0.45
    /// The opacity of the white the rest of the bar is drawn in (MediaCoreUI 0x2595F1EBC).
    static let remainingOpacity: CGFloat = 0.18
    /// The opacity of system gray for the rest of the bar under Increase Contrast (MediaCoreUI 0x2595F1FD8).
    static let increasedContrastRemainingOpacity: CGFloat = 0.3
    /// The opacity the whole bar is drawn at while the slider is disabled: both styles' `disabledOpacity`.
    static let disabledOpacity: CGFloat = 0.25
    /// How far the pointer must be to either side of the press before a drag moves the value
    /// (MediaCoreUI 0x259686A4C).
    static let dragThreshold: CGFloat = 3

    /// Whether the elapsed part may still be sliding to the value of the last press.
    private var isSlidingToPress = false
    /// Where the press that is being tracked went down, along the bar.
    private var trackingStartX: CGFloat = 0
    /// Between the resting bar, 0, and the pressed bar, 1.
    private var expansionMotion = PlaybackSliderSpringMotion.atRest
    /// The elapsed part's slide to a press, as a share of the width; used only while `isSlidingToPress`.
    private var slideMotion = PlaybackSliderSpringMotion.atRest

    private var slider: PlaybackSlider? {
        controlView as? PlaybackSlider
    }

    /// The time the cell's springs run on: its slider's clock.
    private var mediaTime: CFTimeInterval {
        slider?.mediaTime ?? CACurrentMediaTime()
    }

    // MARK: - State

    /// How far the bar has grown from resting, 0, towards pressed, 1, now.
    var presentedExpansion: CGFloat {
        expansion(at: mediaTime)
    }

    /// The share of the width the elapsed part covers now.
    var presentedFraction: Double {
        drawnFraction(at: mediaTime)
    }

    /// Whether a spring is still moving the bar at `time`.
    func isAnimating(at time: CFTimeInterval) -> Bool {
        isSliding(at: time) || !PlaybackSliderSpring.expansion.hasSettled(expansionMotion, at: time)
    }

    /// The share of the range the value covers, kept between 0 and 1; 0 for an empty range.
    private var fraction: Double {
        let range = maxValue - minValue
        guard range > 0 else { return 0 }
        return min(max((doubleValue - minValue) / range, 0), 1)
    }

    /// The value under `x` in `controlView`: the pointer's share of the whole width, kept between 0
    /// and 1 and laid out left to right whatever the layout direction (MediaCoreUI 0x2596863DC, with
    /// the zero drag margin and insets of Music's player, which also makes the layout left to right).
    private func value(atX x: CGFloat, in controlView: NSView) -> Double {
        let rowRect = Self.rowRect(in: controlView.bounds)
        let fraction = rowRect.width > 0 ? Double((x - rowRect.minX) / rowRect.width) : 0
        return minValue + min(max(fraction, 0), 1) * (maxValue - minValue)
    }

    /// Whether the elapsed part is still sliding to the value of the last press: it stops once it
    /// arrives, and at once when the value changes in any other way, which is drawn without an animation.
    private func isSliding(at time: CFTimeInterval) -> Bool {
        guard isSlidingToPress, abs(slideMotion.target - fraction) <= 1e-9 else { return false }
        return !PlaybackSliderSpring.slide.hasSettled(slideMotion, at: time)
    }

    private func expansion(at time: CFTimeInterval) -> CGFloat {
        if PlaybackSliderSpring.expansion.hasSettled(expansionMotion, at: time) {
            return CGFloat(expansionMotion.target)
        }
        return CGFloat(min(max(PlaybackSliderSpring.expansion.evaluate(expansionMotion, at: time).position, 0), 1))
    }

    private func drawnFraction(at time: CFTimeInterval) -> Double {
        guard isSliding(at: time) else { return fraction }
        return min(max(PlaybackSliderSpring.slide.evaluate(slideMotion, at: time).position, 0), 1)
    }

    /// Sends the bar towards `expansion` from wherever it is now.
    private func expand(to expansion: Double, at time: CFTimeInterval) {
        expansionMotion = PlaybackSliderSpring.expansion.retargeted(expansionMotion, at: time, to: expansion)
    }

    // MARK: - Layout direction

    // Music lays its time slider out left to right whatever the language (MediaCoreUI 0x2596D27E0).
    // The control asks its cell which way the arrow keys run.
    override open var userInterfaceLayoutDirection: NSUserInterfaceLayoutDirection {
        get { .leftToRight }
        set { super.userInterfaceLayoutDirection = newValue }
    }

    // MARK: - Size

    // The row's height whatever the control size: Music's bar comes in one size.
    override open var cellSize: NSSize {
        NSSize(width: super.cellSize.width, height: Self.rowHeight)
    }

    override open func cellSize(forBounds rect: NSRect) -> NSSize {
        NSSize(width: super.cellSize(forBounds: rect).width, height: Self.rowHeight)
    }

    // MARK: - Drawing

    override open func barRect(flipped: Bool) -> NSRect {
        guard let controlView else { return super.barRect(flipped: flipped) }
        return Self.rowRect(in: controlView.bounds)
    }

    // `CapsuleProgress.body` (MediaCoreUI 0x259687128): the elapsed part and the rest of the bar side
    // by side, split at the value's share of the width (`SplitPercentageLayout`, 0x25957CA94), clipped
    // together to a capsule.
    override open func drawBar(inside rect: NSRect, flipped: Bool) {
        let time = mediaTime
        let expansion = expansion(at: time)
        let barRect = Self.barRect(in: rect, expansion: expansion)
        let increasesContrast = slider?.increasesContrast ?? Self.appearanceIncreasesContrast(NSAppearance.currentDrawing())
        let isDisabled = !isEnabled

        NSGraphicsContext.saveGraphicsState()
        let context = NSGraphicsContext.current?.cgContext
        if isDisabled {
            context?.setAlpha(Self.disabledOpacity)
            context?.beginTransparencyLayer(auxiliaryInfo: nil)
        }
        Self.capsulePath(in: barRect).setClip()
        let elapsedWidth = barRect.width * CGFloat(drawnFraction(at: time))
        var elapsedRect = barRect
        elapsedRect.size.width = elapsedWidth
        var remainingRect = barRect
        remainingRect.origin.x += elapsedWidth
        remainingRect.size.width -= elapsedWidth
        Self.elapsedColor(increasesContrast: increasesContrast, expansion: expansion).setFill()
        elapsedRect.fill(using: .sourceOver)
        Self.remainingColor(increasesContrast: increasesContrast).setFill()
        remainingRect.fill(using: .sourceOver)
        if isDisabled {
            context?.endTransparencyLayer()
        }
        NSGraphicsContext.restoreGraphicsState()
    }

    // Music's bar has no knob.
    override open func drawKnob(_ knobRect: NSRect) {}

    // MARK: - Focus ring

    // A plain slider rings its knob; with none drawn, the ring goes round the bar as it is drawn now.
    override open func focusRingMaskBounds(forFrame cellFrame: NSRect, in controlView: NSView) -> NSRect {
        Self.barRect(in: Self.rowRect(in: cellFrame), expansion: presentedExpansion)
    }

    override open func drawFocusRingMask(withFrame cellFrame: NSRect, in controlView: NSView) {
        Self.capsulePath(in: focusRingMaskBounds(forFrame: cellFrame, in: controlView)).fill()
    }

    // MARK: - Tracking

    // The first change of `DraggableViewModifier`'s drag gesture, which has no minimum distance and so
    // comes with the press (MediaCoreUI 0x259686A84): the value moves to the pointer at once and the
    // elapsed part slides there, and `ContentBelowSliderStyle` starts growing the bar (0x259683EC4).
    override open func startTracking(at startPoint: NSPoint, in controlView: NSView) -> Bool {
        let time = mediaTime
        let slideStartFraction = drawnFraction(at: time)
        let slideStartVelocity = isSliding(at: time) ? PlaybackSliderSpring.slide.evaluate(slideMotion, at: time).velocity : 0

        let isTracking = super.startTracking(at: startPoint, in: controlView)
        trackingStartX = startPoint.x
        doubleValue = value(atX: startPoint.x, in: controlView)
        slideMotion = PlaybackSliderSpringMotion(startTime: time, startPosition: slideStartFraction, startVelocity: slideStartVelocity, target: fraction)
        isSlidingToPress = true
        expand(to: 1, at: time)
        controlView.needsDisplay = true

        if let slider {
            slider.startAnimationFrames()
            slider.scrubbingDelegate?.playbackSliderDidBeginScrubbing(slider)
        }
        return isTracking
    }

    // The later changes of the drag (MediaCoreUI 0x259686A40): the value follows the pointer only while
    // it is at least 3 points to either side of the press. Not super, which moves the value as far as
    // the pointer moved from the knob.
    override open func continueTracking(last lastPoint: NSPoint, current currentPoint: NSPoint, in controlView: NSView) -> Bool {
        if abs(currentPoint.x - trackingStartX) >= Self.dragThreshold {
            doubleValue = value(atX: currentPoint.x, in: controlView)
        }
        return true
    }

    // The end of the drag (MediaCoreUI 0x259686B54): `ContentBelowSliderStyle` shrinks the bar back.
    override open func stopTracking(last lastPoint: NSPoint, current stopPoint: NSPoint, in controlView: NSView, mouseIsUp flag: Bool) {
        super.stopTracking(last: lastPoint, current: stopPoint, in: controlView, mouseIsUp: flag)
        expand(to: 0, at: mediaTime)
        controlView.needsDisplay = true

        if let slider {
            slider.startAnimationFrames()
            slider.scrubbingDelegate?.playbackSliderDidEndScrubbing(slider)
        }
    }

    // MARK: - Geometry and colour

    /// The 16-point row, the full width of `frame` and centred in its height.
    static func rowRect(in frame: NSRect) -> NSRect {
        NSRect(x: frame.minX, y: frame.midY - rowHeight / 2, width: frame.width, height: rowHeight)
    }

    /// The capsule `expansion` of the way from resting to pressed, across the whole row and centred in it.
    static func barRect(in rowRect: NSRect, expansion: CGFloat) -> NSRect {
        let barHeight = restingBarHeight + (rowRect.height - restingBarHeight) * expansion
        return NSRect(x: rowRect.minX, y: rowRect.midY - barHeight / 2, width: rowRect.width, height: barHeight)
    }

    /// Whether `appearance` is one of the system's high-contrast appearances. The system hands them
    /// out only while Increase Contrast is on: with it off, an appearance asked for by a high-contrast
    /// name is the ordinary one.
    static func appearanceIncreasesContrast(_ appearance: NSAppearance) -> Bool {
        let matchingName = appearance.bestMatch(from: [
            .aqua,
            .darkAqua,
            .accessibilityHighContrastAqua,
            .accessibilityHighContrastDarkAqua,
        ])
        return matchingName == .accessibilityHighContrastAqua || matchingName == .accessibilityHighContrastDarkAqua
    }

    /// The colour of the elapsed part `expansion` of the way from resting to pressed: white at 45 % and
    /// plain white (MediaCoreUI 0x259688318, 0x259688614), or under Increase Contrast system gray and
    /// `Color.primary`.
    static func elapsedColor(increasesContrast: Bool, expansion: CGFloat) -> NSColor {
        guard increasesContrast else {
            return NSColor(white: 1, alpha: restingElapsedOpacity + (1 - restingElapsedOpacity) * expansion)
        }
        let restingColor = NSColor.systemGray.usingColorSpace(.sRGB) ?? .gray
        let pressedColor = NSColor.labelColor.usingColorSpace(.sRGB) ?? .black
        func interpolated(_ restingComponent: CGFloat, _ pressedComponent: CGFloat) -> CGFloat {
            restingComponent + (pressedComponent - restingComponent) * expansion
        }
        return NSColor(
            srgbRed: interpolated(restingColor.redComponent, pressedColor.redComponent),
            green: interpolated(restingColor.greenComponent, pressedColor.greenComponent),
            blue: interpolated(restingColor.blueComponent, pressedColor.blueComponent),
            alpha: interpolated(restingColor.alphaComponent, pressedColor.alphaComponent)
        )
    }

    /// The colour of the rest of the bar: white at 18 %, or under Increase Contrast system gray at 30 %.
    static func remainingColor(increasesContrast: Bool) -> NSColor {
        guard increasesContrast else { return NSColor(white: 1, alpha: remainingOpacity) }
        return NSColor.systemGray.withAlphaComponent(increasedContrastRemainingOpacity)
    }

    /// SwiftUI's `Capsule(style: .continuous)`, which `CapsuleProgress` clips to (MediaCoreUI
    /// 0x259687128). Read from `path(in:)` on macOS 27.2: Apple's continuous corner along the length —
    /// its shoulder reaching 1.5286649 radii from the corner — and across the height a shoulder
    /// shortened to the half height, at any width. Each point below is its distance from the corner in
    /// radii, along the length and then across the height.
    static func capsulePath(in barRect: NSRect) -> NSBezierPath {
        let shoulderAcrossStart: CGFloat = 1, shoulderAcrossFirstControl: CGFloat = 0.96, shoulderAcrossSecondControl: CGFloat = 0.82
        let cornerNear: CGFloat = 0.0749114, cornerFar: CGFloat = 0.631494
        let cornerControlNear: CGFloat = 0.16906, cornerControlFar: CGFloat = 0.372824
        let shoulderAlongFirstControl: CGFloat = 0.868407, shoulderAlongSecondControl: CGFloat = 1.08849, shoulderAlongEnd: CGFloat = 1.5286649

        let radius = barRect.height / 2
        let path = NSBezierPath()
        path.move(to: NSPoint(x: barRect.maxX, y: barRect.maxY - shoulderAcrossStart * radius))
        // Each corner: the shoulder across the height, the curve round the corner, the shoulder along the length.
        for cornerIndex in 0 ..< 4 {
            let cornerX = (cornerIndex == 0 || cornerIndex == 3) ? barRect.maxX : barRect.minX
            let cornerY = (cornerIndex == 0 || cornerIndex == 1) ? barRect.maxY : barRect.minY
            // The signs that point from the corner back into the bar.
            let towardsX: CGFloat = cornerX == barRect.maxX ? -1 : 1
            let towardsY: CGFloat = cornerY == barRect.maxY ? -1 : 1
            func point(_ along: CGFloat, _ across: CGFloat) -> NSPoint {
                NSPoint(x: cornerX + towardsX * along * radius, y: cornerY + towardsY * across * radius)
            }
            // A corner is drawn from its shoulder across the height to its shoulder along the length,
            // or the other way round.
            if cornerIndex == 0 || cornerIndex == 2 {
                path.curve(to: point(cornerNear, cornerFar), controlPoint1: point(0, shoulderAcrossFirstControl), controlPoint2: point(0, shoulderAcrossSecondControl))
                path.curve(to: point(cornerFar, cornerNear), controlPoint1: point(cornerControlNear, cornerControlFar), controlPoint2: point(cornerControlFar, cornerControlNear))
                path.curve(to: point(shoulderAlongEnd, 0), controlPoint1: point(shoulderAlongFirstControl, 0), controlPoint2: point(shoulderAlongSecondControl, 0))
            } else {
                path.line(to: point(shoulderAlongEnd, 0))
                path.curve(to: point(cornerFar, cornerNear), controlPoint1: point(shoulderAlongSecondControl, 0), controlPoint2: point(shoulderAlongFirstControl, 0))
                path.curve(to: point(cornerNear, cornerFar), controlPoint1: point(cornerControlFar, cornerControlNear), controlPoint2: point(cornerControlNear, cornerControlFar))
                path.curve(to: point(0, shoulderAcrossStart), controlPoint1: point(0, shoulderAcrossSecondControl), controlPoint2: point(0, shoulderAcrossFirstControl))
            }
        }
        path.close()
        return path
    }
}

#endif
