#if canImport(AppKit) && !targetEnvironment(macCatalyst)

import Testing
import AppKit
@testable import UIFoundationAppKit

// MARK: - TextIndexStore Tests

@Suite("TextIndexStore")
struct TextIndexStoreTests {

    @Test("Empty store has zero totalLength and no tokens")
    func emptyStore() {
        let store = TextIndexStore()
        #expect(store.totalLength == 0)
        #expect(store.tokens.isEmpty)
    }

    @Test("Append single token sets correct globalIndex and totalLength")
    func appendSingleToken() {
        let store = TextIndexStore()
        store.appendToken(row: 0, column: 0, string: "hello")

        #expect(store.tokens.count == 1)
        #expect(store.tokens[0].row == 0)
        #expect(store.tokens[0].column == 0)
        #expect(store.tokens[0].globalIndex == 0)
        #expect(store.tokens[0].string == "hello")
        #expect(store.tokens[0].item == nil)
        #expect(store.totalLength == 5)
    }

    @Test("Append multiple tokens computes consecutive globalIndex values")
    func appendMultipleTokens() {
        let store = TextIndexStore()
        store.appendToken(row: 0, column: 0, string: "hello")  // length 5, globalIndex 0
        store.appendToken(row: 0, column: 1, string: "world")  // length 5, globalIndex 5
        store.appendToken(row: 1, column: 0, string: "foo")    // length 3, globalIndex 10

        #expect(store.tokens.count == 3)
        #expect(store.tokens[0].globalIndex == 0)
        #expect(store.tokens[1].globalIndex == 5)
        #expect(store.tokens[2].globalIndex == 10)
        #expect(store.totalLength == 13)
    }

    @Test("Token lookup via binary search returns correct token for each character position")
    func binarySearchLookup() {
        let store = TextIndexStore()
        store.appendToken(row: 0, column: 0, string: "abc")    // globalIndex 0, covers [0, 3)
        store.appendToken(row: 0, column: 1, string: "de")     // globalIndex 3, covers [3, 5)
        store.appendToken(row: 1, column: 0, string: "fghij")  // globalIndex 5, covers [5, 10)

        for characterIndex in 0 ..< 3 {
            let token = store.token(at: characterIndex)
            #expect(token.row == 0)
            #expect(token.column == 0)
            #expect(token.string == "abc")
        }

        for characterIndex in 3 ..< 5 {
            let token = store.token(at: characterIndex)
            #expect(token.row == 0)
            #expect(token.column == 1)
            #expect(token.string == "de")
        }

        for characterIndex in 5 ..< 10 {
            let token = store.token(at: characterIndex)
            #expect(token.row == 1)
            #expect(token.column == 0)
            #expect(token.string == "fghij")
        }
    }

    @Test("Token lookup for single token store")
    func singleTokenLookup() {
        let store = TextIndexStore()
        store.appendToken(row: 0, column: 0, string: "only")

        let token = store.token(at: 0)
        #expect(token.string == "only")

        let tokenAtEnd = store.token(at: 3)
        #expect(tokenAtEnd.string == "only")
    }

    @Test("UTF-16 multi-byte characters compute correct lengths")
    func utf16MultiByteLengths() {
        let store = TextIndexStore()
        store.appendToken(row: 0, column: 0, string: "\u{1F600}")  // 2 UTF-16 code units
        #expect(store.totalLength == 2)

        store.appendToken(row: 0, column: 1, string: "cafe\u{0301}")  // 5 UTF-16 code units
        #expect(store.tokens[1].globalIndex == 2)
        #expect(store.totalLength == 7)
    }

    @Test("removeAll clears tokens and resets totalLength")
    func removeAllResetsState() {
        let store = TextIndexStore()
        store.appendToken(row: 0, column: 0, string: "test")
        store.appendToken(row: 1, column: 0, string: "data")

        store.removeAll()

        #expect(store.tokens.isEmpty)
        #expect(store.totalLength == 0)
    }

