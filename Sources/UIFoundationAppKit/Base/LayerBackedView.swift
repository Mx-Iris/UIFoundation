#if canImport(AppKit) && !targetEnvironment(macCatalyst)

import AppKit
import UIFoundationToolbox

@IBDesignable
open class LayerBackedView: NSView, LayerBackgroundProviding {
    open var isLayerBackingEnabled: Bool { true }

    public override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        commonInit()
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    private func commonInit() {
        attachToSelfIfNeeded()
        setup()
    }

    open func setup() {}

    open func firstLayout() {}

    private lazy var _firstLayout: () -> Void = {
        firstLayout()
        return {}
    }()

    open override func layout() {
        super.layout()
        
        _firstLayout()
        layoutLayerBackgroundIfNeeded()
    }

    open override func updateLayer() {
        super.updateLayer()
        
        updateLayerBackgroundIfNeeded()
    }

    open override var wantsUpdateLayer: Bool { isLayerBackingEnabled }
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
