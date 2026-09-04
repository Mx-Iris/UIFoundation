#if canImport(AppKit) && !targetEnvironment(macCatalyst)

import AppKit
import UIFoundationToolbox
#if AppKitPlus && canImport(AppKitPlus)
import AppKitPlus

/// The class `LayerBackedView` inherits from.
///
/// With the `AppKitPlus` trait on, this is `NSLayerBackedView` -- AppKitPlus's
/// port of UXKit's `UXView`, whose `-initWithFrame:` / `-initWithCoder:` already
/// apply the layer-backing defaults this class arranges for itself
/// (`wantsLayer`, `layerContentsRedrawPolicy = .onSetNeedsDisplay`,
/// `wantsUpdateLayer`), and which carries `userInteractionEnabled` and
/// `wantsSafeAreaInsetsFrozen` as real ivars rather than associated objects. The
/// latter is what AppKitPlus's `NSNavigationController` needs from a page it is
/// animating.
///
/// The base class contributes no property whose name collides with
/// `LayerBackgroundProviding`'s -- an ObjC class member would win the name lookup
/// and silently take the pipeline over, which is exactly what AppKitPlus 0.1.6's
/// `NSView (Appearance)` category did with `backgroundColor`. Hence the 0.2.0
/// floor in `Package.swift`, and the two canaries in
/// `LayerBackedViewBaseClassTests`.
public typealias LayerBackedViewBase = NSLayerBackedView
#else
/// The class `LayerBackedView` inherits from -- plain `NSView` unless the
/// `AppKitPlus` trait is on, in which case it becomes `NSLayerBackedView`.
public typealias LayerBackedViewBase = NSView
#endif

@IBDesignable
open class LayerBackedView: LayerBackedViewBase, LayerBackgroundProviding {
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
