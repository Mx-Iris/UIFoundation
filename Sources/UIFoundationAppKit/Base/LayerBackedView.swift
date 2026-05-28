#if canImport(AppKit) && !targetEnvironment(macCatalyst)

import AppKit
import UIFoundationToolbox

@IBDesignable
open class LayerBackedView: NSView, LayerBackgroundProviding {
    public override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        commonInit()
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    open func setup() {}

    open func firstLayout() {}

    private lazy var _firstLayout: Void = {
        firstLayout()
    }()

    private func commonInit() {
        attachToSelf()
        setup()
    }

    open override func updateLayer() {
        super.updateLayer()
        updateLayerBackground()
    }

    open override var wantsUpdateLayer: Bool { true }

    open override func layout() {
        super.layout()
        _ = _firstLayout
        layoutLayerBackground()
    }
}

public protocol ViewProtocol: NSView {}

extension NSView: ViewProtocol {}

extension ViewProtocol {
    public static func scrollableDocumentView() -> (scrollView: NSScrollView, documentView: Self) {
        NSView.scrollableDocumentView()
    }
}

extension NSView {
    public class func scrollableDocumentView<ScrollView: NSScrollView, DocumentView: NSView>() -> (scrollView: ScrollView, documentView: DocumentView) {
        let scrollView = ScrollView()
        let documentView = DocumentView()
        scrollView.do {
            $0.documentView = documentView
            $0.hasVerticalScroller = true
        }
        return (scrollView, documentView)
    }
}

#endif
