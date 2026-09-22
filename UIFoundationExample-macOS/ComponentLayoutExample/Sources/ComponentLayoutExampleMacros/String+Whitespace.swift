//
//  String+Whitespace.swift
//  ComponentLayoutExampleMacros
//
//  Ported from lkzhao/UIComponent's example app (created by Luke Zhao on
//  11/4/25).
//

import Foundation

extension String {
    /// Strips the first line's indentation from every line.
    ///
    /// A captured expression arrives indented to wherever it sat in the source,
    /// so without this every code block in a chapter would show a ragged left
    /// margin that depends on how deeply the sample was nested.
    func trimLeadingWhitespacesBasedOnFirstLine() -> String {
        let lines = trimmingCharacters(in: .newlines).split(separator: "\n", omittingEmptySubsequences: false)
        guard let firstLine = lines.first else { return self }

        let leadingWhitespaceCount = firstLine.prefix { $0.isWhitespace }.count
        let trimmedLines = lines.map { line in
            let count = line.prefix { $0.isWhitespace }.count
            return line.dropFirst(Swift.min(count, leadingWhitespaceCount))
        }
        return trimmedLines.joined(separator: "\n")
    }
}
