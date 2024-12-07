#if canImport(AppKit) && !targetEnvironment(macCatalyst)
/*
 Author: https://github.com/nhojb/SegmentedControl
 */


import AppKit
import QuartzCore
import FrameworkToolbox
@_implementationOnly import UIFoundationToolbox

/**
 * SegmentedControl: an AppKit segmented control based on UISegmentedControl.
 */
public class ModernSegmentedControl: Control {

    private enum Metrics {
        static let standardHeight: CGFloat = 24
        static let cornerRadius: CGFloat = 6
        static let edgeInset: CGFloat = 1
        static let imageInset: CGFloat = 3
        static let segmentPadding: CGFloat = 5
        static let separatorWidth: CGFloat = 1
    }

    /**
     * Number of segments in the control.
     */
    public var count: Int {
        return segments.count
    }

    /**
     * Get or set the selected segment index.
     * Updates to selectedSegmentIndex are always animated, unless explicitly disabled.
     * Returns nil if no segment is selected.
     *
     * See also setSelectedSegmentIndex()
     */
    public var selectedSegmentIndex: Int? {
        get {
            segments.firstIndex { $0.isSelected }
        }
        set {
            guard newValue != selectedSegmentIndex else {
                return
            }

            CATransaction.box.performWithAnimation(duration: 0.3, timing: .easeOut) {
                for idx in 0..<segments.count {
                    segments[idx].isSelected = (idx == newValue)
                }
                updateSeparators()
                layoutSelectionHighlight()
            }
        }
    }

    /**
     * Custom tint color for the selected segment background.
     */
    @IBInspectable
    public var controlTintColor: NSColor? {
        didSet {
            if controlTintColor != oldValue {
                updateSegments()
                updateSelectionHighlightColor()
            }
        }
    }

    /**
     * If isMomentary is true then segments do not display selected state.
     * Often used for toolbar items.
     */
    @IBInspectable
    public var isMomentary: Bool = false {
        didSet {
            if isMomentary != oldValue {
                updateSegments()
                updateSeparators()
                layoutSelectionHighlight()
            }
        }
    }

    /**
     * Indicates whether the control adjusts segment widths based on their content widths.
     */
    @IBInspectable
    public var apportionsSegmentWidthsByContent: Bool = false {
        didSet {
            needsLayout = true
        }
    }

    /**
     * segmentContainer contains our SegmentLayer layers.
     * This layer sits above the control's layer, which contains the selectionHighlight.
     */
    private var segmentContainer = CALayer()

    /**
     * separatorContainer contains our SegmentSeparator layers.
     */
    private var separatorContainer = CALayer()

    private var segments: [SegmentLayer] {
        return segmentContainer.sublayers as? [SegmentLayer] ?? []
    }

    private var separators: [SegmentSeparator] {
        return separatorContainer.sublayers as? [SegmentSeparator] ?? []
    }

    /**
     * selectionHighlight displays a button like background for the selected segment.
     */
    private var selectionHighlight: CALayer = {
        let layer = CALayer()
        layer.cornerRadius = Metrics.cornerRadius - 1
        layer.shadowOpacity = 0.1
        layer.shadowRadius = 3
        layer.shadowOffset = CGSize(width: 0, height: -3)
        return layer
    }()

    private var mouseDownSegmentIndex: Int?

    private var isDraggingSelectedSegment = false {
        didSet {
            layoutSelectionHighlight()
            for segment in segments {
                segment.isInset = isDraggingSelectedSegment
            }
        }
    }

    public override var isEnabled: Bool {
        didSet {
            layer?.opacity = isEnabled ? 1 : 0.5
        }
    }

    public override var intrinsicContentSize: NSSize {
        guard count > 0 else {
            return super.intrinsicContentSize
        }

        var size = CGSize(width: Metrics.edgeInset * 2 + Metrics.segmentPadding * CGFloat(count - 1),
                          height: Metrics.standardHeight)

        for segment in segments {
            if segment.fixedWidth > 0 {
                size.width += segment.fixedWidth
            } else {
                // intrinsicContentSize should accommodate all our segments:
                size.width += segment.preferredFrameSize().width
            }
        }

        return size
    }

    public override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    public convenience init(labels: [String], controlTintColor: NSColor, isMomentary: Bool) {
        self.init(frame: .zero)
        labels.enumerated().forEach { index, label in
            self.insertSegment(title: label, at: index)
        }
        self.controlTintColor = controlTintColor
        self.isMomentary = isMomentary
    }
    
