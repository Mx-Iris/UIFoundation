#if canImport(AppKit) && !targetEnvironment(macCatalyst)

import AppKit

open class OutlineView: NSOutlineView {
    open class func scrollableOutlineView() -> (scrollView: ScrollView, outlineView: OutlineView) {
        let scrollView = ScrollView()
        let outlineView = OutlineView()
        scrollView.do {
            $0.documentView = outlineView
            $0.hasVerticalScroller = true
        }
        return (scrollView, outlineView)
    }
}

#endif
