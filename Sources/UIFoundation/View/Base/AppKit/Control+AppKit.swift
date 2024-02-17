#if canImport(AppKit) && !targetEnvironment(macCatalyst)

import AppKit

open class Control: NSControl {
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
}

#endif
