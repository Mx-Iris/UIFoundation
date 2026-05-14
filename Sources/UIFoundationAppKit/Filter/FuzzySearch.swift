//
//  FuzzySearch.swift
//  UIFoundation
//
//  Fuzzy string matching used by the Filter menus.
//
//  Ported and trimmed from the `fuzzy-search` package by Viktoras Laukevičius.
//  Only the matching path is kept; the caching layer (`CachedFuzzySearchable`
//  and `FuzzyTokens`) was dropped because no call site relies on it.
//
//  MIT License — Copyright (c) 2016 Viktoras Laukevičius
//

#if FilterUI

import Foundation

/// The outcome of fuzzy-matching a pattern against a ``FuzzySearchable`` value.
package struct FuzzySearchResult {
    /// Relevance score; a higher value is a closer match. Zero means no match.
    package let weight: Int
    /// Ranges in the source string covered by the pattern, for highlighting.
    package let parts: [NSRange]
}

/// A value that exposes a string fit for fuzzy-matching against a pattern.
package protocol FuzzySearchable {
    var fuzzyStringToMatch: String { get }
}

/// A character paired with an ASCII-folded variant, so accented characters can
/// still match their plain counterparts.
private struct TokenizedCharacter {
    let character: String
    let normalized: String
}

extension String {
    fileprivate func tokenize() -> [TokenizedCharacter] {
        map { character in
            let lowercasedCharacter = String(character).lowercased()
            guard let asciiData = lowercasedCharacter.data(using: .ascii, allowLossyConversion: true),
                  let accentFoldedCharacter = String(data: asciiData, encoding: .ascii)
            else {
                return TokenizedCharacter(character: lowercasedCharacter, normalized: lowercasedCharacter)
            }
            return TokenizedCharacter(character: lowercasedCharacter, normalized: accentFoldedCharacter)
        }
    }

    /// Returns the matched prefix length when `prefix` (in either its raw or
    /// normalized form) appears at `index`, otherwise `nil`.
    fileprivate func hasPrefix(_ prefix: TokenizedCharacter, atIndex index: Int) -> Int? {
        for candidate in [prefix.character, prefix.normalized] {
            if (self as NSString).substring(from: index).hasPrefix(candidate) {
                return candidate.count
            }
        }
        return nil
    }
}

extension FuzzySearchable {
    /// Fuzzy-matches `pattern` against `fuzzyStringToMatch`, scoring runs of
    /// consecutive matches and recording their ranges.
    package func fuzzyMatch(_ pattern: String) -> FuzzySearchResult {
        let tokenizedString = fuzzyStringToMatch.tokenize()
        let lowercasedPattern = pattern.lowercased()

        var totalScore = 0
        var matchedParts: [NSRange] = []

        var patternIndex = 0
        var currentScore = 0
        var currentPart = NSRange(location: 0, length: 0)

        for (characterIndex, tokenizedCharacter) in tokenizedString.enumerated() {
            if let prefixLength = lowercasedPattern.hasPrefix(tokenizedCharacter, atIndex: patternIndex) {
                patternIndex += prefixLength
                currentScore += 1 + currentScore
                currentPart.length += 1
            } else {
                currentScore = 0
                if currentPart.length != 0 {
                    matchedParts.append(currentPart)
                }
                currentPart = NSRange(location: characterIndex + 1, length: 0)
            }
            totalScore += currentScore
        }
        if currentPart.length != 0 {
            matchedParts.append(currentPart)
        }

        if patternIndex == lowercasedPattern.count {
            // All pattern characters were consumed in order.
            return FuzzySearchResult(weight: totalScore, parts: matchedParts)
        } else {
            return FuzzySearchResult(weight: 0, parts: [])
        }
    }
}

extension Collection where Element: FuzzySearchable {
    /// Fuzzy-matches `pattern` against every element, dropping non-matches and
    /// sorting the remainder best-first.
    package func fuzzyMatch(_ pattern: String) -> [(item: Element, result: FuzzySearchResult)] {
        map { (item: $0, result: $0.fuzzyMatch(pattern)) }
            .filter { $0.result.weight > 0 }
            .sorted { $0.result.weight > $1.result.weight }
    }
}

#endif
