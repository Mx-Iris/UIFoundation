import Foundation
import OSToolbox

/// How far a ``WindowedRowSearch`` has got.
public struct WindowedSearchProgress: Sendable, Equatable {
    /// Rows that matched so far. Matches are only ever appended, so it grows
    /// while the scan runs.
    public let matchedCount: Int

    /// Rows scanned so far.
    public let scannedCount: Int

    /// The source's row count.
    public let totalCount: Int

    /// Whether the scan has walked the whole source.
    public let isComplete: Bool

    public init(matchedCount: Int, scannedCount: Int, totalCount: Int, isComplete: Bool) {
        self.matchedCount = matchedCount
        self.scannedCount = scannedCount
        self.totalCount = totalCount
        self.isComplete = isComplete
    }
}

/// Matches text against a search keyword, ignoring case.
///
/// A keyword made only of ASCII characters is matched byte by byte over the
/// text's UTF-8, several times faster than `localizedStandardContains`, which
/// folds case, width and diacritics by locale on every call. Any other keyword
/// falls back to `localizedStandardContains`. The one difference in meaning: an
/// ASCII keyword does not match diacritic variants, so "e" does not find "é".
///
/// Build one matcher per keyword, outside the per-row work: the decision and the
/// lowercased keyword bytes are computed once, not once per row.
public struct KeywordMatcher: Sendable {
    private enum Strategy: Sendable {
        case asciiCaseInsensitive([UInt8])
        case localized(String)
    }

    private let strategy: Strategy

    public init(keyword: String) {
        strategy = Self.strategy(for: keyword)
    }

    private static func strategy(for keyword: String) -> Strategy {
        var loweredKeywordBytes: [UInt8] = []
        loweredKeywordBytes.reserveCapacity(keyword.utf8.count)
        for byte in keyword.utf8 {
            guard byte < 0x80 else {
                return .localized(keyword)
            }
            loweredKeywordBytes.append(loweredASCII(byte))
        }
        return .asciiCaseInsensitive(loweredKeywordBytes)
    }

    /// Whether `text` contains the keyword. Empty text never matches.
    public func matches(_ text: String) -> Bool {
        guard !text.isEmpty else { return false }
        switch strategy {
        case .asciiCaseInsensitive(let keywordBytes):
            return Self.contains(text, keywordBytes: keywordBytes)
        case .localized(let keyword):
            return text.localizedStandardContains(keyword)
        }
    }

    private static func loweredASCII(_ byte: UInt8) -> UInt8 {
        (byte >= UInt8(ascii: "A") && byte <= UInt8(ascii: "Z")) ? byte &+ 32 : byte
    }

    private static func contains(_ text: String, keywordBytes: [UInt8]) -> Bool {
        guard !keywordBytes.isEmpty else { return true }
        let scanned = text.utf8.withContiguousStorageIfAvailable { textBytes in
            scan(textBytes: textBytes, keywordBytes: keywordBytes)
        }
        if let scanned { return scanned }
        // A bridged `NSString` has no contiguous UTF-8; rare, so copy it out.
        let copiedBytes = Array(text.utf8)
        return copiedBytes.withUnsafeBufferPointer { textBytes in
            scan(textBytes: textBytes, keywordBytes: keywordBytes)
        }
    }

    /// Keyword bytes are all below 0x80 and every byte of a multi-byte UTF-8
    /// scalar is at or above it, so the scan cannot match inside a scalar.
    private static func scan(textBytes: UnsafeBufferPointer<UInt8>, keywordBytes: [UInt8]) -> Bool {
        let keywordCount = keywordBytes.count
        guard textBytes.count >= keywordCount else { return false }
        let firstKeywordByte = keywordBytes[0]
        let lastCandidateIndex = textBytes.count - keywordCount
        var candidateIndex = 0
        while candidateIndex <= lastCandidateIndex {
            if loweredASCII(textBytes[candidateIndex]) == firstKeywordByte {
                var matchedCount = 1
                while matchedCount < keywordCount,
                      loweredASCII(textBytes[candidateIndex + matchedCount]) == keywordBytes[matchedCount] {
                    matchedCount += 1
                }
                if matchedCount == keywordCount { return true }
            }
            candidateIndex += 1
        }
        return false
    }
}

