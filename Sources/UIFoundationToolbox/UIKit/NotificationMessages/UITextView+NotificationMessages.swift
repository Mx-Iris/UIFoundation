#if canImport(UIKit) && !os(watchOS)

import UIKit
import FoundationToolbox

// UIKit's predefined `UITextView` messages. The conventions every file in `NotificationMessages/`
// follows are noted in `Shared/NotificationMessages.swift`.
//
// All three carry the text view the notification is posted from, and UIKit implements them the same
// way: the text view is the notification's object, and a notification without one converts to `nil`.

extension UITextView {
    /// Backports of the messages UIKit declares on `UITextView` from iOS 26. See
    /// `NotificationCenter.Backport`.
    public enum Backport {}
}

/// The messages whose only property is the text view, read from the notification's object.
protocol StandardUITextViewMessage: NotificationCenter.Backport.MainActorMessage where Subject == UITextView {
    var textView: UITextView { get }
    init(textView: UITextView)
}

extension StandardUITextViewMessage {
    @MainActor
    public static func makeMessage(_ notification: Notification) -> Self? {
        guard let textView = notification.object as? UITextView else {
            return nil
        }
        return Self(textView: textView)
    }

    @MainActor
    public static func makeNotification(_ message: Self) -> Notification {
        Notification(name: name, object: message.textView, userInfo: nil)
    }
}

extension UITextView.Backport {
    /// A message that a text view sends when an editing session begins.
    public struct TextDidBeginEditingMessage: NotificationCenter.Backport.MainActorMessage, StandardUITextViewMessage {
        public typealias Subject = UITextView

        public static var name: Notification.Name {
            UITextView.textDidBeginEditingNotification
        }

        /// The text view in which editing began.
        public var textView: UITextView

        public init(textView: UITextView) {
            self.textView = textView
        }
    }

    /// A message that a text view sends when its text changes.
    public struct TextDidChangeMessage: NotificationCenter.Backport.MainActorMessage, StandardUITextViewMessage {
        public typealias Subject = UITextView

        public static var name: Notification.Name {
            UITextView.textDidChangeNotification
        }

        /// The text view whose text changed.
        public var textView: UITextView

        public init(textView: UITextView) {
            self.textView = textView
        }
    }

    /// A message that a text view sends when an editing session ends.
    public struct TextDidEndEditingMessage: NotificationCenter.Backport.MainActorMessage, StandardUITextViewMessage {
        public typealias Subject = UITextView

        public static var name: Notification.Name {
            UITextView.textDidEndEditingNotification
        }

        /// The text view in which editing ended.
        public var textView: UITextView

        public init(textView: UITextView) {
            self.textView = textView
        }
    }
}

extension NotificationCenter.Backport.MessageIdentifier
where Self == NotificationCenter.Backport.BaseMessageIdentifier<UITextView.Backport.TextDidBeginEditingMessage> {
    /// The identifier of `UITextView.Backport.TextDidBeginEditingMessage`.
    @_disfavoredOverload
    public static var textDidBeginEditing: Self { .init() }
}

extension NotificationCenter.Backport.MessageIdentifier
where Self == NotificationCenter.Backport.BaseMessageIdentifier<UITextView.Backport.TextDidChangeMessage> {
    /// The identifier of `UITextView.Backport.TextDidChangeMessage`.
    @_disfavoredOverload
    public static var textDidChange: Self { .init() }
}

extension NotificationCenter.Backport.MessageIdentifier
where Self == NotificationCenter.Backport.BaseMessageIdentifier<UITextView.Backport.TextDidEndEditingMessage> {
    /// The identifier of `UITextView.Backport.TextDidEndEditingMessage`.
    @_disfavoredOverload
    public static var textDidEndEditing: Self { .init() }
}

#endif
