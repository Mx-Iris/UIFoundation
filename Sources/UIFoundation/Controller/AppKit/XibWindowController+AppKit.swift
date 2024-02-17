#if canImport(AppKit) && !targetEnvironment(macCatalyst)

import AppKit

open class XibWindowController: NSWindowController {
    public convenience init() {
        self.init(windowNibName: String(describing: Self.self))
    }
}

#endif
