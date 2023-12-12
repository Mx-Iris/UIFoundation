#if canImport(AppKit) && !targetEnvironment(macCatalyst)

import AppKit

open class ScrollView: NSScrollView {
    public override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    open override var drawsBackground: Bool {
        set {}
        get { false }
    }

    open override func didAddSubview(_ subview: NSView) {
        super.didAddSubview(subview)

        if subview is NSVisualEffectView {
            subview.isHidden = true
        }
    }
}

#endif
