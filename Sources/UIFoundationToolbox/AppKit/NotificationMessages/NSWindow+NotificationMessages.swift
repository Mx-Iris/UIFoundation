#if canImport(AppKit) && !targetEnvironment(macCatalyst)

import AppKit
import FoundationToolbox

// AppKit's predefined `NSWindow` messages. The conventions every file in `NotificationMessages/` follows
// are noted in `Shared/NotificationMessages.swift`.
//
// Twenty-seven of them carry nothing but the window, which is the notification's object, and AppKit
// implements them through one internal protocol, `StandardNSWindowMessage`, reproduced here under
// AppKit's name. (AppKit declares `DidExitFullScreenMessage` on its own rather than through the protocol,
// but it runs the very same code, so here it conforms like the others.) `DidExposeMessage` and
// `DidChangeBackingPropertiesMessage` read the user info as well.

extension NSWindow {
    /// Backports of the messages AppKit declares on `NSWindow` from macOS 27. See
    /// `NotificationCenter.Backport`.
    public enum Backport {}
}

/// The messages whose only property is the window, read from the notification's object.
protocol StandardNSWindowMessage: NotificationCenter.Backport.MainActorMessage where Subject == NSWindow {
    var window: NSWindow { get }
    init(window: NSWindow)
}

extension StandardNSWindowMessage {
    @MainActor
    public static func makeMessage(_ notification: Notification) -> Self? {
        guard let window = notification.object as? NSWindow else {
            return nil
        }
        return Self(window: window)
    }

    @MainActor
    public static func makeNotification(_ message: Self) -> Notification {
        Notification(name: name, object: message.window, userInfo: nil)
    }
}

extension NSWindow.Backport {
    /// A message that a window sends when it becomes the key window.
    public struct DidBecomeKeyMessage: NotificationCenter.Backport.MainActorMessage, StandardNSWindowMessage {
        public typealias Subject = NSWindow

        public static var name: Notification.Name {
            NSWindow.didBecomeKeyNotification
        }

        /// The window that became the key window.
        public var window: NSWindow

        public init(window: NSWindow) {
            self.window = window
        }
    }

    /// A message that a window sends when it becomes the main window.
    public struct DidBecomeMainMessage: NotificationCenter.Backport.MainActorMessage, StandardNSWindowMessage {
        public typealias Subject = NSWindow

        public static var name: Notification.Name {
            NSWindow.didBecomeMainNotification
        }

        /// The window that became the main window.
        public var window: NSWindow

        public init(window: NSWindow) {
            self.window = window
        }
    }

    /// A message that a window sends when a portion of its frame moves onto or off a screen.
    public struct DidChangeScreenMessage: NotificationCenter.Backport.MainActorMessage, StandardNSWindowMessage {
        public typealias Subject = NSWindow

        public static var name: Notification.Name {
            NSWindow.didChangeScreenNotification
        }

        /// The window whose screen changed.
        public var window: NSWindow

        public init(window: NSWindow) {
            self.window = window
        }
    }

    /// A message that a window sends when it's restored from the Dock.
    public struct DidDeminiaturizeMessage: NotificationCenter.Backport.MainActorMessage, StandardNSWindowMessage {
        public typealias Subject = NSWindow

        public static var name: Notification.Name {
            NSWindow.didDeminiaturizeNotification
        }

        /// The window that was restored from the Dock.
        public var window: NSWindow

        public init(window: NSWindow) {
            self.window = window
        }
    }

    /// A message that a window sends when it's minimized to the Dock.
    public struct DidMiniaturizeMessage: NotificationCenter.Backport.MainActorMessage, StandardNSWindowMessage {
        public typealias Subject = NSWindow

        public static var name: Notification.Name {
            NSWindow.didMiniaturizeNotification
        }

        /// The window that was minimized.
        public var window: NSWindow

        public init(window: NSWindow) {
            self.window = window
        }
    }

