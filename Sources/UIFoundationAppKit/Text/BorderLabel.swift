#if canImport(AppKit) && !targetEnvironment(macCatalyst)
import AppKit
import UIFoundationUtilities

@IBDesignable
open class RoundedBorderLabel: Label {
    @ViewInvalidating(.display)
    @IBInspectable
    open dynamic var borderColor: NSColor? = nil

    @ViewInvalidating(.display)
    @IBInspectable
    open dynamic var borderWidth: CGFloat = 0


//    open override func updateLayer() {
//        super.updateLayer()
//
//        layer?.cornerRadius = bounds.height / 2
//        layer?.backgroundColor = layerBackgroundColor.cgColor
//        layer?.borderWidth = borderWidth
//        layer?.borderColor = borderColor.cgColor
//    }
    
    open override func setup() {
        super.setup()
        wantsLayer = true
    }
    
    open override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        layer?.cornerRadius = bounds.height / 2
        layer?.borderWidth = borderWidth
        layer?.borderColor = borderColor?.cgColor
    }
}
#endif
