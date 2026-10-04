#if canImport(AppKit) && !targetEnvironment(macCatalyst)

import AppKit
import FoundationToolbox

// AppKit's predefined `NSMenu` messages. The conventions every file in `NotificationMessages/` follows
// are noted in `Shared/NotificationMessages.swift`.
//
// AppKit implements them through two internal protocols, reproduced here under AppKit's names: four
// carry only the menu, the notification's object (`StandardNSMenuMessage`), and three also carry the
// index of the item concerned (`NSMenuItemIndexMessage`), read from the user info as an `Int` and written
// back as a Swift `Int` rather than an `NSNumber`.

extension NSMenu {
    /// Backports of the messages AppKit declares on `NSMenu` from macOS 27. See
    /// `NotificationCenter.Backport`.
    public enum Backport {}
}

/// The messages whose only property is the menu, read from the notification's object.
protocol StandardNSMenuMessage: NotificationCenter.Backport.MainActorMessage where Subject == NSMenu {
    var menu: NSMenu { get }
    init(menu: NSMenu)
}

extension StandardNSMenuMessage {
    @MainActor
    public static func makeMessage(_ notification: Notification) -> Self? {
        guard let menu = notification.object as? NSMenu else {
            return nil
        }
        return Self(menu: menu)
    }

    @MainActor
    public static func makeNotification(_ message: Self) -> Notification {
        Notification(name: name, object: message.menu, userInfo: nil)
    }
}

/// The messages that carry the menu and the index of an item in it, both required.
protocol NSMenuItemIndexMessage: NotificationCenter.Backport.MainActorMessage where Subject == NSMenu {
    var menu: NSMenu { get }
    var itemIndex: Int { get }
    init(menu: NSMenu, itemIndex: Int)
}

extension NSMenuItemIndexMessage {
    @MainActor
    public static func makeMessage(_ notification: Notification) -> Self? {
        guard let menu = notification.object as? NSMenu,
              let userInfo = notification.userInfo,
              let itemIndex = userInfo["NSMenuItemIndex"] as? Int
        else {
            return nil
        }
        return Self(menu: menu, itemIndex: itemIndex)
    }

    @MainActor
    public static func makeNotification(_ message: Self) -> Notification {
        Notification(name: name, object: message.menu, userInfo: ["NSMenuItemIndex": message.itemIndex])
    }
}

extension NSMenu.Backport {
    /// A message that a menu sends when it's about to send an action message for one of its items.
    public struct WillSendActionMessage: NotificationCenter.Backport.MainActorMessage, StandardNSMenuMessage {
        public typealias Subject = NSMenu

        public static var name: Notification.Name {
            NSMenu.willSendActionNotification
        }

        /// The menu whose item is about to send its action.
        public var menu: NSMenu

        public init(menu: NSMenu) {
            self.menu = menu
        }
    }

    /// A message that a menu sends after one of its items sends its action message.
    public struct DidSendActionMessage: NotificationCenter.Backport.MainActorMessage, StandardNSMenuMessage {
        public typealias Subject = NSMenu

        public static var name: Notification.Name {
            NSMenu.didSendActionNotification
        }

        /// The menu whose item sent its action.
        public var menu: NSMenu

        public init(menu: NSMenu) {
            self.menu = menu
        }
    }

    /// A message that a menu sends when an item is added to it.
    public struct DidAddItemMessage: NotificationCenter.Backport.MainActorMessage, NSMenuItemIndexMessage {
        public typealias Subject = NSMenu

        public static var name: Notification.Name {
            NSMenu.didAddItemNotification
        }

        /// The menu that the item was added to.
        public var menu: NSMenu

        /// The index of the added item.
        public var itemIndex: Int

        public init(menu: NSMenu, itemIndex: Int) {
            self.menu = menu
            self.itemIndex = itemIndex
        }
    }

    /// A message that a menu sends when an item is removed from it.
    public struct DidRemoveItemMessage: NotificationCenter.Backport.MainActorMessage, NSMenuItemIndexMessage {
        public typealias Subject = NSMenu

        public static var name: Notification.Name {
            NSMenu.didRemoveItemNotification
        }

