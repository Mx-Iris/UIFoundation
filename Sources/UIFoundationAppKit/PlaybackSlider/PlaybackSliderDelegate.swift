#if os(macOS)

import AppKit

/// The delegate of a ``PlaybackSlider``, told when the user presses the bar and when they let go.
///
/// Both methods have empty default implementations. A player typically stops moving the slider to
/// the playback position while the user scrubs, and seeks once scrubbing ends; the slider's action,
/// sent continuously during the drag, carries the position the user is at.
///
/// The slider tells the delegate on the main thread only.
@MainActor
public protocol PlaybackSliderDelegate: AnyObject {
    /// Tells the delegate that the user pressed the mouse button on the slider.
    ///
    /// Sent when tracking begins, with `doubleValue` already at the pressed point — a press anywhere
    /// on the bar moves the value there, as Music's does — and before the slider sends its action for
    /// it. The bar starts growing at the same moment. Always followed by
    /// ``playbackSliderDidEndScrubbing(_:)``, even for a click without a drag.
    ///
    /// Not sent for a change made with the keyboard or VoiceOver, nor for a change of `doubleValue` in code.
    func playbackSliderDidBeginScrubbing(_ playbackSlider: PlaybackSlider)

    /// Tells the delegate that the user released the mouse button, or that tracking was cancelled.
    ///
    /// Sent with `doubleValue` where the drag last moved it, as the bar starts shrinking back. The
    /// slider sends one more action after it, for the release itself, carrying the same value.
    func playbackSliderDidEndScrubbing(_ playbackSlider: PlaybackSlider)
}

extension PlaybackSliderDelegate {
    public func playbackSliderDidBeginScrubbing(_ playbackSlider: PlaybackSlider) {}
    public func playbackSliderDidEndScrubbing(_ playbackSlider: PlaybackSlider) {}
}

#endif
