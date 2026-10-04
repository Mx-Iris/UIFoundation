#if canImport(UIKit) && !os(watchOS)

import UIKit
import FoundationToolbox

// UIKit's predefined `UIDevice` messages. The conventions every file in `NotificationMessages/`
// follows are noted in `Shared/NotificationMessages.swift`.
//
// None has properties, and none sets an object when it makes a notification -- not even
// `UIDevice.current`.

extension UIDevice {
    /// Backports of the messages UIKit declares on `UIDevice` from iOS 26. See
    /// `NotificationCenter.Backport`.
    public enum Backport {}
}

extension UIDevice.Backport {
    /// A message that the device sends when its battery level changes.
    @available(tvOS, unavailable)
    public struct BatteryLevelDidChangeMessage: NotificationCenter.Backport.MainActorMessage, PropertylessMainActorMessage {
        public typealias Subject = UIDevice

        public static var name: Notification.Name {
            UIDevice.batteryLevelDidChangeNotification
        }

        public init() {}
    }

    /// A message that the device sends when its battery state changes.
    @available(tvOS, unavailable)
    public struct BatteryStateDidChangeMessage: NotificationCenter.Backport.MainActorMessage, PropertylessMainActorMessage {
        public typealias Subject = UIDevice

        public static var name: Notification.Name {
            UIDevice.batteryStateDidChangeNotification
        }

        public init() {}
    }

    /// A message that the device sends when its orientation changes.
    @available(tvOS, unavailable)
    @available(visionOS, unavailable)
    public struct OrientationDidChangeMessage: NotificationCenter.Backport.MainActorMessage, PropertylessMainActorMessage {
        public typealias Subject = UIDevice

        public static var name: Notification.Name {
            UIDevice.orientationDidChangeNotification
        }

        public init() {}
    }

    /// A message that the device sends when the state of its proximity sensor changes.
    public struct ProximityStateDidChangeMessage: NotificationCenter.Backport.MainActorMessage, PropertylessMainActorMessage {
        public typealias Subject = UIDevice

        public static var name: Notification.Name {
            UIDevice.proximityStateDidChangeNotification
        }

        public init() {}
    }
}

@available(tvOS, unavailable)
extension NotificationCenter.Backport.MessageIdentifier
where Self == NotificationCenter.Backport.BaseMessageIdentifier<UIDevice.Backport.BatteryLevelDidChangeMessage> {
    /// The identifier of `UIDevice.Backport.BatteryLevelDidChangeMessage`.
    @_disfavoredOverload
    public static var batteryLevelDidChange: Self { .init() }
}

@available(tvOS, unavailable)
extension NotificationCenter.Backport.MessageIdentifier
where Self == NotificationCenter.Backport.BaseMessageIdentifier<UIDevice.Backport.BatteryStateDidChangeMessage> {
    /// The identifier of `UIDevice.Backport.BatteryStateDidChangeMessage`.
    @_disfavoredOverload
    public static var batteryStateDidChange: Self { .init() }
}

@available(tvOS, unavailable)
@available(visionOS, unavailable)
extension NotificationCenter.Backport.MessageIdentifier
where Self == NotificationCenter.Backport.BaseMessageIdentifier<UIDevice.Backport.OrientationDidChangeMessage> {
    /// The identifier of `UIDevice.Backport.OrientationDidChangeMessage`.
    @_disfavoredOverload
    public static var orientationDidChange: Self { .init() }
}

extension NotificationCenter.Backport.MessageIdentifier
where Self == NotificationCenter.Backport.BaseMessageIdentifier<UIDevice.Backport.ProximityStateDidChangeMessage> {
    /// The identifier of `UIDevice.Backport.ProximityStateDidChangeMessage`.
    @_disfavoredOverload
    public static var proximityStateDidChange: Self { .init() }
}

#endif