    /// A message that a window sends when it moves.
    public struct DidMoveMessage: NotificationCenter.Backport.MainActorMessage, StandardNSWindowMessage {
        public typealias Subject = NSWindow

        public static var name: Notification.Name {
            NSWindow.didMoveNotification
        }

        /// The window that moved.
        public var window: NSWindow

        public init(window: NSWindow) {
            self.window = window
        }
    }

    /// A message that a window sends when it resigns its status as the key window.
    public struct DidResignKeyMessage: NotificationCenter.Backport.MainActorMessage, StandardNSWindowMessage {
        public typealias Subject = NSWindow

        public static var name: Notification.Name {
            NSWindow.didResignKeyNotification
        }

        /// The window that resigned its status as the key window.
        public var window: NSWindow

        public init(window: NSWindow) {
            self.window = window
        }
    }

    /// A message that a window sends when it resigns its status as the main window.
    public struct DidResignMainMessage: NotificationCenter.Backport.MainActorMessage, StandardNSWindowMessage {
        public typealias Subject = NSWindow

        public static var name: Notification.Name {
            NSWindow.didResignMainNotification
        }

        /// The window that resigned its status as the main window.
        public var window: NSWindow

        public init(window: NSWindow) {
            self.window = window
        }
    }

    /// A message that a window sends when its size changes.
    public struct DidResizeMessage: NotificationCenter.Backport.MainActorMessage, StandardNSWindowMessage {
        public typealias Subject = NSWindow

        public static var name: Notification.Name {
            NSWindow.didResizeNotification
        }

        /// The window whose size changed.
        public var window: NSWindow

        public init(window: NSWindow) {
            self.window = window
        }
    }

    /// A message that a window sends when it receives an update message.
    public struct DidUpdateMessage: NotificationCenter.Backport.MainActorMessage, StandardNSWindowMessage {
        public typealias Subject = NSWindow

        public static var name: Notification.Name {
            NSWindow.didUpdateNotification
        }

        /// The window that received the update message.
        public var window: NSWindow

        public init(window: NSWindow) {
            self.window = window
        }
    }

    /// A message that a window sends when it's about to close.
    public struct WillCloseMessage: NotificationCenter.Backport.MainActorMessage, StandardNSWindowMessage {
        public typealias Subject = NSWindow

        public static var name: Notification.Name {
            NSWindow.willCloseNotification
        }

        /// The window that is about to close.
        public var window: NSWindow

        public init(window: NSWindow) {
            self.window = window
        }
    }

    /// A message that a window sends when it's about to be minimized.
    public struct WillMiniaturizeMessage: NotificationCenter.Backport.MainActorMessage, StandardNSWindowMessage {
        public typealias Subject = NSWindow

        public static var name: Notification.Name {
            NSWindow.willMiniaturizeNotification
        }

        /// The window that is about to be minimized.
        public var window: NSWindow

        public init(window: NSWindow) {
            self.window = window
        }
    }

    /// A message that a window sends when it's about to move.
    public struct WillMoveMessage: NotificationCenter.Backport.MainActorMessage, StandardNSWindowMessage {
        public typealias Subject = NSWindow

        public static var name: Notification.Name {
            NSWindow.willMoveNotification
        }

        /// The window that is about to move.
        public var window: NSWindow

        public init(window: NSWindow) {
            self.window = window
        }
    }

    /// A message that a window sends when it's about to open a sheet.
    public struct WillBeginSheetMessage: NotificationCenter.Backport.MainActorMessage, StandardNSWindowMessage {
        public typealias Subject = NSWindow

        public static var name: Notification.Name {
            NSWindow.willBeginSheetNotification
        }

        /// The window that is about to open a sheet.
        public var window: NSWindow

        public init(window: NSWindow) {
            self.window = window
        }
    }

    /// A message that a window sends when it closes an attached sheet.
    public struct DidEndSheetMessage: NotificationCenter.Backport.MainActorMessage, StandardNSWindowMessage {
        public typealias Subject = NSWindow

