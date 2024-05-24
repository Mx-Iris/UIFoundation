#if canImport(AppKit) && !targetEnvironment(macCatalyst)

import AppKit

open class XiblessWindowController<Window: NSWindow>: NSWindowController {
    public private(set) lazy var contentWindow: Window = windowGenerator()

    private let windowGenerator: () -> Window
    
    public init(windowGenerator: @autoclosure @escaping () -> Window) {
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

open class PlainXiblessWindowController: XiblessWindowController<NSWindow> {
    public init() {
        super.init(windowGenerator: NSWindow(contentRect: .zero, styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView], backing: .buffered, defer: false))
    }
}

#endif
