#if canImport(AppKit) && !targetEnvironment(macCatalyst)

import AppKit
import FoundationToolbox

// AppKit's predefined `NSComboBox` messages. The conventions every file in `NotificationMessages/`
// follows are noted in `Shared/NotificationMessages.swift`.
//
// All four carry nothing but the combo box, which is the notification's object, and AppKit implements
// them through one internal protocol, `SimpleNSComboBoxMessage`, reproduced here under AppKit's name.

extension NSComboBox {
    /// Backports of the messages AppKit declares on `NSComboBox` from macOS 27. See
    /// `NotificationCenter.Backport`.
    public enum Backport {}
}

/// The messages whose only property is the combo box, read from the notification's object.
protocol SimpleNSComboBoxMessage: NotificationCenter.Backport.MainActorMessage where Subject == NSComboBox {
    var comboBox: NSComboBox { get }
    init(comboBox: NSComboBox)
}

extension SimpleNSComboBoxMessage {
    @MainActor
    public static func makeMessage(_ notification: Notification) -> Self? {
        guard let comboBox = notification.object as? NSComboBox else {
            return nil
        }
        return Self(comboBox: comboBox)
    }

    @MainActor
    public static func makeNotification(_ message: Self) -> Notification {
        Notification(name: name, object: message.comboBox, userInfo: nil)
    }
}

extension NSComboBox.Backport {
    /// A message that a combo box sends after the selection in its pop-up list changes.
    public struct SelectionDidChangeMessage: NotificationCenter.Backport.MainActorMessage, SimpleNSComboBoxMessage {
        public typealias Subject = NSComboBox

        public static var name: Notification.Name {
            NSComboBox.selectionDidChangeNotification
        }

        /// The combo box whose selection changed.
        public var comboBox: NSComboBox

        public init(comboBox: NSComboBox) {
            self.comboBox = comboBox
        }
    }

    /// A message that a combo box sends while the selection in its pop-up list is changing.
    public struct SelectionIsChangingMessage: NotificationCenter.Backport.MainActorMessage, SimpleNSComboBoxMessage {
        public typealias Subject = NSComboBox

        public static var name: Notification.Name {
            NSComboBox.selectionIsChangingNotification
        }

        /// The combo box whose selection is changing.
        public var comboBox: NSComboBox

        public init(comboBox: NSComboBox) {
            self.comboBox = comboBox
        }
    }

    /// A message that a combo box sends when its pop-up list is about to be dismissed.
    public struct WillDismissMessage: NotificationCenter.Backport.MainActorMessage, SimpleNSComboBoxMessage {
        public typealias Subject = NSComboBox

        public static var name: Notification.Name {
            NSComboBox.willDismissNotification
        }

        /// The combo box whose pop-up list is about to be dismissed.
        public var comboBox: NSComboBox

        public init(comboBox: NSComboBox) {
            self.comboBox = comboBox
        }
    }

    /// A message that a combo box sends when its pop-up list is about to be displayed.
    public struct WillPopUpMessage: NotificationCenter.Backport.MainActorMessage, SimpleNSComboBoxMessage {
        public typealias Subject = NSComboBox

        public static var name: Notification.Name {
            NSComboBox.willPopUpNotification
        }

        /// The combo box whose pop-up list is about to be displayed.
        public var comboBox: NSComboBox

        public init(comboBox: NSComboBox) {
            self.comboBox = comboBox
        }
    }
}

extension NotificationCenter.Backport.MessageIdentifier
where Self == NotificationCenter.Backport.BaseMessageIdentifier<NSComboBox.Backport.SelectionDidChangeMessage> {
    /// The identifier of `NSComboBox.Backport.SelectionDidChangeMessage`.
    @_disfavoredOverload
    public static var selectionDidChange: Self { .init() }
}

extension NotificationCenter.Backport.MessageIdentifier
where Self == NotificationCenter.Backport.BaseMessageIdentifier<NSComboBox.Backport.SelectionIsChangingMessage> {
    /// The identifier of `NSComboBox.Backport.SelectionIsChangingMessage`.
    @_disfavoredOverload
    public static var selectionIsChanging: Self { .init() }
}

extension NotificationCenter.Backport.MessageIdentifier
where Self == NotificationCenter.Backport.BaseMessageIdentifier<NSComboBox.Backport.WillDismissMessage> {
    /// The identifier of `NSComboBox.Backport.WillDismissMessage`.
    @_disfavoredOverload
    public static var willDismiss: Self { .init() }
}

extension NotificationCenter.Backport.MessageIdentifier
where Self == NotificationCenter.Backport.BaseMessageIdentifier<NSComboBox.Backport.WillPopUpMessage> {
    /// The identifier of `NSComboBox.Backport.WillPopUpMessage`.
    @_disfavoredOverload
    public static var willPopUp: Self { .init() }
}

#endif
