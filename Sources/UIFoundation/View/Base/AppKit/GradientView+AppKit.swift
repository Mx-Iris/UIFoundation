#if canImport(AppKit) && !targetEnvironment(macCatalyst)

import AppKit

open class GradientView: View {
    @Invalidating(.display)
    public private(set) var gradient: NSGradient? = nil
    
    open var colors: [NSColor] = [] {
        didSet {
            gradient = .init(colors: colors)
        }
    }
    
    open var angle: CGFloat = .pi / 2
    
    open override func updateLayer() {
        super.updateLayer()
        
        if let gradient {
            gradient.draw(in: bounds, angle: angle)
        }
    }
}

#endif