/// Scans every row of a source in the background and collects the indices of
/// the rows that match, so a table can show only those.
///
/// The scan walks the source in batches of ``batchSize`` rows, in order, and
/// appends each batch's matches to ``filteredRowIndices``. Because matches are
/// only ever appended in ascending order, a row the table already shows keeps
/// its position while further matches arrive. A table shows
/// `filteredRowIndices.count` rows and maps displayed row `n` to source row
/// `filteredRowIndices[n]`.
///
/// Threading:
/// - Everything except ``cancel()`` runs on the main thread.
/// - ``cancel()`` may run on any thread: it bumps a generation counter that the
///   scan checks between batches.
/// - The scan runs on a detached task and calls the source's `fetch` directly,
///   never through a ``ViewportCache``, so a scan of millions of rows does not
///   evict the windows the table shows.
///
/// The generation lock and the task-slot lock are never held at the same time:
/// ``start(keyword:)`` and ``cancel()`` bump the generation under the first,
/// release it, swap the task slot under the second, release it, and only then
/// cancel the previous task.
@Loggable(subsystem: "UIFoundationWindowedRows", category: "WindowedRowSearch")
public final class WindowedRowSearch<Row: Sendable> {
    /// Rows per background batch: small enough that a cancelled scan of a
    /// million rows stops quickly.
    public static var batchSize: Int { 1024 }

    /// Where progress and completion are reported from.
    public enum CompletionDispatch: Sendable {
        /// On the main actor; what a table needs.
        case mainQueueAsync
        /// On the scan task itself, so a test without a running main run loop
        /// can wait for the scan with ``waitForCompletion(timeoutSeconds:)``.
        case synchronous
    }

    private let source: WindowedRowSource<Row>
    private let matchPredicate: @Sendable (Row) -> Bool
    private let completionDispatch: CompletionDispatch

    /// Bumped by every ``start(keyword:)`` and ``cancel()``; a batch from an
    /// older generation drops its results.
    private let cancellationLock = NSLock()
    private var currentGeneration: UInt64 = 0

    private let scanTaskLock = NSLock()
    private var currentScanTask: Task<Void, Never>?

    /// The source rows that matched, in ascending order.
    public private(set) var filteredRowIndices: [Int] = []

    /// The keyword this search runs for, when built by
    /// ``keywordMatching(source:keyword:completionDispatch:matches:)``.
    public private(set) var keyword: String = ""

    /// The latest progress.
    public private(set) var lastProgress: WindowedSearchProgress

    /// Called after every batch, even one without new matches.
    public var onProgress: ((WindowedSearchProgress) -> Void)?

    /// Called once the scan has walked the whole source. A cancelled scan never
    /// calls it.
    public var onComplete: ((WindowedSearchProgress) -> Void)?

    /// The source's row count.
    public var totalCount: Int { source.totalCount }

    public init(
        source: WindowedRowSource<Row>,
        matchPredicate: @escaping @Sendable (Row) -> Bool,
        completionDispatch: CompletionDispatch = .mainQueueAsync
    ) {
        self.source = source
        self.matchPredicate = matchPredicate
        self.completionDispatch = completionDispatch
        self.lastProgress = WindowedSearchProgress(
            matchedCount: 0,
            scannedCount: 0,
            totalCount: source.totalCount,
            isComplete: source.totalCount == 0
        )
    }

    deinit {
        scanTaskLock.lock()
        let runningTask = currentScanTask
        currentScanTask = nil
        scanTaskLock.unlock()
        runningTask?.cancel()
    }

    /// A search for the rows in which `matches` finds the keyword.
    ///
    /// `matches` receives one ``KeywordMatcher`` built for the keyword and
    /// decides which of the row's strings to try, for example
    /// `{ row, matcher in matcher.matches(row.name) || matcher.matches(row.address) }`.
    /// An empty keyword matches every row; a table should not start a search for
    /// it at all.
    public static func keywordMatching(
        source: WindowedRowSource<Row>,
        keyword: String,
        completionDispatch: CompletionDispatch = .mainQueueAsync,
        matches: @escaping @Sendable (_ row: Row, _ matcher: KeywordMatcher) -> Bool
    ) -> WindowedRowSearch {
        let matcher = KeywordMatcher(keyword: keyword)
        let search = WindowedRowSearch(
            source: source,
            matchPredicate: { row in matches(row, matcher) },
            completionDispatch: completionDispatch
        )
        search.keyword = keyword
        return search
    }

