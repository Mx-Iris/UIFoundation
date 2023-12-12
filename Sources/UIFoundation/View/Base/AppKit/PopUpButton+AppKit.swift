#if canImport(AppKit) && !targetEnvironment(macCatalyst)

import AppKit

open class PopUpButton: NSPopUpButton {
    public override init(frame buttonFrame: NSRect, pullsDown flag: Bool) {
        super.init(frame: buttonFrame, pullsDown: flag)
    }

    public override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
}


#endif
