#if canImport(AppKit) && !targetEnvironment(macCatalyst)
import AppKit
#endif

#if canImport(UIKit)
import UIKit
#endif

import QuartzCore
import FrameworkToolbox
import UIFoundationTypealias

/// Geometry the two frameworks express differently in *shape*, not just in
/// spelling -- so a `NSUI*` typealias cannot bridge them and callers need a
/// common entry point instead.
extension FrameworkToolbox where Base: NSUIView {

    /// The view's backing layer, guaranteed to exist.
    ///
    /// `UIView.layer` is non-optional. `NSView.layer` is optional and stays nil
    /// until the view is made layer-backed, so code that needs a layer
    /// unconditionally -- to animate a transform, or to clear leftover
    /// animations before reuse -- gets nothing on AppKit and silently does
    /// nothing. This turns the view layer-backed on first access.
    ///
    /// Use ``optionalLayer`` instead when a missing layer is an acceptable
    /// answer and you do not want to force layer backing.
    public var backingLayer: CALayer {
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        if !base.wantsLayer {
            base.wantsLayer = true
        }
        if let existingLayer = base.layer {
            return existingLayer
        }
        let newLayer = CALayer()
        base.layer = newLayer
        return newLayer
        #else
        return base.layer
        #endif
    }

    /// Positions and sizes the view to occupy `frame`.
    ///
    /// **Do not substitute `view.bounds.size = …; view.center = …`**, which is
    /// how UIKit code usually spells this. That pair is chosen on UIKit because
    /// it survives a transform on the view, where assigning `frame` would land
    /// elsewhere.
    ///
    /// On AppKit `bounds` is not the frame seen from the inside: it is the
    /// view's own coordinate space, independent of the view's size. Assigning
    /// to it leaves the frame untouched, so the view keeps whatever size it had
    /// -- zero, for a freshly created one -- while `center` still moves it into
    /// position. The result is a correctly placed, zero-sized view that draws
    /// nothing, with no error or warning anywhere.
    public func setFrame(_ frame: CGRect) {
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        if base.frame != frame {
            base.frame = frame
        }
        #else
        if base.bounds.size != frame.size {
            base.bounds.size = frame.size
        }
        let newCenter = CGPoint(x: frame.midX, y: frame.midY)
        if base.center != newCenter {
            base.center = newCenter
        }
        #endif
    }

    /// The frame the view occupies, read back the same way ``setFrame(_:)``
    /// writes it.
    public var occupiedFrame: CGRect {
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        return base.frame
        #else
        return CGRect(
            x: base.center.x - base.bounds.width / 2,
            y: base.center.y - base.bounds.height / 2,
            width: base.bounds.width,
            height: base.bounds.height
        )
        #endif
    }

    /// The size the view would like, given a bounding size.
    ///
    /// `UIView.sizeThatFits(_:)` exists on every view; on AppKit only
    /// `NSControl` has it. This falls back through the intrinsic content size
    /// to the current bounds -- the order a hand-written AppKit cell would use.
    public func sizeThatFits(_ size: CGSize) -> CGSize {
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        if let control = base as? NSControl {
            return control.sizeThatFits(size)
        }
        let intrinsicSize = base.intrinsicContentSize
        if intrinsicSize.width != NSView.noIntrinsicMetric,
           intrinsicSize.height != NSView.noIntrinsicMetric {
            return intrinsicSize
        }
        return base.bounds.size
        #else
        return base.sizeThatFits(size)
        #endif
    }

    /// Whether a point in the view's own coordinate space counts as inside it.
    ///
    /// **Known divergence**: UIKit answers through `point(inside:with:)`, which
    /// a view may override to claim a hit area different from its bounds.
    /// AppKit has no overridable equivalent taking the view's own coordinates,
    /// so on macOS the answer is always the bounds.
    public func contains(_ point: CGPoint) -> Bool {
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        return base.bounds.contains(point)
        #else
        return base.point(inside: point, with: nil)
        #endif
    }

    /// Marks the view as needing a layout pass.
    public func setNeedsLayout() {
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        base.needsLayout = true
        #else
        base.setNeedsLayout()
        #endif
    }

    /// Lays the view's subtree out immediately if it is dirty.
    public func layoutIfNeeded() {
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        base.layoutSubtreeIfNeeded()
        #else
        base.layoutIfNeeded()
        #endif
    }

    /// The midpoint of the view's frame, in its superview's coordinate space.
    ///
    /// `UIView.center` with no AppKit counterpart.
    public var center: CGPoint {
        get {
            CGPoint(x: base.frame.midX, y: base.frame.midY)
        }
        nonmutating set {
            #if canImport(AppKit) && !targetEnvironment(macCatalyst)
            base.frame = CGRect(
                x: newValue.x - base.frame.width / 2,
                y: newValue.y - base.frame.height / 2,
                width: base.frame.width,
                height: base.frame.height
            )
            #else
            base.center = newValue
            #endif
        }
    }

    /// The view's opacity. `UIView.alpha`, spelled `alphaValue` on AppKit.
    public var alpha: CGFloat {
        get {
            #if canImport(AppKit) && !targetEnvironment(macCatalyst)
            return base.alphaValue
            #else
            return base.alpha
            #endif
        }
        nonmutating set {
            #if canImport(AppKit) && !targetEnvironment(macCatalyst)
            base.alphaValue = newValue
            #else
            base.alpha = newValue
            #endif
        }
    }

    /// Inserts a subview at an index, where 0 is the bottom-most.
    ///
    /// Assigning `subviews` is AppKit's supported way to reorder: it diffs
    /// against the current list, so a view already present is moved rather than
    /// removed and re-added -- the latter would reset its layer state
    /// mid-animation.
    public func insertSubview(_ subview: NSUIView, at index: Int) {
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        var reordered = base.subviews.filter { $0 !== subview }
        reordered.insert(subview, at: Swift.min(index, reordered.count))
        base.subviews = reordered
        #else
        base.insertSubview(subview, at: index)
        #endif
    }

    /// A view whose rendered content masks this view.
    ///
    /// `UIView.mask` has no AppKit equivalent; there it is backed by
    /// `CALayer.mask`. The view itself is retained because the layer property
    /// holds only the layer, and a mask view dropped by its owner would take
    /// that layer with it.
    ///
    /// **Known divergence**: UIKit lays out a mask view even though it is not
    /// in the view hierarchy. AppKit does not -- a layer used as a mask is
    /// rendered, but the view owning it never receives a layout pass, so the
    /// caller has to drive the mask's layout itself.
    public var maskingView: NSUIView? {
        get {
            #if canImport(AppKit) && !targetEnvironment(macCatalyst)
            return base.boxMaskingView
            #else
            return base.mask
            #endif
        }
        nonmutating set {
            #if canImport(AppKit) && !targetEnvironment(macCatalyst)
            base.boxMaskingView = newValue
            backingLayer.mask = newValue?.backingLayer
            #else
            base.mask = newValue
            #endif
        }
    }
}
