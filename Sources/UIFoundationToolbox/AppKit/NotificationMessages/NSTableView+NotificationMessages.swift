#if canImport(AppKit) && !targetEnvironment(macCatalyst)

import AppKit
import FoundationToolbox

// AppKit's predefined `NSTableView` messages. The conventions every file in `NotificationMessages/`
// follows are noted in `Shared/NotificationMessages.swift`.
//
// The two selection messages carry nothing but the table view and go through AppKit's internal
// `StandardNSTableViewMessage`, reproduced here under AppKit's name. The two column messages read the
// user info, every value required, under string keys AppKit spells out rather than SDK constants.
//
// `NSOutlineView` declares a message under each of these four names too. On an outline view the
// shorthand matches both and is ambiguous -- in AppKit's own API as well -- so name the type there.

extension NSTableView {
    /// Backports of the messages AppKit declares on `NSTableView` from macOS 27. See
    /// `NotificationCenter.Backport`.
    public enum Backport {}
}

/// The messages whose only property is the table view, read from the notification's object.
protocol StandardNSTableViewMessage: NotificationCenter.Backport.MainActorMessage where Subject == NSTableView {
    var tableView: NSTableView { get }
    init(tableView: NSTableView)
}

extension StandardNSTableViewMessage {
    @MainActor
    public static func makeMessage(_ notification: Notification) -> Self? {
        guard let tableView = notification.object as? NSTableView else {
            return nil
        }
        return Self(tableView: tableView)
    }

    @MainActor
    public static func makeNotification(_ message: Self) -> Notification {
        Notification(name: name, object: message.tableView, userInfo: nil)
    }
}

extension NSTableView.Backport {
    /// A message that a table view sends after its selection changes.
    public struct SelectionDidChangeMessage: NotificationCenter.Backport.MainActorMessage, StandardNSTableViewMessage {
        public typealias Subject = NSTableView

        public static var name: Notification.Name {
            NSTableView.selectionDidChangeNotification
        }

        /// The table view whose selection changed.
        public var tableView: NSTableView

        public init(tableView: NSTableView) {
            self.tableView = tableView
        }
    }

    /// A message that a table view sends while its selection is changing.
    public struct SelectionIsChangingMessage: NotificationCenter.Backport.MainActorMessage, StandardNSTableViewMessage {
        public typealias Subject = NSTableView

        public static var name: Notification.Name {
            NSTableView.selectionIsChangingNotification
        }

        /// The table view whose selection is changing.
        public var tableView: NSTableView

        public init(tableView: NSTableView) {
            self.tableView = tableView
        }
    }

    /// A message that a table view sends when a column moves.
    public struct ColumnDidMoveMessage: NotificationCenter.Backport.MainActorMessage {
        public typealias Subject = NSTableView

        public static var name: Notification.Name {
            NSTableView.columnDidMoveNotification
        }

        /// The table view in which the column moved.
        public var tableView: NSTableView

        /// The column's index before it moved.
        public var oldColumn: Int

        /// The column's index after it moved.
        public var newColumn: Int

        public init(tableView: NSTableView, oldColumn: Int, newColumn: Int) {
            self.tableView = tableView
            self.oldColumn = oldColumn
            self.newColumn = newColumn
        }

        @MainActor
        public static func makeMessage(_ notification: Notification) -> Self? {
            guard let tableView = notification.object as? NSTableView,
                  let userInfo = notification.userInfo,
                  let oldColumn = userInfo["NSOldColumn"] as? Int,
                  let newColumn = userInfo["NSNewColumn"] as? Int
            else {
                return nil
            }
            return Self(tableView: tableView, oldColumn: oldColumn, newColumn: newColumn)
        }

        @MainActor
        public static func makeNotification(_ message: Self) -> Notification {
            Notification(
                name: name,
                object: message.tableView,
                userInfo: ["NSOldColumn": message.oldColumn, "NSNewColumn": message.newColumn]
            )
        }
    }

    /// A message that a table view sends when a column is resized.
    public struct ColumnDidResizeMessage: NotificationCenter.Backport.MainActorMessage {
        public typealias Subject = NSTableView

        public static var name: Notification.Name {
            NSTableView.columnDidResizeNotification
        }

        /// The table view in which the column was resized.
        public var tableView: NSTableView

        /// The column that was resized.
        public var tableColumn: NSTableColumn

        /// The column's width before it was resized.
        public var oldWidth: CGFloat

        public init(tableView: NSTableView, tableColumn: NSTableColumn, oldWidth: CGFloat) {
            self.tableView = tableView
            self.tableColumn = tableColumn
            self.oldWidth = oldWidth
        }

        @MainActor
        public static func makeMessage(_ notification: Notification) -> Self? {
            guard let tableView = notification.object as? NSTableView,
                  let userInfo = notification.userInfo,
                  let tableColumn = userInfo["NSTableColumn"] as? NSTableColumn,
                  let oldWidth = userInfo["NSOldWidth"] as? CGFloat
            else {
                return nil
            }
            return Self(tableView: tableView, tableColumn: tableColumn, oldWidth: oldWidth)
        }

        @MainActor
        public static func makeNotification(_ message: Self) -> Notification {
            Notification(
                name: name,
                object: message.tableView,
                userInfo: ["NSTableColumn": message.tableColumn, "NSOldWidth": message.oldWidth]
            )
        }
    }
}

extension NotificationCenter.Backport.MessageIdentifier
where Self == NotificationCenter.Backport.BaseMessageIdentifier<NSTableView.Backport.SelectionDidChangeMessage> {
    /// The identifier of `NSTableView.Backport.SelectionDidChangeMessage`.
    @_disfavoredOverload
    public static var selectionDidChange: Self { .init() }
}

extension NotificationCenter.Backport.MessageIdentifier
where Self == NotificationCenter.Backport.BaseMessageIdentifier<NSTableView.Backport.SelectionIsChangingMessage> {
    /// The identifier of `NSTableView.Backport.SelectionIsChangingMessage`.
    @_disfavoredOverload
    public static var selectionIsChanging: Self { .init() }
}

extension NotificationCenter.Backport.MessageIdentifier
where Self == NotificationCenter.Backport.BaseMessageIdentifier<NSTableView.Backport.ColumnDidMoveMessage> {
    /// The identifier of `NSTableView.Backport.ColumnDidMoveMessage`.
    @_disfavoredOverload
    public static var columnDidMove: Self { .init() }
}

extension NotificationCenter.Backport.MessageIdentifier
where Self == NotificationCenter.Backport.BaseMessageIdentifier<NSTableView.Backport.ColumnDidResizeMessage> {
    /// The identifier of `NSTableView.Backport.ColumnDidResizeMessage`.
    @_disfavoredOverload
    public static var columnDidResize: Self { .init() }
}

#endif
