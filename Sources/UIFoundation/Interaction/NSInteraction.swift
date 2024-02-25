#if canImport(AppKit) && !targetEnvironment(macCatalyst)

import AppKit

public protocol NSInteraction: AnyObject {
    var view: NSView? { get }
    
    func willMove(to view: NSView?)

    func didMove(to view: NSView?)
}

#endif
