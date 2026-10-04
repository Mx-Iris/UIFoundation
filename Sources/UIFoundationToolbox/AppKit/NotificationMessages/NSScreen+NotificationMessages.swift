#if canImport(AppKit) && !targetEnvironment(macCatalyst)

import AppKit
import FoundationToolbox

// AppKit's predefined `NSScreen` message. The conventions every file in `NotificationMessages/` follows
// are noted in `Shared/NotificationMessages.swift`.

extension NSScreen {
    /// Backports of the messages AppKit declares on `NSScreen` from macOS 27. See
    /// `NotificationCenter.Backport`.
    public enum Backport {}
}

extension NSScreen.Backport {
    /// A message that a screen sends when its color space changes.
    public struct ColorSpaceDidChangeMessage: NotificationCenter.Backport.MainActorMessage {
        public typealias Subject = NSScreen

        public static var name: Notification.Name {
            NSScreen.colorSpaceDidChangeNotification
        }

        /// The screen whose color space changed.
        public var screen: NSScreen

        public init(screen: NSScreen) {
            self.screen = screen
        }

        @MainActor
        public static func makeMessage(_ notification: Notification) -> Self? {
            guard let screen = notification.object as? NSScreen else {
                return nil
            }
            return Self(screen: screen)
        }

        @MainActor
        public static func makeNotification(_ message: Self) -> Notification {
            Notification(name: name, object: message.screen, userInfo: nil)
        }
    }
}

extension NotificationCenter.Backport.MessageIdentifier
where Self == NotificationCenter.Backport.BaseMessageIdentifier<NSScreen.Backport.ColorSpaceDidChangeMessage> {
    /// The identifier of `NSScreen.Backport.ColorSpaceDidChangeMessage`.
    @_disfavoredOverload
    public static var colorSpaceDidChange: Self { .init() }
}

#endif