    private func commonInit() {
        wantsLayer = true
        isEnabled = true

        layer?.cornerRadius = Metrics.cornerRadius
        layer?.borderColor = nil

        layer?.addSublayer(selectionHighlight)
        layer?.addSublayer(segmentContainer)
        layer?.addSublayer(separatorContainer)
    }

    /**
     * Set the selected segment, with or without animation.
     */
    public func setSelectedSegmentIndex(_ idx: Int, animated: Bool) {
        guard idx != selectedSegmentIndex else {
            return
        }

        if !animated {
            CATransaction.box.performWithoutAnimation {
                selectedSegmentIndex = idx
            }
        } else {
            selectedSegmentIndex = idx
        }
    }

    /**
     * Insert a new segment with title at the specified index.
     */
    public func insertSegment(title: String, at idx: Int) {
        insertSegment(at: idx).title = title
    }

    /**
     * Insert a new segment with image at the specified index.
     */
    public func insertSegment(image: NSImage, at idx: Int) {
        insertSegment(at: idx).image = image
    }

    private func insertSegment(at idx: Int) -> SegmentLayer {
        let segment = SegmentLayer()
        segment.isSelected = (count == 0)
        segmentContainer.insertSublayer(segment, at: UInt32(idx))

        let separator = SegmentSeparator()
        separatorContainer.insertSublayer(separator, at: UInt32(idx))

        updateSegments()
        updateSeparators()

        return segment
    }

    /**
     * Remove the segment at the specified index.
     */
    public func removeSegment(at idx: Int) {
        segmentContainer.sublayers?[idx].removeFromSuperlayer()
        separatorContainer.sublayers?[idx].removeFromSuperlayer()
        updateSeparators()
    }

    /**
     * Remove all segments.
     */
    public func removeAllSegments() {
        segmentContainer.sublayers?.forEach { $0.removeFromSuperlayer() }
        separatorContainer.sublayers?.forEach { $0.removeFromSuperlayer() }
        selectionHighlight.isHidden = true
    }

    /**
     * Sets the title of the specified segment.
     * Note that if an image is set on the segment, the title will not be displayed.
     */
    public func setTitle(_ title: String?, forSegment idx: Int) {
        segments[idx].title = title
    }

    /**
     * Returns the title for the specified segment.
     */
    public func titleForSegment(_ idx: Int) -> String? {
        return segments[idx].title
    }

    /**
     * Sets the image of the specified segment.
     * Note that if an image is set on the segment, the title will not be displayed.
     */
    public func setImage(_ image: NSImage?, forSegment idx: Int) {
        segments[idx].image = image
    }

    /**
     * Returns the image for the specified segment.
     */
    public func imageForSegment(_ idx: Int) -> NSImage? {
        return segments[idx].image
    }

    /**
     * Set an explicit width for the specified segment.
     * If width is > 0 then the segment width will be fixed to that width.
     * Otherwise the segment width will auto-adjust.
     */
    public func setWidth(_ width: CGFloat, forSegment idx: Int) {
        segments[idx].fixedWidth = width
    }

    /**
     * Returns the width for the specified segment.
     */
    public func widthForSegment(_ idx: Int) -> CGFloat {
        return segments[idx].fixedWidth
    }

    public override func viewDidChangeBackingProperties() {
        super.viewDidChangeBackingProperties()

        guard let contentsScale = layer?.contentsScale else {
            return
        }

        selectionHighlight.contentsScale = contentsScale

        segmentContainer.sublayers?.forEach {
            $0.contentsScale = contentsScale
        }
    }

    public override func mouseDown(with event: NSEvent) {
        guard isEnabled else {
            return
        }

        let location = convert(event.locationInWindow, from: nil)

        guard let idx = segmentIndex(at: location) else {
            return
        }

        mouseDownSegmentIndex = idx

        if idx == selectedSegmentIndex, !isMomentary {
            isDraggingSelectedSegment = true
        } else {
            highlightSegment(at: idx)
        }
    }

    public override func mouseDragged(with event: NSEvent) {
        guard isEnabled else {
            return
        }

        let location = convert(event.locationInWindow, from: nil)

        guard let idx = segmentIndex(at: location) else {
            highlightSegment(at: nil)
            return
        }

        if isDraggingSelectedSegment {
            if idx != selectedSegmentIndex {
                selectedSegmentIndex = idx
                sendAction(action, to: target)
            }
        } else if isMomentary || idx != selectedSegmentIndex {
            highlightSegment(at: idx)
        } else {
            highlightSegment(at: nil)
        }
    }

