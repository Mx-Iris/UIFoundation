#if canImport(AppKit) && !targetEnvironment(macCatalyst)

import AppKit

open class View: NSView {
    public override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        commonInit()
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    open override func layout() {
        super.layout()
        _ = _firstLayout
    }

    open override var acceptsFirstResponder: Bool { true }

    open func setup() {}

    open func firstLayout() {}

    private lazy var _firstLayout: Void = {
        firstLayout()
    }()

    private func commonInit() {
        wantsLayer = true
        setup()
    }
    
    open override var wantsUpdateLayer: Bool { true }
}

#endif
