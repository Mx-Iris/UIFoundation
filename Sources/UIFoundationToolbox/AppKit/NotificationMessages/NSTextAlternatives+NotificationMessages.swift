#if canImport(AppKit) && !targetEnvironment(macCatalyst)

import AppKit
import FoundationToolbox

// AppKit's predefined `NSTextAlternatives` message. The conventions every file in
// `NotificationMessages/` follows are noted in `Shared/NotificationMessages.swift`.

extension NSTextAlternatives {
    /// Backports of the messages AppKit declares on `NSTextAlternatives` from macOS 27. See
    /// `NotificationCenter.Backport`.
    public enum Backport {}
}

extension NSTextAlternatives.Backport {
    /// A message that a text alternatives object sends when the user selects one of the alternatives.
    ///
    /// Both values are required.
    public struct SelectedAlternativeStringMessage: NotificationCenter.Backport.MainActorMessage {
        public typealias Subject = NSTextAlternatives

        public static var name: Notification.Name {
            NSTextAlternatives.selectedAlternativeStringNotification
        }

        /// The text alternatives object the user selected from.
        public var textAlternatives: NSTextAlternatives

        /// The alternative the user selected.
        public var alternativeString: String

        public init(textAlternatives: NSTextAlternatives, alternativeString: String) {
            self.textAlternatives = textAlternatives
            self.alternativeString = alternativeString
        }

        @MainActor
        public static func makeMessage(_ notification: Notification) -> Self? {
            guard let textAlternatives = notification.object as? NSTextAlternatives,
                  let userInfo = notification.userInfo,
                  let alternativeString = userInfo["NSAlternativeString"] as? String
            else {
                return nil
            }
            return Self(textAlternatives: textAlternatives, alternativeString: alternativeString)
        }

        @MainActor
        public static func makeNotification(_ message: Self) -> Notification {
            Notification(
                name: name,
                object: message.textAlternatives,
                userInfo: ["NSAlternativeString": message.alternativeString]
            )
        }
    }
}

extension NotificationCenter.Backport.MessageIdentifier
where Self == NotificationCenter.Backport.BaseMessageIdentifier<NSTextAlternatives.Backport.SelectedAlternativeStringMessage> {
    /// The identifier of `NSTextAlternatives.Backport.SelectedAlternativeStringMessage`.
    @_disfavoredOverload
    public static var selectedAlternativeString: Self { .init() }
}

#endif
