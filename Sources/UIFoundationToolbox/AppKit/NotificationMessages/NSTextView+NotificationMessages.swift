#if canImport(AppKit) && !targetEnvironment(macCatalyst)

import AppKit
import FoundationToolbox

// AppKit's predefined `NSTextView` messages. The conventions every file in `NotificationMessages/`
// follows are noted in `Shared/NotificationMessages.swift`.
//
// The three editing messages -- `DidBeginEditingMessage`, `DidChangeMessage`, `DidEndEditingMessage` --
// are really `NSText`'s: their subject is `NSText`, their names are `NSText`'s, and any `NSText` passes,
// field editors included. The first two carry only the text and go through AppKit's internal
// `StandardNSTextMessage`, reproduced here under AppKit's name.
//
// The three messages with optional values -- the end-editing movement, the notifying text views, the old
// selection -- treat them alike: a missing value never fails the conversion, and making a notification
// writes only the values that are not `nil`, with no user info at all when none is set.

extension NSTextView {
    /// Backports of the messages AppKit declares on `NSTextView` from macOS 27. See
    /// `NotificationCenter.Backport`.
    public enum Backport {}
}

/// The messages whose only property is the text object, read from the notification's object.
protocol StandardNSTextMessage: NotificationCenter.Backport.MainActorMessage where Subject == NSText {
    var text: NSText { get }
    init(text: NSText)
}

extension StandardNSTextMessage {
    @MainActor
    public static func makeMessage(_ notification: Notification) -> Self? {
        guard let text = notification.object as? NSText else {
            return nil
        }
        return Self(text: text)
    }

    @MainActor
    public static func makeNotification(_ message: Self) -> Notification {
        Notification(name: name, object: message.text, userInfo: nil)
    }
}

extension NSTextView.Backport {
    /// A message that a text object sends when it begins any editing change.
    public struct DidBeginEditingMessage: NotificationCenter.Backport.MainActorMessage, StandardNSTextMessage {
        public typealias Subject = NSText

        public static var name: Notification.Name {
            NSText.didBeginEditingNotification
        }

        /// The text object that began editing.
        public var text: NSText

        public init(text: NSText) {
            self.text = text
        }
    }

    /// A message that a text object sends when its text changes.
    public struct DidChangeMessage: NotificationCenter.Backport.MainActorMessage, StandardNSTextMessage {
        public typealias Subject = NSText

        public static var name: Notification.Name {
            NSText.didChangeNotification
        }

        /// The text object whose text changed.
        public var text: NSText

        public init(text: NSText) {
            self.text = text
        }
    }

    /// A message that a text object sends when it ends editing.
    public struct DidEndEditingMessage: NotificationCenter.Backport.MainActorMessage {
        public typealias Subject = NSText

        public static var name: Notification.Name {
            NSText.didEndEditingNotification
        }

        /// The text object that ended editing.
        public var text: NSText

        /// The movement that ended editing, as a raw `NSTextMovement` value.
        public var textMovement: Int?

        public init(text: NSText, textMovement: Int? = nil) {
            self.text = text
            self.textMovement = textMovement
        }

        @MainActor
        public static func makeMessage(_ notification: Notification) -> Self? {
            guard let text = notification.object as? NSText else {
                return nil
            }
            return Self(text: text, textMovement: notification.userInfo?[NSText.movementUserInfoKey] as? Int)
        }

        @MainActor
        public static func makeNotification(_ message: Self) -> Notification {
            var userInfo: [String: Any] = [:]
            if let textMovement = message.textMovement {
                userInfo[NSText.movementUserInfoKey] = textMovement
            }
            return Notification(name: name, object: message.text, userInfo: userInfo.isEmpty ? nil : userInfo)
        }
    }

    /// A message that a text view sends when the text view that posts notifications for its text system is
    /// about to change.
    public struct WillChangeNotifyingTextViewMessage: NotificationCenter.Backport.MainActorMessage {
        public typealias Subject = NSTextView

        public static var name: Notification.Name {
            NSTextView.willChangeNotifyingTextViewNotification
        }

        /// The text view that posts the message.
        public var textView: NSTextView

        /// The text view that posted notifications until now.
        public var oldNotifyingTextView: NSTextView?

        /// The text view that posts notifications from now on.
        public var newNotifyingTextView: NSTextView?

        public init(textView: NSTextView, oldNotifyingTextView: NSTextView? = nil, newNotifyingTextView: NSTextView? = nil) {
            self.textView = textView
            self.oldNotifyingTextView = oldNotifyingTextView
            self.newNotifyingTextView = newNotifyingTextView
        }

        @MainActor
        public static func makeMessage(_ notification: Notification) -> Self? {
            guard let textView = notification.object as? NSTextView else {
                return nil
            }
            return Self(
                textView: textView,
                oldNotifyingTextView: notification.userInfo?["NSOldNotifyingTextView"] as? NSTextView,
                newNotifyingTextView: notification.userInfo?["NSNewNotifyingTextView"] as? NSTextView
            )
        }

