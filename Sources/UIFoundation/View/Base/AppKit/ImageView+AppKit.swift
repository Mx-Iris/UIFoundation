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
        setup()
    }

    open func setup() {}
    
    open override var wantsUpdateLayer: Bool { true }

    @Invalidating(.display, .layout)
    open var isRounded: Bool = false

    open override func layout() {
        super.layout()
    }

    open override func updateLayer() {
        super.updateLayer()

        layer?.cornerRadius = isRounded ? max(bounds.midX, bounds.midY) : 0
    }
}

#endif
