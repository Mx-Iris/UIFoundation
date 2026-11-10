import Combine
import Foundation

/// The state of a ``ViewportScrollCoordinator``, split out so tests can compare
/// whole states.
internal struct ScrollDragState: Equatable, Sendable {
    /// `true` while the user drags a scroll bar's knob.
    internal var isUserDragging: Bool

    /// The latest range reported while dragging or while a merge is pending;
    /// forwarded when the drag ends or the merge fires.
    internal var pendingRange: Range<Int>?

    /// The range most recently forwarded to the cache, so a repeated report of
    /// the same range is dropped.
    internal var lastReportedRange: Range<Int>?

    internal init(
        isUserDragging: Bool = false,
        pendingRange: Range<Int>? = nil,
        lastReportedRange: Range<Int>? = nil
    ) {
        self.isUserDragging = isUserDragging
        self.pendingRange = pendingRange
        self.lastReportedRange = lastReportedRange
    }
}

/// Decides when a visible-range report reaches the ``ViewportCache``.
///
/// **While the user drags a scroll bar's knob, nothing is forwarded.** AppKit
/// tracks the knob in a modal event loop and posts bounds changes at 60–120 Hz;
/// forwarding each one queued a fetch per window crossed, and their completions
/// piled up on the main thread behind the drag (16.27 s on the main thread in
/// one MachOKitUI trace). During a drag only the latest range is kept; when the
/// drag ends the caller forwards it and settles the rows around it.
///
/// **Otherwise, a burst of reports within `scrollCoalesceMillis` is merged** into
/// one forward of the latest range; `0` forwards each report at once.
@MainActor
internal final class ViewportScrollCoordinator {
    internal var scrollCoalesceMillis: Int

    internal private(set) var dragState: ScrollDragState

    /// The row a settle centres on for a visible range.
    internal static func centerRow(of range: Range<Int>) -> Int {
        (range.lowerBound + range.upperBound) / 2
    }

    private let forwardToCache: (Range<Int>) -> Void
    private let scheduler: any WindowedRowsScheduler
    private var pendingMerge: (any Cancellable)?

    internal init(
        scrollCoalesceMillis: Int,
        scheduler: any WindowedRowsScheduler = MainActorTaskScheduler(),
        forwardToCache: @escaping (Range<Int>) -> Void
    ) {
        self.scrollCoalesceMillis = scrollCoalesceMillis
        self.scheduler = scheduler
        self.forwardToCache = forwardToCache
        self.dragState = ScrollDragState()
    }

    /// Reports the latest visible range. A repeat of the range last forwarded is
    /// dropped; during a drag the range is only stashed.
    internal func reportVisibleRange(_ range: Range<Int>) {
        if dragState.lastReportedRange == range && !dragState.isUserDragging {
            return
        }

        if dragState.isUserDragging {
            // Stash only: the cache has not seen it, so the last forwarded range
            // stays as it is. A later report during the drag replaces it.
            dragState.pendingRange = range
            return
        }

        if scrollCoalesceMillis <= 0 {
            dragState.lastReportedRange = range
            dragState.pendingRange = nil
            forwardToCache(range)
            return
        }

        // Keep the latest range; the merge already scheduled forwards whatever
        // is pending when it fires.
        dragState.pendingRange = range
        if pendingMerge != nil { return }
        pendingMerge = scheduler.schedule(afterMilliseconds: scrollCoalesceMillis) { [weak self] in
            guard let self else { return }
            self.pendingMerge = nil
            guard let pending = self.dragState.pendingRange else { return }
            self.dragState.pendingRange = nil
            self.dragState.lastReportedRange = pending
            self.forwardToCache(pending)
        }
    }

    internal func userDidBeginDragging() {
        dragState.isUserDragging = true
    }

    /// Ends the drag, cancels a pending merge and returns the stashed range,
    /// without forwarding it: the caller forwards it and then settles around its
    /// centre, so the two happen in that order and the settle can be timed.
    @discardableResult
    internal func userDidEndDragging() -> Range<Int>? {
        dragState.isUserDragging = false
        pendingMerge?.cancel()
        pendingMerge = nil
        guard let pending = dragState.pendingRange else { return nil }
        dragState.pendingRange = nil
        dragState.lastReportedRange = pending
        return pending
    }

    /// Cancels a pending merge. Safe from `deinit`.
    internal nonisolated func tearDown() {
        MainActor.assumeIsolated {
            pendingMerge?.cancel()
            pendingMerge = nil
        }
    }
}
