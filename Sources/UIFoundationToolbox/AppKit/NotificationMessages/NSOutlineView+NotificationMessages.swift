#if canImport(AppKit) && !targetEnvironment(macCatalyst)

import AppKit
import FoundationToolbox

// AppKit's predefined `NSOutlineView` messages. The conventions every file in `NotificationMessages/`
// follows are noted in `Shared/NotificationMessages.swift`.
//
// AppKit implements them three ways, reproduced here: the two selection messages carry only the outline
// view (`StandardNSOutlineViewMessage`), the four item messages also carry the item, taken from the user
// info as it is, with no cast (`NSOutlineViewItemMessage`), and the two column messages read the same
// keys as `NSTableView`'s. The internal protocols keep AppKit's names.
//
// `NSTableView` declares a message under each of the selection and column names too. On an outline view
// the shorthand matches both and is ambiguous -- in AppKit's own API as well -- so name the type there.

extension NSOutlineView {
    /// Backports of the messages AppKit declares on `NSOutlineView` from macOS 27. See
    /// `NotificationCenter.Backport`.
    public enum Backport {}
}

/// The messages whose only property is the outline view, read from the notification's object.
protocol StandardNSOutlineViewMessage: NotificationCenter.Backport.MainActorMessage where Subject == NSOutlineView {
    var outlineView: NSOutlineView { get }
    init(outlineView: NSOutlineView)
}

extension StandardNSOutlineViewMessage {
    @MainActor
    public static func makeMessage(_ notification: Notification) -> Self? {
        guard let outlineView = notification.object as? NSOutlineView else {
            return nil
        }
        return Self(outlineView: outlineView)
    }

    @MainActor
    public static func makeNotification(_ message: Self) -> Notification {
        Notification(name: name, object: message.outlineView, userInfo: nil)
    }
}

/// The messages that carry the outline view and the item being expanded or collapsed, both required.
/// The item is whatever the user info holds; only its absence fails the conversion.
protocol NSOutlineViewItemMessage: NotificationCenter.Backport.MainActorMessage where Subject == NSOutlineView {
    var outlineView: NSOutlineView { get }
    var item: Any { get }
    init(outlineView: NSOutlineView, item: Any)
}

extension NSOutlineViewItemMessage {
    @MainActor
    public static func makeMessage(_ notification: Notification) -> Self? {
        guard let outlineView = notification.object as? NSOutlineView,
              let userInfo = notification.userInfo,
              let item = userInfo["NSObject"]
        else {
            return nil
        }
        return Self(outlineView: outlineView, item: item)
    }

    @MainActor
    public static func makeNotification(_ message: Self) -> Notification {
        Notification(name: name, object: message.outlineView, userInfo: ["NSObject": message.item])
    }
}

extension NSOutlineView.Backport {
    /// A message that an outline view sends after its selection changes.
    public struct SelectionDidChangeMessage: NotificationCenter.Backport.MainActorMessage, StandardNSOutlineViewMessage {
        public typealias Subject = NSOutlineView

        public static var name: Notification.Name {
            NSOutlineView.selectionDidChangeNotification
        }

        /// The outline view whose selection changed.
        public var outlineView: NSOutlineView

        public init(outlineView: NSOutlineView) {
            self.outlineView = outlineView
        }
    }

    /// A message that an outline view sends while its selection is changing.
    public struct SelectionIsChangingMessage: NotificationCenter.Backport.MainActorMessage, StandardNSOutlineViewMessage {
        public typealias Subject = NSOutlineView

        public static var name: Notification.Name {
            NSOutlineView.selectionIsChangingNotification
        }

        /// The outline view whose selection is changing.
        public var outlineView: NSOutlineView

        public init(outlineView: NSOutlineView) {
            self.outlineView = outlineView
        }
    }

    /// A message that an outline view sends when a column moves.
    public struct ColumnDidMoveMessage: NotificationCenter.Backport.MainActorMessage {
        public typealias Subject = NSOutlineView

