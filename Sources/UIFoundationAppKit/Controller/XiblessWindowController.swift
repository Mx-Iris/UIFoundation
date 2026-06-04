#if canImport(AppKit) && !targetEnvironment(macCatalyst)

import AppKit

open class XiblessWindowController<Window: NSWindow>: NSWindowController {
    public lazy var contentWindow: Window = windowGenerator() {
        didSet {
            // Mirror `XiblessViewController`: only react after the window is loaded.
            // While unloaded, `loadWindow()` will pick up the new value through the
            // lazy var when it eventually runs.
            guard isWindowLoaded else { return }
            contentWindowDidChange(oldValue)
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

    /// Called from `contentWindow`'s `didSet` only after the window is loaded.
    /// Subclasses override this to rewire setup tied to the new window; the
    /// default swaps the controller's `window` reference.
    open func contentWindowDidChange(_ oldContentWindow: Window) {
        window = contentWindow
    }
}

#endif
