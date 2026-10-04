#if canImport(UIKit) && !os(watchOS)

import UIKit
import FoundationToolbox

// UIKit's predefined `UIDocument` message. The conventions every file in `NotificationMessages/`
// follows are noted in `Shared/NotificationMessages.swift`.
//
// UIKit's `DidMoveToWritableLocationMessage` is not here: its notification only exists from iOS 26,
// where UIKit's own message is available too.

@available(tvOS, unavailable)
extension UIDocument {
    /// Backports of the messages UIKit declares on `UIDocument` from iOS 26. See
    /// `NotificationCenter.Backport`.
    public enum Backport {}
}

@available(tvOS, unavailable)
extension UIDocument.Backport {
    /// A message that a document sends when its state changes.
    public struct StateChangedMessage: NotificationCenter.Backport.MainActorMessage {
        public typealias Subject = UIDocument

        public static var name: Notification.Name {
            UIDocument.stateChangedNotification
        }

        /// The document whose state changed.
        public var document: UIDocument

        public init(document: UIDocument) {
            self.document = document
        }

        @MainActor
        public static func makeMessage(_ notification: Notification) -> Self? {
            guard let document = notification.object as? UIDocument else {
                return nil
            }
            return Self(document: document)
        }

        @MainActor
        public static func makeNotification(_ message: Self) -> Notification {
            Notification(name: name, object: message.document, userInfo: nil)
        }
    }
}

@available(tvOS, unavailable)
extension NotificationCenter.Backport.MessageIdentifier
where Self == NotificationCenter.Backport.BaseMessageIdentifier<UIDocument.Backport.StateChangedMessage> {
    /// The identifier of `UIDocument.Backport.StateChangedMessage`.
    @_disfavoredOverload
    public static var stateChanged: Self { .init() }
}

#endif
