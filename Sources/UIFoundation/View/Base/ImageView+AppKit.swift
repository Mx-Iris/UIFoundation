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
    
    func commonInit() {
        wantsLayer = true
    }
    
    public var isRounded: Bool = false {
        didSet {
            needsLayout = true
        }
    }
    
    
    open override func layout() {
        super.layout()
        if isRounded {
            layer?.cornerRadius = max(bounds.midX, bounds.midY)
        }
    }
}

#endif
