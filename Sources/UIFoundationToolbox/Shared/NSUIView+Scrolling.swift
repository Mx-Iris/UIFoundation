#if canImport(AppKit) && !targetEnvironment(macCatalyst)
import AppKit
#endif

#if canImport(UIKit)
import UIKit
#endif

import FrameworkToolbox
import UIFoundationTypealias

/// A common way to read and write scroll geometry, for code that renders into a
/// view which may or may not be scrolling.
///
/// The two frameworks put that view in structurally different places:
///
/// - On UIKit the content *is* the `UIScrollView`. Its `bounds.origin` is the
///   content offset and `contentSize` is a settable property.
/// - On AppKit the content is the scroll view's **document view**.
///   `NSScrollView` requires one and hosted subviews have to live inside it, so
///   scroll state comes off `enclosingScrollView` and the content size is the
///   document view's own frame.
///
/// Reading every value through here is what keeps that split out of calling
/// code.
extension FrameworkToolbox where Base: NSUIView {

    /// The scroll view whose viewport this view's content scrolls through.
    public var enclosingComponentScrollView: NSUIScrollView? {
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        return base.enclosingScrollView
        #else
        return base as? NSUIScrollView
        #endif
    }

    /// The viewport, expressed in this view's own coordinate space: the origin
    /// is the scrolled position, the size is how much is on screen.
    ///
    /// On UIKit a scroll view's `bounds` is already exactly that. On AppKit the
    /// document view's `bounds` covers the whole content instead, but the clip
    /// view's `bounds` carries the identical meaning -- its origin is how far
    /// into the document view we have scrolled, its size is the viewport -- so
    /// the platforms line up once the value comes from there.
    ///
    /// Deliberately not `visibleRect`: that also subtracts any other clipping
    /// the view sits under, and is empty before the view reaches a window,
    /// which would cull everything on the first layout pass.
    ///
    /// - Important: The clip view's bounds only carries that meaning **for the
    ///   document view itself**. `enclosingScrollView` answers for every
    ///   descendant, and for anything deeper the two coordinate spaces are
    ///   unrelated -- a view nested three levels down would be told its viewport
    ///   starts at the scrolled position of a space it does not live in, and
    ///   cull its entire content once the user scrolls past its own height.
    public var viewportBounds: CGRect {
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        if let scrollView = base.enclosingScrollView, scrollView.documentView === base {
            return scrollView.contentView.bounds
        }
        return base.bounds
        #else
        return base.bounds
        #endif
    }

    /// The scrolled position of the content.
    public var contentOffset: CGPoint {
        get {
            #if canImport(AppKit) && !targetEnvironment(macCatalyst)
            return base.enclosingScrollView?.contentView.bounds.origin ?? .zero
            #else
            return base.bounds.origin
            #endif
        }
        nonmutating set {
            #if canImport(AppKit) && !targetEnvironment(macCatalyst)
            guard let scrollView = base.enclosingScrollView else { return }
            scrollView.contentView.setBoundsOrigin(newValue)
            scrollView.reflectScrolledClipView(scrollView.contentView)
            #else
            base.bounds.origin = newValue
            #endif
        }
    }

    /// Insets the viewport applies to its content.
    public var contentInset: NSUIEdgeInsets {
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        return base.enclosingScrollView?.contentInsets ?? NSUIEdgeInsets.zero
        #else
        return (base as? NSUIScrollView)?.adjustedContentInset ?? NSUIEdgeInsets.zero
        #endif
    }

    /// The zoom applied to the content.
    public var zoomScale: CGFloat {
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        return base.enclosingScrollView?.magnification ?? 1
        #else
        return (base as? NSUIScrollView)?.zoomScale ?? 1
        #endif
    }

    /// Tells the scrolling machinery how large the laid-out content is.
    ///
    /// On AppKit this resizes the document view itself, which is what makes the
    /// scroll view scrollable; there is no separate `contentSize` to set.
    public func setContentSize(_ contentSize: CGSize) {
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        guard base.enclosingScrollView != nil else { return }
        guard base.frame.size != contentSize else { return }
        base.setFrameSize(contentSize)
        #else
        (base as? NSUIScrollView)?.contentSize = contentSize
        #endif
    }

    /// Scrolls the given rect of this view's content into the viewport.
    /// - Returns: `false` when there is no scroll view to scroll.
    @discardableResult
    public func scrollRectToVisible(_ rect: CGRect, animated: Bool) -> Bool {
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        guard let scrollView = base.enclosingScrollView else { return false }
        if animated {
            NSAnimationContext.runAnimationGroup { context in
                context.allowsImplicitAnimation = true
                base.scrollToVisible(rect)
            }
        } else {
            base.scrollToVisible(rect)
        }
        scrollView.reflectScrolledClipView(scrollView.contentView)
        return true
        #else
        guard let scrollView = base as? NSUIScrollView else { return false }
        scrollView.scrollRectToVisible(rect, animated: animated)
        return true
        #endif
    }
}
