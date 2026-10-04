#if canImport(UIKit) && !os(watchOS)

import UIKit
import FoundationToolbox

// UIKit's predefined `UITextInputMode` message. The conventions every file in `NotificationMessages/`
// follows are noted in `Shared/NotificationMessages.swift`.

extension UITextInputMode {
    /// Backports of the messages UIKit declares on `UITextInputMode` from iOS 26. See
    /// `NotificationCenter.Backport`.
    public enum Backport {}
}

extension UITextInputMode.Backport {
    /// A message that the system sends when the current input mode changes.
    public struct CurrentInputModeDidChangeMessage: NotificationCenter.Backport.MainActorMessage, PropertylessMainActorMessage {
        public typealias Subject = UITextInputMode

        public static var name: Notification.Name {
            UITextInputMode.currentInputModeDidChangeNotification
        }

        public init() {}
    }
}

extension NotificationCenter.Backport.MessageIdentifier
where Self == NotificationCenter.Backport.BaseMessageIdentifier<UITextInputMode.Backport.CurrentInputModeDidChangeMessage> {
    /// The identifier of `UITextInputMode.Backport.CurrentInputModeDidChangeMessage`.
    @_disfavoredOverload
    public static var currentInputModeDidChange: Self { .init() }
}

#endif
