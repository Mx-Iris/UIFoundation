#if canImport(AppKit) && !targetEnvironment(macCatalyst)

import AppKit

open class XiblessWindowController<Window: NSWindow>: NSWindowController {
    public lazy var contentWindow: Window = windowGenerator() {
        didSet {
            window = contentWindow
        }
    }

    private let windowGenerator: () -> Window

    public init(windowGenerator: @autoclosure @escaping () -> Window = Window(contentRect: .zero, styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView], backing: .buffered, defer: false)) {
        self.windowGenerator = windowGenerator
        super.init(window: nil)
    }

    @available(*, unavailable)
    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    open override var windowNibName: NSNib.Name? { "" }

    open override func loadWindow() {
        window = contentWindow
    }
}

#endif
