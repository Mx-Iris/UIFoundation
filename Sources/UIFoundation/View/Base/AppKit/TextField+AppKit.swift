#if canImport(AppKit) && !targetEnvironment(macCatalyst)

import AppKit

open class TextField: NSTextField {
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
//        layerContentsRedrawPolicy = .onSetNeedsDisplay
        setup()
    }
    
    open func setup() {}
    
//    open override var wantsUpdateLayer: Bool { true }
    
    public convenience init(bezelStyle: BezelStyle) {
        self.init(frame: .zero)
        self.bezelStyle = bezelStyle
    }
}

#endif
