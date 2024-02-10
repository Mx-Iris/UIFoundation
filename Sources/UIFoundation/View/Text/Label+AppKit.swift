#if canImport(AppKit) && !targetEnvironment(macCatalyst)
import AppKit
import UIFoundationToolbox

open class Label: NSTextField {
    @Invalidating(.display, .layout)
    open var contentInsets: NSEdgeInsets = .zero {
        didSet {
            guard let cell = cell as? LabelCell else { return }
            cell.contentInsets = contentInsets
        }
    }

    public convenience init(_ stringValue: String) {
        self.init(frame: .zero)
        self.stringValue = stringValue
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
        isEditable = false
        drawsBackground = false
        isBordered = false
        wantsLayer = true
        layerContentsRedrawPolicy = .onSetNeedsDisplay
        setup()
    }

    open func setup() {}

    open override var wantsUpdateLayer: Bool { true }
    
    open override class var cellClass: AnyClass? {
        set {}
        get { LabelCell.self }
    }

    open override var intrinsicContentSize: NSSize {
        var intrinsicContentSize = super.intrinsicContentSize
        intrinsicContentSize.width += contentInsets.left + contentInsets.right
        intrinsicContentSize.height += contentInsets.top + contentInsets.bottom
        return intrinsicContentSize
    }
}

#endif
