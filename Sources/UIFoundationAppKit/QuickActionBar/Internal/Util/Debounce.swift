//
//  Debounce.swift
//  UIFoundation
//
//  Ported into UIFoundation from DSFQuickActionBar by Darren Ford
//  (https://github.com/dagronf/DSFQuickActionBar).
//
//  MIT License — Copyright (c) 2022 Darren Ford
//

#if QuickActionBar

import Dispatch
import Foundation

extension QuickActionBar {
    internal final class Debounce {
        private let interval: TimeInterval
        private let queue: DispatchQueue
        private var workItem = DispatchWorkItem(block: {})

        init(seconds: TimeInterval, queue: DispatchQueue = DispatchQueue.main) {
            self.interval = seconds
            self.queue = queue
        }

        func debounce(action: @escaping (() -> Void)) {
            self.workItem.cancel()
            self.workItem = DispatchWorkItem(block: { action() })
            self.queue.asyncAfter(deadline: .now() + self.interval, execute: self.workItem)
        }
    }
}

#endif
