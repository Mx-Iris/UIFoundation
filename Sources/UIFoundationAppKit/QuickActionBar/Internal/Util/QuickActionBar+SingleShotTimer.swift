//
//  QuickActionBar+SingleShotTimer.swift
//  UIFoundation
//
//  Ported into UIFoundation from DSFQuickActionBar by Darren Ford
//  (https://github.com/dagronf/DSFQuickActionBar).
//
//  MIT License — Copyright (c) 2022 Darren Ford
//

#if QuickActionBar && os(macOS)

import Foundation

extension QuickActionBar {
    /// A single-use cancellable timer.
    internal final class SingleShotTimer {
        /// Create a single-use timer object.
        /// - Parameters:
        ///   - delay: The amount of time to delay before calling the completion block.
        ///   - queue: The queue on which to call the completion block.
        ///   - completionBlock: Called when the timer fires.
        init(delay: TimeInterval, queue: DispatchQueue = .main, _ completionBlock: @escaping () -> Void) {
            self.workItem = DispatchWorkItem(block: { completionBlock() })
            queue.asyncAfter(deadline: .now() + delay, execute: workItem!)
        }

        func cancel() {
            self.stop()
        }

        deinit {
            self.stop()
        }

        private var workItem: DispatchWorkItem?

        private func stop() {
            self.workItem?.cancel()
            self.workItem = nil
        }
    }
}

#endif
