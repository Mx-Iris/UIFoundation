#if canImport(AppKit) && !targetEnvironment(macCatalyst)

import AppKit

open class ScrollView: NSScrollView {
    public override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        commonInit()
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    private func commonInit() {
        wantsLayer = true
        layerContentsRedrawPolicy = .onSetNeedsDisplay
        setup()
    }

    open func setup() {}

    open override var drawsBackground: Bool {
        set {}
        get { false }
    }

    open override var wantsUpdateLayer: Bool { true }

    open override func didAddSubview(_ subview: NSView) {
        super.didAddSubview(subview)

        if subview is NSVisualEffectView {
            subview.isHidden = true
        }
    }
}

#endif
