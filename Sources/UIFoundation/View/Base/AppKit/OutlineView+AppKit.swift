#if canImport(AppKit) && !targetEnvironment(macCatalyst)

import AppKit

open class OutlineView: NSOutlineView {
    open class func scrollableOutlineView() -> (scrollView: ScrollView, outlineView: OutlineView) {
        let scrollView = ScrollView()
        let outlineView = Self()
        scrollView.do {
            $0.documentView = outlineView
            $0.hasVerticalScroller = true
        }
        return (scrollView, outlineView)
    }
    
    open class func scrollableOutlineView<ScrollViewType: NSScrollView, OutlineViewType: OutlineView>() -> (scrollView: ScrollViewType, outlineView: OutlineViewType) {
        let scrollView = ScrollViewType()
        let outlineView = OutlineViewType()
        scrollView.do {
            $0.documentView = outlineView
            $0.hasVerticalScroller = true
        }
        return (scrollView, outlineView)
    }
    
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
    }
    
    open func setup() {}
}

#endif
