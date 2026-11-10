import Foundation
import Testing
@testable import UIFoundationWindowedRows

@Suite("The viewport cache")
@MainActor
struct ViewportCacheTests {
    private func makeCache(
        rowCount: Int,
        recorder: FetchRecorder? = nil,
        isPrewarmCandidate: Bool = false,
        windowSize: Int = 10,
        maxResidentWindows: Int = 2,
        prefetchNeighbors: Bool = false
    ) -> ViewportCache<NumberedRow> {
        ViewportCache(
            source: makeNumberedSource(rowCount: rowCount, recorder: recorder, isPrewarmCandidate: isPrewarmCandidate),
            policy: ViewportWindowingPolicy(
                windowSize: windowSize,
                maxResidentWindows: maxResidentWindows,
                prefetchNeighbors: prefetchNeighbors
            ),
            placeholder: .placeholder
        )
    }

    @Test("a row whose window is missing is the placeholder until its window arrives in the background")
    func missingRowIsAPlaceholderUntilItsWindowArrives() async {
        let recorder = FetchRecorder()
        let cache = makeCache(rowCount: 100, recorder: recorder)
        var loadedRanges: [Range<Int>] = []
        cache.onWindowLoaded = { loadedRanges.append($0) }

        #expect(cache.row(at: 25) == .placeholder)
        #expect(cache.isRowResident(at: 25) == false)
        #expect(await waitUntil { !loadedRanges.isEmpty })

        #expect(loadedRanges == [20 ..< 30])
        #expect(cache.row(at: 25) == NumberedRow(index: 25))
        #expect(recorder.mainThreadFetchCount == 0, "a missing row must never be fetched on the main thread")
    }

    @Test("asking for every cell of a missing row starts one fetch, not one per cell")
    func repeatedMissesShareOneFetch() async {
        let recorder = FetchRecorder()
        let cache = makeCache(rowCount: 100, recorder: recorder)
        var loadCount = 0
        cache.onWindowLoaded = { _ in loadCount += 1 }
        for _ in 0 ..< 6 {
            _ = cache.row(at: 5)
        }
        #expect(await waitUntil { loadCount == 1 })
        #expect(recorder.ranges == [0 ..< 10])
        #expect(cache.diagnosticInfo.missCount == 1)
    }

    @Test("reporting the visible range fetches its windows in the background and never on the main thread")
    func visibleRangeFetchesInTheBackground() async {
        let recorder = FetchRecorder()
        let cache = makeCache(rowCount: 100, recorder: recorder)
        var loadedRanges: [Range<Int>] = []
        cache.onWindowLoaded = { loadedRanges.append($0) }

        cache.reportVisibleRange(15 ..< 25)
        #expect(await waitUntil { loadedRanges.count == 2 })
        #expect(Set(loadedRanges) == [10 ..< 20, 20 ..< 30])
        #expect(cache.diagnosticInfo.mainThreadFetchCount == 0)
    }

    @Test("no more windows stay resident than the policy allows")
    func residentWindowsAreBounded() async {
        let cache = makeCache(rowCount: 1_000, maxResidentWindows: 2)
        var loadCount = 0
        cache.onWindowLoaded = { _ in loadCount += 1 }
        for windowIndex in 0 ..< 5 {
            cache.reportVisibleRange(windowIndex * 10 ..< windowIndex * 10 + 1)
            #expect(await waitUntil { loadCount == windowIndex + 1 })
        }
        #expect(cache.diagnosticInfo.residentWindowCount == 2)
        #expect(cache.diagnosticInfo.evictionCount == 3)
        #expect(cache.isRowResident(at: 0) == false, "the least recently used window is evicted first")
        #expect(cache.isRowResident(at: 40))
    }

    @Test("a synchronous prewarm of a candidate source fetches on the calling thread")
    func synchronousPrewarmOfACandidate() {
        let cache = makeCache(rowCount: 100, isPrewarmCandidate: true)
        #expect(cache.prewarmSynchronous(centerRow: 45, radius: 1))
        #expect(cache.isRowResident(at: 45))
        #expect(cache.diagnosticInfo.mainThreadFetchCount == 1)
    }

    @Test("a source whose rows are expensive is never fetched on the main thread, even to settle")
    func synchronousPrewarmOfANonCandidateFetchesInTheBackground() async {
        let recorder = FetchRecorder()
        let cache = makeCache(rowCount: 100, recorder: recorder)
        var loadCount = 0
        cache.onWindowLoaded = { _ in loadCount += 1 }
        #expect(cache.prewarmSynchronous(centerRow: 45, radius: 1) == false)
        #expect(cache.isRowResident(at: 45) == false)
        #expect(await waitUntil { loadCount == 1 })
        #expect(recorder.mainThreadFetchCount == 0)
    }

    @Test("a fetch that finishes after the cache is cancelled changes nothing and reports nothing")
    func cancelledCacheIgnoresLateFetches() async throws {
        let cache = makeCache(rowCount: 100)
        var loadCount = 0
        cache.onWindowLoaded = { _ in loadCount += 1 }
        _ = cache.row(at: 0)
        cache.cancel()
        try await Task.sleep(nanoseconds: 50_000_000)
        #expect(loadCount == 0)
        #expect(cache.isRowResident(at: 0) == false)
    }

    @Test("a first window computed ahead of time is resident from the start")
    func preComputedFirstWindowIsResident() {
        let source = makeNumberedSource(rowCount: 100, isPrewarmCandidate: true)
        source.preComputedFirstWindowStorage?.store((0 ..< 10).map { NumberedRow(index: $0) })
        let cache = ViewportCache(source: source, policy: ViewportWindowingPolicy(windowSize: 10), placeholder: NumberedRow.placeholder)
        #expect(cache.isRowResident(at: 9))
        #expect(cache.row(at: 9) == NumberedRow(index: 9))
        #expect(cache.diagnosticInfo.missCount == 0)
    }
}
