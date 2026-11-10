import Foundation
import Testing
@testable import UIFoundationWindowedRows

@Suite("A lazily computed value")
struct WindowedLazyBoxTests {
    @Test("the resolver runs once, however many threads read the first value at once")
    func resolverRunsOnce() async {
        let counter = FetchRecorder()
        let box = WindowedLazyBox { () -> Int in
            counter.record(0 ..< 1)
            return 42
        }
        await withTaskGroup(of: Int.self) { group in
            for _ in 0 ..< 64 {
                group.addTask { box.value }
            }
            for await value in group {
                #expect(value == 42)
            }
        }
        #expect(counter.ranges.count == 1)
    }

    @Test("once resolved, the box lets go of what its resolver captured")
    func resolvedBoxDropsTheResolver() {
        final class CapturedInput {}
        weak var weakInput: CapturedInput?
        let box: WindowedLazyBox<Int> = {
            let input = CapturedInput()
            weakInput = input
            return WindowedLazyBox { withExtendedLifetime(input) { 7 } }
        }()
        #expect(weakInput != nil, "the resolver holds the input until the first read")
        #expect(box.value == 7)
        #expect(weakInput == nil, "a resolved box must not keep the resolver's captures alive")
    }
}

@Suite("Row sources")
struct WindowedRowSourceTests {
    @Test("a source does not compute its row count until somebody reads it")
    func countIsLazy() {
        let counter = FetchRecorder()
        let source = WindowedRowSource<NumberedRow>(
            totalCount: { counter.record(0 ..< 1); return 10 }(),
            fetch: { range in range.map { NumberedRow(index: $0) } }
        )
        #expect(counter.ranges.isEmpty)
        #expect(source.totalCount == 10)
        #expect(source.totalCount == 10)
        #expect(counter.ranges.count == 1)
    }

    @Test("a row-by-row source builds exactly the rows asked for")
    func rowByRowBuildsTheRange() {
        let source = WindowedRowSource.rowByRow(totalCount: 100) { index in NumberedRow(index: index) }
        #expect(source.totalCount == 100)
        #expect(source.fetch(10 ..< 13).map(\.index) == [10, 11, 12])
    }

    @Test("a source with a fixed number of rows per element splits each row into element and position")
    func fixedRowsPerElement() {
        let source = WindowedRowSource.fixedRowsPerElement(elementCount: 4, rowsPerElement: 3) { elementIndex, rowIndexInElement in
            NumberedRow(index: elementIndex, text: "\(elementIndex).\(rowIndexInElement)")
        }
        #expect(source.totalCount == 12)
        #expect(source.fetch(2 ..< 7).map(\.text) == ["0.2", "1.0", "1.1", "1.2", "2.0"])
    }

    @Test("a source with variable rows per element finds each row's element, skipping elements without rows")
    func variableRowsPerElement() {
        // Element 0 takes two rows, element 1 none, element 2 three.
        let source = WindowedRowSource.variableRowsPerElement(elementRowOffsets: [0, 2, 2, 5]) { elementIndex, rowIndexInElement in
            NumberedRow(index: elementIndex, text: "\(elementIndex).\(rowIndexInElement)")
        }
        #expect(source.totalCount == 5)
        #expect(source.fetch(0 ..< 5).map(\.text) == ["0.0", "0.1", "2.0", "2.1", "2.2"])
    }

    @Test("only a prewarm candidate has somewhere to store a first window computed ahead of time")
    func firstWindowStorageBelongsToCandidates() {
        let candidate = makeNumberedSource(rowCount: 10, isPrewarmCandidate: true)
        let other = makeNumberedSource(rowCount: 10)
        #expect(candidate.preComputedFirstWindowStorage != nil)
        #expect(other.preComputedFirstWindowStorage == nil)
        candidate.preComputedFirstWindowStorage?.store([NumberedRow(index: 0)])
        #expect(candidate.preComputedFirstWindow == [NumberedRow(index: 0)])
    }
}

@Suite("The rows a table displays")
struct WindowedDisplayedRowsTests {
    @Test("without a search, the displayed rows are the source rows")
    func unfilteredRows() {
        let rows = WindowedDisplayedRows(source: makeNumberedSource(rowCount: 50), filteredSourceRowIndices: nil)
        #expect(rows.count == 50)
        #expect(rows.rows(in: 3 ..< 6).map(\.index) == [3, 4, 5])
    }

    @Test("with a search, consecutive matches are fetched in one call")
    func filteredRowsFetchConsecutiveMatchesTogether() {
        let recorder = FetchRecorder()
        let rows = WindowedDisplayedRows(
            source: makeNumberedSource(rowCount: 50, recorder: recorder),
            filteredSourceRowIndices: [2, 3, 4, 9, 20, 21]
        )
        #expect(rows.count == 6)
        #expect(rows.rows(in: 0 ..< 6).map(\.index) == [2, 3, 4, 9, 20, 21])
        #expect(recorder.ranges == [2 ..< 5, 9 ..< 10, 20 ..< 22])
    }
}