        public static var name: Notification.Name {
            NSWindow.didEndSheetNotification
        }

        /// The window whose sheet closed.
        public var window: NSWindow

        public init(window: NSWindow) {
            self.window = window
        }
    }

    /// A message that a window sends when the display profile of its screen changes.
    public struct DidChangeScreenProfileMessage: NotificationCenter.Backport.MainActorMessage, StandardNSWindowMessage {
        public typealias Subject = NSWindow

        public static var name: Notification.Name {
            NSWindow.didChangeScreenProfileNotification
        }

        /// The window whose screen's display profile changed.
        public var window: NSWindow

        public init(window: NSWindow) {
            self.window = window
        }
    }

    /// A message that a window sends when the user is about to resize it.
    public struct WillStartLiveResizeMessage: NotificationCenter.Backport.MainActorMessage, StandardNSWindowMessage {
        public typealias Subject = NSWindow

        public static var name: Notification.Name {
            NSWindow.willStartLiveResizeNotification
        }

        /// The window the user is about to resize.
        public var window: NSWindow

        public init(window: NSWindow) {
            self.window = window
        }
    }

    /// A message that a window sends after the user resizes it.
    public struct DidEndLiveResizeMessage: NotificationCenter.Backport.MainActorMessage, StandardNSWindowMessage {
        public typealias Subject = NSWindow

        public static var name: Notification.Name {
            NSWindow.didEndLiveResizeNotification
        }

        /// The window the user resized.
        public var window: NSWindow

        public init(window: NSWindow) {
            self.window = window
        }
    }

    /// A message that a window sends when it's about to enter full-screen mode.
    public struct WillEnterFullScreenMessage: NotificationCenter.Backport.MainActorMessage, StandardNSWindowMessage {
        public typealias Subject = NSWindow

        public static var name: Notification.Name {
            NSWindow.willEnterFullScreenNotification
        }

        /// The window that is about to enter full-screen mode.
        public var window: NSWindow

        public init(window: NSWindow) {
            self.window = window
        }
    }

    /// A message that a window sends when it enters full-screen mode.
    public struct DidEnterFullScreenMessage: NotificationCenter.Backport.MainActorMessage, StandardNSWindowMessage {
        public typealias Subject = NSWindow

        public static var name: Notification.Name {
            NSWindow.didEnterFullScreenNotification
        }

        /// The window that entered full-screen mode.
        public var window: NSWindow

        public init(window: NSWindow) {
            self.window = window
        }
    }

    /// A message that a window sends when it's about to exit full-screen mode.
    public struct WillExitFullScreenMessage: NotificationCenter.Backport.MainActorMessage, StandardNSWindowMessage {
        public typealias Subject = NSWindow

        public static var name: Notification.Name {
            NSWindow.willExitFullScreenNotification
        }

        /// The window that is about to exit full-screen mode.
        public var window: NSWindow

        public init(window: NSWindow) {
            self.window = window
        }
    }

    /// A message that a window sends when it exits full-screen mode.
    public struct DidExitFullScreenMessage: NotificationCenter.Backport.MainActorMessage, StandardNSWindowMessage {
        public typealias Subject = NSWindow

        public static var name: Notification.Name {
            NSWindow.didExitFullScreenNotification
        }

        /// The window that exited full-screen mode.
        public var window: NSWindow

        public init(window: NSWindow) {
            self.window = window
        }
    }

    /// A message that a window sends when it's about to enter the version browser.
    public struct WillEnterVersionBrowserMessage: NotificationCenter.Backport.MainActorMessage, StandardNSWindowMessage {
        public typealias Subject = NSWindow

        public static var name: Notification.Name {
            NSWindow.willEnterVersionBrowserNotification
        }

        /// The window that is about to enter the version browser.
        public var window: NSWindow

        public init(window: NSWindow) {
            self.window = window
        }
    }

