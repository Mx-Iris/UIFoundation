#if canImport(AppKit) && !targetEnvironment(macCatalyst)

import AppKit
import FrameworkToolbox

extension NSButton {
    public convenience init(
        title: String = "",
        titleColor: NSColor = .labelColor,
        titleFont: NSFont = .systemFont(ofSize: 14),
        alternateTitle: String = "",
        alternateTitleColor: NSColor = .labelColor,
        alternateTitleFont: NSFont = .systemFont(ofSize: 14),
        image: NSImage? = nil,
        alternateImage: NSImage? = nil,
        buttonType: NSButton.ButtonType = .momentaryLight,
        bezelStyle: NSButton.BezelStyle = .rounded
    ) {
        self.init(frame: .zero)
        self.attributedTitle = NSAttributedString(string: title, attributes: [.font: titleFont, .foregroundColor: titleColor])
        self.attributedAlternateTitle = NSAttributedString(string: alternateTitle, attributes: [.font: alternateTitleFont, .foregroundColor: alternateTitleColor])
        self.image = image
        self.alternateImage = alternateImage
        setButtonType(buttonType)
        self.bezelStyle = bezelStyle
    }
}

extension FrameworkToolbox where Base == Bool {
    public var controlState: NSControl.StateValue {
        base ? .on : .off
    }
}

extension NSControl.StateValue: @retroactive ExpressibleByBooleanLiteral {
    public init(booleanLiteral value: BooleanLiteralType) {
        self = value ? .on : .off
    }
}

#endif
