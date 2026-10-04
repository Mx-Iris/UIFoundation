#if canImport(UIKit) && !os(watchOS)

import UIKit
import FoundationToolbox

// UIKit's predefined `UIApplication` messages. The conventions every file in `NotificationMessages/`
// follows are noted in `Shared/NotificationMessages.swift`.
//
// None has properties, and none sets an object when it makes a notification -- not even
// `UIApplication.shared`. UIKit's `SystemPrefersReducedResourceUsageDidChangeMessage` is not here: its
// notification only exists from iOS 27, where UIKit's own message is available too.

extension UIApplication {
    /// Backports of the messages UIKit declares on `UIApplication` from iOS 26. See
    /// `NotificationCenter.Backport`.
    public enum Backport {}
}

extension UIApplication.Backport {
    /// A message that the app sends when it finishes launching.
    public struct DidFinishLaunchingMessage: NotificationCenter.Backport.MainActorMessage, PropertylessMainActorMessage {
        public typealias Subject = UIApplication

        public static var name: Notification.Name {
            UIApplication.didFinishLaunchingNotification
        }

        public init() {}
    }

    /// A message that the app sends when it becomes active.
    public struct DidBecomeActiveMessage: NotificationCenter.Backport.MainActorMessage, PropertylessMainActorMessage {
        public typealias Subject = UIApplication

        public static var name: Notification.Name {
            UIApplication.didBecomeActiveNotification
        }

        public init() {}
    }

    /// A message that the app sends when it enters the background.
    public struct DidEnterBackgroundMessage: NotificationCenter.Backport.MainActorMessage, PropertylessMainActorMessage {
        public typealias Subject = UIApplication

        public static var name: Notification.Name {
            UIApplication.didEnterBackgroundNotification
        }

        public init() {}
    }

    /// A message that the app sends shortly before it leaves the background to become the active app.
    public struct WillEnterForegroundMessage: NotificationCenter.Backport.MainActorMessage, PropertylessMainActorMessage {
        public typealias Subject = UIApplication

        public static var name: Notification.Name {
            UIApplication.willEnterForegroundNotification
        }

        public init() {}
    }

    /// A message that the app sends when it's about to stop being active and lose focus.
    public struct WillResignActiveMessage: NotificationCenter.Backport.MainActorMessage, PropertylessMainActorMessage {
        public typealias Subject = UIApplication

        public static var name: Notification.Name {
            UIApplication.willResignActiveNotification
        }

        public init() {}
    }

    /// A message that the app sends when it's about to terminate.
    public struct WillTerminateMessage: NotificationCenter.Backport.MainActorMessage, PropertylessMainActorMessage {
        public typealias Subject = UIApplication

        public static var name: Notification.Name {
            UIApplication.willTerminateNotification
        }

        public init() {}
    }

    /// A message that the app sends when it receives a warning from the operating system about low memory availability.
    public struct DidReceiveMemoryWarningMessage: NotificationCenter.Backport.MainActorMessage, PropertylessMainActorMessage {
        public typealias Subject = UIApplication

        public static var name: Notification.Name {
            UIApplication.didReceiveMemoryWarningNotification
        }

        public init() {}
    }

    /// A message that the app sends when there's a significant change in time.
    public struct SignificantTimeChangeMessage: NotificationCenter.Backport.MainActorMessage, PropertylessMainActorMessage {
        public typealias Subject = UIApplication

        public static var name: Notification.Name {
            UIApplication.significantTimeChangeNotification
        }

        public init() {}
    }

    /// A message that the app sends when its status for downloading content in the background changes.
    public struct BackgroundRefreshStatusDidChangeMessage: NotificationCenter.Backport.MainActorMessage, PropertylessMainActorMessage {
        public typealias Subject = UIApplication

        public static var name: Notification.Name {
            UIApplication.backgroundRefreshStatusDidChangeNotification
        }

        public init() {}
    }

    /// A message that the app sends after a person takes a screenshot on the device.
    public struct UserDidTakeScreenshotMessage: NotificationCenter.Backport.MainActorMessage, PropertylessMainActorMessage {
        public typealias Subject = UIApplication

        public static var name: Notification.Name {
            UIApplication.userDidTakeScreenshotNotification
        }

        public init() {}
    }

    /// A message that the app sends when the protected files become available for your code to access.
    public struct ProtectedDataDidBecomeAvailableMessage: NotificationCenter.Backport.MainActorMessage, PropertylessMainActorMessage {
        public typealias Subject = UIApplication

        public static var name: Notification.Name {
            UIApplication.protectedDataDidBecomeAvailableNotification
        }

        public init() {}
    }

    /// A message that the app sends when the protected files are about to become unavailable for your code to access.
    public struct ProtectedDataWillBecomeUnavailableMessage: NotificationCenter.Backport.MainActorMessage, PropertylessMainActorMessage {
        public typealias Subject = UIApplication

