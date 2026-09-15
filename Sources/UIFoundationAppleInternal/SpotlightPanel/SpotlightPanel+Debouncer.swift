//
//  Replicated from macOS 26's Spotlight.app (26.6.2).
//  Decision record: Documentations/Evolutions/0021-spotlight-panel-replica.md
//

#if SpotlightPanel && os(macOS)

import Foundation

extension SpotlightPanel {
    /// Coalesces a burst of requests into the last one.
    ///
    /// Spotlight keeps two of these, one for the search query and a separate one for window
    /// sizing, and the separation matters: results arriving in several passes would otherwise
    /// resize the window once per pass and read as a shudder.
    ///
    /// The timer runs in `.common` run loop modes so a panel raised during menu tracking still
    /// makes progress.
    @MainActor
    final class Debouncer {
        private let delay: TimeInterval
        private var scheduledTimer: Timer?

        init(delay: TimeInterval) {
            self.delay = delay
        }

        deinit {
            scheduledTimer?.invalidate()
        }

        /// Run `action` once the delay elapses with no further scheduling.
        func schedule(_ action: @escaping () -> Void) {
            scheduledTimer?.invalidate()
            let timer = Timer(timeInterval: delay, repeats: false) { _ in
                MainActor.assumeIsolated { action() }
            }
            RunLoop.main.add(timer, forMode: .common)
            scheduledTimer = timer
        }

        /// Run `action` now, dropping anything pending.
        func fireImmediately(_ action: () -> Void) {
            cancel()
            action()
        }

        func cancel() {
            scheduledTimer?.invalidate()
            scheduledTimer = nil
        }
    }
}

#endif
