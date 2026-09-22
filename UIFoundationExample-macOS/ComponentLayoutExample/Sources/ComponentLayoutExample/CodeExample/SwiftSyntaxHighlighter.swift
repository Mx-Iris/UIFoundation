//
//  SwiftSyntaxHighlighter.swift
//  ComponentLayoutExample
//
//  Syntax highlighting for the code blocks, over tree-sitter.
//
//  **This is shared and memoised on purpose, and both halves are load-bearing.**
//  View reuse is opt-in from UIComponent 5.0, so every code block that scrolls
//  into view builds a fresh `CodeTextView`. Whatever that view owns, it pays
//  for on every scroll. The previous implementation owned a `Highlightr`, which
//  is a JavaScriptCore context loading highlight.js -- measured at 25-33 ms to
//  construct, against a 16.6 ms frame budget, so a single code block entering
//  the viewport dropped two frames.
//
//  Measured on this toolchain, release build, per code block:
//
//  | step                                  | Highlightr | tree-sitter |
//  |---------------------------------------|-----------:|------------:|
//  | build the engine                      |   25-33 ms |    0.000 ms |
//  | highlight one snippet (warm)          |    0.48 ms |    0.086 ms |
//  | compile the query (once per process)  |          - |    78.6  ms |
//  | repeat visit to the same snippet      |    0.48 ms |    0.000 ms |
//
//  So: one parser and one query for the whole app, the query compiled off the
//  main thread through ``warmUp()``, and every result memoised by snippet. A
//  code block scrolling back into view costs a dictionary lookup.
//

import AppKit
import SwiftTreeSitter
import TreeSitterSwift

/// Colours a Swift snippet, once per snippet per appearance.
///
/// Reach it through ``shared``; a second instance would pay the 78 ms query
/// compilation again for nothing.
final class SwiftSyntaxHighlighter: @unchecked Sendable {
    static let shared = SwiftSyntaxHighlighter()

    /// Everything below is touched from both the warm-up queue and the main
    /// thread, and none of tree-sitter's Swift types are `Sendable`.
    private let lock = NSLock()

    private var language: Language?
    private var parser: Parser?
    private var query: Query?
    private var didAttemptLoad = false

    private struct MemoKey: Hashable {
        let code: String
        let isDark: Bool
        let fontName: String
        let fontSize: CGFloat
    }

    private var memo: [MemoKey: NSAttributedString] = [:]

    private init() {}

    // MARK: - Warm-up

    /// Compiles the grammar's query ahead of the first code block.
    ///
    /// Compiling `highlights.scm` costs ~78 ms, once per process. Left to
    /// happen lazily it lands on whichever code block renders first, which is
    /// during a layout pass. Call this when the example's root view is built
    /// and it is over long before a chapter is picked.
    func warmUp() {
        DispatchQueue.global(qos: .utility).async { [self] in
            lock.lock()
            defer { lock.unlock() }
            loadIfNeededLocked()
        }
    }

    // MARK: - Highlighting

    /// The snippet, coloured for `appearance`, or plainly attributed when the
    /// grammar could not be loaded.
    ///
    /// Never returns `nil`: a missing grammar degrades to readable plain text
    /// rather than to an empty block.
    func highlighted(_ code: String, isDark: Bool, font: NSFont) -> NSAttributedString {
        let key = MemoKey(code: code, isDark: isDark, fontName: font.fontName, fontSize: font.pointSize)

        lock.lock()
        defer { lock.unlock() }

        if let hit = memo[key] {
            return hit
        }
        let result = buildLocked(code: code, isDark: isDark, font: font)
        memo[key] = result
        return result
    }

    // MARK: - Implementation

    /// - Important: call with `lock` held.
    private func loadIfNeededLocked() {
        guard !didAttemptLoad else { return }
        didAttemptLoad = true

        let language = Language(language: tree_sitter_swift())
        self.language = language

        let parser = Parser()
        guard (try? parser.setLanguage(language)) != nil else { return }
        self.parser = parser

        guard let queryURL = Self.highlightsQueryURL() else { return }
        query = try? language.query(contentsOf: queryURL)
    }

    /// - Important: call with `lock` held.
    private func buildLocked(code: String, isDark: Bool, font: NSFont) -> NSAttributedString {
        loadIfNeededLocked()

        let theme = CodeTheme(isDark: isDark)
        let result = NSMutableAttributedString(
            string: code,
            attributes: [.font: font, .foregroundColor: theme.plainText]
        )

        guard let parser, let query,
              let tree = parser.parse(code), let root = tree.rootNode
        else {
            return result
        }

        // tree-sitter's convention is **first pattern wins**: a capture may not
        // repaint a range an earlier one already claimed. Without this, the
        // broad `@variable` pattern at the end of `highlights.scm` would
        // overwrite every `@function.call` before it, and every call site would
        // come out the colour of a plain identifier.
        var claimed = [Bool](repeating: false, count: (code as NSString).length)
        let cursor = query.execute(node: root, in: tree)

        while let match = cursor.next() {
            for capture in match.captures {
                let name = capture.nameComponents.joined(separator: ".")
                guard let colour = theme.colour(forCapture: name) else { continue }

                let range = capture.range
                guard range.location >= 0, range.location + range.length <= claimed.count else { continue }

                var runStart: Int?
                for index in range.location ..< (range.location + range.length) {
                    if claimed[index] {
                        if let start = runStart {
                            result.addAttribute(.foregroundColor, value: colour,
                                                range: NSRange(location: start, length: index - start))
                            runStart = nil
                        }
                    } else {
                        claimed[index] = true
                        if runStart == nil { runStart = index }
                    }
                }
                if let start = runStart {
                    let end = range.location + range.length
                    result.addAttribute(.foregroundColor, value: colour,
                                        range: NSRange(location: start, length: end - start))
                }

                if theme.isItalic(capture: name) {
                    result.addAttribute(.font, value: CodeTheme.italic(of: font), range: range)
                }
            }
        }

        return result
    }

    /// Finds `queries/highlights.scm` inside the grammar package's own resource
    /// bundle.
    ///
    /// `TreeSitterSwift` is a C target, so it has no `Bundle.module` accessor of
    /// its own to ask -- the bundle has to be found by name. SwiftPM names it
    /// `<package>_<target>.bundle` and puts it beside the executable for a
    /// command-line build and in `Contents/Resources` for an app.
    private static func highlightsQueryURL() -> URL? {
        var roots: [URL] = []
        if let resources = Bundle.main.resourceURL { roots.append(resources) }
        roots.append(Bundle.main.bundleURL)
        roots.append(Bundle.main.bundleURL.deletingLastPathComponent())

        for root in roots {
            guard let entries = try? FileManager.default.contentsOfDirectory(
                at: root, includingPropertiesForKeys: nil
            ) else { continue }

            for entry in entries
            where entry.pathExtension == "bundle" && entry.lastPathComponent.contains("TreeSitterSwift") {
                for relative in ["queries/highlights.scm", "Contents/Resources/queries/highlights.scm"] {
                    let candidate = entry.appendingPathComponent(relative)
                    if FileManager.default.fileExists(atPath: candidate.path) {
                        return candidate
                    }
                }
            }
        }
        return nil
    }
}
