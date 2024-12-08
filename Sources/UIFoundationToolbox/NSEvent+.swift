#if canImport(AppKit) && !targetEnvironment(macCatalyst)

import AppKit
import FrameworkToolbox

extension FrameworkToolbox where Base: NSEvent {
    /// The location of the event inside the specified view.
    /// - Parameter view: The view for the location.
    /// - Returns: The location of the event.
    public func location(in view: NSView) -> CGPoint {
        view.convert(base.locationInWindow, from: nil)
    }

    /// The last event that the app retrieved from the event queue.
    public static var current: NSEvent? {
        NSApplication.shared.currentEvent
    }

    /// Creates and returns a new key down event.
    ///
    /// - Parameters:
    ///   - keyCode: The virtual code for the key.
    ///   - modifierFlags: The pressed modifier keys.
    ///   - location: The location of the event.
    public static func keyDown(keyCode: UInt16, modifierFlags: NSEvent.ModifierFlags = [], location: CGPoint = .zero) -> NSEvent? {
        keyEvent(keyCode: keyCode, modifierFlags: modifierFlags, location: location, keyDown: true)
    }

    /// Creates and returns a new key up event.
    ///
    /// - Parameters:
    ///   - keyCode: The virtual code for the key.
    ///   - modifierFlags: The pressed modifier keys.
    ///   - location: The location of the event.
    public static func keyUp(keyCode: UInt16, modifierFlags: NSEvent.ModifierFlags = [], location: CGPoint = .zero) -> NSEvent? {
        keyEvent(keyCode: keyCode, modifierFlags: modifierFlags, location: location, keyDown: false)
    }

    private static func keyEvent(keyCode: UInt16, modifierFlags: NSEvent.ModifierFlags = [], location: CGPoint = .zero, keyDown: Bool) -> NSEvent? {
        guard let cgEvent = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: keyDown) else { return nil }
        cgEvent.flags = modifierFlags.box.cgEventFlags
        cgEvent.location = location
        return NSEvent(cgEvent: cgEvent)
    }

    /// Creates and returns a new mouse event.
    ///
    /// - Parameters:
    ///   - type: The mouse event type.
    ///   - location: The cursor location in the base coordinate system of the window specified by windowNum.
    ///   - modifierFlags: The position of the mouse cursor in global coordinates.
    ///   - clickCount: The number of mouse clicks associated with the mouse event.
    ///   - pressure: A value from `0.0` to `1.0` indicating the pressure applied to the input device on a mouse event, used for an appropriate device such as a graphics tablet. For devices that aren’t pressure-sensitive, the value should be either `0.0` or `1.0`.
    public static func mouse(_ type: NSEvent.EventType, location: CGPoint, modifierFlags: NSEvent.ModifierFlags = [], clickCount: Int = 1, pressure: Float = 1.0, window: NSWindow? = nil) -> NSEvent? {
        NSEvent.mouseEvent(with: type, location: location, modifierFlags: modifierFlags, timestamp: .nan, windowNumber: window?.windowNumber ?? 0, context: nil, eventNumber: Int.random(in: 0 ... Int.max), clickCount: clickCount, pressure: pressure)
    }

    /// A Boolean value that indicates whether no modifier key is pressed.
    public var isNoModifierPressed: Bool {
        base.modifierFlags.intersection(.deviceIndependentFlagsMask).isEmpty
    }

    /// A Boolean value that indicates whether the event type is a right mouse-down event.
    public var isRightMouseDown: Bool {
        base.type == .rightMouseDown || (base.modifierFlags.contains(.control) && base.type == .leftMouseDown)
    }

    /// A Boolean value that indicates whether the event is a right mouse-up event.
    public var isRightMouseUp: Bool {
        base.type == .rightMouseUp || (base.modifierFlags.contains(.control) && base.type == .leftMouseUp)
    }

    /// A Boolean value that indicates whether the event is a user interaction event.
    public var isUserInteraction: Bool {
        base.type == .box.userInteraction
    }

    /// A Boolean value that indicates whether the event is a keyboard event (`keyDown`, `keyUp` or `flagsChanged`).
    public var isKeyboard: Bool {
        base.type == .box.keyboard
    }

    /// A Boolean value that indicates whether the event is a mouse click event.
    public var isMouse: Bool {
        base.type == .box.mouse
    }

    /// A Boolean value that indicates whether the event is a left mouse click event.
    public var isLeftMouse: Bool {
        base.type == .box.leftMouse
    }

    /// A Boolean value that indicates whether the event is a right mouse click event.
    public var isRightMouse: Bool {
        base.type == .box.rightMouse
    }

    /// A Boolean value that indicates whether the event is an other mouse click event.
    public var isOtherMouse: Bool {
        base.type == .box.otherMouse
    }

    /// A Boolean value that indicates whether the event is a mouse movement event (`mouseEntered`, `mouseMoved` or `mouseExited`).
    public var isMouseMovement: Bool {
        base.type == .box.mouseMovements
    }

    /// A Boolean value that indicates whether the command key is pressed.
    public var isCommandPressed: Bool {
        base.modifierFlags.contains(.command)
    }

    /// A Boolean value that indicates whether the option key is pressed.
    public var isOptionPressed: Bool {
        base.modifierFlags.contains(.option)
    }

    /// A Boolean value that indicates whether the control key is pressed.
    public var isControlPressed: Bool {
        base.modifierFlags.contains(.control)
    }

    /// A Boolean value that indicates whether the shift key is pressed.
    public var isShiftPressed: Bool {
        base.modifierFlags.contains(.shift)
    }

    /// A Boolean value that indicates whether the capslock key is pressed.
    public var isCapsLockPressed: Bool {
        base.modifierFlags.contains(.capsLock)
    }
}

