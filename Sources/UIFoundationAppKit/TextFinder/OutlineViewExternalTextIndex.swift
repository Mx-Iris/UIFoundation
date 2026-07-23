#if canImport(AppKit) && !targetEnvironment(macCatalyst)

import AppKit

/// Host-built find index over the **top-level rows** of an outline whose cell
/// strings cannot be gathered through the synchronous data-source walk — for
/// example viewport-windowed content whose rows require background fetching.
///
/// Build it row by row on any thread (the type is a plain value), then hand
/// it to `OutlineViewTextFinderClient.installExternalIndex(_:)` on the main
/// thread. Cell strings are stored in one contiguous UTF-16 pool with a flat
/// offset table, so a million-row index costs megabytes of contiguous
/// storage instead of millions of individual `String` allocations, and
/// `NSTextFinder`'s linear scan never has to re-fetch source rows.
///
/// Tokens produced from an external index carry **top-level row indices**
/// (not absolute outline rows); the client converts when navigating, so
/// expanded child rows in the outline do not shift match targets.
@available(macOS 12.0, *)
public struct OutlineViewExternalTextIndex: Sendable {

    public let numberOfColumns: Int
    public private(set) var numberOfRows: Int = 0

    /// Contiguous UTF-16 code units of every cell, row-major.
    private var utf16Pool: [UInt16] = []

    /// `cellStartOffsets[k]` = pool offset where cell `k` starts; one
    /// trailing sentinel equal to the pool length. Cell `k` maps to
    /// `(row: k / numberOfColumns, column: k % numberOfColumns)`.
    private var cellStartOffsets: [Int] = [0]

    public init(numberOfColumns: Int, estimatedRowCount: Int = 0) {
        precondition(numberOfColumns > 0, "OutlineViewExternalTextIndex needs at least one column")
        self.numberOfColumns = numberOfColumns
        if estimatedRowCount > 0 {
            cellStartOffsets.reserveCapacity(estimatedRowCount * numberOfColumns + 1)
        }
    }

    /// Append the searchable strings for the next top-level row. The element
    /// count must equal `numberOfColumns`. Strings must match what the cells
    /// render so Find hits what the user sees.
    public mutating func appendRow(columnStrings: [String]) {
        precondition(columnStrings.count == numberOfColumns, "column count mismatch")
        for columnString in columnStrings {
            utf16Pool.append(contentsOf: columnString.utf16)
            cellStartOffsets.append(utf16Pool.count)
        }
        numberOfRows += 1
    }

    func makeStore() -> PooledTextIndexStore {
        PooledTextIndexStore(
            utf16Pool: utf16Pool,
            cellStartOffsets: cellStartOffsets,
            numberOfColumns: numberOfColumns,
            numberOfRows: numberOfRows
        )
    }
}

/// Index storage backed by `OutlineViewExternalTextIndex`'s contiguous pool.
/// `token(at:)` binary-searches the flat cell-offset table and decodes the
/// cell's string straight out of the pool — O(log cells) per lookup, no
/// callbacks into the data source.
@available(macOS 12.0, *)
final class PooledTextIndexStore: TextFinderIndexStorage {

    private let utf16Pool: [UInt16]
    private let cellStartOffsets: [Int]
    let numberOfColumns: Int
    let numberOfRows: Int

    var totalLength: Int { utf16Pool.count }

    init(utf16Pool: [UInt16], cellStartOffsets: [Int], numberOfColumns: Int, numberOfRows: Int) {
        self.utf16Pool = utf16Pool
        self.cellStartOffsets = cellStartOffsets
        self.numberOfColumns = numberOfColumns
        self.numberOfRows = numberOfRows
    }

    func token(at characterIndex: Int) -> TextIndexStore.Token {
        let cellCount = cellStartOffsets.count - 1
        precondition(cellCount > 0 && !utf16Pool.isEmpty, "PooledTextIndexStore is empty")
        // Last cell whose start offset <= characterIndex. Zero-length cells
        // share their start with the next cell, so "last" lands on the cell
        // that actually owns the character.
        var lowerBound = 0
        var upperBound = cellCount - 1
        while lowerBound < upperBound {
            let middleIndex = lowerBound + (upperBound - lowerBound + 1) / 2
            if cellStartOffsets[middleIndex] <= characterIndex {
                lowerBound = middleIndex
            } else {
                upperBound = middleIndex - 1
            }
        }
        let cellIndex = lowerBound
        let startOffset = cellStartOffsets[cellIndex]
        let endOffset = cellStartOffsets[cellIndex + 1]
        let cellString = String(decoding: utf16Pool[startOffset ..< endOffset], as: UTF16.self)
        return TextIndexStore.Token(
            row: cellIndex / numberOfColumns,
            column: cellIndex % numberOfColumns,
            globalIndex: startOffset,
            string: cellString,
            item: nil
        )
    }
}

#endif