    /// A message that a window sends when it enters the version browser.
    public struct DidEnterVersionBrowserMessage: NotificationCenter.Backport.MainActorMessage, StandardNSWindowMessage {
        public typealias Subject = NSWindow

        public static var name: Notification.Name {
            NSWindow.didEnterVersionBrowserNotification
        }

        /// The window that entered the version browser.
        public var window: NSWindow

        public init(window: NSWindow) {
            self.window = window
        }
    }

    /// A message that a window sends when it's about to exit the version browser.
    public struct WillExitVersionBrowserMessage: NotificationCenter.Backport.MainActorMessage, StandardNSWindowMessage {
        public typealias Subject = NSWindow

        public static var name: Notification.Name {
            NSWindow.willExitVersionBrowserNotification
        }

        /// The window that is about to exit the version browser.
        public var window: NSWindow

        public init(window: NSWindow) {
            self.window = window
        }
    }

    /// A message that a window sends when it exits the version browser.
    public struct DidExitVersionBrowserMessage: NotificationCenter.Backport.MainActorMessage, StandardNSWindowMessage {
        public typealias Subject = NSWindow

        public static var name: Notification.Name {
            NSWindow.didExitVersionBrowserNotification
        }

        /// The window that exited the version browser.
        public var window: NSWindow

        public init(window: NSWindow) {
            self.window = window
        }
    }

    /// A message that a window sends when its occlusion state changes.
    public struct DidChangeOcclusionStateMessage: NotificationCenter.Backport.MainActorMessage, StandardNSWindowMessage {
        public typealias Subject = NSWindow

        public static var name: Notification.Name {
            NSWindow.didChangeOcclusionStateNotification
        }

        /// The window whose occlusion state changed.
        public var window: NSWindow

        public init(window: NSWindow) {
            self.window = window
        }
    }

    /// A message that a window sends when a portion of a nonretained window is exposed.
    ///
    /// Both values are required. The rectangle is read with a direct cast to `CGRect`, which accepts the
    /// `NSValue` AppKit posts, and written back as a Swift `CGRect` -- both as AppKit does.
    public struct DidExposeMessage: NotificationCenter.Backport.MainActorMessage {
        public typealias Subject = NSWindow

        public static var name: Notification.Name {
            NSWindow.didExposeNotification
        }

        /// The window a portion of which was exposed.
        public var window: NSWindow

        /// The rectangle that was exposed.
        public var exposedRect: NSRect

        public init(window: NSWindow, exposedRect: NSRect) {
            self.window = window
            self.exposedRect = exposedRect
        }

        @MainActor
        public static func makeMessage(_ notification: Notification) -> Self? {
            guard let window = notification.object as? NSWindow,
                  let userInfo = notification.userInfo,
                  let exposedRect = userInfo["NSExposedRect"] as? CGRect
            else {
                return nil
            }
            return Self(window: window, exposedRect: exposedRect)
        }

        @MainActor
        public static func makeNotification(_ message: Self) -> Notification {
            Notification(name: name, object: message.window, userInfo: ["NSExposedRect": message.exposedRect])
        }
    }

    /// A message that a window sends when its backing properties change, such as its scale factor or
    /// color space.
    ///
    /// Only the window is required. A previous value that the notification does not carry is `nil`, and
    /// making a notification writes only the previous values that are not `nil` -- no user info at all
    /// when neither is set -- as AppKit does.
    public struct DidChangeBackingPropertiesMessage: NotificationCenter.Backport.MainActorMessage {
        public typealias Subject = NSWindow

        public static var name: Notification.Name {
            NSWindow.didChangeBackingPropertiesNotification
        }

        /// The window whose backing properties changed.
        public var window: NSWindow

        /// The window's previous backing scale factor.
        public var oldScaleFactor: CGFloat?

        /// The window's previous color space.
        public var oldColorSpace: NSColorSpace?