extension NSEvent.EventTypeMask: @retroactive FrameworkToolboxCompatible {}

extension FrameworkToolbox where Base == NSEvent.EventTypeMask {
    /// A Boolean value that indicates whether the specified event intersects with the event type mask.
    ///
    /// - Parameter event: The event for checking the intersection.
    /// - Returns: `true` if the event interesects with the mask, otherwise `false`.
    public func intersects(_ event: NSEvent?) -> Bool {
        guard let event = event else { return false }
        if event.type == Self.mouse {
            return event.associatedEventsMask.intersection(base).isEmpty == false
        }
        return intersects(event.type)
    }

    /// A Boolean value that indicates whether the specified event type intersects with the mask.
    ///
    /// - Parameter type: The event type.
    /// - Returns: `true` if the event type interesects with the mask, otherwise `false`.
    public func intersects(_ type: NSEvent.EventType) -> Bool {
        switch type {
        case .leftMouseDown: return base.contains(.leftMouseDown)
        case .leftMouseUp: return base.contains(.leftMouseUp)
        case .rightMouseDown: return base.contains(.rightMouseDown)
        case .rightMouseUp: return base.contains(.rightMouseUp)
        case .mouseMoved: return base.contains(.mouseMoved)
        case .leftMouseDragged: return base.contains(.leftMouseDragged)
        case .rightMouseDragged: return base.contains(.rightMouseDragged)
        case .mouseEntered: return base.contains(.mouseEntered)
        case .mouseExited: return base.contains(.mouseExited)
        case .keyDown: return base.contains(.keyDown)
        case .keyUp: return base.contains(.keyUp)
        case .flagsChanged: return base.contains(.flagsChanged)
        case .appKitDefined: return base.contains(.appKitDefined)
        case .systemDefined: return base.contains(.systemDefined)
        case .applicationDefined: return base.contains(.applicationDefined)
        case .periodic: return base.contains(.periodic)
        case .cursorUpdate: return base.contains(.cursorUpdate)
        case .scrollWheel: return base.contains(.scrollWheel)
        case .tabletPoint: return base.contains(.tabletPoint)
        case .tabletProximity: return base.contains(.tabletProximity)
        case .otherMouseDown: return base.contains(.otherMouseDown)
        case .otherMouseUp: return base.contains(.otherMouseUp)
        case .otherMouseDragged: return base.contains(.otherMouseDragged)
        case .gesture: return base.contains(.gesture)
        case .magnify: return base.contains(.magnify)
        case .swipe: return base.contains(.swipe)
        case .rotate: return base.contains(.rotate)
        case .beginGesture: return base.contains(.beginGesture)
        case .endGesture: return base.contains(.endGesture)
        case .smartMagnify: return base.contains(.smartMagnify)
        case .pressure: return base.contains(.pressure)
        case .directTouch: return base.contains(.directTouch)
        case .changeMode: return base.contains(.changeMode)
        //  case .quickLook: return contains(.quick)
        default: return false
        }
    }