        /// The menu that the item was removed from.
        public var menu: NSMenu

        /// The index the removed item had.
        public var itemIndex: Int

        public init(menu: NSMenu, itemIndex: Int) {
            self.menu = menu
            self.itemIndex = itemIndex
        }
    }

    /// A message that a menu sends when one of its items changes visually.
    public struct DidChangeItemMessage: NotificationCenter.Backport.MainActorMessage, NSMenuItemIndexMessage {
        public typealias Subject = NSMenu

        public static var name: Notification.Name {
            NSMenu.didChangeItemNotification
        }

        /// The menu whose item changed.
        public var menu: NSMenu

        /// The index of the item that changed.
        public var itemIndex: Int

        public init(menu: NSMenu, itemIndex: Int) {
            self.menu = menu
            self.itemIndex = itemIndex
        }
    }

    /// A message that a menu sends when it begins tracking.
    public struct DidBeginTrackingMessage: NotificationCenter.Backport.MainActorMessage, StandardNSMenuMessage {
        public typealias Subject = NSMenu

        public static var name: Notification.Name {
            NSMenu.didBeginTrackingNotification
        }

        /// The menu that began tracking.
        public var menu: NSMenu

        public init(menu: NSMenu) {
            self.menu = menu
        }
    }

    /// A message that a menu sends when it stops tracking.
    public struct DidEndTrackingMessage: NotificationCenter.Backport.MainActorMessage, StandardNSMenuMessage {
        public typealias Subject = NSMenu

        public static var name: Notification.Name {
            NSMenu.didEndTrackingNotification
        }

        /// The menu that stopped tracking.
        public var menu: NSMenu

        public init(menu: NSMenu) {
            self.menu = menu
        }
    }
}

extension NotificationCenter.Backport.MessageIdentifier
where Self == NotificationCenter.Backport.BaseMessageIdentifier<NSMenu.Backport.WillSendActionMessage> {
    /// The identifier of `NSMenu.Backport.WillSendActionMessage`.
    @_disfavoredOverload
    public static var willSendAction: Self { .init() }
}

extension NotificationCenter.Backport.MessageIdentifier
where Self == NotificationCenter.Backport.BaseMessageIdentifier<NSMenu.Backport.DidSendActionMessage> {
    /// The identifier of `NSMenu.Backport.DidSendActionMessage`.
    @_disfavoredOverload
    public static var didSendAction: Self { .init() }
}

extension NotificationCenter.Backport.MessageIdentifier
where Self == NotificationCenter.Backport.BaseMessageIdentifier<NSMenu.Backport.DidAddItemMessage> {
    /// The identifier of `NSMenu.Backport.DidAddItemMessage`.
    @_disfavoredOverload
    public static var didAddItem: Self { .init() }
}

extension NotificationCenter.Backport.MessageIdentifier
where Self == NotificationCenter.Backport.BaseMessageIdentifier<NSMenu.Backport.DidRemoveItemMessage> {
    /// The identifier of `NSMenu.Backport.DidRemoveItemMessage`.
    @_disfavoredOverload
    public static var didRemoveItem: Self { .init() }
}

extension NotificationCenter.Backport.MessageIdentifier
where Self == NotificationCenter.Backport.BaseMessageIdentifier<NSMenu.Backport.DidChangeItemMessage> {
    /// The identifier of `NSMenu.Backport.DidChangeItemMessage`.
    @_disfavoredOverload
    public static var didChangeItem: Self { .init() }
}

extension NotificationCenter.Backport.MessageIdentifier
where Self == NotificationCenter.Backport.BaseMessageIdentifier<NSMenu.Backport.DidBeginTrackingMessage> {
    /// The identifier of `NSMenu.Backport.DidBeginTrackingMessage`.
    @_disfavoredOverload
    public static var didBeginTracking: Self { .init() }
}

extension NotificationCenter.Backport.MessageIdentifier
where Self == NotificationCenter.Backport.BaseMessageIdentifier<NSMenu.Backport.DidEndTrackingMessage> {
    /// The identifier of `NSMenu.Backport.DidEndTrackingMessage`.
    @_disfavoredOverload
    public static var didEndTracking: Self { .init() }
}

#endif
