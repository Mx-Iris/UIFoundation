#if canImport(AppKit) && !targetEnvironment(macCatalyst)

import AppKit

open class PushButton: Button {
    public enum AvailableButtonType: UInt, @unchecked Sendable {
        case toggle = 2
        case momentaryPushIn = 7
    }

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

    open var availableButtonType: AvailableButtonType = .momentaryPushIn {
        didSet {
            super.setButtonType(.init(rawValue: availableButtonType.rawValue)!)
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
        super.bezelStyle = .push
        super.setButtonType(.momentaryPushIn)
    }
}
#endif
