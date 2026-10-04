#if canImport(AppKit) && !targetEnvironment(macCatalyst)

import AppKit
import FoundationToolbox

// AppKit's predefined `NSFont` message. The conventions every file in `NotificationMessages/` follows
// are noted in `Shared/NotificationMessages.swift`.

extension NSFont {
    /// Backports of the messages AppKit declares on `NSFont` from macOS 27. See
    /// `NotificationCenter.Backport`.
    public enum Backport {}
}

extension NSFont.Backport {
    /// A message that the system sends when the set of available fonts changes.
    public struct FontSetChangedMessage: NotificationCenter.Backport.MainActorMessage, PropertylessMainActorMessage {
        public typealias Subject = NSFont

        public static var name: Notification.Name {
            NSFont.fontSetChangedNotification
        }

        public init() {}
    }
}

extension NotificationCenter.Backport.MessageIdentifier
where Self == NotificationCenter.Backport.BaseMessageIdentifier<NSFont.Backport.FontSetChangedMessage> {
    /// The identifier of `NSFont.Backport.FontSetChangedMessage`.
    @_disfavoredOverload
    public static var fontSetChanged: Self { .init() }
}

#endif
