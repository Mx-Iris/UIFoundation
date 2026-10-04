#if canImport(UIKit) && !os(watchOS)

import UIKit
import FoundationToolbox

// UIKit's predefined `UIPasteboard` messages. The conventions every file in `NotificationMessages/`
// follows are noted in `Shared/NotificationMessages.swift`.
//
// Neither sets an object when it makes a notification -- not the pasteboard either.

@available(tvOS, unavailable)
extension UIPasteboard {
    /// Backports of the messages UIKit declares on `UIPasteboard` from iOS 26. See
    /// `NotificationCenter.Backport`.
    public enum Backport {}
}

@available(tvOS, unavailable)
extension UIPasteboard.Backport {
    /// A message that a pasteboard sends when its contents change.
    ///
    /// Both lists are required: a notification that carries only one of them converts to `nil`, not
    /// to a message with an empty list.
    public struct ChangedMessage: NotificationCenter.Backport.MainActorMessage {
        public typealias Subject = UIPasteboard

        public static var name: Notification.Name {
            UIPasteboard.changedNotification
        }

        /// The representation types the change added.
        public var typesAdded: [String]

        /// The representation types the change removed.
        public var typesRemoved: [String]

        public init(typesAdded: [String], typesRemoved: [String]) {
            self.typesAdded = typesAdded
            self.typesRemoved = typesRemoved
        }

        @MainActor
        public static func makeMessage(_ notification: Notification) -> Self? {
            guard let userInfo = notification.userInfo,
                  let typesAdded = userInfo[UIPasteboard.changedTypesAddedUserInfoKey] as? [String],
                  let typesRemoved = userInfo[UIPasteboard.changedTypesRemovedUserInfoKey] as? [String]
            else {
                return nil
            }
            return Self(typesAdded: typesAdded, typesRemoved: typesRemoved)
        }

        @MainActor
        public static func makeNotification(_ message: Self) -> Notification {
            Notification(
                name: name,
                object: nil,
                userInfo: [
                    UIPasteboard.changedTypesAddedUserInfoKey: message.typesAdded,
                    UIPasteboard.changedTypesRemovedUserInfoKey: message.typesRemoved,
                ]
            )
        }
    }

    /// A message that a pasteboard sends just before an app removes it.
    public struct RemovedMessage: NotificationCenter.Backport.MainActorMessage, PropertylessMainActorMessage {
        public typealias Subject = UIPasteboard

        public static var name: Notification.Name {
            UIPasteboard.removedNotification
        }

        public init() {}
    }
}

@available(tvOS, unavailable)
extension NotificationCenter.Backport.MessageIdentifier
where Self == NotificationCenter.Backport.BaseMessageIdentifier<UIPasteboard.Backport.ChangedMessage> {
    /// The identifier of `UIPasteboard.Backport.ChangedMessage`.
    @_disfavoredOverload
    public static var changed: Self { .init() }
}

@available(tvOS, unavailable)
extension NotificationCenter.Backport.MessageIdentifier
where Self == NotificationCenter.Backport.BaseMessageIdentifier<UIPasteboard.Backport.RemovedMessage> {
    /// The identifier of `UIPasteboard.Backport.RemovedMessage`.
    @_disfavoredOverload
    public static var removed: Self { .init() }
}

#endif
