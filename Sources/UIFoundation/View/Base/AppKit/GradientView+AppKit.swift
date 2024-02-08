#if canImport(AppKit) && !targetEnvironment(macCatalyst)

import AppKit

open class GradientView: View {
    
    public private(set) var gradient: NSGradient?
    
    @Invalidating(.display)
    open var colors: [NSColor] = [] {
        didSet {
            gradient = .init(colors: colors)
        }
    }
    
    open var angle: CGFloat = .pi / 2
    
    open override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        if let gradient {
            gradient.draw(in: bounds, angle: angle)
        }
    }
}

#endif
