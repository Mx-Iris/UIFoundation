//
//  Replicated from macOS 26's Spotlight.app (26.6.2).
//  Decision record: Documentations/Evolutions/0021-spotlight-panel-replica.md
//

#if SpotlightPanel && os(macOS)

import Foundation

extension SpotlightPanel {
    /// One search request, completable now or later.
    ///
    /// The panel hands a task to the data source and forgets about it; whichever task completes
    /// while still current wins, and the rest are no-ops. That is what lets a host answer out of
    /// order without having to track staleness itself.
    @MainActor
    public final class SearchTask {
        /// What the user has typed, already trimmed of nothing — exactly the field's contents.
        public let searchTerm: String

        /// `true` once the panel has moved on and this task's results would be discarded.
        public private(set) var isCancelled = false

        private var completion: (([AnyHashable]) -> Void)?

        init(searchTerm: String, completion: @escaping ([AnyHashable]) -> Void) {
            self.searchTerm = searchTerm
            self.completion = completion
        }

        /// Supply the results. Calling this more than once, or after cancellation, does nothing.
        public func complete(with results: [AnyHashable]) {
            guard let completion else { return }
            self.completion = nil
            completion(results)
        }

        /// Supply the results from a background context.
        ///
        /// Provided because a host doing real work off the main thread would otherwise have to
        /// write the hop itself at every call site.
        public nonisolated func completeFromBackgroundThread(with results: [AnyHashable]) {
            let sendableResults = results
            Task { @MainActor [weak self] in
                self?.complete(with: sendableResults)
            }
        }

        /// Abandon this request without producing results.
        public func cancel() {
            completion = nil
            isCancelled = true
        }
    }
}

#endif
