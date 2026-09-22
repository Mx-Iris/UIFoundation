//
//  CodeTextView.swift
//  ComponentLayoutExample
//
//  Ported from lkzhao/UIComponent's example app (created by Luke Zhao on
//  11/4/25), rewritten for `NSTextView`.
//

import AppKit
import Highlightr

/// Shows a syntax-highlighted Swift snippet.
final class CodeTextView: NSTextView {
    private let highlighter = Highlightr()

    var code: String = "" {
        didSet {
            guard code != oldValue else { return }
            applyHighlighting()
        }
    }

    init() {
        // **Built as an explicit TextKit 1 stack.** From macOS 12 an
        // `NSTextView` created the ordinary way uses TextKit 2, and its
        // `layoutManager` comes back `nil` -- which would take `sizeThatFits`
        // below down with it. Handing `init(frame:textContainer:)` a container
        // of our own opts back into TextKit 1, the same machinery `Text` uses
        // to measure, so the snippet's measured height and drawn height agree.
        let textStorage = NSTextStorage()
        let layoutManager = NSLayoutManager()
        layoutManager.usesFontLeading = false
        textStorage.addLayoutManager(layoutManager)

        // `CGFloat.` spelled out: a leading dot here is ambiguous, because
        // `FrameworkToolbox`'s `@dynamicMemberLookup` offers a second candidate.
        // Same family as the `Swift.min` / `Swift.max` rule in AGENTS.md.
        let textContainer = NSTextContainer(size: CGSize(width: 0, height: CGFloat.greatestFiniteMagnitude))
        textContainer.lineFragmentPadding = 0
        textContainer.widthTracksTextView = false
        layoutManager.addTextContainer(textContainer)

        super.init(frame: .zero, textContainer: textContainer)

        isEditable = false
        isSelectable = true
        // The code block's background is drawn by the component around this
        // view; an opaque text view would cover the rounded corners.
        drawsBackground = false
        // Both zeroed so the glyphs start at the view's own origin. Left at
        // their defaults the text sits a few points in from where the layout
        // system placed the view.
        textContainerInset = .zero
        isVerticallyResizable = false
        isHorizontallyResizable = false

        applyTheme()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// The size this snippet needs within `size`.
    ///
    /// Not an override -- `NSTextView` is not an `NSControl` and has no
    /// `sizeThatFits(_:)` to override. `ViewComponent` reaches it through
    /// `box.sizeThatFits`, which falls back to `intrinsicContentSize`, so
    /// `CodeComponent` calls this directly instead.
    func sizeThatFits(_ size: CGSize) -> CGSize {
        guard let textContainer, let layoutManager else { return .zero }
        textContainer.size = CGSize(width: size.width, height: CGFloat.greatestFiniteMagnitude)
        layoutManager.ensureLayout(for: textContainer)
        let usedRect = layoutManager.usedRect(for: textContainer)
        return CGSize(
            width: Swift.min(ceil(usedRect.width), size.width),
            height: ceil(usedRect.height)
        )
    }

    /// AppKit's counterpart of `traitCollectionDidChange` for light/dark.
    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        applyTheme()
    }

    private func applyTheme() {
        guard let highlighter else { return }
        let isDark = effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
        highlighter.setTheme(to: isDark ? "monokai" : "xcode")
        highlighter.theme.setCodeFont(NSFont.monospacedSystemFont(ofSize: 13, weight: .regular))
        applyHighlighting()
    }

    private func applyHighlighting() {
        guard let highlighter, let highlighted = highlighter.highlight(code, as: "swift") else {
            string = code
            return
        }
        textStorage?.setAttributedString(highlighted)
    }
}
