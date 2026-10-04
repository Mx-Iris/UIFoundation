#if canImport(AppKit) && !targetEnvironment(macCatalyst)

import AppKit
import FoundationToolbox

// AppKit's predefined `NSPopUpButton` message. The conventions every file in `NotificationMessages/`
// follows are noted in `Shared/NotificationMessages.swift`.

extension NSPopUpButton {
    /// Backports of the messages AppKit declares on `NSPopUpButton` from macOS 27. See
    /// `NotificationCenter.Backport`.
    public enum Backport {}
}

extension NSPopUpButton.Backport {
    /// A message that a pop-up button sends when it's about to display its menu.
    public struct WillPopUpMessage: NotificationCenter.Backport.MainActorMessage {
        public typealias Subject = NSPopUpButton

        public static var name: Notification.Name {
            NSPopUpButton.willPopUpNotification
        }

        /// The pop-up button that is about to display its menu.
        public var popUpButton: NSPopUpButton

        public init(popUpButton: NSPopUpButton) {
            self.popUpButton = popUpButton
        }

        @MainActor
        public static func makeMessage(_ notification: Notification) -> Self? {
            guard let popUpButton = notification.object as? NSPopUpButton else {
                return nil
            }
            return Self(popUpButton: popUpButton)
        }

        @MainActor
        public static func makeNotification(_ message: Self) -> Notification {
            Notification(name: name, object: message.popUpButton, userInfo: nil)
        }
    }
}

extension NotificationCenter.Backport.MessageIdentifier
where Self == NotificationCenter.Backport.BaseMessageIdentifier<NSPopUpButton.Backport.WillPopUpMessage> {
    /// The identifier of `NSPopUpButton.Backport.WillPopUpMessage`.
    @_disfavoredOverload
    public static var willPopUp: Self { .init() }
}

#endif
