#if canImport(AppKit) && !targetEnvironment(macCatalyst)

import AppKit
import FoundationToolbox

// AppKit's predefined `NSControl` messages. The conventions every file in `NotificationMessages/`
// follows are noted in `Shared/NotificationMessages.swift`.
//
// All three carry the control, the notification's object, and its field editor, read from the user info
// under the key "NSFieldEditor"; both are required. AppKit implements them through one internal protocol,
// `NSControlFieldEditorMessage`, reproduced here under AppKit's name.

extension NSControl {
    /// Backports of the messages AppKit declares on `NSControl` from macOS 27. See
    /// `NotificationCenter.Backport`.
    public enum Backport {}
}

/// The messages that carry the control and its field editor, both required.
protocol NSControlFieldEditorMessage: NotificationCenter.Backport.MainActorMessage where Subject == NSControl {
    var control: NSControl { get }
    var fieldEditor: NSText { get }
    init(control: NSControl, fieldEditor: NSText)
}

extension NSControlFieldEditorMessage {
    @MainActor
    public static func makeMessage(_ notification: Notification) -> Self? {
        guard let control = notification.object as? NSControl,
              let userInfo = notification.userInfo,
              let fieldEditor = userInfo["NSFieldEditor"] as? NSText
        else {
            return nil
        }
        return Self(control: control, fieldEditor: fieldEditor)
    }

    @MainActor
    public static func makeNotification(_ message: Self) -> Notification {
        Notification(name: name, object: message.control, userInfo: ["NSFieldEditor": message.fieldEditor])
    }
}

extension NSControl.Backport {
    /// A message that a control sends when it begins editing text.
    public struct TextDidBeginEditingMessage: NotificationCenter.Backport.MainActorMessage, NSControlFieldEditorMessage {
        public typealias Subject = NSControl

        public static var name: Notification.Name {
            NSControl.textDidBeginEditingNotification
        }

        /// The control whose text began to be edited.
        public var control: NSControl

        /// The field editor that edits the control's text.
        public var fieldEditor: NSText

        public init(control: NSControl, fieldEditor: NSText) {
            self.control = control
            self.fieldEditor = fieldEditor
        }
    }

    /// A message that a control sends when the text in its field editor changes.
    public struct TextDidChangeMessage: NotificationCenter.Backport.MainActorMessage, NSControlFieldEditorMessage {
        public typealias Subject = NSControl

        public static var name: Notification.Name {
            NSControl.textDidChangeNotification
        }

        /// The control whose text changed.
        public var control: NSControl

        /// The field editor that edits the control's text.
        public var fieldEditor: NSText

        public init(control: NSControl, fieldEditor: NSText) {
            self.control = control
            self.fieldEditor = fieldEditor
        }
    }

    /// A message that a control sends when it ends editing text.
    public struct TextDidEndEditingMessage: NotificationCenter.Backport.MainActorMessage, NSControlFieldEditorMessage {
        public typealias Subject = NSControl

        public static var name: Notification.Name {
            NSControl.textDidEndEditingNotification
        }

        /// The control whose text ended being edited.
        public var control: NSControl

        /// The field editor that edited the control's text.
        public var fieldEditor: NSText

        public init(control: NSControl, fieldEditor: NSText) {
            self.control = control
            self.fieldEditor = fieldEditor
        }
    }
}

extension NotificationCenter.Backport.MessageIdentifier
where Self == NotificationCenter.Backport.BaseMessageIdentifier<NSControl.Backport.TextDidBeginEditingMessage> {
    /// The identifier of `NSControl.Backport.TextDidBeginEditingMessage`.
    @_disfavoredOverload
    public static var textDidBeginEditing: Self { .init() }
}

extension NotificationCenter.Backport.MessageIdentifier
where Self == NotificationCenter.Backport.BaseMessageIdentifier<NSControl.Backport.TextDidChangeMessage> {
    /// The identifier of `NSControl.Backport.TextDidChangeMessage`.
    @_disfavoredOverload
    public static var textDidChange: Self { .init() }
}

extension NotificationCenter.Backport.MessageIdentifier
where Self == NotificationCenter.Backport.BaseMessageIdentifier<NSControl.Backport.TextDidEndEditingMessage> {
    /// The identifier of `NSControl.Backport.TextDidEndEditingMessage`.
    @_disfavoredOverload
    public static var textDidEndEditing: Self { .init() }
}

#endif
