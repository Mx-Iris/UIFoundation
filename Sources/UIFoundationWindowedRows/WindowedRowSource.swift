import Foundation

/// The rows of a table too large to build at once: how many there are, and a
/// function that builds any contiguous range of them.
///
/// A ``ViewportCache`` calls ``fetch`` for the windows around the visible rows,
/// a ``WindowedRowSearch`` calls it for every row in batches, and a find index
/// scan calls it for every displayed row, so only the rows somebody is looking
/// at, or scanning right now, exist at any time.
///
/// Contract:
/// - ``fetch`` runs on background tasks, several at once. It must be a pure
///   function of what it captured — immutable collections and stateless
///   formatters — and must return exactly `range.count` rows. It is only called
///   with `0 <= range.lowerBound` and `range.upperBound <= totalCount`.
/// - ``totalCount`` is computed the first time it is read and kept. It may be
///   expensive; ``WindowedRowsController`` reads it on a background task, and
///   nothing should read it on the main thread before that.
/// - ``prewarm`` is a hint the cache calls on a background task after it fetched
///   a window, so the source can warm caches of its own for the rows around it.
public struct WindowedRowSource<Row: Sendable>: Sendable {
    /// Rows a host computed for the first window before the source is shown.
    ///
    /// A host that knows which sources are likely to be selected first can fetch
    /// their first window ahead of time and store it here; a ``ViewportCache``
    /// built over the source then starts with that window resident instead of
    /// showing placeholders. Written from a background task, read on the main
    /// thread, so a lock guards the slot.
    public final class FirstWindowStorage: @unchecked Sendable {
        private let lock = NSLock()
        private var storedRows: [Row]?

        public init() {}

        /// The stored rows, or `nil` while nothing has been stored.
        public var value: [Row]? {
            lock.lock()
            defer { lock.unlock() }
            return storedRows
        }

        /// Replaces the stored rows.
        public func store(_ newValue: [Row]?) {
            lock.lock()
            defer { lock.unlock() }
            storedRows = newValue
        }
    }

    private let totalCountBox: WindowedLazyBox<Int>

    /// The number of rows, computed the first time it is read.
    public var totalCount: Int { totalCountBox.value }

    /// Builds the rows in a range. See the type's contract.
    public let fetch: @Sendable (Range<Int>) -> [Row]

    /// Warms the source's own caches for a range it has just been asked for.
    public let prewarm: @Sendable (Range<Int>) -> Void

    /// Whether a host should fetch this source's first window ahead of time,
    /// and whether ``ViewportCache/prewarmSynchronous(centerRow:radius:)`` may
    /// fetch it on the main thread. Only sources whose rows are cheap to build
    /// should say `true`; for the rest the cache always fetches in the
    /// background.
    public let isPrewarmCandidate: Bool

    /// The order in which a host prewarms several candidates within one time
    /// budget; lower values run first. See ``WindowedRowsPrewarmPriority``.
    public let prewarmPriority: Int

    /// Where a host stores the first window it fetched ahead of time. Only
    /// prewarm candidates have one.
    public let preComputedFirstWindowStorage: FirstWindowStorage?

    /// The first window a host fetched ahead of time, if it has finished.
    public var preComputedFirstWindow: [Row]? {
        preComputedFirstWindowStorage?.value
    }

    /// Creates a source from a row count and a function that builds a range of
    /// rows.
    public init(
        totalCount: @autoclosure @escaping () -> Int,
        fetch: @escaping @Sendable (Range<Int>) -> [Row],
        prewarm: @escaping @Sendable (Range<Int>) -> Void = { _ in },
        isPrewarmCandidate: Bool = false,
        prewarmPriority: Int = 0
    ) {
        self.totalCountBox = WindowedLazyBox(totalCount)
        self.fetch = fetch
        self.prewarm = prewarm
        self.isPrewarmCandidate = isPrewarmCandidate
        self.prewarmPriority = prewarmPriority
        self.preComputedFirstWindowStorage = isPrewarmCandidate ? FirstWindowStorage() : nil
    }
}

// MARK: - Common shapes

extension WindowedRowSource {
    /// A source that builds each row on its own: row `index` is `rowAt(index)`.
    ///
    /// The count expression is evaluated once, the first time the count is
    /// needed, and shared by the fetch, so a count that reads a lazily built
    /// collection does not build it before the source is shown.
    public static func rowByRow(
        totalCount: @autoclosure @escaping () -> Int,
        rowAt: @escaping @Sendable (_ index: Int) -> Row,
        prewarm: (@Sendable (_ range: Range<Int>) -> Void)? = nil,
        isPrewarmCandidate: Bool = false,
        prewarmPriority: Int = 0
    ) -> WindowedRowSource {
        let totalCountBox = WindowedLazyBox(totalCount)
        return WindowedRowSource(
            totalCount: totalCountBox.value,
            fetch: { range in
                let resolvedTotalCount = totalCountBox.value
                precondition(
                    range.lowerBound >= 0 && range.upperBound <= resolvedTotalCount,
                    "WindowedRowSource.rowByRow: range \(range) out of bounds 0..<\(resolvedTotalCount)"
                )
                var rows: [Row] = []
                rows.reserveCapacity(range.count)
                for index in range {
                    rows.append(rowAt(index))
                }
                return rows
            },
            prewarm: prewarm ?? { _ in },
            isPrewarmCandidate: isPrewarmCandidate,
            prewarmPriority: prewarmPriority
        )
    }

