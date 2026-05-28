#if os(macOS)

import AppKit

open class GridView: NSGridView {
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

public protocol GridViewProtocol: NSGridView {}

extension NSGridView: GridViewProtocol {}

extension GridViewProtocol {
    public static func scrollableGridView() -> (scrollView: NSScrollView, gridView: Self) {
        NSGridView.scrollableGridView()
    }
}

extension NSGridView {
    public class func scrollableGridView<ScrollView: NSScrollView, GridView: NSGridView>() -> (scrollView: ScrollView, gridView: GridView) {
        let scrollView = ScrollView()
        let gridView = GridView()
        scrollView.do {
            $0.documentView = gridView
            $0.hasVerticalScroller = true
        }
        return (scrollView, gridView)
    }
}

#endif
