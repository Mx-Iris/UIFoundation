#if canImport(AppKit) && !targetEnvironment(macCatalyst)
import AppKit
#endif

#if canImport(UIKit)
import UIKit
#endif



open class MaterialLoadingIndicator: Indicator {
    fileprivate let drawableLayer = CAShapeLayer()

    open override var color: NSUIColor {
        didSet {
            drawableLayer.strokeColor = color.cgColor
        }
    }

    @IBInspectable open var lineWidth: CGFloat = 3 {
        didSet {
            drawableLayer.lineWidth = self.lineWidth
            self.updatePath()
        }
    }

    open override var bounds: CGRect {
        didSet {
            updateFrame()
            updatePath()
        }
    }

    public convenience init(radius: CGFloat = 18.0, color: NSUIColor = .gray) {
        self.init()
        self.radius = radius
        self.color = color
        setup()
    }

    public override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    public required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        setup()
    }

    #if canImport(AppKit) && !targetEnvironment(macCatalyst)
    open override func layout() {
        super.layout()
        updateFrame()
        updatePath()
    }
    #endif

    #if canImport(UIKit)
    open override func layoutSubviews() {
        super.layoutSubviews()
        updateFrame()
        updatePath()
    }
    #endif

    open override func startAnimating() {
        if isAnimating {
            return
        }
        isAnimating = true
        isHidden = false
        // Size is unused here.
        setupAnimation(in: drawableLayer, size: .zero)
    }

    open override func stopAnimating() {
        drawableLayer.removeAllAnimations()
        isAnimating = false
        isHidden = true
    }

    fileprivate func setup() {
        isHidden = true
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        layer?.addSublayer(drawableLayer)
        #endif

        #if canImport(UIKit)
        layer.addSublayer(drawableLayer)
        #endif
        drawableLayer.strokeColor = color.cgColor
        drawableLayer.lineWidth = lineWidth
        drawableLayer.fillColor = NSUIColor.clear.cgColor
        drawableLayer.lineJoin = .round
        drawableLayer.lineCap = .round
        drawableLayer.strokeStart = 0.99
        drawableLayer.strokeEnd = 1
        updateFrame()
        updatePath()
    }

    fileprivate func updateFrame() {
        drawableLayer.frame = CGRect(x: 0, y: 0, width: bounds.width, height: bounds.height)
    }

    fileprivate func updatePath() {
        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        let radius: CGFloat = radius - lineWidth
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        let path = NSBezierPath()
        path.appendArc(withCenter: center, radius: radius, startAngle: 0, endAngle: CGFloat(2 * Double.pi), clockwise: true)
        drawableLayer.path = path.asCGPath
        #endif

        #if canImport(UIKit)
        drawableLayer.path = UIBezierPath(
            arcCenter: center,
            radius: radius,
            startAngle: 0,
            endAngle: CGFloat(2 * Double.pi),
            clockwise: true
        ).cgPath
        #endif
    }

    open override func setupAnimation(in layer: CALayer, size: CGSize) {
        layer.removeAllAnimations()

        let rotationAnim = CABasicAnimation(keyPath: "transform.rotation")
        rotationAnim.fromValue = 0
        rotationAnim.duration = 4
//        rotationAnim.toValue = 2 * Double.pi
        rotationAnim.repeatCount = Float.infinity
        rotationAnim.isRemovedOnCompletion = false
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        rotationAnim.toValue = -2 * Double.pi
        #elseif canImport(UIKit)
        rotationAnim.toValue = 2 * Double.pi
        #endif
        let startHeadAnim = CABasicAnimation(keyPath: "strokeStart")
        startHeadAnim.beginTime = 0.1
        startHeadAnim.fromValue = 0
        startHeadAnim.toValue = 0.25
        startHeadAnim.duration = 1
        startHeadAnim.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)

        let startTailAnim = CABasicAnimation(keyPath: "strokeEnd")
        startTailAnim.beginTime = 0.1
        startTailAnim.fromValue = 0
        startTailAnim.toValue = 1
        startTailAnim.duration = 1
        startTailAnim.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)

        let endHeadAnim = CABasicAnimation(keyPath: "strokeStart")
        endHeadAnim.beginTime = 1
        endHeadAnim.fromValue = 0.25
        endHeadAnim.toValue = 0.99
        endHeadAnim.duration = 0.5
        endHeadAnim.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)

        let endTailAnim = CABasicAnimation(keyPath: "strokeEnd")
        endTailAnim.beginTime = 1
        endTailAnim.fromValue = 1
        endTailAnim.toValue = 1
        endTailAnim.duration = 0.5
        endTailAnim.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)

        let strokeAnimGroup = CAAnimationGroup()
        strokeAnimGroup.duration = 1.5
        strokeAnimGroup.animations = [startHeadAnim, startTailAnim, endHeadAnim, endTailAnim]
        strokeAnimGroup.repeatCount = Float.infinity
        strokeAnimGroup.isRemovedOnCompletion = false

        layer.add(rotationAnim, forKey: "rotation")
        layer.add(strokeAnimGroup, forKey: "stroke")
    }
}

extension NSBezierPath {
    var asCGPath: CGPath {
        if #available(macOS 14.0, *) {
            return cgPath
        } else {
            let path = CGMutablePath()
            var points = [CGPoint](repeating: .zero, count: 3)
            for i in 0 ..< elementCount {
                let type = element(at: i, associatedPoints: &points)
                switch type {
                case .moveTo: path.move(to: points[0])
                case .lineTo: path.addLine(to: points[0])
                case .curveTo,
                     .cubicCurveTo: path.addCurve(to: points[2], control1: points[0], control2: points[1])
                case .closePath: path.closeSubpath()
                case .quadraticCurveTo: path.addQuadCurve(to: points[1], control: points[0])
                @unknown default:
                    break
                }
            }
            return path
        }
    }
}