    @Test("Appending after removeAll rebuilds from zero")
    func appendAfterRemoveAll() {
        let store = TextIndexStore()
        store.appendToken(row: 0, column: 0, string: "first")
        store.removeAll()
        store.appendToken(row: 0, column: 0, string: "second")

        #expect(store.tokens.count == 1)
        #expect(store.tokens[0].globalIndex == 0)
        #expect(store.tokens[0].string == "second")
        #expect(store.totalLength == 6)
    }

    @Test("Token stores item reference")
    func tokenStoresItem() {
        let store = TextIndexStore()
        let itemObject = NSObject()
        store.appendToken(row: 0, column: 0, string: "test", item: itemObject)

        let token = store.token(at: 0)
        #expect(token.item as AnyObject === itemObject)
    }

    @Test("Empty string tokens have zero length")
    func emptyStringToken() {
        let store = TextIndexStore()
        store.appendToken(row: 0, column: 0, string: "")
        store.appendToken(row: 0, column: 1, string: "after")

        #expect(store.tokens[0].globalIndex == 0)
        #expect(store.tokens[1].globalIndex == 0)
        #expect(store.totalLength == 5)
    }

    @Test("Binary search with many tokens performs correctly")
    func binarySearchManyTokens() {
        let store = TextIndexStore()
        let tokenCount = 1000
        for rowIndex in 0 ..< tokenCount {
            store.appendToken(row: rowIndex, column: 0, string: "row\(rowIndex)")
        }

        let firstToken = store.token(at: 0)
        #expect(firstToken.row == 0)
        #expect(firstToken.string == "row0")

        let middleToken = store.token(at: store.tokens[500].globalIndex)
        #expect(middleToken.row == 500)

        let lastTokenIndex = store.tokens[999].globalIndex
        let lastToken = store.token(at: lastTokenIndex)
        #expect(lastToken.row == 999)
    }

    @Test("Separator length is zero")
    func separatorLengthIsZero() {
        #expect(TextIndexStore.separatorLength == 0)
    }

    @Test("Tokens with multi-row multi-column layout have correct positions")
    func multiRowMultiColumnLayout() {
        let store = TextIndexStore()
        // Simulating a 2x2 table:
        // Row 0: "Name"(4) "Type"(4)
        // Row 1: "File"(4) "Text"(4)
        store.appendToken(row: 0, column: 0, string: "Name")
        store.appendToken(row: 0, column: 1, string: "Type")
        store.appendToken(row: 1, column: 0, string: "File")
        store.appendToken(row: 1, column: 1, string: "Text")

        #expect(store.totalLength == 16)

        // Verify each token is reachable at its start position
        let tokenAtName = store.token(at: 0)
        #expect(tokenAtName.row == 0)
        #expect(tokenAtName.column == 0)

        let tokenAtType = store.token(at: 4)
        #expect(tokenAtType.row == 0)
        #expect(tokenAtType.column == 1)

        let tokenAtFile = store.token(at: 8)
        #expect(tokenAtFile.row == 1)
        #expect(tokenAtFile.column == 0)

        let tokenAtText = store.token(at: 12)
        #expect(tokenAtText.row == 1)
        #expect(tokenAtText.column == 1)
    }

    @Test("Token boundary positions map to correct tokens")
    func tokenBoundaryPositions() {
        let store = TextIndexStore()
        store.appendToken(row: 0, column: 0, string: "ab")   // globalIndex 0, covers [0, 2)
        store.appendToken(row: 0, column: 1, string: "cd")   // globalIndex 2, covers [2, 4)
        store.appendToken(row: 0, column: 2, string: "ef")   // globalIndex 4, covers [4, 6)

        // Last position of first token
        let tokenAtBoundary1 = store.token(at: 1)
        #expect(tokenAtBoundary1.string == "ab")

        // First position of second token (boundary)
        let tokenAtBoundary2 = store.token(at: 2)
        #expect(tokenAtBoundary2.string == "cd")

        // Last position of second token
        let tokenAtBoundary3 = store.token(at: 3)
        #expect(tokenAtBoundary3.string == "cd")

        // First position of third token (boundary)
        let tokenAtBoundary4 = store.token(at: 4)
        #expect(tokenAtBoundary4.string == "ef")
    }
}