        public static var name: Notification.Name {
            UIApplication.protectedDataWillBecomeUnavailableNotification
        }

        public init() {}
    }
}

extension NotificationCenter.Backport.MessageIdentifier
where Self == NotificationCenter.Backport.BaseMessageIdentifier<UIApplication.Backport.DidFinishLaunchingMessage> {
    /// The identifier of `UIApplication.Backport.DidFinishLaunchingMessage`.
    @_disfavoredOverload
    public static var didFinishLaunching: Self { .init() }
}

extension NotificationCenter.Backport.MessageIdentifier
where Self == NotificationCenter.Backport.BaseMessageIdentifier<UIApplication.Backport.DidBecomeActiveMessage> {
    /// The identifier of `UIApplication.Backport.DidBecomeActiveMessage`.
    @_disfavoredOverload
    public static var didBecomeActive: Self { .init() }
}

extension NotificationCenter.Backport.MessageIdentifier
where Self == NotificationCenter.Backport.BaseMessageIdentifier<UIApplication.Backport.DidEnterBackgroundMessage> {
    /// The identifier of `UIApplication.Backport.DidEnterBackgroundMessage`.
    @_disfavoredOverload
    public static var didEnterBackground: Self { .init() }
}

extension NotificationCenter.Backport.MessageIdentifier
where Self == NotificationCenter.Backport.BaseMessageIdentifier<UIApplication.Backport.WillEnterForegroundMessage> {
    /// The identifier of `UIApplication.Backport.WillEnterForegroundMessage`.
    @_disfavoredOverload
    public static var willEnterForeground: Self { .init() }
}

extension NotificationCenter.Backport.MessageIdentifier
where Self == NotificationCenter.Backport.BaseMessageIdentifier<UIApplication.Backport.WillResignActiveMessage> {
    /// The identifier of `UIApplication.Backport.WillResignActiveMessage`.
    @_disfavoredOverload
    public static var willResignActive: Self { .init() }
}

extension NotificationCenter.Backport.MessageIdentifier
where Self == NotificationCenter.Backport.BaseMessageIdentifier<UIApplication.Backport.WillTerminateMessage> {
    /// The identifier of `UIApplication.Backport.WillTerminateMessage`.
    @_disfavoredOverload
    public static var willTerminate: Self { .init() }
}

extension NotificationCenter.Backport.MessageIdentifier
where Self == NotificationCenter.Backport.BaseMessageIdentifier<UIApplication.Backport.DidReceiveMemoryWarningMessage> {
    /// The identifier of `UIApplication.Backport.DidReceiveMemoryWarningMessage`.
    @_disfavoredOverload
    public static var didReceiveMemoryWarning: Self { .init() }
}

extension NotificationCenter.Backport.MessageIdentifier
where Self == NotificationCenter.Backport.BaseMessageIdentifier<UIApplication.Backport.SignificantTimeChangeMessage> {
    /// The identifier of `UIApplication.Backport.SignificantTimeChangeMessage`.
    @_disfavoredOverload
    public static var significantTimeChange: Self { .init() }
}

extension NotificationCenter.Backport.MessageIdentifier
where Self == NotificationCenter.Backport.BaseMessageIdentifier<UIApplication.Backport.BackgroundRefreshStatusDidChangeMessage> {
    /// The identifier of `UIApplication.Backport.BackgroundRefreshStatusDidChangeMessage`.
    @_disfavoredOverload
    public static var backgroundRefreshStatusDidChange: Self { .init() }
}

extension NotificationCenter.Backport.MessageIdentifier
where Self == NotificationCenter.Backport.BaseMessageIdentifier<UIApplication.Backport.UserDidTakeScreenshotMessage> {
    /// The identifier of `UIApplication.Backport.UserDidTakeScreenshotMessage`.
    @_disfavoredOverload
    public static var userDidTakeScreenshot: Self { .init() }
}

extension NotificationCenter.Backport.MessageIdentifier
where Self == NotificationCenter.Backport.BaseMessageIdentifier<UIApplication.Backport.ProtectedDataDidBecomeAvailableMessage> {
    /// The identifier of `UIApplication.Backport.ProtectedDataDidBecomeAvailableMessage`.
    @_disfavoredOverload
    public static var protectedDataDidBecomeAvailable: Self { .init() }
}

extension NotificationCenter.Backport.MessageIdentifier
where Self == NotificationCenter.Backport.BaseMessageIdentifier<UIApplication.Backport.ProtectedDataWillBecomeUnavailableMessage> {
    /// The identifier of `UIApplication.Backport.ProtectedDataWillBecomeUnavailableMessage`.
    @_disfavoredOverload
    public static var protectedDataWillBecomeUnavailable: Self { .init() }
}

#endif
