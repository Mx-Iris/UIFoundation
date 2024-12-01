#if canImport(AppKit) && !targetEnvironment(macCatalyst)

import AppKit

open class XibWindowController: NSWindowController {
    open override var windowNibName: NSNib.Name? { String(describing: Self.self) }

    public init() {
        super.init(window: nil)
    }

    @available(*, unavailable)
    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

#endif
