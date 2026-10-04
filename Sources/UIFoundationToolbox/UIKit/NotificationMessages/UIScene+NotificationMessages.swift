#if canImport(UIKit) && !os(watchOS)

import UIKit
import FoundationToolbox

// UIKit's predefined `UIScene` messages. The conventions every file in `NotificationMessages/`
// follows are noted in `Shared/NotificationMessages.swift`.
//
// All six carry the scene the notification is posted from, and UIKit implements them the same way:
// the scene is the notification's object, and a notification without one converts to `nil`.

extension UIScene {
    /// Backports of the messages UIKit declares on `UIScene` from iOS 26. See
    /// `NotificationCenter.Backport`.
    public enum Backport {}
}

/// The messages whose only property is the scene, read from the notification's object.
protocol StandardUISceneMessage: NotificationCenter.Backport.MainActorMessage where Subject == UIScene {
    var scene: UIScene { get }
    init(scene: UIScene)
}

extension StandardUISceneMessage {
    @MainActor
    public static func makeMessage(_ notification: Notification) -> Self? {
        guard let scene = notification.object as? UIScene else {
            return nil
        }
        return Self(scene: scene)
    }

    @MainActor
    public static func makeNotification(_ message: Self) -> Notification {
        Notification(name: name, object: message.scene, userInfo: nil)
    }
}

extension UIScene.Backport {
    /// A message that the system sends when it adds a scene to the app.
    public struct WillConnectMessage: NotificationCenter.Backport.MainActorMessage, StandardUISceneMessage {
        public typealias Subject = UIScene

        public static var name: Notification.Name {
            UIScene.willConnectNotification
        }

        /// The scene the system added.
        public var scene: UIScene

        public init(scene: UIScene) {
            self.scene = scene
        }
    }

    /// A message that the system sends when a scene is about to begin running in the foreground and become visible.
    public struct WillEnterForegroundMessage: NotificationCenter.Backport.MainActorMessage, StandardUISceneMessage {
        public typealias Subject = UIScene

        public static var name: Notification.Name {
            UIScene.willEnterForegroundNotification
        }

        /// The scene that is entering the foreground.
        public var scene: UIScene

        public init(scene: UIScene) {
            self.scene = scene
        }
    }

    /// A message that the system sends when a scene becomes active and responds to user events.
    public struct DidActivateMessage: NotificationCenter.Backport.MainActorMessage, StandardUISceneMessage {
        public typealias Subject = UIScene

        public static var name: Notification.Name {
            UIScene.didActivateNotification
        }

        /// The scene that became active.
        public var scene: UIScene

        public init(scene: UIScene) {
            self.scene = scene
        }
    }

    /// A message that the system sends when a scene is about to resign the active state and stop responding to user events.
    public struct WillDeactivateMessage: NotificationCenter.Backport.MainActorMessage, StandardUISceneMessage {
        public typealias Subject = UIScene

        public static var name: Notification.Name {
            UIScene.willDeactivateNotification
        }

        /// The scene that is resigning the active state.
        public var scene: UIScene

        public init(scene: UIScene) {
            self.scene = scene
        }
    }

    /// A message that the system sends when a scene is running in the background.
    public struct DidEnterBackgroundMessage: NotificationCenter.Backport.MainActorMessage, StandardUISceneMessage {
        public typealias Subject = UIScene

        public static var name: Notification.Name {
            UIScene.didEnterBackgroundNotification
        }

        /// The scene that entered the background.
        public var scene: UIScene

        public init(scene: UIScene) {
            self.scene = scene
        }
    }

    /// A message that the system sends when the system protection of a scene changes.
    @available(iOS 18.0, macCatalyst 18.0, *)
    @available(tvOS, unavailable)
    @available(visionOS, unavailable)
    public struct SystemProtectionDidChangeMessage: NotificationCenter.Backport.MainActorMessage, StandardUISceneMessage {
        public typealias Subject = UIScene

        public static var name: Notification.Name {
            UIScene.systemProtectionDidChangeNotification
        }

        /// The scene whose system protection changed.
        public var scene: UIScene

        public init(scene: UIScene) {
            self.scene = scene
        }
    }
}

extension NotificationCenter.Backport.MessageIdentifier
where Self == NotificationCenter.Backport.BaseMessageIdentifier<UIScene.Backport.WillConnectMessage> {
    /// The identifier of `UIScene.Backport.WillConnectMessage`.
    @_disfavoredOverload
    public static var willConnect: Self { .init() }
}

extension NotificationCenter.Backport.MessageIdentifier
where Self == NotificationCenter.Backport.BaseMessageIdentifier<UIScene.Backport.WillEnterForegroundMessage> {
    /// The identifier of `UIScene.Backport.WillEnterForegroundMessage`.
    @_disfavoredOverload
    public static var willEnterForeground: Self { .init() }
}

extension NotificationCenter.Backport.MessageIdentifier
where Self == NotificationCenter.Backport.BaseMessageIdentifier<UIScene.Backport.DidActivateMessage> {
    /// The identifier of `UIScene.Backport.DidActivateMessage`.
    @_disfavoredOverload
    public static var didActivate: Self { .init() }
}

extension NotificationCenter.Backport.MessageIdentifier
where Self == NotificationCenter.Backport.BaseMessageIdentifier<UIScene.Backport.WillDeactivateMessage> {
    /// The identifier of `UIScene.Backport.WillDeactivateMessage`.
    @_disfavoredOverload
    public static var willDeactivate: Self { .init() }
}

extension NotificationCenter.Backport.MessageIdentifier
where Self == NotificationCenter.Backport.BaseMessageIdentifier<UIScene.Backport.DidEnterBackgroundMessage> {
    /// The identifier of `UIScene.Backport.DidEnterBackgroundMessage`.
    @_disfavoredOverload
    public static var didEnterBackground: Self { .init() }
}

@available(iOS 18.0, macCatalyst 18.0, *)
@available(tvOS, unavailable)
@available(visionOS, unavailable)
extension NotificationCenter.Backport.MessageIdentifier
where Self == NotificationCenter.Backport.BaseMessageIdentifier<UIScene.Backport.SystemProtectionDidChangeMessage> {
    /// The identifier of `UIScene.Backport.SystemProtectionDidChangeMessage`.
    @_disfavoredOverload
    public static var systemProtectionDidChange: Self { .init() }
}

#endif
