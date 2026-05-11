#if canImport(AppKit) && !targetEnvironment(macCatalyst)

import AppKit
import UIFoundationUtilities

@IBDesignable
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

    @ViewInvalidating(.layout)
    @IBInspectable
    open var isRounded: Bool = false
    
    open override func layout() {
        super.layout()
        
        layer?.masksToBounds = isRounded
        layer?.cornerRadius = isRounded ? max(bounds.midX, bounds.midY) : 0
    }
}

#endif
