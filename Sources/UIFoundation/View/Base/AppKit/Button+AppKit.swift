#if canImport(AppKit) && !targetEnvironment(macCatalyst)

import AppKit

open class Button: NSButton {
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
}

#endif
