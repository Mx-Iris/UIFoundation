#if canImport(AppKit) && !targetEnvironment(macCatalyst)

import AppKit
import UIFoundationToolbox

/// A clip view that is always flipped, so a scroll view's content starts at its top left.
///
/// `NSClipView` is flipped exactly when its document view is. A table, an outline or a text view is
/// flipped and opens at its top; a stack view or a plain `NSView` is not, and a scroll view showing
/// one taller than itself opens scrolled to the document's bottom. Behind this clip view every
/// document opens at its top.
///
/// Install it before the document view, or make the scroll view with `makeFlipped()`, which does:
///
/// ```swift
/// let scrollView = NSScrollView.box.makeFlipped()
/// scrollView.documentView = stackView
/// ```
open class FlippedClipView: NSClipView {
    open override var isFlipped: Bool { true }
}

extension FrameworkToolbox where Base: NSScrollView {
    /// Makes a scroll view whose content starts at its top left: its clip view is a
    /// ``FlippedClipView``, so a document view that is not flipped, such as a stack view, opens at
    /// its top rather than scrolled to its bottom.
    ///
    /// Apart from the clip view, the scroll view is as `Base()` makes it, background included, and
    /// it is of the class the method is called on: `SelfSizingScrollView.box.makeFlipped()` makes a
    /// ``SelfSizingScrollView``.
    public static func makeFlipped() -> Base {
        let scrollView = Base()
        let originalClipView = scrollView.contentView
        let flippedClipView = FlippedClipView()
        flippedClipView.drawsBackground = originalClipView.drawsBackground
        flippedClipView.backgroundColor = originalClipView.backgroundColor
        scrollView.contentView = flippedClipView
        return scrollView
    }
}

#endif
