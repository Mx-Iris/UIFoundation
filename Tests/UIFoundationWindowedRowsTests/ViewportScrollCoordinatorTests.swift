import Testing
@testable import UIFoundationWindowedRows

@Suite("Pacing visible-range reports")
@MainActor
struct ViewportScrollCoordinatorTests {
    private final class ForwardedRanges {
        var ranges: [Range<Int>] = []
    }

    private func makeCoordinator(
        scrollCoalesceMillis: Int = 0,
        scheduler: any WindowedRowsScheduler = ManualTestScheduler()
    ) -> (ViewportScrollCoordinator, ForwardedRanges) {
        let forwarded = ForwardedRanges()
        let coordinator = ViewportScrollCoordinator(
            scrollCoalesceMillis: scrollCoalesceMillis,
            scheduler: scheduler,
            forwardToCache: { forwarded.ranges.append($0) }
        )
        return (coordinator, forwarded)
    }

    @Test("the state starts with no drag and nothing pending")
    func initialStateIsClean() {
        let (coordinator, _) = makeCoordinator()
        #expect(coordinator.dragState == ScrollDragState())
    }

    @Test("reporting the range just forwarded again forwards nothing")
    func repeatedRangeIsDropped() {
        let (coordinator, forwarded) = makeCoordinator()
        coordinator.reportVisibleRange(0 ..< 10)
        coordinator.reportVisibleRange(0 ..< 10)
        #expect(forwarded.ranges == [0 ..< 10])
    }

    @Test("during a drag only the latest range is kept, and nothing is forwarded")
    func dragStashesTheLatestRange() {
        let (coordinator, forwarded) = makeCoordinator()
        coordinator.userDidBeginDragging()
        coordinator.reportVisibleRange(0 ..< 10)
        coordinator.reportVisibleRange(500 ..< 510)
        #expect(forwarded.ranges.isEmpty)
        #expect(coordinator.dragState.pendingRange == 500 ..< 510)
    }

    @Test("ending a drag returns the latest range without forwarding it, once")
    func dragEndReturnsTheStashOnce() {
        let (coordinator, forwarded) = makeCoordinator()
        coordinator.userDidBeginDragging()
        coordinator.reportVisibleRange(500 ..< 510)
        #expect(coordinator.userDidEndDragging() == 500 ..< 510)
        #expect(forwarded.ranges.isEmpty, "the caller forwards it, then settles around it")
        #expect(coordinator.userDidEndDragging() == nil)
        #expect(coordinator.dragState.lastReportedRange == 500 ..< 510)
    }

    @Test("a burst of reports within the merge window is forwarded once, as its latest range")
    func burstIsMerged() {
        let scheduler = ManualTestScheduler()
        let (coordinator, forwarded) = makeCoordinator(scrollCoalesceMillis: 16, scheduler: scheduler)
        coordinator.reportVisibleRange(0 ..< 10)
        coordinator.reportVisibleRange(5 ..< 15)
        coordinator.reportVisibleRange(9 ..< 19)
        #expect(forwarded.ranges.isEmpty)
        scheduler.advance(byMilliseconds: 15)
        #expect(forwarded.ranges.isEmpty)
        scheduler.advance(byMilliseconds: 1)
        #expect(forwarded.ranges == [9 ..< 19])
    }

    @Test("ending a drag cancels a pending merge")
    func dragEndCancelsThePendingMerge() {
        let scheduler = ManualTestScheduler()
        let (coordinator, forwarded) = makeCoordinator(scrollCoalesceMillis: 16, scheduler: scheduler)
        coordinator.reportVisibleRange(0 ..< 10)
        coordinator.userDidBeginDragging()
        coordinator.reportVisibleRange(90 ..< 100)
        #expect(coordinator.userDidEndDragging() == 90 ..< 100)
        scheduler.advance(byMilliseconds: 100)
        #expect(forwarded.ranges.isEmpty)
    }

    @Test("tearing down cancels a pending merge, and may run twice")
    func tearDownCancelsThePendingMerge() {
        let scheduler = ManualTestScheduler()
        let (coordinator, forwarded) = makeCoordinator(scrollCoalesceMillis: 16, scheduler: scheduler)
        coordinator.reportVisibleRange(0 ..< 10)
        coordinator.tearDown()
        coordinator.tearDown()
        scheduler.advance(byMilliseconds: 100)
        #expect(forwarded.ranges.isEmpty)
    }

    @Test("a settle centres on the middle of the range")
    func settleCentre() {
        #expect(ViewportScrollCoordinator.centerRow(of: 50 ..< 114) == 82)
    }
}
