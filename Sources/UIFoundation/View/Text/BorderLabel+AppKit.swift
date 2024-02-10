#if canImport(AppKit) && !targetEnvironment(macCatalyst)
import AppKit

open class RoundedBorderLabel: Label {
    @Invalidating(.display, .layout)
    open var borderColor: NSColor = .clear

    @Invalidating(.display, .layout)
    open var borderWidth: CGFloat = 0

    @Invalidating(.display, .layout)
    open var layerBackgroundColor: NSColor = .clear

    open override func updateLayer() {
        super.updateLayer()

        layer?.cornerRadius = bounds.height / 2
        layer?.backgroundColor = layerBackgroundColor.cgColor
        layer?.borderWidth = borderWidth
        layer?.borderColor = borderColor.cgColor
    }
}
#endif