        public static var name: Notification.Name {
            NSOutlineView.columnDidMoveNotification
        }

        /// The outline view in which the column moved.
        public var outlineView: NSOutlineView

        /// The column's index before it moved.
        public var oldColumn: Int

        /// The column's index after it moved.
        public var newColumn: Int

        public init(outlineView: NSOutlineView, oldColumn: Int, newColumn: Int) {
            self.outlineView = outlineView
            self.oldColumn = oldColumn
            self.newColumn = newColumn
        }

        @MainActor
        public static func makeMessage(_ notification: Notification) -> Self? {
            guard let outlineView = notification.object as? NSOutlineView,
                  let userInfo = notification.userInfo,
                  let oldColumn = userInfo["NSOldColumn"] as? Int,
                  let newColumn = userInfo["NSNewColumn"] as? Int
            else {
                return nil
            }
            return Self(outlineView: outlineView, oldColumn: oldColumn, newColumn: newColumn)
        }

        @MainActor
        public static func makeNotification(_ message: Self) -> Notification {
            Notification(
                name: name,
                object: message.outlineView,
                userInfo: ["NSOldColumn": message.oldColumn, "NSNewColumn": message.newColumn]
            )
        }
    }

    /// A message that an outline view sends when a column is resized.
    public struct ColumnDidResizeMessage: NotificationCenter.Backport.MainActorMessage {
        public typealias Subject = NSOutlineView

        public static var name: Notification.Name {
            NSOutlineView.columnDidResizeNotification
        }

        /// The outline view in which the column was resized.
        public var outlineView: NSOutlineView

        /// The column that was resized.
        public var tableColumn: NSTableColumn

        /// The column's width before it was resized.
        public var oldWidth: CGFloat

        public init(outlineView: NSOutlineView, tableColumn: NSTableColumn, oldWidth: CGFloat) {
            self.outlineView = outlineView
            self.tableColumn = tableColumn
            self.oldWidth = oldWidth
        }

        @MainActor
        public static func makeMessage(_ notification: Notification) -> Self? {
            guard let outlineView = notification.object as? NSOutlineView,
                  let userInfo = notification.userInfo,
                  let tableColumn = userInfo["NSTableColumn"] as? NSTableColumn,
                  let oldWidth = userInfo["NSOldWidth"] as? CGFloat
            else {
                return nil
            }
            return Self(outlineView: outlineView, tableColumn: tableColumn, oldWidth: oldWidth)
        }

        @MainActor
        public static func makeNotification(_ message: Self) -> Notification {
            Notification(
                name: name,
                object: message.outlineView,
                userInfo: ["NSTableColumn": message.tableColumn, "NSOldWidth": message.oldWidth]
            )
        }
    }

    /// A message that an outline view sends when an item is about to expand.
    public struct ItemWillExpandMessage: NotificationCenter.Backport.MainActorMessage, NSOutlineViewItemMessage {
        public typealias Subject = NSOutlineView

        public static var name: Notification.Name {
            NSOutlineView.itemWillExpandNotification
        }

        /// The outline view in which the item is about to expand.
        public var outlineView: NSOutlineView

        /// The item that is about to expand.
        public var item: Any

        public init(outlineView: NSOutlineView, item: Any) {
            self.outlineView = outlineView
            self.item = item
        }
    }

    /// A message that an outline view sends after an item expands.
    public struct ItemDidExpandMessage: NotificationCenter.Backport.MainActorMessage, NSOutlineViewItemMessage {
        public typealias Subject = NSOutlineView

        public static var name: Notification.Name {
            NSOutlineView.itemDidExpandNotification
        }

        /// The outline view in which the item expanded.
        public var outlineView: NSOutlineView

        /// The item that expanded.
        public var item: Any

        public init(outlineView: NSOutlineView, item: Any) {
            self.outlineView = outlineView
            self.item = item
        }
    }

    /// A message that an outline view sends when an item is about to collapse.
    public struct ItemWillCollapseMessage: NotificationCenter.Backport.MainActorMessage, NSOutlineViewItemMessage {
        public typealias Subject = NSOutlineView

