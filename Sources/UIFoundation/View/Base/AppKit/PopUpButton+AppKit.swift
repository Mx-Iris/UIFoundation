#if canImport(AppKit) && !targetEnvironment(macCatalyst)

import AppKit

open class PopUpButton: NSPopUpButton {
    public override init(frame buttonFrame: NSRect, pullsDown flag: Bool) {
        super.init(frame: buttonFrame, pullsDown: flag)
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
}


#endif
