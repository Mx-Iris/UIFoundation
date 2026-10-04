#if canImport(UIKit) && !os(watchOS)

import UIKit
import FoundationToolbox

// UIKit's predefined `UIWindow` messages. The conventions every file in `NotificationMessages/`
// follows are noted in `Shared/NotificationMessages.swift`.
//
// All four carry the window the notification is posted from, and UIKit implements them the same way:
// the window is the notification's object, and a notification without one converts to `nil`.

extension UIWindow {
    /// Backports of the messages UIKit declares on `UIWindow` from iOS 26. See
    /// `NotificationCenter.Backport`.
    public enum Backport {}
}

/// The messages whose only property is the window, read from the notification's object.
protocol StandardUIWindowMessage: NotificationCenter.Backport.MainActorMessage where Subject == UIWindow {
    var window: UIWindow { get }
    init(window: UIWindow)
}

extension StandardUIWindowMessage {
    @MainActor
    public static func makeMessage(_ notification: Notification) -> Self? {
        guard let window = notification.object as? UIWindow else {
            return nil
        }
        return Self(window: window)
    }

    @MainActor
    public static func makeNotification(_ message: Self) -> Notification {
        Notification(name: name, object: message.window, userInfo: nil)
    }
}

extension UIWindow.Backport {
    /// A message that a window sends when it becomes visible.
    public struct DidBecomeVisibleMessage: NotificationCenter.Backport.MainActorMessage, StandardUIWindowMessage {
        public typealias Subject = UIWindow

        public static var name: Notification.Name {
            UIWindow.didBecomeVisibleNotification
        }

        /// The window that became visible.
        public var window: UIWindow

        public init(window: UIWindow) {
            self.window = window
        }
    }

    /// A message that a window sends when it becomes hidden.
    public struct DidBecomeHiddenMessage: NotificationCenter.Backport.MainActorMessage, StandardUIWindowMessage {
        public typealias Subject = UIWindow

        public static var name: Notification.Name {
            UIWindow.didBecomeHiddenNotification
        }

        /// The window that became hidden.
        public var window: UIWindow

        public init(window: UIWindow) {
            self.window = window
        }
    }

    /// A message that a window sends whenever it becomes the key window.
    public struct DidBecomeKeyMessage: NotificationCenter.Backport.MainActorMessage, StandardUIWindowMessage {
        public typealias Subject = UIWindow

        public static var name: Notification.Name {
            UIWindow.didBecomeKeyNotification
        }

        /// The window that became the key window.
        public var window: UIWindow

        public init(window: UIWindow) {
            self.window = window
        }
    }

    /// A message that a window sends whenever it resigns its status as the key window.
    public struct DidResignKeyMessage: NotificationCenter.Backport.MainActorMessage, StandardUIWindowMessage {
        public typealias Subject = UIWindow

        public static var name: Notification.Name {
            UIWindow.didResignKeyNotification
        }

        /// The window that resigned its status as the key window.
        public var window: UIWindow

        public init(window: UIWindow) {
            self.window = window
        }
    }
}

extension NotificationCenter.Backport.MessageIdentifier
where Self == NotificationCenter.Backport.BaseMessageIdentifier<UIWindow.Backport.DidBecomeVisibleMessage> {
    /// The identifier of `UIWindow.Backport.DidBecomeVisibleMessage`.
    @_disfavoredOverload
    public static var didBecomeVisible: Self { .init() }
}

extension NotificationCenter.Backport.MessageIdentifier
where Self == NotificationCenter.Backport.BaseMessageIdentifier<UIWindow.Backport.DidBecomeHiddenMessage> {
    /// The identifier of `UIWindow.Backport.DidBecomeHiddenMessage`.
    @_disfavoredOverload
    public static var didBecomeHidden: Self { .init() }
}

extension NotificationCenter.Backport.MessageIdentifier
where Self == NotificationCenter.Backport.BaseMessageIdentifier<UIWindow.Backport.DidBecomeKeyMessage> {
    /// The identifier of `UIWindow.Backport.DidBecomeKeyMessage`.
    @_disfavoredOverload
    public static var didBecomeKey: Self { .init() }
}

extension NotificationCenter.Backport.MessageIdentifier
where Self == NotificationCenter.Backport.BaseMessageIdentifier<UIWindow.Backport.DidResignKeyMessage> {
    /// The identifier of `UIWindow.Backport.DidResignKeyMessage`.
    @_disfavoredOverload
    public static var didResignKey: Self { .init() }
}

#endif
