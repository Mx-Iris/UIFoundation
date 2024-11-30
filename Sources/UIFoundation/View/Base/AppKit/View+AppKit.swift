#if canImport(AppKit) && !targetEnvironment(macCatalyst)

import AppKit
import UIFoundationToolbox

@IBDesignable
open class View: NSView {
    public struct BorderPositions: OptionSet, Hashable {
        public let rawValue: Int

        public init(rawValue: Int) {
            self.rawValue = rawValue
        }

        public static let left = Self(rawValue: 1 << 0)
        public static let right = Self(rawValue: 1 << 1)
        public static let top = Self(rawValue: 1 << 2)
        public static let bottom = Self(rawValue: 1 << 3)
        public static var all: BorderPositions = [.top, .left, .right, .bottom]
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
        borderLayer?.path = NSBezierPath(bounds: bounds, borderWidth: borderWidth, borderInsets: borderInsets, borderLocation: borderLocation, borderPositions: borderPositions).asCGPath
    }

    private func performUpdateLayer() {
        guard let layer else { return }

        borderLayer?.path = NSBezierPath(bounds: bounds, borderWidth: borderWidth, borderInsets: borderInsets, borderLocation: borderLocation, borderPositions: borderPositions).asCGPath
        borderLayer?.strokeColor = borderColor?.cgColor
        borderLayer?.lineWidth = borderWidth
        borderLayer?.cornerRadius = cornerRadius
        layer.cornerRadius = cornerRadius
        layer.backgroundColor = backgroundColor?.cgColor
        layer.shadowColor = shadowColor?.cgColor
        layer.shadowOpacity = shadowOpacity
        layer.shadowOffset = shadowOffset
        layer.shadowRadius = shadowRadius
        layer.shadowPath = shadowPath?.asCGPath
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
    fileprivate convenience init(bounds: NSRect, borderWidth: CGFloat, borderInsets: NSEdgeInsets, borderLocation: View.BorderLocation, borderPositions: View.BorderPositions) {
        let adjustsLocation: (CGFloat, CGFloat, CGFloat) -> CGFloat = { inside, center, outside in
            switch borderLocation {
            case .inside: return inside
            case .center: return center
            case .outside: return outside
            }
        }

        let lineOffset = adjustsLocation(borderWidth / 2.0, 0, -borderWidth / 2.0)
        let lineCapOffset = adjustsLocation(0, borderWidth / 2.0, borderWidth)
        let verticalInset = borderInsets.top - borderInsets.bottom

        let shouldShowTopBorder = borderPositions.contains(.top)
        let shouldShowLeftBorder = borderPositions.contains(.left)
        let shouldShowBottomBorder = borderPositions.contains(.bottom)
        let shouldShowRightBorder = borderPositions.contains(.right)

        let points: [String: [NSPoint]] = [
            "toppath": [
                NSPoint(
                    x: (shouldShowLeftBorder ? (-lineCapOffset + verticalInset) : 0) + borderInsets.left,
                    y: bounds.height - (lineOffset + verticalInset)
                ),
                NSPoint(
                    x: bounds.width + (shouldShowRightBorder ? (lineCapOffset - verticalInset) : 0) - borderInsets.right,
                    y: bounds.height - (lineOffset + verticalInset)
                ),
            ],
            "leftpath": [
                NSPoint(
                    x: lineOffset + verticalInset,
                    y: (shouldShowBottomBorder ? lineCapOffset - verticalInset : 0) + borderInsets.bottom
                ),
                NSPoint(
                    x: lineOffset + verticalInset,
                    y: bounds.height - (shouldShowTopBorder ? -lineCapOffset + verticalInset : 0) - borderInsets.top
                ),
            ],
            "bottompath": [
                NSPoint(
                    x: bounds.width + (shouldShowRightBorder ? (lineCapOffset - verticalInset) : 0) - borderInsets.right,
                    y: lineOffset + verticalInset
                ),
                NSPoint(
                    x: (shouldShowLeftBorder ? (-lineCapOffset + verticalInset) : 0) + borderInsets.left,
                    y: lineOffset + verticalInset
                ),
            ],
            "rightpath": [
                NSPoint(
                    x: bounds.width - lineOffset - verticalInset,
                    y: bounds.height - (shouldShowTopBorder ? -lineCapOffset + verticalInset : 0) - borderInsets.top
                ),
                NSPoint(
                    x: bounds.width - lineOffset - verticalInset,
                    y: (shouldShowBottomBorder ? lineCapOffset - verticalInset : 0) + borderInsets.bottom
                ),
            ],
        ]

        self.init()

        let topPath = NSBezierPath()
        let leftPath = NSBezierPath()
        let bottomPath = NSBezierPath()
        let rightPath = NSBezierPath()

        topPath.move(to: points["toppath"]![0])
        topPath.line(to: points["toppath"]![1])

        leftPath.move(to: points["leftpath"]![0])
        leftPath.line(to: points["leftpath"]![1])

        bottomPath.move(to: points["bottompath"]![0])
        bottomPath.line(to: points["bottompath"]![1])

        rightPath.move(to: points["rightpath"]![0])
        rightPath.line(to: points["rightpath"]![1])

        if shouldShowTopBorder, !topPath.isEmpty {
            append(topPath)
        }

        if shouldShowLeftBorder, !leftPath.isEmpty {
            append(leftPath)
        }

        if shouldShowBottomBorder, !bottomPath.isEmpty {
            append(bottomPath)
        }

        if shouldShowRightBorder, !rightPath.isEmpty {
            append(rightPath)
        }
    }
}

extension NSEdgeInsets {
    static let zero = NSEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
}

#endif