        @MainActor
        public static func makeNotification(_ message: Self) -> Notification {
            var userInfo: [String: Any] = [:]
            if let oldNotifyingTextView = message.oldNotifyingTextView {
                userInfo["NSOldNotifyingTextView"] = oldNotifyingTextView
            }
            if let newNotifyingTextView = message.newNotifyingTextView {
                userInfo["NSNewNotifyingTextView"] = newNotifyingTextView
            }
            return Notification(name: name, object: message.textView, userInfo: userInfo.isEmpty ? nil : userInfo)
        }
    }

    /// A message that a text view sends when its selection changes.
    ///
    /// Like AppKit's, it has no public initializer: messages of this type come from notifications.
    public struct DidChangeSelectionMessage: NotificationCenter.Backport.MainActorMessage {
        public typealias Subject = NSTextView

        public static var name: Notification.Name {
            NSTextView.didChangeSelectionNotification
        }

        /// The text view whose selection changed.
        public var textView: NSTextView

        /// The character range that was selected before the change.
        public var oldSelectedCharacterRange: NSRange?

        init(textView: NSTextView, oldSelectedCharacterRange: NSRange?) {
            self.textView = textView
            self.oldSelectedCharacterRange = oldSelectedCharacterRange
        }

        @MainActor
        public static func makeMessage(_ notification: Notification) -> Self? {
            guard let textView = notification.object as? NSTextView else {
                return nil
            }
            let oldSelectedCharacterRange = notification.userInfo?["NSOldSelectedCharacterRange"] as? NSValue
            return Self(textView: textView, oldSelectedCharacterRange: oldSelectedCharacterRange?.rangeValue)
        }

        @MainActor
        public static func makeNotification(_ message: Self) -> Notification {
            var userInfo: [String: Any] = [:]
            if let oldSelectedCharacterRange = message.oldSelectedCharacterRange {
                userInfo["NSOldSelectedCharacterRange"] = NSValue(range: oldSelectedCharacterRange)
            }
            return Notification(name: name, object: message.textView, userInfo: userInfo.isEmpty ? nil : userInfo)
        }
    }

    /// A message that a text view sends when its typing attributes change.
    public struct DidChangeTypingAttributesMessage: NotificationCenter.Backport.MainActorMessage {
        public typealias Subject = NSTextView

        public static var name: Notification.Name {
            NSTextView.didChangeTypingAttributesNotification
        }

        /// The text view whose typing attributes changed.
        public var textView: NSTextView

        public init(textView: NSTextView) {
            self.textView = textView
        }

        @MainActor
        public static func makeMessage(_ notification: Notification) -> Self? {
            guard let textView = notification.object as? NSTextView else {
                return nil
            }
            return Self(textView: textView)
        }

        @MainActor
        public static func makeNotification(_ message: Self) -> Notification {
            Notification(name: name, object: message.textView, userInfo: nil)
        }
    }
}

extension NotificationCenter.Backport.MessageIdentifier
where Self == NotificationCenter.Backport.BaseMessageIdentifier<NSTextView.Backport.DidBeginEditingMessage> {
    /// The identifier of `NSTextView.Backport.DidBeginEditingMessage`.
    @_disfavoredOverload
    public static var didBeginEditing: Self { .init() }
}

extension NotificationCenter.Backport.MessageIdentifier
where Self == NotificationCenter.Backport.BaseMessageIdentifier<NSTextView.Backport.DidChangeMessage> {
    /// The identifier of `NSTextView.Backport.DidChangeMessage`.
    @_disfavoredOverload
    public static var didChange: Self { .init() }
}

extension NotificationCenter.Backport.MessageIdentifier
where Self == NotificationCenter.Backport.BaseMessageIdentifier<NSTextView.Backport.DidEndEditingMessage> {
    /// The identifier of `NSTextView.Backport.DidEndEditingMessage`.
    @_disfavoredOverload
    public static var didEndEditing: Self { .init() }
}

extension NotificationCenter.Backport.MessageIdentifier
where Self == NotificationCenter.Backport.BaseMessageIdentifier<NSTextView.Backport.WillChangeNotifyingTextViewMessage> {
    /// The identifier of `NSTextView.Backport.WillChangeNotifyingTextViewMessage`.
    @_disfavoredOverload
    public static var willChangeNotifyingTextView: Self { .init() }
}

extension NotificationCenter.Backport.MessageIdentifier
where Self == NotificationCenter.Backport.BaseMessageIdentifier<NSTextView.Backport.DidChangeSelectionMessage> {
    /// The identifier of `NSTextView.Backport.DidChangeSelectionMessage`.
    @_disfavoredOverload
    public static var didChangeSelection: Self { .init() }
}

extension NotificationCenter.Backport.MessageIdentifier
where Self == NotificationCenter.Backport.BaseMessageIdentifier<NSTextView.Backport.DidChangeTypingAttributesMessage> {
    /// The identifier of `NSTextView.Backport.DidChangeTypingAttributesMessage`.
    @_disfavoredOverload
    public static var didChangeTypingAttributes: Self { .init() }
}

#endif
