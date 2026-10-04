#if canImport(UIKit) && !os(watchOS)

import UIKit
import FoundationToolbox

// UIKit's predefined `UIFocusSystem` messages. The conventions every file in `NotificationMessages/`
// follows are noted in `Shared/NotificationMessages.swift`.
//
// Only the focus system, the notification's object, is required. The update context and the animation
// coordinator come from the user info and are `nil` when missing, and `makeNotification(_:)` writes
// their keys even then, holding the `nil` itself -- both as UIKit does.

extension UIFocusSystem {
    /// Backports of the messages UIKit declares on `UIFocusSystem` from iOS 26. See
    /// `NotificationCenter.Backport`.
    public enum Backport {}
}

extension UIFocusSystem.Backport {
    /// A message that a focus system sends when a focus update occurs.
    public struct DidUpdateMessage: NotificationCenter.Backport.MainActorMessage {
        public typealias Subject = UIFocusSystem

        public static var name: Notification.Name {
            UIFocusSystem.didUpdateNotification
        }

        /// The context of the focus update.
        public var updateContext: UIFocusUpdateContext?

        /// The coordinator that animates the focus update.
        public var animationCoordinator: UIFocusAnimationCoordinator?

        /// The focus system that performed the update.
        public var focusSystem: UIFocusSystem

        public init(updateContext: UIFocusUpdateContext?, animationCoordinator: UIFocusAnimationCoordinator?, focusSystem: UIFocusSystem) {
            self.updateContext = updateContext
            self.animationCoordinator = animationCoordinator
            self.focusSystem = focusSystem
        }

        @MainActor
        public static func makeMessage(_ notification: Notification) -> Self? {
            guard let focusSystem = notification.object as? UIFocusSystem else {
                return nil
            }
            return Self(
                updateContext: notification.userInfo?[UIFocusSystem.focusUpdateContextUserInfoKey] as? UIFocusUpdateContext,
                animationCoordinator: notification.userInfo?[UIFocusSystem.animationCoordinatorUserInfoKey] as? UIFocusAnimationCoordinator,
                focusSystem: focusSystem
            )
        }

        @MainActor
        public static func makeNotification(_ message: Self) -> Notification {
            Notification(
                name: name,
                object: message.focusSystem,
                userInfo: [
                    UIFocusSystem.focusUpdateContextUserInfoKey: message.updateContext as Any,
                    UIFocusSystem.animationCoordinatorUserInfoKey: message.animationCoordinator as Any,
                ]
            )
        }
    }

    /// A message that a focus system sends when a focus movement fails.
    public struct MovementDidFailMessage: NotificationCenter.Backport.MainActorMessage {
        public typealias Subject = UIFocusSystem

        public static var name: Notification.Name {
            UIFocusSystem.movementDidFailNotification
        }

        /// The context of the failed focus update.
        public var updateContext: UIFocusUpdateContext?

        /// The focus system in which the movement failed.
        public var focusSystem: UIFocusSystem

        public init(updateContext: UIFocusUpdateContext?, focusSystem: UIFocusSystem) {
            self.updateContext = updateContext
            self.focusSystem = focusSystem
        }

        @MainActor
        public static func makeMessage(_ notification: Notification) -> Self? {
            guard let focusSystem = notification.object as? UIFocusSystem else {
                return nil
            }
            return Self(
                updateContext: notification.userInfo?[UIFocusSystem.focusUpdateContextUserInfoKey] as? UIFocusUpdateContext,
                focusSystem: focusSystem
            )
        }

        @MainActor
        public static func makeNotification(_ message: Self) -> Notification {
            Notification(
                name: name,
                object: message.focusSystem,
                userInfo: [UIFocusSystem.focusUpdateContextUserInfoKey: message.updateContext as Any]
            )
        }
    }
}

extension NotificationCenter.Backport.MessageIdentifier
where Self == NotificationCenter.Backport.BaseMessageIdentifier<UIFocusSystem.Backport.DidUpdateMessage> {
    /// The identifier of `UIFocusSystem.Backport.DidUpdateMessage`.
    @_disfavoredOverload
    public static var didUpdate: Self { .init() }
}

extension NotificationCenter.Backport.MessageIdentifier
where Self == NotificationCenter.Backport.BaseMessageIdentifier<UIFocusSystem.Backport.MovementDidFailMessage> {
    /// The identifier of `UIFocusSystem.Backport.MovementDidFailMessage`.
    @_disfavoredOverload
    public static var movementDidFail: Self { .init() }
}

#endif