    public override func mouseUp(with event: NSEvent) {
        guard isEnabled else {
            return
        }

        highlightSegment(at: nil)

        if !isDraggingSelectedSegment {
            let location = convert(event.locationInWindow, from: nil)
            if let idx = segmentIndex(at: location) {
                if isMomentary {
                    // Only send action if mouse-up in the same segment
                    if idx == mouseDownSegmentIndex {
                        selectedSegmentIndex = idx
                        sendAction(action, to: target)
                    }
                } else if idx != selectedSegmentIndex {
                    selectedSegmentIndex = idx
                    sendAction(action, to: target)
                }
            }
        }

        isDraggingSelectedSegment = false
        mouseDownSegmentIndex = nil
    }

    /**
     * Note: Cocoa will set the correct (current) NSAppearance when calling updateLayer()
     * This means we can obtain the correct NSColors etc.
     */
    public override func updateLayer() {
        super.updateLayer()

        // quaternaryLabelColor is a good match for aqua and dark appearance modes.
        // controlBackgroundColor works for dark, but not for aqua (where it is white).
        layer?.backgroundColor = NSColor.quaternaryLabelColor.cgColor

        updateSelectionHighlightColor()

        segments.forEach { $0.updateAppearance() }
        separators.forEach { $0.updateAppearance() }
    }

    public override func layout() {
        super.layout()

        separatorContainer.frame = bounds
        segmentContainer.frame = bounds

        layoutSegments()
        layoutSelectionHighlight()
    }

    private func layoutSegments() {
        let count = self.count

        guard count > 0 else {
            return
        }

        // If any segments have fixed widths, then reduce "flexible" width by that amount:
        var fixedCount: Int = 0
        var fixedWidth: CGFloat = 0
        var contentWidth: CGFloat = 0

        let segments = self.segments

        for segment in segments {
            if segment.fixedWidth > 0 {
                fixedWidth += segment.fixedWidth
                fixedCount += 1
            } else {
                contentWidth += segment.preferredFrameSize().width
            }
        }

        var contentBounds = bounds.insetBy(dx: Metrics.edgeInset, dy: Metrics.edgeInset)
        contentBounds.size.width -= Metrics.segmentPadding * CGFloat(count - 1)
        var segmentWidth: CGFloat = 0
        var unusedWidth: CGFloat = 0

        if fixedCount < count {
            let nonFixedCount = count - fixedCount
            if apportionsSegmentWidthsByContent {
                // Increase section width if segments do not take up remaining flexibleWidth.
                // This may be negative if available width will not accommodate all content.
                unusedWidth = contentBounds.size.width - contentWidth - fixedWidth
            } else {
                let flexibleWidth = contentBounds.size.width - fixedWidth
                segmentWidth = max(0, flexibleWidth / CGFloat(nonFixedCount))
            }
        }

        var frame = contentBounds;
        let separators = self.separators

        for (idx, segment) in segments.enumerated() {
            if segment.fixedWidth > 0 {
                frame.size.width = segment.fixedWidth
            } else if apportionsSegmentWidthsByContent {
                // Any unused width is added proportionally
                let width = segment.preferredFrameSize().width
                frame.size.width = width + unusedWidth * width / contentWidth
            } else {
                frame.size.width = segmentWidth
            }
            segment.frame = frame.rounded
            separators[idx].frame = separatorFrame(for: frame).rounded

            frame.origin.x = frame.maxX + Metrics.segmentPadding
        }
    }

    private func layoutSelectionHighlight() {
        if let idx = selectedSegmentIndex, !isMomentary {
            selectionHighlight.isHidden = false
            let frame = segments[idx].frame
            if isDraggingSelectedSegment {
                selectionHighlight.frame = frame.insetBy(dx: Metrics.edgeInset, dy: Metrics.edgeInset)
            } else {
                selectionHighlight.frame = frame
            }
        } else {
            selectionHighlight.isHidden = true
        }
    }

    private func separatorFrame(for segmentFrame: CGRect) -> CGRect {
        var frame = segmentFrame
        frame.origin.x = frame.maxX
        frame.size.width = Metrics.segmentPadding
        return frame
    }

    private func updateSegments() {
        for segment in segments {
            segment.isMomentary = isMomentary
            segment.tintColor = controlTintColor
        }
    }

    private func updateSeparators() {
        let selectedIndex = selectedSegmentIndex ?? NSNotFound
        let count = self.count

        for (idx, separator) in separators.enumerated() {
            if isMomentary {
                separator.isHidden = (idx == count - 1)
            } else {
                separator.isHidden = (idx == count - 1 || idx == selectedIndex - 1 || idx == selectedIndex)
            }
        }
    }

