import Foundation
import Testing
@testable import UIFoundationWindowedRows

@Suite("Matching text against a keyword")
struct KeywordMatcherTests {
    @Test("an ASCII keyword matches regardless of case", arguments: ["swift", "SWIFT", "SwIfT"])
    func asciiKeywordIgnoresCase(keyword: String) {
        #expect(KeywordMatcher(keyword: keyword).matches("_$s5SwiftUI4ViewP"))
    }

    @Test("an ASCII keyword does not match a diacritic variant")
    func asciiKeywordIsNotDiacriticInsensitive() {
        #expect(KeywordMatcher(keyword: "cafe").matches("café") == false)
    }

    @Test("a keyword with non-ASCII characters matches the way the locale compares text")
    func nonASCIIKeywordUsesTheLocale() {
        #expect(KeywordMatcher(keyword: "É").matches("café"))
    }

    @Test("an ASCII keyword never matches inside a multi-byte character")
    func asciiKeywordStaysOutOfMultiByteCharacters() {
        #expect(KeywordMatcher(keyword: "a").matches("日本語") == false)
        #expect(KeywordMatcher(keyword: "x").matches("日本語x"))
    }

    @Test("empty text never matches")
    func emptyTextNeverMatches() {
        #expect(KeywordMatcher(keyword: "a").matches("") == false)
    }
}

@Suite("Searching the rows of a source")
struct WindowedRowSearchTests {
    private func makeSearch(rowCount: Int, keyword: String) -> WindowedRowSearch<NumberedRow> {
        WindowedRowSearch.keywordMatching(
            source: makeNumberedSource(rowCount: rowCount) { $0 % 1_000 == 7 ? "needle \($0)" : "hay \($0)" },
            keyword: keyword,
            completionDispatch: .synchronous
        ) { row, matcher in
            matcher.matches(row.text)
        }
    }

    @Test("a search collects every matching source row, in ascending order, across batches")
    func searchCollectsMatchesInOrder() {
        let search = makeSearch(rowCount: 5_000, keyword: "NEEDLE")
        search.start()
        #expect(search.waitForCompletion())
        #expect(search.filteredRowIndices == [7, 1_007, 2_007, 3_007, 4_007])
        #expect(search.lastProgress == WindowedSearchProgress(matchedCount: 5, scannedCount: 5_000, totalCount: 5_000, isComplete: true))
    }

    @Test("progress arrives once per batch, and completion once")
    func progressPerBatch() {
        let search = makeSearch(rowCount: 3 * WindowedRowSearch<NumberedRow>.batchSize, keyword: "needle")
        var progressCount = 0
        var completionCount = 0
        search.onProgress = { _ in progressCount += 1 }
        search.onComplete = { _ in completionCount += 1 }
        search.start()
        #expect(search.waitForCompletion())
        #expect(progressCount == 3)
        #expect(completionCount == 1)
    }

    @Test("a search over an empty source completes at once")
    func emptySourceCompletesAtOnce() {
        let search = makeSearch(rowCount: 0, keyword: "needle")
        var completed = false
        search.onComplete = { _ in completed = true }
        search.start()
        #expect(completed)
        #expect(search.filteredRowIndices.isEmpty)
    }

    @Test("cancelling a search moves it to a new generation, so batches in flight drop their results")
    func cancelBumpsTheGeneration() {
        let search = makeSearch(rowCount: 10, keyword: "needle")
        let generationBefore = search.currentGenerationForTesting
        search.cancel()
        #expect(search.currentGenerationForTesting == generationBefore + 1)
    }
}
