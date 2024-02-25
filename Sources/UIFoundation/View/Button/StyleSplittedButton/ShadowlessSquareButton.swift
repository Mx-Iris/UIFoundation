#if canImport(AppKit) && !targetEnvironment(macCatalyst)

import AppKit

public typealias SquareButton = ShadowlessSquareButton

public typealias ImageButton = ShadowlessSquareButton

open class ShadowlessSquareButton: Button {
    @available(*, unavailable)
    open override func setButtonType(_ type: NSButton.ButtonType) {
        super.setButtonType(type)
    }

    @available(*, unavailable)
    open override var bezelStyle: NSButton.BezelStyle {
        set {
            super.bezelStyle = newValue
        }
        get {
            super.bezelStyle
        }
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
        super.bezelStyle = .shadowlessSquare
        super.setButtonType(.momentaryPushIn)
    }
}
#endif
