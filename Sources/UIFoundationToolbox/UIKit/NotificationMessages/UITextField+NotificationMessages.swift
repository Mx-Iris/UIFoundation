#if canImport(UIKit) && !os(watchOS)

import UIKit
import FoundationToolbox

// UIKit's predefined `UITextField` messages. The conventions every file in `NotificationMessages/`
// follows are noted in `Shared/NotificationMessages.swift`.
//
// The text field is the notification's object, and a notification without one converts to `nil`.
// `TextDidEndEditingMessage` also reads a reason, which never fails the conversion; see there why it
// comes out `nil` for the notifications UIKit itself posts.

extension UITextField {
    /// Backports of the messages UIKit declares on `UITextField` from iOS 26. See
    /// `NotificationCenter.Backport`.
    public enum Backport {}
}

/// The messages whose only property is the text field, read from the notification's object.
protocol StandardUITextFieldMessage: NotificationCenter.Backport.MainActorMessage where Subject == UITextField {
    var textField: UITextField { get }
    init(textField: UITextField)
}

extension StandardUITextFieldMessage {
    @MainActor
    public static func makeMessage(_ notification: Notification) -> Self? {
        guard let textField = notification.object as? UITextField else {
            return nil
        }
        return Self(textField: textField)
    }

    @MainActor
    public static func makeNotification(_ message: Self) -> Notification {
        Notification(name: name, object: message.textField, userInfo: nil)
    }
}

extension UITextField.Backport {
    /// A message that a text field sends when an editing session begins.
    public struct TextDidBeginEditingMessage: NotificationCenter.Backport.MainActorMessage, StandardUITextFieldMessage {
        public typealias Subject = UITextField

        public static var name: Notification.Name {
            UITextField.textDidBeginEditingNotification
        }

        /// The text field in which editing began.
        public var textField: UITextField

        public init(textField: UITextField) {
            self.textField = textField
        }
    }

    /// A message that a text field sends when its text changes.
    public struct TextDidChangeMessage: NotificationCenter.Backport.MainActorMessage, StandardUITextFieldMessage {
        public typealias Subject = UITextField

        public static var name: Notification.Name {
            UITextField.textDidChangeNotification
        }

        /// The text field whose text changed.
        public var textField: UITextField

        public init(textField: UITextField) {
            self.textField = textField
        }
    }

    /// A message that a text field sends when an editing session ends.
    ///
    /// `reason` is read with a cast straight to `UITextField.DidEndEditingReason`, as UIKit's own
    /// implementation reads it. UIKit posts the reason as an `NSNumber`, which does not cast to the
    /// enumeration, so for the notifications UIKit itself posts `reason` is `nil`.
    public struct TextDidEndEditingMessage: NotificationCenter.Backport.MainActorMessage {
        public typealias Subject = UITextField

        public static var name: Notification.Name {
            UITextField.textDidEndEditingNotification
        }

        /// The reason editing ended.
        public var reason: UITextField.DidEndEditingReason?

        /// The text field in which editing ended.
        public var textField: UITextField

        public init(reason: UITextField.DidEndEditingReason?, textField: UITextField) {
            self.reason = reason
            self.textField = textField
        }

        @MainActor
        public static func makeMessage(_ notification: Notification) -> Self? {
            guard let textField = notification.object as? UITextField else {
                return nil
            }
            let reason = notification.userInfo?[UITextField.didEndEditingReasonUserInfoKey] as? UITextField.DidEndEditingReason
            return Self(reason: reason, textField: textField)
        }

        @MainActor
        public static func makeNotification(_ message: Self) -> Notification {
            // The key is written even when there is no reason, holding the `nil` itself, as UIKit does.
            Notification(
                name: name,
                object: message.textField,
                userInfo: [UITextField.didEndEditingReasonUserInfoKey: message.reason as Any]
            )
        }
    }
}

extension NotificationCenter.Backport.MessageIdentifier
where Self == NotificationCenter.Backport.BaseMessageIdentifier<UITextField.Backport.TextDidBeginEditingMessage> {
    /// The identifier of `UITextField.Backport.TextDidBeginEditingMessage`.
    @_disfavoredOverload
    public static var textDidBeginEditing: Self { .init() }
}

extension NotificationCenter.Backport.MessageIdentifier
where Self == NotificationCenter.Backport.BaseMessageIdentifier<UITextField.Backport.TextDidChangeMessage> {
    /// The identifier of `UITextField.Backport.TextDidChangeMessage`.
    @_disfavoredOverload
    public static var textDidChange: Self { .init() }
}

extension NotificationCenter.Backport.MessageIdentifier
where Self == NotificationCenter.Backport.BaseMessageIdentifier<UITextField.Backport.TextDidEndEditingMessage> {
    /// The identifier of `UITextField.Backport.TextDidEndEditingMessage`.
    @_disfavoredOverload
    public static var textDidEndEditing: Self { .init() }
}

#endif
