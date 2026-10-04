#if os(macOS) || targetEnvironment(macCatalyst)

#if targetEnvironment(macCatalyst)
import UIKit
#else
import AppKit
#endif
import FoundationToolbox

// AppKit's predefined `NSToolbar` messages, on macOS and on Mac Catalyst alike. The conventions every
// file in `NotificationMessages/` follows are noted in `Shared/NotificationMessages.swift`.
//
// Every value is required. The keys are `NSToolbarUserInfoKey`s, and making a notification stores them as
// such, as AppKit does. The SDK's constants for them need macOS 13 (`NSToolbarItemKey`) and 15
// (`NSToolbarNewIndexKey`), so they are built from their raw values here, which gives the same keys.

extension NSToolbar {
    /// Backports of the messages AppKit declares on `NSToolbar` from macOS 27. See
    /// `NotificationCenter.Backport`.
    public enum Backport {}
}

extension NSToolbar.Backport {
    /// The value of `NSToolbarItemKey`.
    static let itemUserInfoKey = NSToolbarUserInfoKey(rawValue: "item")

    /// The value of `NSToolbarNewIndexKey`.
    static let newIndexUserInfoKey = NSToolbarUserInfoKey(rawValue: "newIndex")

    /// A message that a toolbar sends when it's about to add an item.
    public struct WillAddItemMessage: NotificationCenter.Backport.MainActorMessage {
        public typealias Subject = NSToolbar

        public static var name: Notification.Name {
            NSToolbar.willAddItemNotification
        }

        /// The toolbar the item is about to be added to.
        public var toolbar: NSToolbar

        /// The item that is about to be added.
        public var item: NSToolbarItem

        /// The index the item will have.
        public var newIndex: Int

        public init(toolbar: NSToolbar, item: NSToolbarItem, newIndex: Int) {
            self.toolbar = toolbar
            self.item = item
            self.newIndex = newIndex
        }

        @MainActor
        public static func makeMessage(_ notification: Notification) -> Self? {
            guard let toolbar = notification.object as? NSToolbar,
                  let userInfo = notification.userInfo,
                  let item = userInfo[NSToolbar.Backport.itemUserInfoKey] as? NSToolbarItem,
                  let newIndex = userInfo[NSToolbar.Backport.newIndexUserInfoKey] as? Int
            else {
                return nil
            }
            return Self(toolbar: toolbar, item: item, newIndex: newIndex)
        }

        @MainActor
        public static func makeNotification(_ message: Self) -> Notification {
            Notification(
                name: name,
                object: message.toolbar,
                userInfo: [
                    NSToolbar.Backport.itemUserInfoKey: message.item,
                    NSToolbar.Backport.newIndexUserInfoKey: message.newIndex,
                ]
            )
        }
    }

    /// A message that a toolbar sends after it removes an item.
    public struct DidRemoveItemMessage: NotificationCenter.Backport.MainActorMessage {
        public typealias Subject = NSToolbar

        public static var name: Notification.Name {
            NSToolbar.didRemoveItemNotification
        }

        /// The toolbar the item was removed from.
        public var toolbar: NSToolbar

        /// The item that was removed.
        public var item: NSToolbarItem

        public init(toolbar: NSToolbar, item: NSToolbarItem) {
            self.toolbar = toolbar
            self.item = item
        }

        @MainActor
        public static func makeMessage(_ notification: Notification) -> Self? {
            guard let toolbar = notification.object as? NSToolbar,
                  let userInfo = notification.userInfo,
                  let item = userInfo[NSToolbar.Backport.itemUserInfoKey] as? NSToolbarItem
            else {
                return nil
            }
            return Self(toolbar: toolbar, item: item)
        }

        @MainActor
        public static func makeNotification(_ message: Self) -> Notification {
            Notification(name: name, object: message.toolbar, userInfo: [NSToolbar.Backport.itemUserInfoKey: message.item])
        }
    }
}

extension NotificationCenter.Backport.MessageIdentifier
where Self == NotificationCenter.Backport.BaseMessageIdentifier<NSToolbar.Backport.WillAddItemMessage> {
    /// The identifier of `NSToolbar.Backport.WillAddItemMessage`.
    @_disfavoredOverload
    public static var willAddItem: Self { .init() }
}

extension NotificationCenter.Backport.MessageIdentifier
where Self == NotificationCenter.Backport.BaseMessageIdentifier<NSToolbar.Backport.DidRemoveItemMessage> {
    /// The identifier of `NSToolbar.Backport.DidRemoveItemMessage`.
    @_disfavoredOverload
    public static var didRemoveItem: Self { .init() }
}

#endif
