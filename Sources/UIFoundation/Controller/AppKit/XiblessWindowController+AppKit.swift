#if canImport(AppKit)

import AppKit


open class XiblessWindowController<Window: NSWindow>: NSWindowController {
    public private(set) var contentWindow: Window?

    public convenience init(windowGenerator: @autoclosure () -> Window) {
        self.init(windowNibName: "")
        contentWindow = windowGenerator()
    }
    
    open override func loadWindow() {
        window = contentWindow
    }
}

open class PlainXiblessWindowController: XiblessWindowController<NSWindow> {
    public convenience init() {
        self.init(windowGenerator: NSWindow(contentRect: .zero, styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView], backing: .buffered, defer: false))
    }
}


#endif
