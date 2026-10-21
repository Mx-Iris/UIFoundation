#if os(macOS)

import AppKit
import Carbon.HIToolbox

/// The keys tests press by sending a key-down into a window with `NSWindow.sendEvent(_:)`, which
/// lets the first responder interpret it the way a real keystroke would.
enum KeyboardKey {
    case escape
    case tab

    var characters: String {
        switch self {
        case .escape: "\u{1B}"
        case .tab: "\t"
        }
    }

    var keyCode: UInt16 {
        switch self {
        case .escape: UInt16(kVK_Escape)
        case .tab: UInt16(kVK_Tab)
        }
    }
}

extension NSEvent {
    /// A key-down for `key`, without modifiers, addressed to `window`.
    static func keyDown(_ key: KeyboardKey, in window: NSWindow) -> NSEvent {
        NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: [],
            timestamp: ProcessInfo.processInfo.systemUptime,
            windowNumber: window.windowNumber,
            context: nil,
            characters: key.characters,
            charactersIgnoringModifiers: key.characters,
            isARepeat: false,
            keyCode: key.keyCode
        )!
    }
}

#endif
