#if canImport(AppKit) && !targetEnvironment(macCatalyst)

import AppKit
import UIFoundationToolbox
import UIFoundationUtilities

@IBDesignable
open class LayerBackedView: NSView {
    public struct BorderPositions: OptionSet, Hashable {
        public let rawValue: Int

        public init(rawValue: Int) {
            self.rawValue = rawValue
        }

        public static let left = Self(rawValue: 1 << 0)
        public static let right = Self(rawValue: 1 << 1)
        public static let top = Self(rawValue: 1 << 2)
        public static let bottom = Self(rawValue: 1 << 3)
        public static var all: BorderPositions { [.top, .left, .right, .bottom] }
    }

    public enum BorderLocation {
        case inside
        case center
        case outside
    }

    public override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        commonInit()
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    private var borderLayer: CAShapeLayer?

    @ViewInvalidating(.display)
    open var borderPositions: BorderPositions = [] {
        didSet {
            createBorderLayerIfNeeded()
        }
    }

    @ViewInvalidating(.display)
    open var borderLocation: BorderLocation = .inside {
        didSet {
            createBorderLayerIfNeeded()
        }
    }

    @ViewInvalidating(.display)
    @IBInspectable
    open dynamic var borderColor: NSColor? = nil {
        didSet {
            createBorderLayerIfNeeded()
        }
    }

    @ViewInvalidating(.display)
    @IBInspectable
    open dynamic var borderWidth: CGFloat = 0 {
        didSet {
            createBorderLayerIfNeeded()
        }
    }

    @ViewInvalidating(.display)
    @IBInspectable
    open dynamic var borderInsets: NSEdgeInsets = .zero {
        didSet {
            createBorderLayerIfNeeded()
        }
    }

    @ViewInvalidating(.display)
    @IBInspectable
    open dynamic var cornerRadius: CGFloat = 0

    @ViewInvalidating(.display)
    @IBInspectable
    open dynamic var backgroundColor: NSColor? = nil

    @ViewInvalidating(.display)
    @IBInspectable
    open var shadowColor: NSColor? = nil

    @ViewInvalidating(.display)
    @IBInspectable
    open var shadowOpacity: Float = 0.0

    @ViewInvalidating(.display)
    @IBInspectable
    open var shadowOffset: CGSize = .init(width: 0, height: -3)

    @ViewInvalidating(.display)
    @IBInspectable
    open var shadowRadius: CGFloat = 3

    @ViewInvalidating(.display)
    open var shadowPath: NSBezierPath? = nil

    open override var shadow: NSShadow? {
        get {
            guard shadowColor != nil else { return nil }
            let result = NSShadow()
            result.shadowColor = shadowColor
            result.shadowOffset = shadowOffset
            result.shadowBlurRadius = shadowRadius
            return result
        }
        set {
            shadowColor = newValue?.shadowColor
            shadowOffset = newValue?.shadowOffset ?? .zero
            shadowRadius = newValue?.shadowBlurRadius ?? 0
        }
    }

    open func setup() {}

    open func firstLayout() {}

    private lazy var _firstLayout: Void = {
        firstLayout()
    }()

    private func commonInit() {
        wantsLayer = true
        layerContentsRedrawPolicy = .onSetNeedsDisplay
        setup()
    }

    open override func updateLayer() {
        super.updateLayer()

        performUpdateLayer()
    }

    open override var wantsUpdateLayer: Bool { true }

    open override func layout() {
        super.layout()
        _ = _firstLayout
        borderLayer?.frame = bounds
        borderLayer?.path = NSBezierPath(bounds: bounds, borderWidth: borderWidth, borderInsets: borderInsets, borderLocation: borderLocation, borderPositions: borderPositions).box.cgPath
    }

    private func performUpdateLayer() {
        guard let layer else { return }

        borderLayer?.path = NSBezierPath(bounds: bounds, borderWidth: borderWidth, borderInsets: borderInsets, borderLocation: borderLocation, borderPositions: borderPositions).box.cgPath
        borderLayer?.strokeColor = borderColor?.cgColor
        borderLayer?.lineWidth = borderWidth
        borderLayer?.cornerRadius = cornerRadius
        borderLayer?.masksToBounds = cornerRadius > 0
        layer.cornerRadius = cornerRadius
        layer.backgroundColor = backgroundColor?.cgColor
        layer.shadowColor = shadowColor?.cgColor
        layer.shadowOpacity = shadowOpacity
        layer.shadowOffset = shadowOffset
        layer.shadowRadius = shadowRadius
        layer.shadowPath = shadowPath?.box.cgPath
        layer.masksToBounds = clipsToBounds
    }

    private func createBorderLayerIfNeeded() {
        let shouldShowBorderLayer = borderWidth > 0 && borderColor != nil && borderPositions != []

        guard shouldShowBorderLayer else {
            if let existBorderLayer = borderLayer {
                existBorderLayer.removeFromSuperlayer()
                borderLayer = nil
            }
            return
        }

        guard borderLayer == nil else { return }

        let newBorderLayer = CAShapeLayer()
        newBorderLayer.frame = bounds
        layer?.addSublayer(newBorderLayer)
        borderLayer = newBorderLayer
    }
}

extension NSBezierPath {
    fileprivate convenience init(
        bounds: NSRect,
        borderWidth: CGFloat,
        borderInsets: NSEdgeInsets,
        borderLocation: LayerBackedView.BorderLocation,
        borderPositions: LayerBackedView.BorderPositions
    ) {
        self.init()

        let lineOffset: CGFloat
        let lineCapOffset: CGFloat
        switch borderLocation {
        case .inside:
            lineOffset = borderWidth / 2
            lineCapOffset = 0
        case .center:
            lineOffset = 0
            lineCapOffset = borderWidth / 2
        case .outside:
            lineOffset = -borderWidth / 2
            lineCapOffset = borderWidth
        }

        let verticalInset = borderInsets.top - borderInsets.bottom

        let showsTop = borderPositions.contains(.top)
        let showsLeft = borderPositions.contains(.left)
        let showsBottom = borderPositions.contains(.bottom)
        let showsRight = borderPositions.contains(.right)

        let leftEdgeX = lineOffset + verticalInset
        let rightEdgeX = bounds.width - lineOffset - verticalInset
        let topEdgeY = bounds.height - lineOffset - verticalInset
        let bottomEdgeY = lineOffset + verticalInset

        let horizontalStartX = (showsLeft ? -lineCapOffset + verticalInset : 0) + borderInsets.left
        let horizontalEndX = bounds.width + (showsRight ? lineCapOffset - verticalInset : 0) - borderInsets.right
        let verticalStartY = (showsBottom ? lineCapOffset - verticalInset : 0) + borderInsets.bottom
        let verticalEndY = bounds.height - (showsTop ? -lineCapOffset + verticalInset : 0) - borderInsets.top

        if showsTop {
            move(to: NSPoint(x: horizontalStartX, y: topEdgeY))
            line(to: NSPoint(x: horizontalEndX, y: topEdgeY))
        }

        if showsLeft {
            move(to: NSPoint(x: leftEdgeX, y: verticalStartY))
            line(to: NSPoint(x: leftEdgeX, y: verticalEndY))
        }

        if showsBottom {
            move(to: NSPoint(x: horizontalEndX, y: bottomEdgeY))
            line(to: NSPoint(x: horizontalStartX, y: bottomEdgeY))
        }

        if showsRight {
            move(to: NSPoint(x: rightEdgeX, y: verticalEndY))
            line(to: NSPoint(x: rightEdgeX, y: verticalStartY))
        }
    }
}

extension NSEdgeInsets {
    package static let zero = NSEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
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
