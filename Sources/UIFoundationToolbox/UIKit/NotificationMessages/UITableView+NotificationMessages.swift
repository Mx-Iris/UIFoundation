#if canImport(UIKit) && !os(watchOS)

import UIKit
import FoundationToolbox

// UIKit's predefined `UITableView` message. The conventions every file in `NotificationMessages/`
// follows are noted in `Shared/NotificationMessages.swift`.

extension UITableView {
    /// Backports of the messages UIKit declares on `UITableView` from iOS 26. See
    /// `NotificationCenter.Backport`.
    public enum Backport {}
}

extension UITableView.Backport {
    /// A message that a table view sends when its selected row changes.
    public struct SelectionDidChangeMessage: NotificationCenter.Backport.MainActorMessage {
        public typealias Subject = UITableView

        public static var name: Notification.Name {
            UITableView.selectionDidChangeNotification
        }

        /// The table view whose selection changed.
        public var tableView: UITableView

        public init(tableView: UITableView) {
            self.tableView = tableView
        }

        @MainActor
        public static func makeMessage(_ notification: Notification) -> Self? {
            guard let tableView = notification.object as? UITableView else {
                return nil
            }
            return Self(tableView: tableView)
        }

        @MainActor
        public static func makeNotification(_ message: Self) -> Notification {
            Notification(name: name, object: message.tableView, userInfo: nil)
        }
    }
}

extension NotificationCenter.Backport.MessageIdentifier
where Self == NotificationCenter.Backport.BaseMessageIdentifier<UITableView.Backport.SelectionDidChangeMessage> {
    /// The identifier of `UITableView.Backport.SelectionDidChangeMessage`.
    @_disfavoredOverload
    public static var selectionDidChange: Self { .init() }
}

#endif
