//
//  QuickActionBar+DelayedIndeterminiteRadialProgressIndicator.swift
//  UIFoundation
//
//  Ported into UIFoundation from DSFQuickActionBar by Darren Ford
//  (https://github.com/dagronf/DSFQuickActionBar).
//
//  MIT License — Copyright (c) 2022 Darren Ford
//

#if QuickActionBar && os(macOS)

import AppKit
import Foundation

extension QuickActionBar {
    /// A radial, indeterminite, `NSProgressIndicator` that delays its visibility for a specific time.
    @IBDesignable
    internal final class DelayedIndeterminiteRadialProgressIndicator: NSProgressIndicator {
        /// The time to delay before displaying the spinner.
        @IBInspectable var delayUntilDisplay: TimeInterval = 0.25

        convenience init() {
            self.init(frame: .zero)
        }

        override init(frame frameRect: NSRect) {
            super.init(frame: frameRect)
            self.setup()
        }

        required init?(coder: NSCoder) {
            super.init(coder: coder)
            self.setup()
        }

        /// Start the animation. The spinner becomes visible only after the delay.
        override func startAnimation(_ sender: Any?) {
            assert(Thread.isMainThread)
            guard self._timer == nil || self.isHidden == false else {
                return
            }
            self._timer = SingleShotTimer(delay: self.delayUntilDisplay) { [weak self] in
                self?.delayedStart()
            }
        }

        /// Stop and hide the spinner.
        override func stopAnimation(_ sender: Any?) {
            assert(Thread.isMainThread)
            self._timer?.cancel()
            self._timer = nil
            super.stopAnimation(self)
        }

        private var _timer: SingleShotTimer?

        private func setup() {
            self.translatesAutoresizingMaskIntoConstraints = false
            self.wantsLayer = true
            self.usesThreadedAnimation = true
            self.isIndeterminate = true
            self.isDisplayedWhenStopped = false
            self.style = .spinning
            self.controlSize = .regular

            self.setContentHuggingPriority(.defaultHigh, for: .horizontal)
            self.setContentHuggingPriority(.defaultHigh, for: .vertical)
            self.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)
            self.setContentCompressionResistancePriority(.defaultHigh, for: .vertical)
        }

        private func delayedStart() {
            self._timer = nil
            super.startAnimation(self)
        }
    }
}

#endif
