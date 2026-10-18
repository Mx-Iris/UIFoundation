//
//  QuickActionBar+SearchTask.swift
//  UIFoundation
//
//  Ported into UIFoundation from DSFQuickActionBar by Darren Ford
//  (https://github.com/dagronf/DSFQuickActionBar).
//
//  MIT License — Copyright (c) 2022 Darren Ford
//

#if QuickActionBar && os(macOS)

import Foundation
import OSToolbox

public extension QuickActionBar {
    /// An async-capable search task representing a single search term query.
    final class SearchTask {
        /// The search term for the query.
        public let searchTerm: String

        /// Is the current search task cancelled?
        public var isCancelled: Bool {
            completion.withLock { $0 == nil }
        }

        /// Supply the results for this search query.
        public func complete(with results: [AnyHashable]) {
            completion.withLock { $0?(results) }
        }

        /// Cancel the current search request.
        public func cancel() {
            completion.withLock { $0?(nil) }
        }

        /// `completion` is `sending` because the task takes it over: every call to it is made with
        /// the lock held.
        internal init(searchTerm: String, completion: sending @escaping ([AnyHashable]?) -> Void) {
            self.completion = Mutex(completion)
            self.searchTerm = searchTerm
        }

        /// Detaches the task from the bar: from here on it reports `isCancelled` and delivers
        /// nothing.
        internal func invalidate() {
            completion.withLock { $0 = nil }
        }

        /// Called with the lock held, so once `invalidate()` returns it is never called again.
        private let completion: Mutex<(([AnyHashable]?) -> Void)?>
    }
}

#endif
