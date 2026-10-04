#if canImport(AppKit) && !targetEnvironment(macCatalyst)

import AppKit
import FoundationToolbox

// AppKit's predefined `NSFontCollection` message. The conventions every file in `NotificationMessages/`
// follows are noted in `Shared/NotificationMessages.swift`.

extension NSFontCollection {
    /// Backports of the messages AppKit declares on `NSFontCollection` from macOS 27. See
    /// `NotificationCenter.Backport`.
    public enum Backport {}
}

extension NSFontCollection.Backport {
    /// A message that a font collection sends when it changes: when it's shown, hidden or renamed.
    ///
    /// Only the font collection, the notification's object, and the action are required; the other
    /// values are `nil` when missing. Both requirements are AppKit's own, and they keep this message
    /// from arriving for the notifications AppKit itself posts: measured on macOS 27.0, showing and
    /// hiding a collection posts this notification with no object at all, so it converts to `nil` --
    /// in AppKit's implementation as in this one. The visibility is cast straight to
    /// `NSFontCollection.Visibility`, as AppKit casts it, and AppKit posts it as an `NSNumber`, which
    /// does not cast to that type, so with an object present `visibility` would still be `nil`.
    public struct DidChangeMessage: NotificationCenter.Backport.MainActorMessage {
        public typealias Subject = NSFontCollection

        public static var name: Notification.Name {
            NSFontCollection.didChangeNotification
        }

        /// The font collection that changed.
        public var fontCollection: NSFontCollection

        /// The kind of change.
        public var action: NSFontCollection.ActionTypeKey

        /// The name of the collection that changed.
        public var collectionName: String?

        /// The collection's previous name, when it was renamed.
        public var oldName: String?

        /// The visibility of the collection that changed.
        public var visibility: NSFontCollection.Visibility?

        public init(
            fontCollection: NSFontCollection,
            action: NSFontCollection.ActionTypeKey,
            collectionName: String? = nil,
            oldName: String? = nil,
            visibility: NSFontCollection.Visibility? = nil
        ) {
            self.fontCollection = fontCollection
            self.action = action
            self.collectionName = collectionName
            self.oldName = oldName
            self.visibility = visibility
        }

        @MainActor
        public static func makeMessage(_ notification: Notification) -> Self? {
            guard let fontCollection = notification.object as? NSFontCollection,
                  let userInfo = notification.userInfo,
                  let action = userInfo[NSFontCollection.actionUserInfoKey] as? NSFontCollection.ActionTypeKey
            else {
                return nil
            }
            return Self(
                fontCollection: fontCollection,
                action: action,
                collectionName: userInfo[NSFontCollection.nameUserInfoKey] as? String,
                oldName: userInfo[NSFontCollection.oldNameUserInfoKey] as? String,
                visibility: userInfo[NSFontCollection.visibilityUserInfoKey] as? NSFontCollection.Visibility
            )
        }

        @MainActor
        public static func makeNotification(_ message: Self) -> Notification {
            var userInfo: [NSFontCollection.UserInfoKey: Any] = [:]
            userInfo[NSFontCollection.actionUserInfoKey] = message.action
            if let collectionName = message.collectionName {
                userInfo[NSFontCollection.nameUserInfoKey] = collectionName
            }
            if let oldName = message.oldName {
                userInfo[NSFontCollection.oldNameUserInfoKey] = oldName
            }
            if let visibility = message.visibility {
                userInfo[NSFontCollection.visibilityUserInfoKey] = visibility
            }
            return Notification(name: name, object: message.fontCollection, userInfo: userInfo.isEmpty ? nil : userInfo)
        }
    }
}

extension NotificationCenter.Backport.MessageIdentifier
where Self == NotificationCenter.Backport.BaseMessageIdentifier<NSFontCollection.Backport.DidChangeMessage> {
    /// The identifier of `NSFontCollection.Backport.DidChangeMessage`.
    @_disfavoredOverload
    public static var didChange: Self { .init() }
}

#endif
