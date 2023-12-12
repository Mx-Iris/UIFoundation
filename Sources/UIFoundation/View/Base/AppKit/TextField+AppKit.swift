#if canImport(AppKit) && !targetEnvironment(macCatalyst)

import AppKit

open class TextField: NSTextField {
    public override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
    }

    @available(*, unavailable)
    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public convenience init(bezelStyle: BezelStyle) {
        self.init(frame: .zero)
        self.bezelStyle = bezelStyle
    }
}

#endif