    /// A source in which every element of an underlying collection takes the
    /// same number of rows: row `index` is
    /// `rowAt(index / rowsPerElement, index % rowsPerElement)`.
    public static func fixedRowsPerElement(
        elementCount: @autoclosure @escaping () -> Int,
        rowsPerElement: Int,
        rowAt: @escaping @Sendable (_ elementIndex: Int, _ rowIndexInElement: Int) -> Row,
        prewarm: (@Sendable (_ range: Range<Int>) -> Void)? = nil,
        isPrewarmCandidate: Bool = false,
        prewarmPriority: Int = 0
    ) -> WindowedRowSource {
        precondition(rowsPerElement > 0, "WindowedRowSource.fixedRowsPerElement: rowsPerElement must be > 0")
        let totalCountBox = WindowedLazyBox { elementCount() * rowsPerElement }
        return WindowedRowSource(
            totalCount: totalCountBox.value,
            fetch: { range in
                let resolvedTotalCount = totalCountBox.value
                precondition(
                    range.lowerBound >= 0 && range.upperBound <= resolvedTotalCount,
                    "WindowedRowSource.fixedRowsPerElement: range \(range) out of bounds 0..<\(resolvedTotalCount)"
                )
                var rows: [Row] = []
                rows.reserveCapacity(range.count)
                for index in range {
                    rows.append(rowAt(index / rowsPerElement, index % rowsPerElement))
                }
                return rows
            },
            prewarm: prewarm ?? { _ in },
            isPrewarmCandidate: isPrewarmCandidate,
            prewarmPriority: prewarmPriority
        )
    }

    /// A source in which the elements of an underlying collection take
    /// different numbers of rows.
    ///
    /// `elementRowOffsets` is the prefix sum of the row counts: it starts with
    /// `0`, never decreases, and its last entry is the total row count, so
    /// element `e` takes the rows `elementRowOffsets[e] ..< elementRowOffsets[e + 1]`.
    /// An element may take no rows. Row `index` is `rowAt(e, index - elementRowOffsets[e])`
    /// for the element whose rows contain it, found by binary search.
    public static func variableRowsPerElement(
        elementRowOffsets: @autoclosure @escaping () -> [Int],
        rowAt: @escaping @Sendable (_ elementIndex: Int, _ rowIndexInElement: Int) -> Row,
        prewarm: (@Sendable (_ range: Range<Int>) -> Void)? = nil,
        isPrewarmCandidate: Bool = false,
        prewarmPriority: Int = 0
    ) -> WindowedRowSource {
        let offsetsBox = WindowedLazyBox(elementRowOffsets)
        return WindowedRowSource(
            totalCount: offsetsBox.value.last ?? 0,
            fetch: { range in
                let elementRowOffsets = offsetsBox.value
                precondition(
                    elementRowOffsets.count >= 1 && elementRowOffsets.first == 0,
                    "WindowedRowSource.variableRowsPerElement: the offsets must start with 0 and have at least one entry"
                )
                // Checked in debug builds only: the check walks every offset.
                assert(
                    zip(elementRowOffsets, elementRowOffsets.dropFirst()).allSatisfy { $0 <= $1 },
                    "WindowedRowSource.variableRowsPerElement: the offsets must never decrease"
                )
                let resolvedTotalCount = elementRowOffsets.last ?? 0
                precondition(
                    range.lowerBound >= 0 && range.upperBound <= resolvedTotalCount,
                    "WindowedRowSource.variableRowsPerElement: range \(range) out of bounds 0..<\(resolvedTotalCount)"
                )
                var rows: [Row] = []
                rows.reserveCapacity(range.count)
                for index in range {
                    let elementIndex = Self.elementIndex(containingRow: index, elementRowOffsets: elementRowOffsets)
                    rows.append(rowAt(elementIndex, index - elementRowOffsets[elementIndex]))
                }
                return rows
            },
            prewarm: prewarm ?? { _ in },
            isPrewarmCandidate: isPrewarmCandidate,
            prewarmPriority: prewarmPriority
        )
    }

    /// The largest `elementIndex` whose offset is at most `rowIndex`, which skips
    /// elements that take no rows.
    private static func elementIndex(containingRow rowIndex: Int, elementRowOffsets: [Int]) -> Int {
        var lowerIndex = 0
        var upperIndex = elementRowOffsets.count - 1
        while lowerIndex < upperIndex {
            let middleIndex = (lowerIndex + upperIndex + 1) / 2
            if elementRowOffsets[middleIndex] <= rowIndex {
                lowerIndex = middleIndex
            } else {
                upperIndex = middleIndex - 1
            }
        }
        return lowerIndex
    }
}