    private func updateSelectionHighlightColor() {
        // Ensure CGColor is appearance aware:
        NSApp.box.withEffectiveAppearance {
            selectionHighlight.backgroundColor = (controlTintColor ?? NSColor.controlColor).cgColor
        }
    }

    private func segmentIndex(at point: CGPoint) -> Int? {
        for (idx, segment) in segments.enumerated() {
            let frame = segment.frame.insetBy(dx: -Metrics.edgeInset, dy: -Metrics.edgeInset)
            if frame.contains(point) {
                return idx
            }
        }
        return nil
    }

    private func highlightSegment(at highlightIdx: Int?) {
        for (idx, segment) in segments.enumerated() {
            segment.isHighlighted = (idx == highlightIdx)
        }
    }

}

extension ModernSegmentedControl {

    /**
     * SegmentLayer handles the segment appearance.
     * It supports display of a title or image.
     */
    private class SegmentLayer: CALayer {

        var title: String? {
            didSet {
                if title != oldValue {
                    needsAppearanceUpdate = true
                }
            }
        }

        var image: NSImage? {
            didSet {
                if image != oldValue {
                    needsAppearanceUpdate = true
                }
            }
        }

        var tintColor: NSColor? {
            didSet {
                if tintColor != oldValue {
                    needsAppearanceUpdate = true
                }
            }
        }

        /**
         * Segment is auto-sized if width is zero. Otherwise the width is fixed.
         */
        var fixedWidth: CGFloat = 0.0

        /**
         * Toggles the appearance of the title or image.
         */
        var isHighlighted = false {
            didSet {
                if isHighlighted != oldValue {
                    needsAppearanceUpdate = true
                }
            }
        }

        var isSelected = false {
            didSet {
                if isSelected != oldValue {
                    needsAppearanceUpdate = true
                }
            }
        }

        var isMomentary = false {
            didSet {
                if isMomentary != oldValue {
                    needsAppearanceUpdate = true
                }
            }
        }

        /**
         * If true then the segment is drawn slightly inset.
         * Used during dragging of the selected segment.
         */
        var isInset = false {
            didSet {
                if isInset != oldValue {
                    needsAppearanceUpdate = true
                }
            }
        }

        private let imageLayer: CALayer = {
            let layer = CALayer()
            layer.contentsGravity = .resizeAspect
            return layer
        }()

        /**
         * CATextLayer does not handle transitions between fonts very well.
         * So to avoid visual glitches when switching between our selected state,
         * we use two separate text layers, one for each state.
         * We can then easily fade between text layers.
         */
        private let textLayer: CATextLayer = {
            let layer = CATextLayer()
            layer.fontSize = NSFont.systemFontSize
            layer.font = NSFont.systemFont(ofSize: layer.fontSize) // regular
            layer.alignmentMode = .center
            layer.truncationMode = .end
            return layer
        }()

        private let selectedTextLayer: CATextLayer = {
            let layer = CATextLayer()
            layer.fontSize = NSFont.systemFontSize
            layer.font = NSFont.systemFont(ofSize: layer.fontSize, weight: .medium)
            layer.alignmentMode = .center
            layer.truncationMode = .end
            return layer
        }()

        private var needsAppearanceUpdate = false {
            didSet {
                if needsAppearanceUpdate {
                    setNeedsLayout()
                }
            }
        }

        override init() {
            super.init()
            commonInit()
        }

        override init(layer: Any) {
            super.init(layer: layer)
            commonInit()

            if let segment = layer as? SegmentLayer {
                // initialize our "persistent" properties with other layer's properties
                image = segment.image
                title = segment.title
                tintColor = segment.tintColor
                isSelected = segment.isSelected
                isMomentary = segment.isMomentary
            }
        }

        required init?(coder aDecoder: NSCoder) {
            super.init(coder: aDecoder)
            commonInit()
        }

        private func commonInit() {
            addSublayer(imageLayer)
            addSublayer(textLayer)
            addSublayer(selectedTextLayer)
            updateAppearance()
        }

        func updateAppearance() {
            needsAppearanceUpdate = false

            if let image = self.image {
                if image.isTemplate {
                    // Ensure that template images update with the effectiveAppearance
                    NSApp.box.withEffectiveAppearance {
                        imageLayer.contents = image.box.image(withTintColor: .textColor)
                    }
                } else {
                    imageLayer.contents = image
                }
                imageLayer.isHidden = false
                textLayer.isHidden = true
                selectedTextLayer.isHidden = true

                imageLayer.opacity = isHighlighted ? 0.3 : 1.0
            } else {
                imageLayer.contents = nil
                imageLayer.isHidden = true

                textLayer.isHidden = false
                textLayer.string = title
                selectedTextLayer.isHidden = false
                selectedTextLayer.string = title

                // Ensure CGColor is appearance aware:
                NSApp.box.withEffectiveAppearance {
                    updateTitleAppearance()
                }
            }
        }