        public init(window: NSWindow, oldScaleFactor: CGFloat? = nil, oldColorSpace: NSColorSpace? = nil) {
            self.window = window
            self.oldScaleFactor = oldScaleFactor
            self.oldColorSpace = oldColorSpace
        }

        @MainActor
        public static func makeMessage(_ notification: Notification) -> Self? {
            guard let window = notification.object as? NSWindow else {
                return nil
            }
            return Self(
                window: window,
                oldScaleFactor: notification.userInfo?[NSWindow.oldScaleFactorUserInfoKey] as? CGFloat,
                oldColorSpace: notification.userInfo?[NSWindow.oldColorSpaceUserInfoKey] as? NSColorSpace
            )
        }

        @MainActor
        public static func makeNotification(_ message: Self) -> Notification {
            var userInfo: [String: Any] = [:]
            if let oldScaleFactor = message.oldScaleFactor {
                userInfo[NSWindow.oldScaleFactorUserInfoKey] = oldScaleFactor
            }
            if let oldColorSpace = message.oldColorSpace {
                userInfo[NSWindow.oldColorSpaceUserInfoKey] = oldColorSpace
            }
            return Notification(name: name, object: message.window, userInfo: userInfo.isEmpty ? nil : userInfo)
        }
    }
}

extension NotificationCenter.Backport.MessageIdentifier
where Self == NotificationCenter.Backport.BaseMessageIdentifier<NSWindow.Backport.DidBecomeKeyMessage> {
    /// The identifier of `NSWindow.Backport.DidBecomeKeyMessage`.
    @_disfavoredOverload
    public static var didBecomeKey: Self { .init() }
}

extension NotificationCenter.Backport.MessageIdentifier
where Self == NotificationCenter.Backport.BaseMessageIdentifier<NSWindow.Backport.DidBecomeMainMessage> {
    /// The identifier of `NSWindow.Backport.DidBecomeMainMessage`.
    @_disfavoredOverload
    public static var didBecomeMain: Self { .init() }
}

extension NotificationCenter.Backport.MessageIdentifier
where Self == NotificationCenter.Backport.BaseMessageIdentifier<NSWindow.Backport.DidChangeScreenMessage> {
    /// The identifier of `NSWindow.Backport.DidChangeScreenMessage`.
    @_disfavoredOverload
    public static var didChangeScreen: Self { .init() }
}

extension NotificationCenter.Backport.MessageIdentifier
where Self == NotificationCenter.Backport.BaseMessageIdentifier<NSWindow.Backport.DidDeminiaturizeMessage> {
    /// The identifier of `NSWindow.Backport.DidDeminiaturizeMessage`.
    @_disfavoredOverload
    public static var didDeminiaturize: Self { .init() }
}

extension NotificationCenter.Backport.MessageIdentifier
where Self == NotificationCenter.Backport.BaseMessageIdentifier<NSWindow.Backport.DidMiniaturizeMessage> {
    /// The identifier of `NSWindow.Backport.DidMiniaturizeMessage`.
    @_disfavoredOverload
    public static var didMiniaturize: Self { .init() }
}

extension NotificationCenter.Backport.MessageIdentifier
where Self == NotificationCenter.Backport.BaseMessageIdentifier<NSWindow.Backport.DidMoveMessage> {
    /// The identifier of `NSWindow.Backport.DidMoveMessage`.
    @_disfavoredOverload
    public static var didMove: Self { .init() }
}

extension NotificationCenter.Backport.MessageIdentifier
where Self == NotificationCenter.Backport.BaseMessageIdentifier<NSWindow.Backport.DidResignKeyMessage> {
    /// The identifier of `NSWindow.Backport.DidResignKeyMessage`.
    @_disfavoredOverload
    public static var didResignKey: Self { .init() }
}

extension NotificationCenter.Backport.MessageIdentifier
where Self == NotificationCenter.Backport.BaseMessageIdentifier<NSWindow.Backport.DidResignMainMessage> {
    /// The identifier of `NSWindow.Backport.DidResignMainMessage`.
    @_disfavoredOverload
    public static var didResignMain: Self { .init() }
}

