#if canImport(AppKit) && !targetEnvironment(macCatalyst)

import AppKit
import FoundationToolbox

// AppKit's predefined `NSPopUpButtonCell` message. The conventions every file in `NotificationMessages/`
// follows are noted in `Shared/NotificationMessages.swift`.

extension NSPopUpButtonCell {
    /// Backports of the messages AppKit declares on `NSPopUpButtonCell` from macOS 27. See
    /// `NotificationCenter.Backport`.
    public enum Backport {}
}

extension NSPopUpButtonCell.Backport {
    /// A message that a pop-up button cell sends when it's about to display its menu.
    public struct WillPopUpMessage: NotificationCenter.Backport.MainActorMessage {
        public typealias Subject = NSPopUpButtonCell

        public static var name: Notification.Name {
            NSPopUpButtonCell.willPopUpNotification
        }

        /// The pop-up button cell that is about to display its menu.
        public var popUpButtonCell: NSPopUpButtonCell

        public init(popUpButtonCell: NSPopUpButtonCell) {
            self.popUpButtonCell = popUpButtonCell
        }

        @MainActor
        public static func makeMessage(_ notification: Notification) -> Self? {
            guard let popUpButtonCell = notification.object as? NSPopUpButtonCell else {
                return nil
            }
            return Self(popUpButtonCell: popUpButtonCell)
        }

        @MainActor
        public static func makeNotification(_ message: Self) -> Notification {
            Notification(name: name, object: message.popUpButtonCell, userInfo: nil)
        }
    }
}

extension NotificationCenter.Backport.MessageIdentifier
where Self == NotificationCenter.Backport.BaseMessageIdentifier<NSPopUpButtonCell.Backport.WillPopUpMessage> {
    /// The identifier of `NSPopUpButtonCell.Backport.WillPopUpMessage`.
    @_disfavoredOverload
    public static var willPopUp: Self { .init() }
}

#endif
