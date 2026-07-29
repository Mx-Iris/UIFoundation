#if canImport(AppKit) && !targetEnvironment(macCatalyst)

import AppKit
import UIFoundationUtilities

open class ScrollView: NSScrollView {
    public var isHiddenVisualEffectView: Bool = false

    public override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        commonInit()
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    private func commonInit() {
        setup()
    }

    open func setup() {}

    open override var drawsBackground: Bool {
        set {}
        get { false }
    }

    open override func didAddSubview(_ subview: NSView) {
        super.didAddSubview(subview)

        if isHiddenVisualEffectView, subview is NSVisualEffectView {
            subview.isHidden = true
        }
    }
}

/// Scroll view whose intrinsic content size mirrors its document view, so it only grows to fit the
/// embedded content. `minimumContentSize` keeps the view from collapsing below a floor;
/// `maximumContentSize` (or an external `lessThanOrEqualTo` constraint) caps the size. Once the
/// document exceeds the cap, the built-in scrollers take over.
///
/// The document view has to report an intrinsic size of its own for this to do anything —
/// ``SelfSizingTableView`` and ``SelfSizingOutlineView`` are the ones built to do that.
open class SelfSizingScrollView: ScrollView {
    @ViewInvalidating(.intrinsicContentSize)
    public var minimumContentSize = NSSize(width: NSView.noIntrinsicMetric, height: NSView.noIntrinsicMetric)

    @ViewInvalidating(.intrinsicContentSize)
    public var maximumContentSize = NSSize(width: NSView.noIntrinsicMetric, height: NSView.noIntrinsicMetric)

    open override var intrinsicContentSize: NSSize {
        guard let documentView else { return super.intrinsicContentSize }
        let documentIntrinsic = documentView.intrinsicContentSize
        return NSSize(
            width: clampedAxis(documentIntrinsic.width, minimum: minimumContentSize.width, maximum: maximumContentSize.width),
            height: clampedAxis(documentIntrinsic.height, minimum: minimumContentSize.height, maximum: maximumContentSize.height)
        )
    }

    private func clampedAxis(_ contentValue: CGFloat, minimum: CGFloat, maximum: CGFloat) -> CGFloat {
        let hasMinimum = minimum != NSView.noIntrinsicMetric && minimum > 0
        let hasMaximum = maximum != NSView.noIntrinsicMetric && maximum > 0

        if contentValue == NSView.noIntrinsicMetric {
            return hasMinimum ? minimum : NSView.noIntrinsicMetric
        }
        var resolved = contentValue
        if hasMaximum {
            resolved = min(resolved, maximum)
        }
        if hasMinimum {
            resolved = max(resolved, minimum)
        }
        return resolved
    }
}

#endif
