#if os(macOS)

import AppKit
import QuartzCore

/// The time slider of the Music app's full-screen player: a thin capsule with no knob that grows to
/// the full height of the slider while it is pressed. Port of MediaCoreUI's `MacTimeControlView` with
/// `ContentBelowSliderStyle` (macOS 26.6), by way of AppKitPlus's `NSPlaybackSlider`; the contract is
/// in `Documentations/PlaybackSlider.md`.
///
/// At rest the bar is a 7-point capsule across the middle of the 16-point-tall slider, its elapsed
/// part drawn brighter than the rest. Pressing anywhere moves the value to the pointer, slides the
/// elapsed part there and grows the bar to fill the slider; dragging moves the value with the pointer;
/// letting go shrinks the bar back.
///
/// It is an `NSSlider` in every other respect: the value, its range, `isContinuous`, the target and
/// action, the keyboard and accessibility work the way they do for any slider. Because it is
/// continuous, AppKit sends the action on the press, for every movement of the drag it reports and
/// once more after the release; ``scrubbingDelegate`` is told when the press begins and ends.
///
/// With the `AppleInternal` trait on it adds its colours onto whatever is behind it, as Music's
/// `plusLighter` blending does, through Core Animation's private "plusL" compositing filter on its
/// layer; leave the layer's `compositingFilter` alone then. Without the trait it blends normally, a
/// little darker on a dark backdrop. Under Increase Contrast it always blends normally.
///
/// Main thread only. Built in code: there is no nib support.
open class PlaybackSlider: NSSlider {
    /// The slider's height: the 7-point capsule with 4.5 points of padding above and below
    /// (MediaCoreUI 0x259688318).
    static let height: CGFloat = 16

    /// The object told when the user presses the bar and when they let go. Not retained.
    public weak var scrubbingDelegate: PlaybackSliderDelegate?

    /// The clock the springs run on; `nil` is `CACurrentMediaTime()`. Tests replace it.
    var mediaTimeProvider: (() -> CFTimeInterval)?

    /// Increase Contrast forced on or off, for tests; `nil` follows the appearance. The system hands
    /// out its high-contrast appearances only while the user's setting is on.
    var increasedContrastOverride: Bool? {
        didSet {
            updateCompositingFilter()
            needsDisplay = true
        }
    }

    /// Sends a system with view display links down the path of macOS 12 and 13, where the frames come
    /// from a timer. For tests: a display link never fires in a window off screen and a timer does.
    var animationFramesUseTimer = false

    /// The display link — or before macOS 14 the timer — that calls ``animationFrame(_:)`` while the
    /// bar moves. It holds the slider, so it is invalidated when the bar comes to rest and when the
    /// slider leaves its window.
    private var animationFrameSource: AnyObject?

    override open class var cellClass: AnyClass? {
        get { PlaybackSliderCell.self }
        set { super.cellClass = newValue }
    }

    override public init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        isContinuous = true
        sliderType = .linear
        wantsLayer = true
        updateCompositingFilter()
    }

    @available(*, unavailable)
    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private var playbackCell: PlaybackSliderCell? {
        cell as? PlaybackSliderCell
    }

    // MARK: - Appearance

    var increasesContrast: Bool {
        increasedContrastOverride ?? PlaybackSliderCell.appearanceIncreasesContrast(effectiveAppearance)
    }

    /// Music draws the time slider with `.blendMode(.plusLighter)`, or `.normal` under Increase
    /// Contrast (MediaCoreUI 0x2596D2668). SwiftUI's plus-lighter is Core Animation's "plusL"
    /// compositing filter, which only a layer takes — the view's own `compositingFilter` takes Core
    /// Image filters, whose addition comes out far brighter. The filter is private, so it is set only
    /// under the `AppleInternal` trait; without the trait the layer's filter is left alone.
    private func updateCompositingFilter() {
        #if AppleInternal
        guard let layer else { return }
        let compositingFilter: String? = increasesContrast ? nil : "plusL"
        if layer.compositingFilter as? String != compositingFilter {
            layer.compositingFilter = compositingFilter
        }
        #endif
    }

    override open func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        updateCompositingFilter()
        needsDisplay = true
    }

    // MARK: - Clock

    var mediaTime: CFTimeInterval {
        mediaTimeProvider?() ?? CACurrentMediaTime()
    }

    // MARK: - Frames

    var isRunningAnimationFrames: Bool {
        animationFrameSource != nil
    }

    /// Redraws the slider on every display frame until the bar comes to rest. Does nothing outside a
    /// window, or while the frames already run.
    func startAnimationFrames() {
        guard animationFrameSource == nil, window != nil else { return }
        if #available(macOS 14.0, *), !animationFramesUseTimer {
            let displayLink = displayLink(target: self, selector: #selector(animationFrame(_:)))
            displayLink.add(to: .main, forMode: .common)
            animationFrameSource = displayLink
            return
        }
        let timer = Timer(timeInterval: 1.0 / 60.0, target: self, selector: #selector(animationFrame(_:)), userInfo: nil, repeats: true)
        RunLoop.main.add(timer, forMode: .common)
        animationFrameSource = timer
    }

    private func stopAnimationFrames() {
        if #available(macOS 14.0, *), let displayLink = animationFrameSource as? CADisplayLink {
            displayLink.invalidate()
        }
        (animationFrameSource as? Timer)?.invalidate()
        animationFrameSource = nil
    }

    @objc func animationFrame(_ frameSource: Any?) {
        needsDisplay = true
        if window?.firstResponder === self {
            noteFocusRingMaskChanged()
        }
        if playbackCell?.isAnimating(at: mediaTime) != true {
            stopAnimationFrames()
        }
    }

    override open func viewWillMove(toWindow newWindow: NSWindow?) {
        stopAnimationFrames()
        super.viewWillMove(toWindow: newWindow)
    }

    override open func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        updateCompositingFilter()
        if playbackCell?.isAnimating(at: mediaTime) == true {
            startAnimationFrames()
        }
    }

    // MARK: - Size

    // 16 points tall and no intrinsic width; `sizeToFit` and the cell's `cellSize` give the same height.
    override open var intrinsicContentSize: NSSize {
        NSSize(width: NSView.noIntrinsicMetric, height: Self.height)
    }

    // Its alignment rectangle is its frame: Music places its time labels 6 points below this row.
    override open var alignmentRectInsets: NSEdgeInsets {
        NSEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
    }
}

#endif
