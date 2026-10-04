#if canImport(UIKit) && !os(watchOS)

import UIKit
import FoundationToolbox

// UIKit's predefined `UIPointerLockState` message. The conventions every file in
// `NotificationMessages/` follows are noted in `Shared/NotificationMessages.swift`.
//
// The lock state is the notification's object and the scene comes from the user info; both are
// required.

@available(iOS 14.0, macCatalyst 14.0, *)
@available(tvOS, unavailable)
extension UIPointerLockState {
    /// Backports of the messages UIKit declares on `UIPointerLockState` from iOS 26. See
    /// `NotificationCenter.Backport`.
    public enum Backport {}
}

@available(iOS 14.0, macCatalyst 14.0, *)
@available(tvOS, unavailable)
extension UIPointerLockState.Backport {
    /// A message that a pointer lock state sends when the lock status of a scene changes.
    public struct DidChangeMessage: NotificationCenter.Backport.MainActorMessage {
        public typealias Subject = UIPointerLockState

        public static var name: Notification.Name {
            UIPointerLockState.didChangeNotification
        }

        /// The scene whose pointer lock status changed.
        public var scene: UIScene

        /// The pointer lock state that changed.
        public var pointerLockState: UIPointerLockState

        public init(scene: UIScene, pointerLockState: UIPointerLockState) {
            self.scene = scene
            self.pointerLockState = pointerLockState
        }

        @MainActor
        public static func makeMessage(_ notification: Notification) -> Self? {
            guard let scene = notification.userInfo?[UIPointerLockState.sceneUserInfoKey] as? UIScene,
                  let pointerLockState = notification.object as? UIPointerLockState
            else {
                return nil
            }
            return Self(scene: scene, pointerLockState: pointerLockState)
        }

        @MainActor
        public static func makeNotification(_ message: Self) -> Notification {
            Notification(
                name: name,
                object: message.pointerLockState,
                userInfo: [UIPointerLockState.sceneUserInfoKey: message.scene]
            )
        }
    }
}

@available(iOS 14.0, macCatalyst 14.0, *)
@available(tvOS, unavailable)
extension NotificationCenter.Backport.MessageIdentifier
where Self == NotificationCenter.Backport.BaseMessageIdentifier<UIPointerLockState.Backport.DidChangeMessage> {
    /// The identifier of `UIPointerLockState.Backport.DidChangeMessage`.
    @_disfavoredOverload
    public static var didChange: Self { .init() }
}

#endif