// MARK: - OutlineViewSearchScope Tests

@Suite("OutlineViewSearchScope")
struct OutlineViewSearchScopeTests {

    @Test("All three scope cases exist and are distinct")
    func scopeCasesAreDistinct() {
        let expandedOnly = OutlineViewSearchScope.expandedOnly
        let onDemand = OutlineViewSearchScope.onDemand
        let all = OutlineViewSearchScope.all

        switch expandedOnly {
        case .expandedOnly: break
        default: Issue.record("expandedOnly did not match")
        }

        switch onDemand {
        case .onDemand: break
        default: Issue.record("onDemand did not match")
        }

        switch all {
        case .all: break
        default: Issue.record("all did not match")
        }
    }
}

@Suite("RunLengthTextIndexStore")
struct RunLengthTextIndexStoreTests {

    /// Reference strings whose UTF-16 lengths drive the builder; the provider
    /// serves them back so token strings can be checked verbatim.
    private static func makeStore(rows: [[String]]) -> RunLengthTextIndexStore {
        var builder = RunLengthTextIndexStore.Builder()
        for row in rows {
            builder.appendRow(columnLengths: row.map { $0.utf16.count })
        }
        return builder.build { rowIndex, columnIndex in
            rows[rowIndex][columnIndex]
        }
    }

    @Test("Uniform rows collapse into a single run with correct positions")
    func uniformRowsSingleRun() {
        let rows = [
            ["ab", "cde"],
            ["fg", "hij"],
            ["kl", "mno"],
        ]
        let store = Self.makeStore(rows: rows)
        #expect(store.totalLength == 15)

        let firstToken = store.token(at: 0)
        #expect(firstToken.row == 0)
        #expect(firstToken.column == 0)
        #expect(firstToken.globalIndex == 0)
        #expect(firstToken.string == "ab")

        // Character 7 = second row (starts at 5), offset 2 → column 1 (starts at 7).
        let middleToken = store.token(at: 7)
        #expect(middleToken.row == 1)
        #expect(middleToken.column == 1)
        #expect(middleToken.globalIndex == 7)
        #expect(middleToken.string == "hij")

        let lastToken = store.token(at: 14)
        #expect(lastToken.row == 2)
        #expect(lastToken.column == 1)
        #expect(lastToken.globalIndex == 12)
        #expect(lastToken.string == "mno")
    }

    @Test("A shorter final row starts a second run")
    func shorterFinalRowStartsNewRun() {
        let rows = [
            ["aaaa", "bbbb"],
            ["cccc", "dddd"],
            ["ee", ""],
        ]
        let store = Self.makeStore(rows: rows)
        #expect(store.totalLength == 18)

        let finalRowToken = store.token(at: 17)
        #expect(finalRowToken.row == 2)
        #expect(finalRowToken.column == 0)
        #expect(finalRowToken.globalIndex == 16)
        #expect(finalRowToken.string == "ee")
    }

    @Test("Zero-length columns are skipped when resolving the containing cell")
    func zeroLengthColumnsAreSkipped() {
        let rows = [
            ["", "abcd"],
            ["", "efgh"],
        ]
        let store = Self.makeStore(rows: rows)
        #expect(store.totalLength == 8)

        let token = store.token(at: 4)
        #expect(token.row == 1)
        #expect(token.column == 1)
        #expect(token.globalIndex == 4)
        #expect(token.string == "efgh")
    }

    @Test("Rows with zero total length own no characters and break run contiguity")
    func zeroLengthRowsAreSkipped() {
        let rows = [
            ["ab", "cd"],
            ["", ""],
            ["ef", "gh"],
        ]
        let store = Self.makeStore(rows: rows)
        #expect(store.totalLength == 8)

        let beforeGapToken = store.token(at: 3)
        #expect(beforeGapToken.row == 0)
        #expect(beforeGapToken.column == 1)
        #expect(beforeGapToken.string == "cd")

        let afterGapToken = store.token(at: 4)
        #expect(afterGapToken.row == 2)
        #expect(afterGapToken.column == 0)
        #expect(afterGapToken.globalIndex == 4)
        #expect(afterGapToken.string == "ef")
    }

