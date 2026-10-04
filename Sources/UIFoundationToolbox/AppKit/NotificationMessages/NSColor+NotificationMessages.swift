#if canImport(AppKit) && !targetEnvironment(macCatalyst)

import AppKit
import FoundationToolbox

// AppKit's predefined `NSColor` message. The conventions every file in `NotificationMessages/` follows
// are noted in `Shared/NotificationMessages.swift`.

extension NSColor {
    /// Backports of the messages AppKit declares on `NSColor` from macOS 27. See
    /// `NotificationCenter.Backport`.
    public enum Backport {}
}

extension NSColor.Backport {
    /// A message that the system sends when the system colors change.
    public struct SystemColorsDidChangeMessage: NotificationCenter.Backport.MainActorMessage, PropertylessMainActorMessage {
        public typealias Subject = NSColor

        public static var name: Notification.Name {
            NSColor.systemColorsDidChangeNotification
        }

        public init() {}
    }
}

extension NotificationCenter.Backport.MessageIdentifier
where Self == NotificationCenter.Backport.BaseMessageIdentifier<NSColor.Backport.SystemColorsDidChangeMessage> {
    /// The identifier of `NSColor.Backport.SystemColorsDidChangeMessage`.
    @_disfavoredOverload
    public static var systemColorsDidChange: Self { .init() }
}

#endif