    /// Starts a scan from the first row, dropping any previous matches and any
    /// scan in flight. Must be called on the main thread.
    public func start(keyword: String? = nil) {
        let newGeneration: UInt64 = {
            cancellationLock.lock()
            currentGeneration &+= 1
            let value = currentGeneration
            cancellationLock.unlock()
            return value
        }()

        scanTaskLock.lock()
        let previousTask = currentScanTask
        currentScanTask = nil
        scanTaskLock.unlock()
        previousTask?.cancel()

        if let keyword {
            self.keyword = keyword
        }
        filteredRowIndices.removeAll(keepingCapacity: true)

        let initialProgress = WindowedSearchProgress(
            matchedCount: 0,
            scannedCount: 0,
            totalCount: source.totalCount,
            isComplete: source.totalCount == 0
        )
        lastProgress = initialProgress

        guard source.totalCount > 0 else {
            onProgress?(initialProgress)
            onComplete?(initialProgress)
            return
        }

        #log(.debug, "search_start — keyword=\(self.keyword) total=\(self.source.totalCount)")
        startScanTask(generation: newGeneration)
    }

    /// Stops the scan. Safe from any thread, and idempotent. Does not call
    /// ``onComplete``.
    public func cancel() {
        cancellationLock.lock()
        currentGeneration &+= 1
        cancellationLock.unlock()
        scanTaskLock.lock()
        let runningTask = currentScanTask
        currentScanTask = nil
        scanTaskLock.unlock()
        runningTask?.cancel()
    }

    /// The current generation, for tests that check a cancellation took effect.
    public var currentGenerationForTesting: UInt64 {
        cancellationLock.lock()
        defer { cancellationLock.unlock() }
        return currentGeneration
    }

    /// Blocks the calling thread until the scan completes or `timeoutSeconds`
    /// pass, and returns whether it completed. Only for a search with
    /// ``CompletionDispatch/synchronous`` dispatch: with main-actor dispatch the
    /// results can never arrive while the main thread waits here.
    @discardableResult
    public func waitForCompletion(timeoutSeconds: Double = 5.0) -> Bool {
        let deadline = Date().addingTimeInterval(timeoutSeconds)
        while Date() < deadline {
            if lastProgress.isComplete { return true }
            Thread.sleep(forTimeInterval: 0.001)
        }
        return lastProgress.isComplete
    }

    // MARK: - Scan

    private func startScanTask(generation: UInt64) {
        let dispatch = completionDispatch
        let total = source.totalCount
        let predicate = matchPredicate
        let batchSize = Self.batchSize

        let task = Task.detached(priority: .userInitiated) { [weak self, source] in
            var cursor = 0
            while cursor < total {
                if Task.isCancelled { return }
                if let self, self.observedGeneration() != generation { return }

                let upperBound = min(cursor + batchSize, total)
                let batchRange = cursor ..< upperBound
                let rows = source.fetch(batchRange)
                let batchMatches: [Int] = rows.enumerated().compactMap { entry in
                    let (offsetInBatch, row) = entry
                    return predicate(row) ? batchRange.lowerBound + offsetInBatch : nil
                }

                switch dispatch {
                case .mainQueueAsync:
                    await MainActor.run { [weak self] in
                        guard let self else { return }
                        if self.observedGeneration() != generation { return }
                        self.absorbBatch(matches: batchMatches, scannedUpTo: upperBound)
                    }
                case .synchronous:
                    // Runs on the scan task; callers read the search's state
                    // only after the scan completes.
                    guard let self else { return }
                    if self.observedGeneration() != generation { return }
                    self.absorbBatch(matches: batchMatches, scannedUpTo: upperBound)
                }

                cursor = upperBound
            }
        }

        scanTaskLock.lock()
        currentScanTask = task
        scanTaskLock.unlock()
    }

    private func observedGeneration() -> UInt64 {
        cancellationLock.lock()
        defer { cancellationLock.unlock() }
        return currentGeneration
    }

    private func absorbBatch(matches: [Int], scannedUpTo: Int) {
        filteredRowIndices.append(contentsOf: matches)
        let total = source.totalCount
        let isComplete = scannedUpTo >= total
        let snapshot = WindowedSearchProgress(
            matchedCount: filteredRowIndices.count,
            scannedCount: scannedUpTo,
            totalCount: total,
            isComplete: isComplete
        )
        lastProgress = snapshot
        #log(.debug, "search_batch — matched=\(snapshot.matchedCount) scanned=\(snapshot.scannedCount)/\(snapshot.totalCount)")
        onProgress?(snapshot)
        if isComplete {
            onComplete?(snapshot)
        }
    }
}
