//
//  QuickActionBar+SearchTask.swift
//  UIFoundation
//
//  Ported into UIFoundation from DSFQuickActionBar by Darren Ford
//  (https://github.com/dagronf/DSFQuickActionBar).
//
//  MIT License — Copyright (c) 2022 Darren Ford
//

#if QuickActionBar

import Foundation

public extension QuickActionBar {
    /// An async-capable search task representing a single search term query.
    final class SearchTask {
        /// The search term for the query.
        public let searchTerm: String

        /// Is the current search task cancelled?
        public var isCancelled: Bool {
            self.completionLock.lock()
            defer { self.completionLock.unlock() }
            return completion == nil
        }

        /// Supply the results for this search query.
        public func complete(with results: [AnyHashable]) {
            self.completionLock.lock()
            defer { self.completionLock.unlock() }
            self.completion?(results)
        }

        /// Cancel the current search request.
        public func cancel() {
            self.completionLock.lock()
            defer { self.completionLock.unlock() }
            self.completion?(nil)
        }

        internal init(searchTerm: String, completion: @escaping ([AnyHashable]?) -> Void) {
            self.completion = completion
            self.searchTerm = searchTerm
        }

        internal var completion: (([AnyHashable]?) -> Void)?
        internal let completionLock = NSLock()
    }
}

#endif
