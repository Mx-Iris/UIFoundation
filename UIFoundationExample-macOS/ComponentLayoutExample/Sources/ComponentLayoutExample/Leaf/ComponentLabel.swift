//
//  ComponentLabel.swift
//  ComponentLayoutExample
//
//  The view a `Text` renders into.
//
//  AppKit has no `UILabel`. The two candidates were an `NSTextField` in label
//  configuration and a view that draws the string itself; this is the second,
//  and the reason is correspondence rather than taste:
//
//    `Text.layout(_:)` measures with `NSAttributedString.boundingRect(…)` or
//    with TextKit directly. `NSAttributedString.draw(with:options:)` is the
//    inverse of the first, and `NSLayoutManager.drawGlyphs(…)` the inverse of
//    the second -- so measurement and drawing agree by construction. An
//    `NSTextField` decides where glyphs land through `NSTextFieldCell`'s
//    `drawingRect(forBounds:)`, which is a different calculation entirely
//    (UIFoundation's own `InsetsTextFieldCell` exists to override that family).
//    Nothing guarantees the two land in the same place.
//

import AppKit

/// Draws an attributed string in the frame the layout system hands it.
public final class ComponentLabel: NSView {
    /// **Load-bearing.** TextKit lays lines out downwards from the origin, so in
    /// AppKit's default bottom-left space a multi-line string would render its
    /// lines in the wrong order. It also matches the layout system's own
    /// top-left convention, so `bounds` means the same thing to both.
    public override var isFlipped: Bool { true }

    public override var isOpaque: Bool { false }

    /// The string to draw, already carrying its font and colour.
    public var attributedText: NSAttributedString? {
        didSet { needsDisplay = true }
    }

    /// `0` means no limit.
    public var numberOfLines: Int = 0 {
        didSet { needsDisplay = true }
    }

    public var lineBreakMode: NSLineBreakMode = .byWordWrapping {
        didSet { needsDisplay = true }
    }

    /// Horizontal alignment within the frame the layout system assigned.
    ///
    /// Only visible when that frame is wider than the text, which is why the
    /// chapters pair it with `.size(width:)`.
    public var textAlignment: NSTextAlignment = .natural {
        didSet { needsDisplay = true }
    }

    /// The string actually drawn.
    ///
    /// `NSAttributedString` carries alignment in its paragraph style rather
    /// than as a drawing parameter, so a non-default alignment means deriving a
    /// copy. An existing paragraph style is preserved and amended, not replaced
    /// -- dropping it would silently discard line spacing a caller had set.
    private var drawableText: NSAttributedString? {
        guard let attributedText, attributedText.length > 0 else { return nil }
        guard textAlignment != .natural else { return attributedText }

        let mutable = NSMutableAttributedString(attributedString: attributedText)
        let fullRange = NSRange(location: 0, length: mutable.length)
        let existing = attributedText.attribute(.paragraphStyle, at: 0, effectiveRange: nil) as? NSParagraphStyle
        let paragraphStyle = (existing?.mutableCopy() as? NSMutableParagraphStyle) ?? NSMutableParagraphStyle()
        paragraphStyle.alignment = textAlignment
        if existing == nil {
            paragraphStyle.lineBreakMode = lineBreakMode
        }
        mutable.addAttribute(.paragraphStyle, value: paragraphStyle, range: fullRange)
        return mutable
    }

    public override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard let attributedText = drawableText else { return }

        if numberOfLines == 0 {
            // Inverse of the `boundingRect` measurement path.
            attributedText.draw(with: bounds, options: [.usesLineFragmentOrigin], context: nil)
        } else {
            // Inverse of the TextKit measurement path. `boundingRect` has no way
            // to express a line limit, so a limited label has to go through the
            // layout manager both to measure and to draw.
            drawThroughTextKit(attributedText)
        }
    }

    private func drawThroughTextKit(_ attributedText: NSAttributedString) {
        let textStorage = NSTextStorage(attributedString: attributedText)
        let layoutManager = NSLayoutManager()
        // Same flag the measurement path sets -- without it the two disagree by
        // the font's leading on every line.
        layoutManager.usesFontLeading = false
        textStorage.addLayoutManager(layoutManager)

        let textContainer = NSTextContainer(size: bounds.size)
        textContainer.lineFragmentPadding = 0
        textContainer.lineBreakMode = lineBreakMode
        textContainer.maximumNumberOfLines = numberOfLines
        layoutManager.addTextContainer(textContainer)

        let glyphRange = layoutManager.glyphRange(for: textContainer)
        layoutManager.drawBackground(forGlyphRange: glyphRange, at: bounds.origin)
        layoutManager.drawGlyphs(forGlyphRange: glyphRange, at: bounds.origin)
    }
}
