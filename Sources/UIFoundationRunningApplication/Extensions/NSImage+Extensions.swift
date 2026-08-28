#if RunningApplication && os(macOS)

import AppKit

@available(macOS 11.0, *)
extension NSImage {
    static let checkmarkImage = NSImage(systemSymbolName: "checkmark.circle", accessibilityDescription: nil)
    static let xmarkImage = NSImage(systemSymbolName: "xmark.circle", accessibilityDescription: nil)
}

#endif
