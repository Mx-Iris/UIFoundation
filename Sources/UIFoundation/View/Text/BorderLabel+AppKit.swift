#if canImport(AppKit) && !targetEnvironment(macCatalyst)
import AppKit

open class RoundedBorderLabel: Label {
    @Invalidating(.display)
    open var borderColor: NSColor = .clear

    @Invalidating(.display)
    open var borderWidth: CGFloat = 0

    @Invalidating(.display)
    open var layerBackgroundColor: NSColor = .clear

    public override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        commonInit()
    }

    open func commonInit() {
        wantsLayer = true
    }

    open override var wantsUpdateLayer: Bool { true }

    open override func layout() {
        super.layout()
    }

    open override func updateLayer() {
        super.updateLayer()

        layer?.cornerRadius = bounds.height / 2
        layer?.backgroundColor = layerBackgroundColor.cgColor
        layer?.borderWidth = borderWidth
        layer?.borderColor = borderColor.cgColor
    }
}
#endif
