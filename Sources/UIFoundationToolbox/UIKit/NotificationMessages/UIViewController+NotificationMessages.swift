#if canImport(UIKit) && !os(watchOS)

import UIKit
import FoundationToolbox

// UIKit's predefined `UIViewController` message. The conventions every file in
// `NotificationMessages/` follows are noted in `Shared/NotificationMessages.swift`.

extension UIViewController {
    /// Backports of the messages UIKit declares on `UIViewController` from iOS 26. See
    /// `NotificationCenter.Backport`.
    public enum Backport {}
}

extension UIViewController.Backport {
    /// A message that a view controller sends when a split view controller expands or collapses.
    public struct ShowDetailTargetDidChangeMessage: NotificationCenter.Backport.MainActorMessage {
        public typealias Subject = UIViewController

        public static var name: Notification.Name {
            UIViewController.showDetailTargetDidChangeNotification
        }

        /// The view controller whose target for showing detail changed.
        public var viewController: UIViewController

        public init(viewController: UIViewController) {
            self.viewController = viewController
        }

        @MainActor
        public static func makeMessage(_ notification: Notification) -> Self? {
            guard let viewController = notification.object as? UIViewController else {
                return nil
            }
            return Self(viewController: viewController)
        }

        @MainActor
        public static func makeNotification(_ message: Self) -> Notification {
            Notification(name: name, object: message.viewController, userInfo: nil)
        }
    }
}

extension NotificationCenter.Backport.MessageIdentifier
where Self == NotificationCenter.Backport.BaseMessageIdentifier<UIViewController.Backport.ShowDetailTargetDidChangeMessage> {
    /// The identifier of `UIViewController.Backport.ShowDetailTargetDidChangeMessage`.
    @_disfavoredOverload
    public static var showDetailTargetDidChange: Self { .init() }
}

#endif
