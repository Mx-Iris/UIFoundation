//
//  CodeTextView.swift
//  ComponentLayoutExample
//
//  Ported from lkzhao/UIComponent's example app (created by Luke Zhao on
//  11/4/25), rewritten for `NSTextView`.
//

import AppKit

/// Shows a syntax-highlighted Swift snippet.
final class CodeTextView: NSTextView {
    /// **No highlighter is owned here, deliberately.** View reuse is opt-in, so
    /// one of these is built for every code block that scrolls into view; an
    /// engine owned per view is an engine constructed per scroll. See
    /// ``SwiftSyntaxHighlighter``.
    private static let font = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)

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

        applyHighlighting()
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

    /// Keeps the text container as wide as the view.
    ///
    /// **Load-bearing.** The container starts at width zero, and
    /// `sizeThatFits(_:)` sets it on the *measuring* instance -- a different
    /// object from the one on screen. Without this the displayed view keeps a
    /// zero-width container, lays out no lines at all, and draws an empty box
    /// of exactly the right height.
    ///
    /// `widthTracksTextView` would do it automatically, but it also makes
    /// AppKit overwrite the container size, which is what `sizeThatFits(_:)`
    /// relies on setting by hand.
    override func layout() {
        super.layout()
        textContainer?.size = CGSize(width: bounds.width, height: CGFloat.greatestFiniteMagnitude)
    }

    /// AppKit's counterpart of `traitCollectionDidChange` for light/dark.
    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        applyHighlighting()
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        // `viewDidChangeEffectiveAppearance` only fires on a *change*. A view
        // built while the app is already dark never sees one, and at init a
        // view outside any window answers `.aqua` -- which is how a dark app
        // ended up rendering its code blocks in the light theme.
        applyHighlighting()
    }

    private func applyHighlighting() {
        // The app's appearance, not this view's: before it joins a window the
        // view has none of its own to report.
        let appearance = window?.effectiveAppearance ?? NSApp?.effectiveAppearance ?? effectiveAppearance
        let isDark = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
        textStorage?.setAttributedString(
            SwiftSyntaxHighlighter.shared.highlighted(code, isDark: isDark, font: Self.font)
        )
    }
}
