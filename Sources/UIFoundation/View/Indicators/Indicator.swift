#if canImport(AppKit) && !targetEnvironment(macCatalyst)
import AppKit
#endif

#if canImport(UIKit)
import UIKit
#endif



open class Indicator: _NSUIView, IndicatorProtocol {
    open var isAnimating: Bool = false
    open var radius: CGFloat = 18.0
    open var color: _NSUIColor = .lightGray

    public convenience init(radius: CGFloat = 18.0, color: _NSUIColor = .gray) {
        self.init()
        self.radius = radius
        self.color = color
    }

    public override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        self.wantsLayer = true
        #endif
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        self.wantsLayer = true
        #endif
    }

    open func startAnimating() {
        guard !isAnimating else { return }
        isHidden = false
        isAnimating = true

        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        guard let layer else { return }
        #endif

        layer.speed = 1
        setupAnimation(in: layer, size: CGSize(width: 2 * radius, height: 2 * radius))
    }

    open func stopAnimating() {
        guard isAnimating else { return }
        isHidden = true
        isAnimating = false

        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        guard let layer else { return }
        #endif

        layer.sublayers?.removeAll()
    }

    open func setupAnimation(in layer: CALayer, size: CGSize) {
        fatalError("Need to be implemented")
    }
}