    @Test("UTF-16 lengths drive positions for non-ASCII content")
    func utf16LengthsDrivePositions() {
        let rows = [
            ["héllo", "🌍"],
            ["wörld", "🚀"],
        ]
        let store = Self.makeStore(rows: rows)
        // "héllo" = 5 UTF-16 units, "🌍" = 2 (surrogate pair) → 7 per row.
        #expect(store.totalLength == 14)

        let emojiToken = store.token(at: 5)
        #expect(emojiToken.row == 0)
        #expect(emojiToken.column == 1)
        #expect(emojiToken.globalIndex == 5)
        #expect(emojiToken.string == "🌍")

        let secondRowToken = store.token(at: 7)
        #expect(secondRowToken.row == 1)
        #expect(secondRowToken.column == 0)
        #expect(secondRowToken.globalIndex == 7)
        #expect(secondRowToken.string == "wörld")
    }
}

@Suite("PooledTextIndexStore")
struct PooledTextIndexStoreTests {

    private static func makeStore(rows: [[String]]) -> PooledTextIndexStore {
        var externalIndex = OutlineViewExternalTextIndex(numberOfColumns: rows[0].count)
        for row in rows {
            externalIndex.appendRow(columnStrings: row)
        }
        return externalIndex.makeStore()
    }

    @Test("Tokens decode row, column, globalIndex, and string from the pool")
    func tokensDecodeFromPool() {
        let rows = [
            ["ab", "cde"],
            ["fg", "hij"],
        ]
        let store = Self.makeStore(rows: rows)
        #expect(store.totalLength == 10)
        #expect(store.numberOfRows == 2)

        let firstToken = store.token(at: 0)
        #expect(firstToken.row == 0)
        #expect(firstToken.column == 0)
        #expect(firstToken.globalIndex == 0)
        #expect(firstToken.string == "ab")
        #expect(firstToken.item == nil)

        // Character 6 = second row (starts at 5), offset 1 → still column 0.
        let secondRowToken = store.token(at: 6)
        #expect(secondRowToken.row == 1)
        #expect(secondRowToken.column == 0)
        #expect(secondRowToken.globalIndex == 5)
        #expect(secondRowToken.string == "fg")

        let lastToken = store.token(at: 9)
        #expect(lastToken.row == 1)
        #expect(lastToken.column == 1)
        #expect(lastToken.globalIndex == 7)
        #expect(lastToken.string == "hij")
    }

    @Test("Empty cells never own characters")
    func emptyCellsAreSkipped() {
        let rows = [
            ["", "abcd", ""],
            ["", "", "efgh"],
        ]
        let store = Self.makeStore(rows: rows)
        #expect(store.totalLength == 8)

        let firstRowToken = store.token(at: 2)
        #expect(firstRowToken.row == 0)
        #expect(firstRowToken.column == 1)
        #expect(firstRowToken.globalIndex == 0)
        #expect(firstRowToken.string == "abcd")

        let secondRowToken = store.token(at: 4)
        #expect(secondRowToken.row == 1)
        #expect(secondRowToken.column == 2)
        #expect(secondRowToken.globalIndex == 4)
        #expect(secondRowToken.string == "efgh")
    }

    @Test("UTF-16 surrogate pairs round-trip through the pool")
    func surrogatePairsRoundTrip() {
        let rows = [["héllo", "🌍🚀"]]
        let store = Self.makeStore(rows: rows)
        #expect(store.totalLength == 9)
        let emojiToken = store.token(at: 6)
        #expect(emojiToken.column == 1)
        #expect(emojiToken.globalIndex == 5)
        #expect(emojiToken.string == "🌍🚀")
    }
}

#endif
