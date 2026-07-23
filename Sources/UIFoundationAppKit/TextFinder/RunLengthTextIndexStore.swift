#if canImport(AppKit) && !targetEnvironment(macCatalyst)

import AppKit

/// Index storage that keeps only the *lengths* of the searchable cell strings,
/// compressed as runs of identical per-column length patterns, and materializes
/// the actual strings on demand through a provider closure.
///
/// Compared to `TextIndexStore` (one `Token` with an owned `String` per cell),
/// this store is O(runs) in memory and O(rows) to build with no string work at
/// all — which makes `NSTextFinder` viable over grid-shaped content with
/// millions of rows (hex dumps, fixed-width tables) where materializing every
/// cell string is prohibitive.
///
/// Correctness contract: the string returned by the provider for `(row,
/// column)` must have exactly the UTF-16 length that was advertised for that
/// cell at build time. A mismatch is a data-source bug; the store raises an
/// assertion in debug builds and pads/truncates in release builds so
/// `NSTextFinder` never observes inconsistent ranges.
@available(macOS 12.0, *)
final class RunLengthTextIndexStore: TextFinderIndexStorage {

    /// A maximal range of consecutive rows sharing one per-column length
    /// pattern. Rows whose total length is zero own no characters and are not
    /// stored in any run.
    struct Run {
        let startRow: Int
        let rowCount: Int
        let startCharacterIndex: Int
        let columnLengths: [Int]
        /// Sum of `columnLengths`; always > 0 for stored runs.
        let rowLength: Int
    }

    private let runs: [Run]
    let totalLength: Int
    private let stringProvider: (_ row: Int, _ column: Int) -> String

    private init(
        runs: [Run],
        totalLength: Int,
        stringProvider: @escaping (_ row: Int, _ column: Int) -> String
    ) {
        self.runs = runs
        self.totalLength = totalLength
        self.stringProvider = stringProvider
    }

    func token(at characterIndex: Int) -> TextIndexStore.Token {
        precondition(!runs.isEmpty, "RunLengthTextIndexStore is empty")
        // Binary search: last run whose startCharacterIndex <= characterIndex.
        var lowerBound = 0
        var upperBound = runs.count - 1
        while lowerBound < upperBound {
            let middleIndex = lowerBound + (upperBound - lowerBound + 1) / 2
            if runs[middleIndex].startCharacterIndex <= characterIndex {
                lowerBound = middleIndex
            } else {
                upperBound = middleIndex - 1
            }
        }
        let run = runs[lowerBound]
        let offsetInRun = characterIndex - run.startCharacterIndex
        let rowOffsetInRun = min(offsetInRun / run.rowLength, run.rowCount - 1)
        let rowIndex = run.startRow + rowOffsetInRun

        // Walk the (small) column pattern to find the containing cell. After
        // the walk `remainingOffset` is the character offset *within* the
        // cell, so the cell's global start index is the queried index minus it.
        var remainingOffset = offsetInRun - rowOffsetInRun * run.rowLength
        var columnIndex = run.columnLengths.count - 1
        for (candidateColumnIndex, columnLength) in run.columnLengths.enumerated() {
            if remainingOffset < columnLength {
                columnIndex = candidateColumnIndex
                break
            }
            remainingOffset -= columnLength
        }
        let cellGlobalIndex = characterIndex - remainingOffset
        let expectedLength = run.columnLengths[columnIndex]

        var cellString = stringProvider(rowIndex, columnIndex)
        if cellString.utf16.count != expectedLength {
            assertionFailure(
                "RunLengthTextIndexStore: string for row \(rowIndex) column \(columnIndex) has UTF-16 length \(cellString.utf16.count), expected \(expectedLength)"
            )
            cellString = Self.normalize(cellString, toUTF16Length: expectedLength)
        }

        return TextIndexStore.Token(
            row: rowIndex,
            column: columnIndex,
            globalIndex: cellGlobalIndex,
            string: cellString,
            item: nil
        )
    }

    /// Release-build safety net for provider strings whose length disagrees
    /// with the advertised layout: pad with spaces or truncate on a UTF-16
    /// boundary so the store's global indices stay consistent.
    private static func normalize(_ string: String, toUTF16Length expectedLength: Int) -> String {
        let currentLength = string.utf16.count
        if currentLength < expectedLength {
            return string + String(repeating: " ", count: expectedLength - currentLength)
        }
        return String(decoding: Array(string.utf16.prefix(expectedLength)), as: UTF16.self)
    }

    // MARK: - Builder

    /// Accumulates per-row column-length patterns into maximal runs. Feed rows
    /// in ascending order via `appendRow(columnLengths:)`, then call
    /// `build(stringProvider:)`.
    struct Builder {
        private var runs: [Run] = []
        private var nextRowIndex = 0
        private var nextCharacterIndex = 0

        init() {}

        var totalLength: Int { nextCharacterIndex }

        mutating func appendRow(columnLengths: [Int]) {
            let rowLength = columnLengths.reduce(0, +)
            defer {
                nextRowIndex += 1
                nextCharacterIndex += rowLength
            }
            guard rowLength > 0 else { return }
            if let lastRun = runs.last,
               lastRun.startRow + lastRun.rowCount == nextRowIndex,
               lastRun.columnLengths == columnLengths {
                runs[runs.count - 1] = Run(
                    startRow: lastRun.startRow,
                    rowCount: lastRun.rowCount + 1,
                    startCharacterIndex: lastRun.startCharacterIndex,
                    columnLengths: lastRun.columnLengths,
                    rowLength: lastRun.rowLength
                )
            } else {
                runs.append(Run(
                    startRow: nextRowIndex,
                    rowCount: 1,
                    startCharacterIndex: nextCharacterIndex,
                    columnLengths: columnLengths,
                    rowLength: rowLength
                ))
            }
        }

        func build(
            stringProvider: @escaping (_ row: Int, _ column: Int) -> String
        ) -> RunLengthTextIndexStore {
            RunLengthTextIndexStore(
                runs: runs,
                totalLength: nextCharacterIndex,
                stringProvider: stringProvider
            )
        }
    }
}

#endif
