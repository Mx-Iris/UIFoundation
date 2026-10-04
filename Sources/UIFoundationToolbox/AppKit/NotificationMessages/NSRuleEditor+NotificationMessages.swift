#if canImport(AppKit) && !targetEnvironment(macCatalyst)

import AppKit
import FoundationToolbox

// AppKit's predefined `NSRuleEditor` message. The conventions every file in `NotificationMessages/`
// follows are noted in `Shared/NotificationMessages.swift`.
//
// AppKit implements it through an internal protocol of its own, `StandardNSRuleEditorMessage`,
// reproduced here under AppKit's name: the rule editor is the notification's object, and a notification
// without one converts to `nil`.

extension NSRuleEditor {
    /// Backports of the messages AppKit declares on `NSRuleEditor` from macOS 27. See
    /// `NotificationCenter.Backport`.
    public enum Backport {}
}

/// The messages whose only property is the rule editor, read from the notification's object.
protocol StandardNSRuleEditorMessage: NotificationCenter.Backport.MainActorMessage where Subject == NSRuleEditor {
    var ruleEditor: NSRuleEditor { get }
    init(ruleEditor: NSRuleEditor)
}

extension StandardNSRuleEditorMessage {
    @MainActor
    public static func makeMessage(_ notification: Notification) -> Self? {
        guard let ruleEditor = notification.object as? NSRuleEditor else {
            return nil
        }
        return Self(ruleEditor: ruleEditor)
    }

    @MainActor
    public static func makeNotification(_ message: Self) -> Notification {
        Notification(name: name, object: message.ruleEditor, userInfo: nil)
    }
}

extension NSRuleEditor.Backport {
    /// A message that a rule editor sends when the number of its rows changes.
    public struct RowsDidChangeMessage: NotificationCenter.Backport.MainActorMessage, StandardNSRuleEditorMessage {
        public typealias Subject = NSRuleEditor

        public static var name: Notification.Name {
            NSRuleEditor.rowsDidChangeNotification
        }

        /// The rule editor whose rows changed.
        public var ruleEditor: NSRuleEditor

        public init(ruleEditor: NSRuleEditor) {
            self.ruleEditor = ruleEditor
        }
    }
}

extension NotificationCenter.Backport.MessageIdentifier
where Self == NotificationCenter.Backport.BaseMessageIdentifier<NSRuleEditor.Backport.RowsDidChangeMessage> {
    /// The identifier of `NSRuleEditor.Backport.RowsDidChangeMessage`.
    @_disfavoredOverload
    public static var rowsDidChange: Self { .init() }
}

#endif