    /// A mask all user interaction events.
    public static let userInteraction: NSEvent.EventTypeMask = keyboard + mouse + Base.mouseMoved + [.magnify, .scrollWheel, .swipe, .rotate]

    /// A mask for keyboard events.
    public static let keyboard: NSEvent.EventTypeMask = [.keyDown, .keyUp, .flagsChanged]

    /// A mask for mouse click events.
    public static let mouse: NSEvent.EventTypeMask = leftMouse + rightMouse + otherMouse

    /// A mask for left mouse click events.
    public static let leftMouse: NSEvent.EventTypeMask = [.leftMouseDown, .leftMouseUp, .leftMouseDragged]

    /// A mask for right mouse click events.
    public static let rightMouse: NSEvent.EventTypeMask = [.rightMouseDown, .rightMouseUp, .rightMouseDragged]

    /// A mask for other mouse click events.
    public static let otherMouse: NSEvent.EventTypeMask = [.otherMouseDown, .otherMouseUp, .otherMouseDragged]

    /// A mask for mouse movement events.
    public static let mouseMovements: NSEvent.EventTypeMask = [.mouseEntered, .mouseMoved, .mouseExited]
}

extension NSEvent.EventType {
    public static func == (lhs: Self, rhs: NSEvent.EventTypeMask) -> Bool {
        rhs.box.intersects(lhs)
    }
}

extension NSEvent.EventTypeMask {
    public static func + (lhs: Self, rhs: Self) -> Self {
        var lhs = lhs
        lhs.insert(rhs)
        return lhs
    }

    public static func += (lhs: inout Self, rhs: Self) {
        lhs.insert(rhs)
    }
}

extension NSEvent.ModifierFlags: @retroactive FrameworkToolboxCompatible {}

extension FrameworkToolbox where Base == NSEvent.ModifierFlags {
    /// A Boolean value that indicates whether no modifier key is pressed.
    public var hasNoKeyPressed: Bool {
        base.intersection(.deviceIndependentFlagsMask).isEmpty
    }

    /// A Boolean value that indicates whether the Command key is pressed.
    public var isCommandPressed: Bool {
        base.contains(.command)
    }

    /// A Boolean value that indicates whether the Function key is pressed.
    public var isOptionPressed: Bool {
        base.contains(.option)
    }

    /// A Boolean value that indicates whether the Control key is pressed.
    public var isControlPressed: Bool {
        base.contains(.control)
    }

    /// A Boolean value that indicates whether the Command key is pressed.
    public var isFunctionPressed: Bool {
        base.contains(.function)
    }

    /// A Boolean value that indicates whether the Shift key is pressed.
    public var isShiftPressed: Bool {
        base.contains(.shift)
    }

    /// A Boolean value that indicates whether the Caps Lock key is pressed.
    public var isCapsLockPressed: Bool {
        base.contains(.capsLock)
    }

    /// A Boolean value that indicates whether the Help key is pressed.
    public var isHelpPressed: Bool {
        base.contains(.help)
    }

    /// A Boolean value that indicates whether a numeric keypad or arrow key is pressed.
    public var isNumericPadOrArrowPressed: Bool {
        base.contains(.numericPad)
    }

    /// The modifier flags as `CGEventFlags`.
    public var cgEventFlags: CGEventFlags {
        var flags: CGEventFlags = []
        if base.contains(.shift) { flags.insert(.maskShift) }
        if base.contains(.control) { flags.insert(.maskControl) }
        if base.contains(.command) { flags.insert(.maskCommand) }
        if base.contains(.numericPad) { flags.insert(.maskNumericPad) }
        if base.contains(.help) { flags.insert(.maskHelp) }
        if base.contains(.option) { flags.insert(.maskAlternate) }
        if base.contains(.function) { flags.insert(.maskSecondaryFn) }
        if base.contains(.capsLock) { flags.insert(.maskAlphaShift) }
        return flags
    }
}

extension FrameworkToolbox where Base: CGEvent {
    /// The location of the mouse pointer.
    public static var mouseLocation: CGPoint? {
        CGEvent(source: nil)?.location
    }
}

#endif