extension NotificationCenter.Backport.MessageIdentifier
where Self == NotificationCenter.Backport.BaseMessageIdentifier<NSWindow.Backport.DidResizeMessage> {
    /// The identifier of `NSWindow.Backport.DidResizeMessage`.
    @_disfavoredOverload
    public static var didResize: Self { .init() }
}

extension NotificationCenter.Backport.MessageIdentifier
where Self == NotificationCenter.Backport.BaseMessageIdentifier<NSWindow.Backport.DidUpdateMessage> {
    /// The identifier of `NSWindow.Backport.DidUpdateMessage`.
    @_disfavoredOverload
    public static var didUpdate: Self { .init() }
}

extension NotificationCenter.Backport.MessageIdentifier
where Self == NotificationCenter.Backport.BaseMessageIdentifier<NSWindow.Backport.WillCloseMessage> {
    /// The identifier of `NSWindow.Backport.WillCloseMessage`.
    @_disfavoredOverload
    public static var willClose: Self { .init() }
}

extension NotificationCenter.Backport.MessageIdentifier
where Self == NotificationCenter.Backport.BaseMessageIdentifier<NSWindow.Backport.WillMiniaturizeMessage> {
    /// The identifier of `NSWindow.Backport.WillMiniaturizeMessage`.
    @_disfavoredOverload
    public static var willMiniaturize: Self { .init() }
}

extension NotificationCenter.Backport.MessageIdentifier
where Self == NotificationCenter.Backport.BaseMessageIdentifier<NSWindow.Backport.WillMoveMessage> {
    /// The identifier of `NSWindow.Backport.WillMoveMessage`.
    @_disfavoredOverload
    public static var willMove: Self { .init() }
}

extension NotificationCenter.Backport.MessageIdentifier
where Self == NotificationCenter.Backport.BaseMessageIdentifier<NSWindow.Backport.WillBeginSheetMessage> {
    /// The identifier of `NSWindow.Backport.WillBeginSheetMessage`.
    @_disfavoredOverload
    public static var willBeginSheet: Self { .init() }
}

extension NotificationCenter.Backport.MessageIdentifier
where Self == NotificationCenter.Backport.BaseMessageIdentifier<NSWindow.Backport.DidEndSheetMessage> {
    /// The identifier of `NSWindow.Backport.DidEndSheetMessage`.
    @_disfavoredOverload
    public static var didEndSheet: Self { .init() }
}

extension NotificationCenter.Backport.MessageIdentifier
where Self == NotificationCenter.Backport.BaseMessageIdentifier<NSWindow.Backport.DidChangeScreenProfileMessage> {
    /// The identifier of `NSWindow.Backport.DidChangeScreenProfileMessage`.
    @_disfavoredOverload
    public static var didChangeScreenProfile: Self { .init() }
}

extension NotificationCenter.Backport.MessageIdentifier
where Self == NotificationCenter.Backport.BaseMessageIdentifier<NSWindow.Backport.WillStartLiveResizeMessage> {
    /// The identifier of `NSWindow.Backport.WillStartLiveResizeMessage`.
    @_disfavoredOverload
    public static var willStartLiveResize: Self { .init() }
}

extension NotificationCenter.Backport.MessageIdentifier
where Self == NotificationCenter.Backport.BaseMessageIdentifier<NSWindow.Backport.DidEndLiveResizeMessage> {
    /// The identifier of `NSWindow.Backport.DidEndLiveResizeMessage`.
    @_disfavoredOverload
    public static var didEndLiveResize: Self { .init() }
}

extension NotificationCenter.Backport.MessageIdentifier
where Self == NotificationCenter.Backport.BaseMessageIdentifier<NSWindow.Backport.WillEnterFullScreenMessage> {
    /// The identifier of `NSWindow.Backport.WillEnterFullScreenMessage`.
    @_disfavoredOverload
    public static var willEnterFullScreen: Self { .init() }
}

