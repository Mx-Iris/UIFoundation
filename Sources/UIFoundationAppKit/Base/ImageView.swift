#if canImport(AppKit) && !targetEnvironment(macCatalyst)

import AppKit
import UIFoundationUtilities

@IBDesignable
open class ImageView: NSImageView {
    /// Constants that specify the image scaling behavior.
    public enum ImageScaling: Int {
        /// The image is resized to fit the entire bounds rectangle.
        case resize
        /// The image is resized to completely fill the bounds rectangle, while still preserving the aspect of the image.
        case scaleToFill
        /// The image is resized to fit the bounds rectangle, preserving the aspect of the image.
        case scaleToFit
        /// The image isn't resized.
        case none
        
        var nsImageScaling: NSImageScaling {
            switch self {
            case .resize: return .scaleAxesIndependently
            case .none: return .scaleNone
            default: return .scaleProportionallyUpOrDown
            }
        }
    }
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
    @IBInspectable
    open var isRounded: Bool = false

    open override var wantsUpdateLayer: Bool { true }
    
    open override func updateLayer() {
        super.updateLayer()
        
        layer?.cornerRadius = isRounded ? max(bounds.midX, bounds.midY) : 0
    }
}

#endif
