#if canImport(UIKit) && !os(watchOS)

import UIKit
import FoundationToolbox

// UIKit's predefined `UIScreen` messages. The conventions every file in `NotificationMessages/`
// follows are noted in `Shared/NotificationMessages.swift`.
//
// All four carry the screen the notification is posted from, and UIKit implements them the same way:
// the screen is the notification's object, and a notification without one converts to `nil`.
// `UIScreen` itself is unavailable on visionOS, and so are they.

@available(visionOS, unavailable)
extension UIScreen {
    /// Backports of the messages UIKit declares on `UIScreen` from iOS 26. See
    /// `NotificationCenter.Backport`.
    public enum Backport {}
}

/// The messages whose only property is the screen, read from the notification's object.
@available(visionOS, unavailable)
protocol StandardUIScreenMessage: NotificationCenter.Backport.MainActorMessage where Subject == UIScreen {
    var screen: UIScreen { get }
    init(screen: UIScreen)
}

@available(visionOS, unavailable)
extension StandardUIScreenMessage {
    @MainActor
    public static func makeMessage(_ notification: Notification) -> Self? {
        guard let screen = notification.object as? UIScreen else {
            return nil
        }
        return Self(screen: screen)
    }

    @MainActor
    public static func makeNotification(_ message: Self) -> Notification {
        Notification(name: name, object: message.screen, userInfo: nil)
    }
}

@available(visionOS, unavailable)
extension UIScreen.Backport {
    /// A message that a screen sends when its brightness changes.
    public struct BrightnessDidChangeMessage: NotificationCenter.Backport.MainActorMessage, StandardUIScreenMessage {
        public typealias Subject = UIScreen

        public static var name: Notification.Name {
            UIScreen.brightnessDidChangeNotification
        }

        /// The screen whose brightness changed.
        public var screen: UIScreen

        public init(screen: UIScreen) {
            self.screen = screen
        }
    }

    /// A message that a screen sends when its current mode changes.
    public struct ModeDidChangeMessage: NotificationCenter.Backport.MainActorMessage, StandardUIScreenMessage {
        public typealias Subject = UIScreen

        public static var name: Notification.Name {
            UIScreen.modeDidChangeNotification
        }

        /// The screen whose mode changed.
        public var screen: UIScreen

        public init(screen: UIScreen) {
            self.screen = screen
        }
    }

    /// A message that a screen sends when its recording, mirroring or AirPlay status changes.
    public struct CapturedDidChangeMessage: NotificationCenter.Backport.MainActorMessage, StandardUIScreenMessage {
        public typealias Subject = UIScreen

        public static var name: Notification.Name {
            UIScreen.capturedDidChangeNotification
        }

        /// The screen whose captured status changed.
        public var screen: UIScreen

        public init(screen: UIScreen) {
            self.screen = screen
        }
    }

    /// A message that a screen sends when its reference display mode status changes.
    @available(iOS 16.0, macCatalyst 16.0, tvOS 16.0, *)
    public struct ReferenceDisplayModeStatusDidChangeMessage: NotificationCenter.Backport.MainActorMessage, StandardUIScreenMessage {
        public typealias Subject = UIScreen

        public static var name: Notification.Name {
            UIScreen.referenceDisplayModeStatusDidChangeNotification
        }

        /// The screen whose reference display mode status changed.
        public var screen: UIScreen

        public init(screen: UIScreen) {
            self.screen = screen
        }
    }
}

@available(visionOS, unavailable)
extension NotificationCenter.Backport.MessageIdentifier
where Self == NotificationCenter.Backport.BaseMessageIdentifier<UIScreen.Backport.BrightnessDidChangeMessage> {
    /// The identifier of `UIScreen.Backport.BrightnessDidChangeMessage`.
    @_disfavoredOverload
    public static var brightnessDidChange: Self { .init() }
}

@available(visionOS, unavailable)
extension NotificationCenter.Backport.MessageIdentifier
where Self == NotificationCenter.Backport.BaseMessageIdentifier<UIScreen.Backport.ModeDidChangeMessage> {
    /// The identifier of `UIScreen.Backport.ModeDidChangeMessage`.
    @_disfavoredOverload
    public static var modeDidChange: Self { .init() }
}

@available(visionOS, unavailable)
extension NotificationCenter.Backport.MessageIdentifier
where Self == NotificationCenter.Backport.BaseMessageIdentifier<UIScreen.Backport.CapturedDidChangeMessage> {
    /// The identifier of `UIScreen.Backport.CapturedDidChangeMessage`.
    @_disfavoredOverload
    public static var capturedDidChange: Self { .init() }
}

@available(iOS 16.0, macCatalyst 16.0, tvOS 16.0, *)
@available(visionOS, unavailable)
extension NotificationCenter.Backport.MessageIdentifier
where Self == NotificationCenter.Backport.BaseMessageIdentifier<UIScreen.Backport.ReferenceDisplayModeStatusDidChangeMessage> {
    /// The identifier of `UIScreen.Backport.ReferenceDisplayModeStatusDidChangeMessage`.
    @_disfavoredOverload
    public static var referenceDisplayModeStatusDidChange: Self { .init() }
}

#endif
