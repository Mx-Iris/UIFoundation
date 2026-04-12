#if canImport(AppKit) && !targetEnvironment(macCatalyst)
import AppKit

@IBDesignable
open class RoundedBorderLabel: Label {
    @IBInspectable
    open dynamic var borderColor: NSColor? = nil {
        didSet { layer?.borderColor = borderColor?.cgColor }
    }

    @IBInspectable
    open dynamic var borderWidth: CGFloat = 0 {
        didSet { layer?.borderWidth = borderWidth }
    }

    open override func setup() {
        super.setup()
        wantsLayer = true
    }

    // By NOT overriding draw(_:), NSTextField's `_textFieldOverridesDrawingMethods`
    // flag stays FALSE, allowing wantsUpdateLayer to return YES and this
    // updateLayer() to actually be called.
    open override func updateLayer() {
        super.updateLayer()
        layer?.cornerRadius = bounds.height / 2
        // Apply initial values (covers the case where didSet fired before
        // the layer existed, e.g., during init?(coder:) decoding from IB).
        layer?.borderColor = borderColor?.cgColor
        layer?.borderWidth = borderWidth
    }
}
#endif