        public static var name: Notification.Name {
            NSOutlineView.itemWillCollapseNotification
        }

        /// The outline view in which the item is about to collapse.
        public var outlineView: NSOutlineView

        /// The item that is about to collapse.
        public var item: Any

        public init(outlineView: NSOutlineView, item: Any) {
            self.outlineView = outlineView
            self.item = item
        }
    }

    /// A message that an outline view sends after an item collapses.
    public struct ItemDidCollapseMessage: NotificationCenter.Backport.MainActorMessage, NSOutlineViewItemMessage {
        public typealias Subject = NSOutlineView

        public static var name: Notification.Name {
            NSOutlineView.itemDidCollapseNotification
        }

        /// The outline view in which the item collapsed.
        public var outlineView: NSOutlineView

        /// The item that collapsed.
        public var item: Any

        public init(outlineView: NSOutlineView, item: Any) {
            self.outlineView = outlineView
            self.item = item
        }
    }
}

extension NotificationCenter.Backport.MessageIdentifier
where Self == NotificationCenter.Backport.BaseMessageIdentifier<NSOutlineView.Backport.SelectionDidChangeMessage> {
    /// The identifier of `NSOutlineView.Backport.SelectionDidChangeMessage`.
    @_disfavoredOverload
    public static var selectionDidChange: Self { .init() }
}

extension NotificationCenter.Backport.MessageIdentifier
where Self == NotificationCenter.Backport.BaseMessageIdentifier<NSOutlineView.Backport.SelectionIsChangingMessage> {
    /// The identifier of `NSOutlineView.Backport.SelectionIsChangingMessage`.
    @_disfavoredOverload
    public static var selectionIsChanging: Self { .init() }
}

extension NotificationCenter.Backport.MessageIdentifier
where Self == NotificationCenter.Backport.BaseMessageIdentifier<NSOutlineView.Backport.ColumnDidMoveMessage> {
    /// The identifier of `NSOutlineView.Backport.ColumnDidMoveMessage`.
    @_disfavoredOverload
    public static var columnDidMove: Self { .init() }
}

extension NotificationCenter.Backport.MessageIdentifier
where Self == NotificationCenter.Backport.BaseMessageIdentifier<NSOutlineView.Backport.ColumnDidResizeMessage> {
    /// The identifier of `NSOutlineView.Backport.ColumnDidResizeMessage`.
    @_disfavoredOverload
    public static var columnDidResize: Self { .init() }
}

extension NotificationCenter.Backport.MessageIdentifier
where Self == NotificationCenter.Backport.BaseMessageIdentifier<NSOutlineView.Backport.ItemWillExpandMessage> {
    /// The identifier of `NSOutlineView.Backport.ItemWillExpandMessage`.
    @_disfavoredOverload
    public static var itemWillExpand: Self { .init() }
}

extension NotificationCenter.Backport.MessageIdentifier
where Self == NotificationCenter.Backport.BaseMessageIdentifier<NSOutlineView.Backport.ItemDidExpandMessage> {
    /// The identifier of `NSOutlineView.Backport.ItemDidExpandMessage`.
    @_disfavoredOverload
    public static var itemDidExpand: Self { .init() }
}

extension NotificationCenter.Backport.MessageIdentifier
where Self == NotificationCenter.Backport.BaseMessageIdentifier<NSOutlineView.Backport.ItemWillCollapseMessage> {
    /// The identifier of `NSOutlineView.Backport.ItemWillCollapseMessage`.
    @_disfavoredOverload
    public static var itemWillCollapse: Self { .init() }
}

extension NotificationCenter.Backport.MessageIdentifier
where Self == NotificationCenter.Backport.BaseMessageIdentifier<NSOutlineView.Backport.ItemDidCollapseMessage> {
    /// The identifier of `NSOutlineView.Backport.ItemDidCollapseMessage`.
    @_disfavoredOverload
    public static var itemDidCollapse: Self { .init() }
}

#endif
