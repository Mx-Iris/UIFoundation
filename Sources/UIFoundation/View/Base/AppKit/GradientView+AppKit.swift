#if canImport(AppKit) && !targetEnvironment(macCatalyst)

import AppKit

@IBDesignable
open class GradientView: View {

    public enum Position {
        case topLeft
        case centerLeft
        case bottomLeft
        case topCenter
        case center
        case bottomCenter
        case topRight
        case centerRight
        case bottomRight
        
        var cgPoint: CGPoint {
            switch self {
            case .topLeft:
                CGPoint(x: 0, y: 1)
            case .centerLeft:
                CGPoint(x: 0, y: 0.5)
            case .bottomLeft:
                CGPoint(x: 0, y: 0)
            case .topCenter:
                CGPoint(x: 0.5, y: 1)
            case .center:
                CGPoint(x: 0.5, y: 0.5)
            case .bottomCenter:
                CGPoint(x: 0.5, y: 0)
            case .topRight:
                CGPoint(x: 1, y: 1)
            case .centerRight:
                CGPoint(x: 1, y: 0.5)
            case .bottomRight:
                CGPoint(x: 1, y: 0)
            }
        }
    }
    
    private let gradientLayer = CAGradientLayer()
    
    @Invalidating(.display)
    @IBInspectable
    open dynamic var colors: [NSColor] = []

    @Invalidating(.display)
    @IBInspectable
    open dynamic var startPoint: NSPoint = .init(x: 0, y: 0.5)

    @Invalidating(.display)
    @IBInspectable
    open dynamic var endPoint: NSPoint = .init(x: 1, y: 0.5)

    @Invalidating(.display)
    @IBInspectable
    open dynamic var locations: [CGFloat] = [0, 1]
    
    public func setStartPosition(_ startPosition: Position) {
        startPoint = startPosition.cgPoint
    }
    
    public func setEndPosition(_ endPosition: Position) {
        endPoint = endPosition.cgPoint
    }
    
    open override func updateLayer() {
        super.updateLayer()
        gradientLayer.colors = colors.map(\.cgColor)
        gradientLayer.startPoint = startPoint
        gradientLayer.endPoint = endPoint
        gradientLayer.locations = locations.map { NSNumber(value: $0) }
    }
    
    open override func setup() {
        super.setup()
        
        layer?.addSublayer(gradientLayer)
        gradientLayer.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]
    }
}

#endif