        private func updateTitleAppearance() {
            if isSelected && !isMomentary {
                textLayer.opacity = 0
                selectedTextLayer.opacity = 1
                // FIXME: 添加可选是否显示对比颜色
//                selectedTextLayer.foregroundColor = (tintColor?.contrastingTextColor ?? .textColor).cgColor
                
                selectedTextLayer.foregroundColor = NSColor.textColor.cgColor

                // Adjusting the fontSize when the segment is "inset", gives a nice little "push" effect.
                var fontSize = NSFont.systemFontSize
                if isInset {
                    fontSize -= 0.5
                }
                selectedTextLayer.fontSize = fontSize
            } else {
                selectedTextLayer.opacity = 0
                textLayer.opacity = 1
                // systemGray works well in both aqua and dark appearance modes
                textLayer.foregroundColor = (isHighlighted ? NSColor.systemGray : NSColor.textColor).cgColor
            }
        }

        override func layoutSublayers() {
            super.layoutSublayers()

            if needsAppearanceUpdate {
                updateAppearance()
            }

            if !imageLayer.isHidden {
                layoutImageLayer()
            } else {
                layoutTextLayer(textLayer)
                layoutTextLayer(selectedTextLayer)
            }
        }

        private func layoutImageLayer() {
            imageLayer.frame = bounds.insetBy(dx: 0, dy: Metrics.imageInset)
        }

        private func layoutTextLayer(_ textLayer: CATextLayer) {
            guard let font = textLayer.font,
                  let string = textLayer.string as? NSString,
                  string.length > 0 else {
                return
            }

            let textSize = string.size(withAttributes: [.font: font])

            var frame = bounds
            frame.size.height = textSize.height

            frame.origin.y = (bounds.height - textSize.height) / 2
            if !isInset || textLayer == self.textLayer {
                frame.origin.y += 1.0
            } else {
                frame.origin.y += 0.5
            }
            // Avoid text truncation from changing when toggling between medium and regular fonts
            if textLayer == self.textLayer {
                frame = frame.insetBy(dx: 1, dy: 0)
            }
            textLayer.frame = frame
        }

        override var contentsScale: CGFloat {
            didSet {
                imageLayer.contentsScale = contentsScale
                textLayer.contentsScale = contentsScale
                selectedTextLayer.contentsScale = contentsScale
            }
        }

        override func preferredFrameSize() -> CGSize {
            var size = CGSize(width: 0, height: superlayer?.bounds.size.height ?? Metrics.standardHeight)
            if (fixedWidth > 0) {
                size.width = fixedWidth
            } else if image != nil {
                size.width = size.height * 2
            } else if let title = self.title,
                      let font = textLayer.font {
                size.width = title.size(withAttributes: [.font: font]).width + Metrics.segmentPadding * 2
            }
            return size
        }

    }

}

extension ModernSegmentedControl {

    /**
     * SegmentSeparator handles the separator appearance.
     */
    private class SegmentSeparator: CALayer {

        override init() {
            super.init()
            commonInit()
        }

        override init(layer: Any) {
            super.init(layer: layer)
            commonInit()
        }

        required init?(coder aDecoder: NSCoder) {
            super.init(coder: aDecoder)
            commonInit()
        }

        private func commonInit() {
            // The separator bar is drawn using a separate sub-layer, centered in SegmentSeparator
            let separator = CALayer()
            addSublayer(separator)
            updateAppearance()
        }

        func updateAppearance() {
            // Ensure CGColor is appearance aware:
            NSApp.box.withEffectiveAppearance {
                sublayers?.first?.backgroundColor = NSColor.separatorColor.cgColor
            }
        }

        override func layoutSublayers() {
            super.layoutSublayers()

            // Vertical line with `Metrics.separatorWidth` (default 1px)
            var frame = bounds.insetBy(dx: 0, dy: floor(bounds.height * 0.2))
            frame.size.width = Metrics.separatorWidth
            frame.origin.x = (bounds.width - frame.size.width) / 2.0
            sublayers?.first?.frame = frame.rounded
        }

    }

}

extension CGRect {

    var rounded: CGRect {
        CGRect(x: floor(origin.x),
               y: floor(origin.y),
               width: ceil(size.width),
               height: ceil(size.height))
    }

}

#endif
