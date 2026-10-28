//
//  PlaybackSliderDemoViewController.swift
//  UIFoundationExample-macOS
//
//  Music's full-screen time slider on a dark backdrop, following a simulated
//  playback clock. The bar is left alone while it is pressed and seeks once on
//  release; the arrow keys seek at once. The scrubbing callbacks are logged.
//

import AppKit
import UIFoundation

final class PlaybackSliderDemoViewController: NSViewController, PlaybackSliderDelegate {
    private let duration: TimeInterval = 217
    private var currentTime: TimeInterval = 40
    private var isScrubbing = false
    private var playbackTimer: Timer?

    private let backdrop = LayerBackedView()
    private let timeSlider = PlaybackSlider()
    private let elapsedLabel = NSTextField(labelWithString: "")
    private let remainingLabel = NSTextField(labelWithString: "")
    private let eventLabel = NSTextField(labelWithString: "Press or drag the bar, or focus it and use the arrow keys.")

    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 720, height: 360))
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        // Music's player sits on a dark, blurred artwork; the bar is drawn for it.
        backdrop.backgroundColor = NSColor(white: 0.12, alpha: 1)
        backdrop.cornerRadius = 16
        backdrop.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(backdrop)

        timeSlider.minValue = 0
        timeSlider.maxValue = duration
        timeSlider.doubleValue = currentTime
        timeSlider.scrubbingDelegate = self
        timeSlider.box.actionBlock = { [weak self] _ in
            self?.timeSliderDidChangeValue()
        }
        timeSlider.translatesAutoresizingMaskIntoConstraints = false
        backdrop.addSubview(timeSlider)

        for label in [elapsedLabel, remainingLabel] {
            label.font = .monospacedDigitSystemFont(ofSize: 11, weight: .medium)
            label.textColor = NSColor.white.withAlphaComponent(0.6)
            label.translatesAutoresizingMaskIntoConstraints = false
            backdrop.addSubview(label)
        }
        remainingLabel.alignment = .right

        eventLabel.textColor = .secondaryLabelColor
        eventLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(eventLabel)

        NSLayoutConstraint.activate([
            backdrop.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 40),
            backdrop.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -40),
            backdrop.topAnchor.constraint(equalTo: view.topAnchor, constant: 40),

            timeSlider.leadingAnchor.constraint(equalTo: backdrop.leadingAnchor, constant: 32),
            timeSlider.trailingAnchor.constraint(equalTo: backdrop.trailingAnchor, constant: -32),
            timeSlider.topAnchor.constraint(equalTo: backdrop.topAnchor, constant: 40),

            // Music puts its time labels 6 points below the slider's 16-point row.
            elapsedLabel.topAnchor.constraint(equalTo: timeSlider.bottomAnchor, constant: 6),
            elapsedLabel.leadingAnchor.constraint(equalTo: timeSlider.leadingAnchor),
            elapsedLabel.bottomAnchor.constraint(equalTo: backdrop.bottomAnchor, constant: -32),
            remainingLabel.topAnchor.constraint(equalTo: timeSlider.bottomAnchor, constant: 6),
            remainingLabel.trailingAnchor.constraint(equalTo: timeSlider.trailingAnchor),

            eventLabel.leadingAnchor.constraint(equalTo: backdrop.leadingAnchor),
            eventLabel.trailingAnchor.constraint(lessThanOrEqualTo: backdrop.trailingAnchor),
            eventLabel.topAnchor.constraint(equalTo: backdrop.bottomAnchor, constant: 16),
        ])
        showTime(currentTime)
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        playbackTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.advancePlayback(by: 0.1)
            }
        }
    }

    override func viewWillDisappear() {
        super.viewWillDisappear()
        playbackTimer?.invalidate()
        playbackTimer = nil
    }

    // MARK: Playback

    private func advancePlayback(by interval: TimeInterval) {
        currentTime = currentTime + interval >= duration ? 0 : currentTime + interval
        // A pressed bar follows the pointer, not playback.
        guard !isScrubbing else { return }
        timeSlider.doubleValue = currentTime
        showTime(currentTime)
    }

    private func seek(to time: TimeInterval, because reason: String) {
        currentTime = time
        showTime(time)
        eventLabel.stringValue = "\(reason): seek to \(Self.format(time))"
    }

    // MARK: PlaybackSliderDelegate

    func playbackSliderDidBeginScrubbing(_ playbackSlider: PlaybackSlider) {
        isScrubbing = true
        showTime(playbackSlider.doubleValue)
        eventLabel.stringValue = "Pressed at \(Self.format(playbackSlider.doubleValue))"
    }

    func playbackSliderDidEndScrubbing(_ playbackSlider: PlaybackSlider) {
        isScrubbing = false
        seek(to: playbackSlider.doubleValue, because: "Released")
    }

    /// Sent on the press, for every movement of a drag, once more after the release, and for each
    /// arrow key or VoiceOver adjustment.
    private func timeSliderDidChangeValue() {
        if isScrubbing {
            showTime(timeSlider.doubleValue)
        } else if timeSlider.doubleValue != currentTime {
            // The arrow keys and VoiceOver; the action after a release carries the time just sought to.
            seek(to: timeSlider.doubleValue, because: "Arrow key")
        }
    }

    private func showTime(_ time: TimeInterval) {
        elapsedLabel.stringValue = Self.format(time)
        remainingLabel.stringValue = "-" + Self.format(max(0, duration - time))
    }

    private static func format(_ time: TimeInterval) -> String {
        let totalSeconds = Int(max(0, time))
        return String(format: "%d:%02d", totalSeconds / 60, totalSeconds % 60)
    }
}
