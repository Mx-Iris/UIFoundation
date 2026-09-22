//
//  CodeTheme.swift
//  ComponentLayoutExample
//
//  Maps tree-sitter capture names onto colours.
//
//  Highlightr shipped 271 ready-made themes; tree-sitter hands back capture
//  names like `function.call` and leaves the palette to the host, so this file
//  is the price of the swap. It is also the reason the colours can finally be
//  right: `highlights.scm` distinguishes a call from a member from a plain
//  identifier, which a regex-based grammar cannot.
//
//  The palette is One Dark / One Light, which is what the code blocks already
//  wore -- four of the dark values here were read straight off the previous
//  implementation's output so the blocks did not change appearance in the swap.
//

import AppKit

/// The colours one appearance gives each kind of token.
struct CodeTheme {
    let isDark: Bool

    init(isDark: Bool) {
        self.isDark = isDark
    }

    // MARK: - Palette

    var plainText: NSColor { isDark ? Self.rgb(0xABB2BF) : Self.rgb(0x383A42) }
    private var comment: NSColor { isDark ? Self.rgb(0x5C6370) : Self.rgb(0xA0A1A7) }
    private var keyword: NSColor { isDark ? Self.rgb(0xC678DD) : Self.rgb(0xA626A4) }
    private var string: NSColor { isDark ? Self.rgb(0x98C379) : Self.rgb(0x50A14F) }
    private var number: NSColor { isDark ? Self.rgb(0xD19A66) : Self.rgb(0x986801) }
    private var type: NSColor { isDark ? Self.rgb(0xE5C07B) : Self.rgb(0xC18401) }
    private var function: NSColor { isDark ? Self.rgb(0x61AFEF) : Self.rgb(0x4078F2) }
    private var property: NSColor { isDark ? Self.rgb(0xE06C75) : Self.rgb(0xE45649) }

    /// The colour for a capture, or `nil` to leave the range alone.
    ///
    /// Resolution is longest-prefix on the dotted name, so `keyword.conditional`
    /// and `keyword.repeat` both land on `keyword` without being listed. That
    /// matters: `highlights.scm` uses fourteen `keyword.*` variants and adding
    /// each one here by hand would rot the moment the grammar gains another.
    func colour(forCapture capture: String) -> NSColor? {
        var name = capture
        while true {
            if let exact = exactColour(for: name) { return exact }
            guard let dot = name.lastIndex(of: ".") else { return nil }
            name = String(name[name.startIndex ..< dot])
        }
    }

    private func exactColour(for name: String) -> NSColor? {
        switch name {
        case "keyword": keyword
        case "comment": comment
        case "string", "character": string
        case "number", "boolean", "constant": number
        case "type", "constructor": type
        case "function": function
        case "attribute": type
        case "variable.member", "variable.parameter": property
        case "variable.builtin": keyword
        // Deliberately plain: `variable` is `highlights.scm`'s catch-all for any
        // identifier, and colouring it paints every argument label and every
        // local. Punctuation and operators stay plain for the same reason --
        // One Dark does not tint them, and tinting brackets in a layout DSL,
        // which is mostly brackets, reads as noise.
        case "variable", "operator", "punctuation", "label": plainText
        // `@spell` captures the prose inside comments for a spell checker. It
        // has no colour of its own, and claiming the range would stop the
        // `comment` capture from reaching it.
        case "spell": nil
        default: nil
        }
    }

    /// Comments are the one token kind that changes shape rather than colour.
    func isItalic(capture: String) -> Bool {
        capture == "comment" || capture.hasPrefix("comment.")
    }

    // MARK: - Helpers

    /// The italic cut of `font`, or `font` itself when the family has none.
    ///
    /// `NSFont.italicSystemFont(ofSize:)` is no use here -- it answers for the
    /// *system* font, and this is a monospaced one.
    static func italic(of font: NSFont) -> NSFont {
        let descriptor = font.fontDescriptor.withSymbolicTraits(.italic)
        return NSFont(descriptor: descriptor, size: font.pointSize) ?? font
    }

    private static func rgb(_ value: Int) -> NSColor {
        NSColor(
            srgbRed: CGFloat((value >> 16) & 0xFF) / 255,
            green: CGFloat((value >> 8) & 0xFF) / 255,
            blue: CGFloat(value & 0xFF) / 255,
            alpha: 1
        )
    }
}