extension NotificationCenter.Backport.MessageIdentifier
where Self == NotificationCenter.Backport.BaseMessageIdentifier<NSWindow.Backport.DidEnterFullScreenMessage> {
    /// The identifier of `NSWindow.Backport.DidEnterFullScreenMessage`.
    @_disfavoredOverload
    public static var didEnterFullScreen: Self { .init() }
}

extension NotificationCenter.Backport.MessageIdentifier
where Self == NotificationCenter.Backport.BaseMessageIdentifier<NSWindow.Backport.WillExitFullScreenMessage> {
    /// The identifier of `NSWindow.Backport.WillExitFullScreenMessage`.
    @_disfavoredOverload
    public static var willExitFullScreen: Self { .init() }
}

extension NotificationCenter.Backport.MessageIdentifier
where Self == NotificationCenter.Backport.BaseMessageIdentifier<NSWindow.Backport.DidExitFullScreenMessage> {
    /// The identifier of `NSWindow.Backport.DidExitFullScreenMessage`.
    @_disfavoredOverload
    public static var didExitFullScreen: Self { .init() }
}

extension NotificationCenter.Backport.MessageIdentifier
where Self == NotificationCenter.Backport.BaseMessageIdentifier<NSWindow.Backport.WillEnterVersionBrowserMessage> {
    /// The identifier of `NSWindow.Backport.WillEnterVersionBrowserMessage`.
    @_disfavoredOverload
    public static var willEnterVersionBrowser: Self { .init() }
}

extension NotificationCenter.Backport.MessageIdentifier
where Self == NotificationCenter.Backport.BaseMessageIdentifier<NSWindow.Backport.DidEnterVersionBrowserMessage> {
    /// The identifier of `NSWindow.Backport.DidEnterVersionBrowserMessage`.
    @_disfavoredOverload
    public static var didEnterVersionBrowser: Self { .init() }
}

extension NotificationCenter.Backport.MessageIdentifier
where Self == NotificationCenter.Backport.BaseMessageIdentifier<NSWindow.Backport.WillExitVersionBrowserMessage> {
    /// The identifier of `NSWindow.Backport.WillExitVersionBrowserMessage`.
    @_disfavoredOverload
    public static var willExitVersionBrowser: Self { .init() }
}

extension NotificationCenter.Backport.MessageIdentifier
where Self == NotificationCenter.Backport.BaseMessageIdentifier<NSWindow.Backport.DidExitVersionBrowserMessage> {
    /// The identifier of `NSWindow.Backport.DidExitVersionBrowserMessage`.
    @_disfavoredOverload
    public static var didExitVersionBrowser: Self { .init() }
}

extension NotificationCenter.Backport.MessageIdentifier
where Self == NotificationCenter.Backport.BaseMessageIdentifier<NSWindow.Backport.DidChangeOcclusionStateMessage> {
    /// The identifier of `NSWindow.Backport.DidChangeOcclusionStateMessage`.
    @_disfavoredOverload
    public static var didChangeOcclusionState: Self { .init() }
}

extension NotificationCenter.Backport.MessageIdentifier
where Self == NotificationCenter.Backport.BaseMessageIdentifier<NSWindow.Backport.DidExposeMessage> {
    /// The identifier of `NSWindow.Backport.DidExposeMessage`.
    @_disfavoredOverload
    public static var didExpose: Self { .init() }
}

extension NotificationCenter.Backport.MessageIdentifier
where Self == NotificationCenter.Backport.BaseMessageIdentifier<NSWindow.Backport.DidChangeBackingPropertiesMessage> {
    /// The identifier of `NSWindow.Backport.DidChangeBackingPropertiesMessage`.
    @_disfavoredOverload
    public static var didChangeBackingProperties: Self { .init() }
}

#endif
