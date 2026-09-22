//
//  Text.swift
//  ComponentLayoutExample
//
//  A text leaf component, ported from lkzhao/UIComponent's `Text` with the
//  AppKit half rewritten.
//
//  This is the worked example of writing a leaf component, and it covers all
//  four things one has to get right:
//
//    1. Measure within the constraint  -- `layout(_:)` below.
//    2. Report a baseline              -- `ascender` / `descender`.
//    3. Be a value, not a view         -- so the engine can recycle the view.
//    4. Read the environment           -- `@Environment(\.font)` / `\.textColor`.
//
//  Only (1) is obvious. Skipping (2) makes `.baselineFirst` silently align to
//  the bottom edge; skipping (3) pins one view per item forever, which defeats
//  the point of the engine on a long list.
//

import AppKit
import UIFoundationComponent

/// What a ``Text`` is showing: a plain string plus a font, or a ready-made
/// attributed string.
public enum TextContent {
    case string(String, NSFont)
    case attributedString(NSAttributedString)

    /// Distance from the top of a line to its baseline.
    var ascender: CGFloat {
        switch self {
        case .string(_, let font): font.ascender
        case .attributedString(let attributed): attributed.ascender
        }
    }

    /// Distance from the baseline to the bottom of a line (negative).
    var descender: CGFloat {
        switch self {
        case .string(_, let font): font.descender
        case .attributedString(let attributed): attributed.descender
        }
    }

    /// Resolves to the string that actually gets measured and drawn.
    func resolved(textColor: NSColor?) -> NSAttributedString {
        switch self {
        case .string(let string, let font):
            var attributes: [NSAttributedString.Key: Any] = [.font: font]
            if let textColor {
                attributes[.foregroundColor] = textColor
            }
            return NSAttributedString(string: string, attributes: attributes)
        case .attributedString(let attributed):
            return attributed
        }
    }
}

/// A run of text.
///
/// ```swift
/// Text("Hello", font: .title).textColor(.secondaryLabel)
/// ```
public struct Text: Component {
    /// Font inherited from the tree, used when this was built from a plain string.
    @Environment(\.font) var font

    /// Colour inherited from the tree, used when this was built from a plain string.
    @Environment(\.textColor) var textColor

    public let content: TextContent

    /// `0` means no limit.
    public let numberOfLines: Int

    public let lineBreakMode: NSLineBreakMode

    /// Swift's `AttributedString` carries attributes (`NSInlinePresentationIntent`
    /// and friends) that the fast measurement path does not understand, so one
    /// built that way always takes the TextKit route.
    public let isSwiftAttributedString: Bool

    public init(
        _ text: String,
        numberOfLines: Int = 0,
        lineBreakMode: NSLineBreakMode = .byWordWrapping
    ) {
        self.content = .string(text, NSFont.systemFont(ofSize: NSFont.systemFontSize))
        self.numberOfLines = numberOfLines
        self.lineBreakMode = lineBreakMode
        self.isSwiftAttributedString = false
    }

    public init(
        _ text: String,
        font: NSFont,
        numberOfLines: Int = 0,
        lineBreakMode: NSLineBreakMode = .byWordWrapping
    ) {
        self.content = .attributedString(NSAttributedString(string: text, attributes: [.font: font]))
        self.numberOfLines = numberOfLines
        self.lineBreakMode = lineBreakMode
        self.isSwiftAttributedString = false
    }

    public init(
        attributedString: AttributedString,
        numberOfLines: Int = 0,
        lineBreakMode: NSLineBreakMode = .byWordWrapping
    ) {
        self.content = .attributedString(NSAttributedString(attributedString))
        self.numberOfLines = numberOfLines
        self.lineBreakMode = lineBreakMode
        self.isSwiftAttributedString = true
    }

    public init(
        attributedString: NSAttributedString,
        numberOfLines: Int = 0,
        lineBreakMode: NSLineBreakMode = .byWordWrapping
    ) {
        self.content = .attributedString(attributedString)
        self.numberOfLines = numberOfLines
        self.lineBreakMode = lineBreakMode
        self.isSwiftAttributedString = false
    }

    public func layout(_ constraint: Constraint) -> TextRenderNode {
        var content = content
        if case .string(let string, _) = content, let environmentFont = font {
            content = .string(string, environmentFont)
        }
        let attributedString = content.resolved(textColor: textColor)

        let size: CGSize
        if numberOfLines != 0 || isSwiftAttributedString {
            size = Self.textKitSize(
                of: attributedString,
                within: constraint.maxSize,
                numberOfLines: numberOfLines,
                lineBreakMode: lineBreakMode
            )
        } else {
            size = attributedString
                .boundingRect(with: constraint.maxSize, options: [.usesLineFragmentOrigin], context: nil)
                .size
        }

        return TextRenderNode(
            content: content,
            textColor: textColor,
            numberOfLines: numberOfLines,
            lineBreakMode: lineBreakMode,
            size: size.bound(to: constraint),
            ascender: content.ascender,
            descender: content.descender
        )
    }

    /// The measurement half of the pair `ComponentLabel` draws with.
    private static func textKitSize(
        of attributedString: NSAttributedString,
        within maxSize: CGSize,
        numberOfLines: Int,
        lineBreakMode: NSLineBreakMode
    ) -> CGSize {
        let textStorage = NSTextStorage()
        let layoutManager = NSLayoutManager()
        layoutManager.usesFontLeading = false
        textStorage.addLayoutManager(layoutManager)
        textStorage.setAttributedString(attributedString)

        let textContainer = NSTextContainer(size: maxSize)
        textContainer.lineFragmentPadding = 0
        textContainer.lineBreakMode = lineBreakMode
        textContainer.maximumNumberOfLines = numberOfLines
        layoutManager.addTextContainer(textContainer)
        layoutManager.ensureLayout(for: textContainer)

        return layoutManager.usedRect(for: textContainer).size
    }
}

/// The render node backing a ``Text``.
public struct TextRenderNode: RenderNode {
    public let content: TextContent
    public let textColor: NSColor?
    public let numberOfLines: Int
    public let lineBreakMode: NSLineBreakMode
    public let size: CGSize

    /// Reported to the stack layouts so `.baselineFirst` / `.baselineLast` line
    /// text up by its baseline instead of by its box. Without these overrides
    /// `RenderNode`'s defaults (`size.height` and `0`) make baseline alignment
    /// behave like bottom alignment -- quietly.
    public let ascender: CGFloat
    public let descender: CGFloat

    public init(
        content: TextContent,
        textColor: NSColor? = nil,
        numberOfLines: Int,
        lineBreakMode: NSLineBreakMode,
        size: CGSize,
        ascender: CGFloat,
        descender: CGFloat
    ) {
        self.content = content
        self.textColor = textColor
        self.numberOfLines = numberOfLines
        self.lineBreakMode = lineBreakMode
        self.size = size
        self.ascender = ascender
        self.descender = descender
    }

    /// Pushes the description onto whatever view the engine handed back --
    /// possibly one recycled from another `Text` that has scrolled away. This
    /// is what (3) in the file header buys.
    public func updateView(_ label: ComponentLabel) {
        label.numberOfLines = numberOfLines
        label.lineBreakMode = lineBreakMode
        label.attributedText = content.resolved(textColor: textColor)
    }
}
