#if canImport(AppKit) && !targetEnvironment(macCatalyst)

import AppKit

open class ImageView: NSImageView {
    public override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        commonInit()
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    private func commonInit() {
        wantsLayer = true
        layerContentsRedrawPolicy = .onSetNeedsDisplay
        setup()
    }

    open func setup() {}

    @ViewInvalidating(.display)
    open var isRounded: Bool = false

    open override var wantsUpdateLayer: Bool { true }
    
    open override func updateLayer() {
        super.updateLayer()
        
        layer?.cornerRadius = isRounded ? max(bounds.midX, bounds.midY) : 0
    }
}

#endif
