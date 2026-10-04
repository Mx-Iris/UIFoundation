#if canImport(AppKit) && !targetEnvironment(macCatalyst)

import AppKit
import FoundationToolbox

// AppKit's predefined `NSTextInputContext` message. The conventions every file in
// `NotificationMessages/` follows are noted in `Shared/NotificationMessages.swift`.

extension NSTextInputContext {
    /// Backports of the messages AppKit declares on `NSTextInputContext` from macOS 27. See
    /// `NotificationCenter.Backport`.
    public enum Backport {}
}

extension NSTextInputContext.Backport {
    /// A message that the system sends when the selected keyboard input source changes.
    public struct KeyboardSelectionDidChangeMessage: NotificationCenter.Backport.MainActorMessage, PropertylessMainActorMessage {
        public typealias Subject = NSTextInputContext

        public static var name: Notification.Name {
            NSTextInputContext.keyboardSelectionDidChangeNotification
        }

        public init() {}
    }
}

extension NotificationCenter.Backport.MessageIdentifier
where Self == NotificationCenter.Backport.BaseMessageIdentifier<NSTextInputContext.Backport.KeyboardSelectionDidChangeMessage> {
    /// The identifier of `NSTextInputContext.Backport.KeyboardSelectionDidChangeMessage`.
    @_disfavoredOverload
    public static var keyboardSelectionDidChange: Self { .init() }
}

#endif
