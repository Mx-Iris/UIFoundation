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
/// It also owns the view's appearance. AppKitPlus 0.24.0 gave it `cornerRadius`,
/// `cornerCurve`, `backgroundColor`, `borderColor`, `borderWidth`,
/// `borderPositions`, `borderLocation`, `borderInsets` and `shadowProperties` --
/// the names `LayerBackgroundProviding` uses -- and an Objective-C class member
/// wins the name lookup over a protocol extension. So with the trait on,
/// `LayerBackedView` leaves those members to its base class and does not run
/// `LayerBackgroundRenderer` at all: a renderer that never receives a value still
/// writes its defaults (radius 0, no background) onto the layer on every update.
/// `LayerBackedView+Shadow.swift` keeps the five `shadow*` members by writing
/// through to `shadowProperties`. See Documentations/LayerBackground.md and the
/// Evolution proposal `appkitplus-owns-layer-backed-view-appearance`.
public typealias LayerBackedViewBase = NSLayerBackedView
#else
/// The class `LayerBackedView` inherits from -- plain `NSView` unless the
/// `AppKitPlus` trait is on, in which case it becomes `NSLayerBackedView`.
public typealias LayerBackedViewBase = NSView
#endif

/// A layer-backed view that renders in `updateLayer()`, with `setup()` and
/// `firstLayout()` hooks.
///
/// Its corner radius, background colour, border and shadow come from
/// `LayerBackgroundProviding` and `LayerBackgroundRenderer` with the `AppKitPlus`
/// trait off, and from `NSLayerBackedView` with it on (see `LayerBackedViewBase`).
/// The members keep their names either way.
@IBDesignable
open class LayerBackedView: LayerBackedViewBase {
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
        #if AppKitPlus && canImport(AppKitPlus)
        // AppKitPlus draws a border along every edge until told otherwise; this class has always
        // drawn none until the edges are named, and keeps that default with the trait on or off.
        borderPositions = []
        #else
        attachToSelfIfNeeded()
        #endif
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
        #if !(AppKitPlus && canImport(AppKitPlus))
        layoutLayerBackgroundIfNeeded()
        #endif
    }

    open override func updateLayer() {
        super.updateLayer()

        #if !(AppKitPlus && canImport(AppKitPlus))
        updateLayerBackgroundIfNeeded()
        #endif
    }

    open override var wantsUpdateLayer: Bool { isLayerBackingEnabled }
}

#if !(AppKitPlus && canImport(AppKitPlus))
extension LayerBackedView: LayerBackgroundProviding {}
#endif

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
