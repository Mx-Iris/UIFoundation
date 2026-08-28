#if RunningApplication && os(macOS)

import AppKit
import UIFoundationAppKit

// MARK: - SkeletonTableCellView

/// Placeholder cell shown in the table while real content is still loading.
/// It is a regular table cell view, so `NSTableView` owns its column frame,
/// row height, intercell spacing, and reuse — the skeleton needs no overlay
/// and no manual column-frame math.
@available(macOS 11.0, *)
final class SkeletonTableCellView: TableCellView {
    var style: SkeletonColumnDescriptor.Style = .text {
        didSet {
            guard style != oldValue else { return }
            applyCornerRadius()
            needsLayout = true
        }
    }

    var textAlignment: NSTextAlignment = .left {
        didSet {
            guard textAlignment != oldValue else { return }
            needsLayout = true
        }
    }

    var widthFraction: CGFloat = 0.7 {
        didSet {
            guard widthFraction != oldValue else { return }
            needsLayout = true
        }
    }

    var skeletonAppearance: SkeletonAppearance = .init() {
        didSet {
            placeholderView.applyAppearance(skeletonAppearance)
            applyCornerRadius()
            needsLayout = true
        }
    }

    private let placeholderView = SkeletonPlaceholderView()

    override func setup() {
        super.setup()
        addSubview(placeholderView)
        placeholderView.applyAppearance(skeletonAppearance)
        applyCornerRadius()
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        stopAnimating()
    }

    override func layout() {
        super.layout()
        switch style {
        case .icon:
            let iconSize = skeletonAppearance.iconSizeMode.size(forCellHeight: bounds.height)
            placeholderView.frame = .init(
                x: (bounds.width - iconSize) / 2,
                y: (bounds.height - iconSize) / 2 + skeletonAppearance.iconVerticalOffset,
                width: iconSize,
                height: iconSize,
            )
        case .text:
            let barHeight = skeletonAppearance.textBarHeight
            let leadingInset = skeletonAppearance.textBarLeadingInset
            let trailingInset = skeletonAppearance.textBarTrailingInset
            let usableWidth = max(0, bounds.width - leadingInset - trailingInset)
            let barWidth = min(usableWidth, max(12, usableWidth * widthFraction))
            let barX: CGFloat = switch textAlignment {
            case .center:
                leadingInset + (usableWidth - barWidth) / 2
            case .right:
                bounds.width - trailingInset - barWidth
            default:
                leadingInset
            }
            placeholderView.frame = .init(
                x: barX,
                y: (bounds.height - barHeight) / 2 + skeletonAppearance.textBarVerticalOffset,
                width: barWidth,
                height: barHeight,
            )
        }
    }

    func startAnimating(phaseOffset: CFTimeInterval = 0) {
        placeholderView.startAnimating(offset: phaseOffset)
    }

    func stopAnimating() {
        placeholderView.stopAnimating()
    }

    private func applyCornerRadius() {
        placeholderView.cornerRadius = style == .icon
            ? skeletonAppearance.iconCornerRadius
            : skeletonAppearance.textCornerRadius
    }
}

// MARK: - SkeletonPlaceholderView

/// A single rounded rectangle with a moving gradient highlight ("shimmer").
///
/// Uses the layer-backing `updateLayer` pattern: layer-only properties without
/// guard flags (cornerRadius, masksToBounds, backgroundColor in the absence of
/// `setBackgroundColor:`) would otherwise be overwritten by NSView's
/// ivar→layer sync. Setters mark `needsDisplay`; `updateLayer` is the single
/// place that pushes properties to the layer, inside the correct appearance
/// context.
@available(macOS 11.0, *)
final class SkeletonPlaceholderView: NSView {
    var cornerRadius: CGFloat = 4 {
        didSet {
            guard cornerRadius != oldValue else { return }
            needsDisplay = true
        }
    }

    private let gradientLayer = CAGradientLayer()
    private var baseColor: NSColor = .tertiaryLabelColor.withAlphaComponent(0.32)
    private var highlightColor: NSColor = .labelColor.withAlphaComponent(0.14)
    private var shimmerDuration: TimeInterval = 1.4

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layerContentsRedrawPolicy = .onSetNeedsDisplay
        // clipsToBounds drives layer.masksToBounds via NSView's ivar pipeline,
        // so it survives `_updateLayerMasksToBoundsFromView` resyncs.
        clipsToBounds = true

        gradientLayer.locations = [0, 0.5, 1]
        gradientLayer.startPoint = .init(x: 0, y: 0.5)
        gradientLayer.endPoint = .init(x: 1, y: 0.5)
        // Suppress implicit animations on the gradient so frame changes during
        // layout don't trigger Core Animation cross-fades on top of the shimmer.
        gradientLayer.actions = [
            "position": NSNull(),
            "bounds": NSNull(),
            "frame": NSNull(),
            "locations": NSNull(),
            "contents": NSNull(),
        ]
        layer?.addSublayer(gradientLayer)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var isFlipped: Bool { true }
    override var wantsUpdateLayer: Bool { true }

    override func layout() {
        super.layout()
        gradientLayer.frame = bounds
    }

    override func updateLayer() {
        // Single window where AppKit's ivar→layer sync has already run, so
        // re-applying these stays sticky until the next display cycle.
        layer?.cornerRadius = cornerRadius
        effectiveAppearance.performAsCurrentDrawingAppearance {
            layer?.backgroundColor = baseColor.cgColor
            gradientLayer.colors = [
                NSColor.clear.cgColor,
                highlightColor.cgColor,
                NSColor.clear.cgColor,
            ]
        }
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        needsDisplay = true
    }

    func applyAppearance(_ appearance: SkeletonAppearance) {
        baseColor = appearance.baseColor
        highlightColor = appearance.highlightColor
        shimmerDuration = appearance.shimmerDuration
        needsDisplay = true

        // If a shimmer is currently running, restart it so the new duration
        // takes effect immediately rather than after the next stop/start cycle.
        if gradientLayer.animation(forKey: "shimmer") != nil {
            startAnimating()
        }
    }

    func startAnimating(offset: CFTimeInterval = 0) {
        let animation = CABasicAnimation(keyPath: "locations")
        animation.fromValue = [-1.0, -0.5, 0.0]
        animation.toValue = [1.0, 1.5, 2.0]
        animation.duration = shimmerDuration
        animation.repeatCount = .infinity
        // Negative offset advances the animation so each placeholder enters
        // at a different phase, producing a continuous wave effect.
        animation.beginTime = CACurrentMediaTime() + offset
        gradientLayer.add(animation, forKey: "shimmer")
    }

    func stopAnimating() {
        gradientLayer.removeAnimation(forKey: "shimmer")
    }
}

#endif
