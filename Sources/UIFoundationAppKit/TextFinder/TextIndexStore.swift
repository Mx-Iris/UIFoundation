#if canImport(AppKit) && !targetEnvironment(macCatalyst)

import AppKit

@available(macOS 12.0, *)
class TextIndexStore {

    struct Token {
        let row: Int
        let column: Int
        let globalIndex: Int
        let string: String
        let item: Any?
    }

    /// Boundary separator length between tokens.
    /// Prevents matches from spanning across cells.
    static let separatorLength: Int = 1

    private(set) var tokens: [Token] = []
    private(set) var totalLength: Int = 0

    /// Look up the token containing the given character index.
    /// Uses binary search for O(log n) performance.
    func token(at characterIndex: Int) -> Token {
        precondition(!tokens.isEmpty, "TextIndexStore is empty")
        var lowerBound = 0
        var upperBound = tokens.count - 1
        while lowerBound < upperBound {
            let middleIndex = lowerBound + (upperBound - lowerBound + 1) / 2
            if tokens[middleIndex].globalIndex <= characterIndex {
                lowerBound = middleIndex
            } else {
                upperBound = middleIndex - 1
            }
        }
        return tokens[lowerBound]
    }

    /// Remove all tokens and reset total length.
    func removeAll() {
        tokens.removeAll()
        totalLength = 0
    }

    /// Append a single token for the given row, column, string, and optional item.
    /// Automatically computes the globalIndex based on current totalLength.
    func appendToken(row: Int, column: Int, string: String, item: Any? = nil) {
        let token = Token(
            row: row,
            column: column,
            globalIndex: totalLength,
            string: string,
            item: item
        )
        tokens.append(token)
        totalLength += string.utf16.count + TextIndexStore.separatorLength
    }
}

// MARK: - CGRect pixel alignment helper

extension CGRect {
    var pixelAligned: CGRect {
        NSIntegralRectWithOptions(self, .alignAllEdgesNearest)
    }
}

#endif
