#if canImport(AppKit) && !targetEnvironment(macCatalyst)

import AppKit

open class PopUpButton: NSPopUpButton {
    
    public convenience init() {
        self.init(frame: .zero, pullsDown: false)
    }
    
    public override init(frame buttonFrame: NSRect, pullsDown flag: Bool) {
        super.init(frame: buttonFrame, pullsDown: flag)
        commonInit()
    }
    
    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }
    
    private func commonInit() {
        setup()
    }
    
    open func setup() {}
}


#endif
