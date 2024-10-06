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
        wantsLayer = true
        setup()
    }

    open func setup() {}
}

public protocol OutlineViewProtocol: NSOutlineView {}
extension NSOutlineView: OutlineViewProtocol {}

extension OutlineViewProtocol {
    public static func scrollableOutlineView() -> (scrollView: NSScrollView, outlineView: Self) {
        let scrollView = NSScrollView()
        let outlineView = Self()
        scrollView.do {
            $0.documentView = outlineView
            $0.hasVerticalScroller = true
        }
        return (scrollView, outlineView)
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
}

#endif
