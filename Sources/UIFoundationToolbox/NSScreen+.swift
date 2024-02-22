#if canImport(AppKit) && !targetEnvironment(macCatalyst)

import AppKit
import CoreGraphics
import IOKit.pwr_mgt
import FrameworkToolbox
import FoundationToolbox

extension FrameworkToolbox where Base: NSScreen {
    /// Returns the windows of a application visible on the scrren.
    ///
    /// - Parameters:
    ///   - application: The application for the windows
    ///
    /// - Returns: The visible windows of the application.
    public func visibleWindows(for application: NSApplication = NSApp) -> [NSWindow] {
        application.windows.filter { $0.isVisible && $0.screen == base && !$0.isFloatingPanel }
    }

    /// Returns the identifier of the display.
    public var displayID: CGDirectDisplayID {
        base.deviceDescription[.box.screenNumber] as? CGDirectDisplayID ?? 0
    }

    /// Returns the ordered index of the screen.
    public var orderedIndex: Int? {
        let screens = NSScreen.screens.sorted { $0.frame.minX < $1.frame.minX }
        return screens.firstIndex(of: base)
    }

    /// Returns the bounds of the screen in the global display coordinate space.
    public var quartzFrame: CGRect {
        CGDisplayBounds(base.displayID)
    }

    /// A Boolean value that indicates whether the mouse cursor is visble on the screen.
    public var containsMouse: Bool {
        Self.withMouse == base
    }

    /// Returns the screeen which includes the mouse cursor.
    public static var withMouse: NSScreen? {
        let mouseLocation = NSEvent.mouseLocation
        let screens = NSScreen.screens
        let screenWithMouse = (screens.first { NSMouseInRect(mouseLocation, $0.frame, false) })
        return screenWithMouse
    }

    //// Returns the AirPlay screen.
    public static var airplay: NSScreen? {
        NSScreen.screens.first(where: { $0.localizedName.lowercased().contains("airplay") })
    }

    /// Returns the Sidecar screen.
    public static var sidecar: NSScreen? {
        NSScreen.screens.first(where: { $0.localizedName.lowercased().contains("sidecar") })
    }

    /// Returns the built-in screen.
    public static var builtIn: NSScreen? {
        NSScreen.screens.first(where: { CGDisplayIsBuiltin($0.displayID) != 0 })
    }

    /// A Boolean value that indicates whether the screen is built-in.
    public var isBuiltIn: Bool {
        base == Self.builtIn
    }

    /// A Boolean value that indicates whether the screen is virtual (e.g. Sidecar or Airplay screens)
    public var isVirtual: Bool {
        var isVirtual = false
        let name = base.localizedName
        if name.contains("dummy") || name.contains("airplay") || name.contains("sidecar") {
            isVirtual = true
        }
        return isVirtual
    }

    /// Returns the screen that contains a point.
    ///
    /// - Parameter point: The point which the screen should contain.
    public static func screen(at point: NSPoint) -> NSScreen? {
        var returnScreen: NSScreen?
        let screens = NSScreen.screens
        for screen in screens {
            if NSMouseInRect(point, screen.frame, false) {
                returnScreen = screen
            }
        }
        return returnScreen
    }

    /// Disables screen sleep and returns a Boolean value that indicates whether disabling succeeded.
    @discardableResult
    public static func disableScreenSleep() -> Bool {
        guard _screenSleepIsDisabled == false else { return true }
        _screenSleepIsDisabled = IOPMAssertionCreateWithName(
            kIOPMAssertionTypeNoDisplaySleep as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            "Unknown reason" as CFString,
            &noSleepAssertionID
        ) == kIOReturnSuccess
        return _screenSleepIsDisabled
    }

    /// Enables screen sleep and returns a Boolean value that indicates whether enabling succeeded.
    @discardableResult
    public static func enableScreenSleep() -> Bool {
        guard _screenSleepIsDisabled == true else { return true }
        _screenSleepIsDisabled = !(IOPMAssertionRelease(noSleepAssertionID) == kIOReturnSuccess)
        return _screenSleepIsDisabled == false
    }

    private static var _screenSleepIsDisabled: Bool {
        get { getAssociatedValue(key: "screenSleepIsDisabled", object: Base.self, initialValue: false) }
        set { set(associatedValue: newValue, key: "screenSleepIsDisabled", object: Base.self) }
    }

    private static var noSleepAssertionID: IOPMAssertionID {
        get { getAssociatedValue(key: "noSleepAssertionID", object: Base.self, initialValue: 0) }
        set { set(associatedValue: newValue, key: "noSleepAssertionID", object: Base.self) }
    }
}

extension NSDeviceDescriptionKey: FrameworkToolboxCompatible, FrameworkToolboxDynamicMemberLookup {}

extension FrameworkToolbox where Base == NSDeviceDescriptionKey {
    /// The corresponding value is an `UInt32` value that identifies a `NSScreen` object.
    public static let screenNumber = NSDeviceDescriptionKey("NSScreenNumber")
}

#endif
