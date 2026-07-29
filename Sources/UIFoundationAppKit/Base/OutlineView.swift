#if canImport(AppKit) && !targetEnvironment(macCatalyst)

import AppKit

open class OutlineView: NSOutlineView {
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
}

/// ``OutlineView`` variant whose intrinsic content height is the sum of its visible rows, so the
/// tree grows and shrinks with every disclosure instead of scrolling inside a fixed frame. Pair it
/// with ``SelfSizingScrollView``, or drop it straight into a stack view.
///
/// **A disclosure does not animate**, and that is not a matter of taste: a self-sizing outline view
/// has two things to move at once and AppKit drives only one of them. `expandItem(_:expandChildren:)`
/// slides the new rows in over `NSAnimationContext`'s default 0.25s duration, while the height this
/// view reports travels through Auto Layout on its own schedule — two timelines that never line up,
/// which reads as a jitter. Wrapping the whole disclosure in a zero-duration grouping makes both
/// instant, and it also covers whatever a delegate does from `outlineViewItemDidExpand`, which is
/// posted from inside this call. Set ``animatesExpansionAndCollapse`` to `true` to hand the
/// animation back to AppKit — sensible only when the host's height does not follow the row count.
///
/// Overriding this one method catches every way of expanding: the programmatic `expandItem(_:)`
/// forwards to it, and so does the user clicking the disclosure triangle — that triangle is a real
/// `NSButton` targeting the outline view, whose `_outlineControlClicked:` action routes through
/// here.
open class SelfSizingOutlineView: OutlineView {
    /// Whether a disclosure animates. Off by default — see the discussion above.
    public var animatesExpansionAndCollapse = false

    open override var intrinsicContentSize: NSSize {
        selfSizingRowsContentSize
    }

    open override func invalidateIntrinsicContentSize() {
        super.invalidateIntrinsicContentSize()
        // The scroll view derives its own intrinsic size from this one, and nothing tells it to ask
        // again.
        enclosingScrollView?.invalidateIntrinsicContentSize()
    }

    open override func reloadData() {
        super.reloadData()
        invalidateIntrinsicContentSize()
    }

    open override func noteHeightOfRows(withIndexesChanged indexSet: IndexSet) {
        super.noteHeightOfRows(withIndexesChanged: indexSet)
        invalidateIntrinsicContentSize()
    }

    open override func noteNumberOfRowsChanged() {
        super.noteNumberOfRowsChanged()
        invalidateIntrinsicContentSize()
    }

    open override func expandItem(_ item: Any?, expandChildren: Bool) {
        performDisclosure {
            super.expandItem(item, expandChildren: expandChildren)
            // A disclosure changes the row count without going through `noteNumberOfRowsChanged()`,
            // so the invalidation has to be driven from here.
            invalidateIntrinsicContentSize()
        }
    }

    open override func collapseItem(_ item: Any?, collapseChildren: Bool) {
        performDisclosure {
            super.collapseItem(item, collapseChildren: collapseChildren)
            invalidateIntrinsicContentSize()
        }
    }

    private func performDisclosure(_ body: () -> Void) {
        guard !animatesExpansionAndCollapse else {
            body()
            return
        }
        NSAnimationContext.beginGrouping()
        NSAnimationContext.current.duration = 0
        body()
        NSAnimationContext.endGrouping()
    }
}

public protocol OutlineViewProtocol: NSOutlineView {}

extension NSOutlineView: OutlineViewProtocol {}

extension OutlineViewProtocol {
    public static func scrollableOutlineView() -> (scrollView: NSScrollView, outlineView: Self) {
        NSOutlineView.scrollableOutlineView()
    }
    
    public static func scrollableSingleColumnOutlineView() -> (scrollView: NSScrollView, outlineView: Self) {
        NSOutlineView.scrollableSingleColumnOutlineView()
    }
}

extension NSOutlineView {
    public class func scrollableOutlineView<ScrollViewType: NSScrollView, OutlineViewType: NSOutlineView>() -> (scrollView: ScrollViewType, outlineView: OutlineViewType) {
        let scrollView = ScrollViewType()
        let outlineView = OutlineViewType()
        scrollView.do {
            $0.documentView = outlineView
            $0.hasVerticalScroller = true
        }
        return (scrollView, outlineView)
    }

    public class func scrollableSingleColumnOutlineView<ScrollViewType: NSScrollView, OutlineViewType: NSOutlineView>() -> (scrollView: ScrollViewType, outlineView: OutlineViewType) {
        let scrollView = ScrollViewType()
        let outlineView = OutlineViewType()
        scrollView.do {
            $0.documentView = outlineView
            $0.hasVerticalScroller = true
        }
        outlineView.do {
            $0.headerView = nil
            $0.addTableColumn(NSTableColumn(identifier: "\(Self.self)"))
            $0.autoresizesOutlineColumn = false
        }

        return (scrollView, outlineView)
    }
}

#endif
