#if canImport(AppKit)

import AppKit

open class XibWindowController: NSWindowController {
    public convenience init() {
        self.init(windowNibName: String(describing: Self.self))
    }
}

#endif
