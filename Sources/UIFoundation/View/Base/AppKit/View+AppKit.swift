#if canImport(AppKit) && !targetEnvironment(macCatalyst)

import AppKit
import UIFoundationToolbox

@IBDesignable
open class View: NSView {
    public override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        commonInit()
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    open override func layout() {
        super.layout()
        _ = _firstLayout
    }

    @ViewInvalidating(.display)
    @IBInspectable
    open dynamic var borderColor: NSColor? = nil

    @ViewInvalidating(.display)
    @IBInspectable
    open dynamic var borderWidth: CGFloat = 0

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

    private func performUpdateLayer() {
        guard let layer else { return }
        layer.borderColor = borderColor?.cgColor
        layer.borderWidth = borderWidth
        layer.cornerRadius = cornerRadius
        layer.backgroundColor = backgroundColor?.cgColor
        layer.shadowColor = shadowColor?.cgColor
        layer.shadowOpacity = shadowOpacity
        layer.shadowOffset = shadowOffset
        layer.shadowRadius = shadowRadius
        layer.shadowPath = shadowPath?.asCGPath
    }
}

#endif
