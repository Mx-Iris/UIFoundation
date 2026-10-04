#if canImport(AppKit) && !targetEnvironment(macCatalyst)

import AppKit
import FoundationToolbox

// AppKit's predefined `NSWorkspace` messages. The conventions every file in `NotificationMessages/`
// follows are noted in `Shared/NotificationMessages.swift`.
//
// AppKit posts all of these on `NSWorkspace.shared.notificationCenter`, not on
// `NotificationCenter.default`, so that is the center to observe them on.
//
// AppKit implements them with three shared bodies, reproduced here as four internal protocols -- the
// messages without properties need one per message kind, main-actor and asynchronous: the application
// messages read `NSWorkspace.applicationUserInfoKey`, the volume messages read the volume's name and
// URL, and the messages without properties read nothing. Every `makeNotification(_:)` posts
// from `NSWorkspace.shared` -- the ones without properties included, which is why none of them falls
// back on the protocol's default.

extension NSWorkspace {
    /// Backports of the messages AppKit declares on `NSWorkspace` from macOS 26. See
    /// `NotificationCenter.Backport`.
    public enum Backport {}
}

/// The seven messages that carry the application a notification is about.
protocol NSWorkspaceApplicationMessage: NotificationCenter.Backport.MainActorMessage where Subject == NSWorkspace {
    var application: NSRunningApplication { get }
    init(application: NSRunningApplication)
}

extension NSWorkspaceApplicationMessage {
    @MainActor
    public static func makeMessage(_ notification: Notification) -> Self? {
        guard let application = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else {
            return nil
        }
        return Self(application: application)
    }

    @MainActor
    public static func makeNotification(_ message: Self) -> Notification {
        Notification(
            name: name,
            object: NSWorkspace.shared,
            userInfo: [NSWorkspace.applicationUserInfoKey: message.application]
        )
    }
}

/// The three messages that carry a volume's name and URL. Both are stored as Swift values, a `String`
/// and a `URL`, as AppKit's own implementation stores them; reading them back with `as?` accepts the
/// `NSString` and `NSURL` AppKit posts as well.
protocol NSWorkspaceVolumeMessage: NotificationCenter.Backport.MainActorMessage where Subject == NSWorkspace {
    var localizedVolumeName: String { get }
    var volumeURL: URL { get }
    init(localizedVolumeName: String, volumeURL: URL)
}

extension NSWorkspaceVolumeMessage {
    @MainActor
    public static func makeMessage(_ notification: Notification) -> Self? {
        guard let localizedVolumeName = notification.userInfo?[NSWorkspace.localizedVolumeNameUserInfoKey] as? String,
              let volumeURL = notification.userInfo?[NSWorkspace.volumeURLUserInfoKey] as? URL
        else {
            return nil
        }
        return Self(localizedVolumeName: localizedVolumeName, volumeURL: volumeURL)
    }

    @MainActor
    public static func makeNotification(_ message: Self) -> Notification {
        Notification(
            name: name,
            object: NSWorkspace.shared,
            userInfo: [
                NSWorkspace.localizedVolumeNameUserInfoKey: message.localizedVolumeName,
                NSWorkspace.volumeURLUserInfoKey: message.volumeURL,
            ]
        )
    }
}

/// The main-actor messages without properties.
protocol NSWorkspacePropertylessMessage: NotificationCenter.Backport.MainActorMessage where Subject == NSWorkspace {
    init()
}

extension NSWorkspacePropertylessMessage {
    @MainActor
    public static func makeMessage(_ notification: Notification) -> Self? {
        Self()
    }

    @MainActor
    public static func makeNotification(_ message: Self) -> Notification {
        Notification(name: name, object: NSWorkspace.shared, userInfo: nil)
    }
}

/// The asynchronous messages without properties. AppKit runs exactly the same code for them as for
/// the main-actor ones; only the protocol differs.
protocol NSWorkspacePropertylessAsyncMessage: NotificationCenter.Backport.AsyncMessage where Subject == NSWorkspace {
    init()
}

extension NSWorkspacePropertylessAsyncMessage {
    public static func makeMessage(_ notification: Notification) -> Self? {
        Self()
    }

    public static func makeNotification(_ message: Self) -> Notification {
        Notification(name: name, object: NSWorkspace.shared, userInfo: nil)
    }
}

extension NSWorkspace.Backport {
    /// A message that the workspace sends when an app is about to launch.
    public struct WillLaunchApplicationMessage: NotificationCenter.Backport.MainActorMessage, NSWorkspaceApplicationMessage {
        public typealias Subject = NSWorkspace

        public static var name: Notification.Name {
            NSWorkspace.willLaunchApplicationNotification
        }

        /// The app that is about to launch.
        public var application: NSRunningApplication

        public init(application: NSRunningApplication) {
            self.application = application
        }
    }

    /// A message that the workspace sends when a new app starts up.
    public struct DidLaunchApplicationMessage: NotificationCenter.Backport.MainActorMessage, NSWorkspaceApplicationMessage {
        public typealias Subject = NSWorkspace

        public static var name: Notification.Name {
            NSWorkspace.didLaunchApplicationNotification
        }

        /// The app that started up.
        public var application: NSRunningApplication

        public init(application: NSRunningApplication) {
            self.application = application
        }
    }

    /// A message that the workspace sends when an app finishes executing.
    public struct DidTerminateApplicationMessage: NotificationCenter.Backport.MainActorMessage, NSWorkspaceApplicationMessage {
        public typealias Subject = NSWorkspace

        public static var name: Notification.Name {
            NSWorkspace.didTerminateApplicationNotification
        }

        /// The app that finished executing.
        public var application: NSRunningApplication

        public init(application: NSRunningApplication) {
            self.application = application
        }
    }

    /// A message that the workspace sends when an app is hidden.
    public struct DidHideApplicationMessage: NotificationCenter.Backport.MainActorMessage, NSWorkspaceApplicationMessage {
        public typealias Subject = NSWorkspace

        public static var name: Notification.Name {
            NSWorkspace.didHideApplicationNotification
        }

        /// The app that was hidden.
        public var application: NSRunningApplication

        public init(application: NSRunningApplication) {
            self.application = application
        }
    }

    /// A message that the workspace sends when an app is unhidden.
    public struct DidUnhideApplicationMessage: NotificationCenter.Backport.MainActorMessage, NSWorkspaceApplicationMessage {
        public typealias Subject = NSWorkspace

        public static var name: Notification.Name {
            NSWorkspace.didUnhideApplicationNotification
        }

        /// The app that was unhidden.
        public var application: NSRunningApplication

        public init(application: NSRunningApplication) {
            self.application = application
        }
    }

    /// A message that the workspace sends when an app is activated.
    public struct DidActivateApplicationMessage: NotificationCenter.Backport.MainActorMessage, NSWorkspaceApplicationMessage {
        public typealias Subject = NSWorkspace

        public static var name: Notification.Name {
            NSWorkspace.didActivateApplicationNotification
        }

        /// The app that was activated.
        public var application: NSRunningApplication

        public init(application: NSRunningApplication) {
            self.application = application
        }
    }

    /// A message that the workspace sends when an app is deactivated.
    public struct DidDeactivateApplicationMessage: NotificationCenter.Backport.MainActorMessage, NSWorkspaceApplicationMessage {
        public typealias Subject = NSWorkspace

        public static var name: Notification.Name {
            NSWorkspace.didDeactivateApplicationNotification
        }

        /// The app that was deactivated.
        public var application: NSRunningApplication

        public init(application: NSRunningApplication) {
            self.application = application
        }
    }

    /// A message that the workspace sends when a new device mounts.
    public struct DidMountVolumeMessage: NotificationCenter.Backport.MainActorMessage, NSWorkspaceVolumeMessage {
        public typealias Subject = NSWorkspace

        public static var name: Notification.Name {
            NSWorkspace.didMountNotification
        }

        /// The user-visible name of the volume.
        public var localizedVolumeName: String

        /// The mount path of the volume.
        public var volumeURL: URL

        public init(localizedVolumeName: String, volumeURL: URL) {
            self.localizedVolumeName = localizedVolumeName
            self.volumeURL = volumeURL
        }
    }

    /// A message that the workspace sends when a device is about to unmount.
    public struct WillUnmountVolumeMessage: NotificationCenter.Backport.MainActorMessage, NSWorkspaceVolumeMessage {
        public typealias Subject = NSWorkspace

        public static var name: Notification.Name {
            NSWorkspace.willUnmountNotification
        }

        /// The user-visible name of the volume.
        public var localizedVolumeName: String

        /// The mount path of the volume.
        public var volumeURL: URL

        public init(localizedVolumeName: String, volumeURL: URL) {
            self.localizedVolumeName = localizedVolumeName
            self.volumeURL = volumeURL
        }
    }

    /// A message that the workspace sends when a device unmounts.
    public struct DidUnmountVolumeMessage: NotificationCenter.Backport.MainActorMessage, NSWorkspaceVolumeMessage {
        public typealias Subject = NSWorkspace

        public static var name: Notification.Name {
            NSWorkspace.didUnmountNotification
        }

        /// The user-visible name of the volume.
        public var localizedVolumeName: String

        /// The mount path of the volume.
        public var volumeURL: URL

        public init(localizedVolumeName: String, volumeURL: URL) {
            self.localizedVolumeName = localizedVolumeName
            self.volumeURL = volumeURL
        }
    }

    /// A message that the workspace sends when a volume changes its name or mount path.
    ///
    /// All four properties are required: a notification missing any of them converts to `nil`.
    public struct DidRenameVolumeMessage: NotificationCenter.Backport.MainActorMessage {
        public typealias Subject = NSWorkspace

        public static var name: Notification.Name {
            NSWorkspace.didRenameVolumeNotification
        }

        /// The new user-visible name of the volume.
        public var localizedVolumeName: String

        /// The new mount path of the volume.
        public var volumeURL: URL

        /// The previous user-visible name of the volume.
        public var oldLocalizedVolumeName: String

        /// The previous mount path of the volume.
        public var oldVolumeURL: URL

        public init(localizedVolumeName: String, volumeURL: URL, oldLocalizedVolumeName: String, oldVolumeURL: URL) {
            self.localizedVolumeName = localizedVolumeName
            self.volumeURL = volumeURL
            self.oldLocalizedVolumeName = oldLocalizedVolumeName
            self.oldVolumeURL = oldVolumeURL
        }

        @MainActor
        public static func makeMessage(_ notification: Notification) -> Self? {
            guard let localizedVolumeName = notification.userInfo?[NSWorkspace.localizedVolumeNameUserInfoKey] as? String,
                  let volumeURL = notification.userInfo?[NSWorkspace.volumeURLUserInfoKey] as? URL,
                  let oldLocalizedVolumeName = notification.userInfo?[NSWorkspace.oldLocalizedVolumeNameUserInfoKey] as? String,
                  let oldVolumeURL = notification.userInfo?[NSWorkspace.oldVolumeURLUserInfoKey] as? URL
            else {
                return nil
            }
            return Self(
                localizedVolumeName: localizedVolumeName,
                volumeURL: volumeURL,
                oldLocalizedVolumeName: oldLocalizedVolumeName,
                oldVolumeURL: oldVolumeURL
            )
        }

        @MainActor
        public static func makeNotification(_ message: Self) -> Notification {
            Notification(
                name: name,
                object: NSWorkspace.shared,
                userInfo: [
                    NSWorkspace.localizedVolumeNameUserInfoKey: message.localizedVolumeName,
                    NSWorkspace.volumeURLUserInfoKey: message.volumeURL,
                    NSWorkspace.oldLocalizedVolumeNameUserInfoKey: message.oldLocalizedVolumeName,
                    NSWorkspace.oldVolumeURLUserInfoKey: message.oldVolumeURL,
                ]
            )
        }
    }

    /// A message that the workspace sends before the device goes to sleep.
    public struct WillSleepMessage: NotificationCenter.Backport.MainActorMessage, NSWorkspacePropertylessMessage {
        public typealias Subject = NSWorkspace

        public static var name: Notification.Name {
            NSWorkspace.willSleepNotification
        }

        public init() {}
    }

    /// A message that the workspace sends when the device wakes from sleep.
    public struct DidWakeMessage: NotificationCenter.Backport.MainActorMessage, NSWorkspacePropertylessMessage {
        public typealias Subject = NSWorkspace

        public static var name: Notification.Name {
            NSWorkspace.didWakeNotification
        }

        public init() {}
    }

    /// A message that the workspace sends when the screens go to sleep.
    public struct ScreensDidSleepMessage: NotificationCenter.Backport.AsyncMessage, NSWorkspacePropertylessAsyncMessage {
        public typealias Subject = NSWorkspace

        public static var name: Notification.Name {
            NSWorkspace.screensDidSleepNotification
        }

        public init() {}
    }

    /// A message that the workspace sends when the screens wake.
    public struct ScreensDidWakeMessage: NotificationCenter.Backport.AsyncMessage, NSWorkspacePropertylessAsyncMessage {
        public typealias Subject = NSWorkspace

        public static var name: Notification.Name {
            NSWorkspace.screensDidWakeNotification
        }

        public init() {}
    }

    /// A message that the workspace sends after a user session switches in.
    public struct SessionDidBecomeActiveMessage: NotificationCenter.Backport.MainActorMessage, NSWorkspacePropertylessMessage {
        public typealias Subject = NSWorkspace

        public static var name: Notification.Name {
            NSWorkspace.sessionDidBecomeActiveNotification
        }

        public init() {}
    }

    /// A message that the workspace sends before a user session switches out.
    public struct SessionDidResignActiveMessage: NotificationCenter.Backport.MainActorMessage, NSWorkspacePropertylessMessage {
        public typealias Subject = NSWorkspace

        public static var name: Notification.Name {
            NSWorkspace.sessionDidResignActiveNotification
        }

        public init() {}
    }

    /// A message that the workspace sends when the Finder file labels or colors change.
    public struct DidChangeFileLabelsMessage: NotificationCenter.Backport.MainActorMessage, NSWorkspacePropertylessMessage {
        public typealias Subject = NSWorkspace

        public static var name: Notification.Name {
            NSWorkspace.didChangeFileLabelsNotification
        }

        public init() {}
    }

    /// A message that the workspace sends when a Mission Control space changes.
    public struct ActiveSpaceDidChangeMessage: NotificationCenter.Backport.AsyncMessage, NSWorkspacePropertylessAsyncMessage {
        public typealias Subject = NSWorkspace

        public static var name: Notification.Name {
            NSWorkspace.activeSpaceDidChangeNotification
        }

        public init() {}
    }

    /// A message that the workspace sends when any of the accessibility display options change.
    public struct AccessibilityDisplayOptionsDidChangeMessage: NotificationCenter.Backport.MainActorMessage, NSWorkspacePropertylessMessage {
        public typealias Subject = NSWorkspace

        public static var name: Notification.Name {
            NSWorkspace.accessibilityDisplayOptionsDidChangeNotification
        }

        public init() {}
    }
}

extension NotificationCenter.Backport.MessageIdentifier
where Self == NotificationCenter.Backport.BaseMessageIdentifier<NSWorkspace.Backport.WillLaunchApplicationMessage> {
    /// The identifier of `NSWorkspace.Backport.WillLaunchApplicationMessage`.
    @_disfavoredOverload
    public static var willLaunchApplication: Self { .init() }
}

extension NotificationCenter.Backport.MessageIdentifier
where Self == NotificationCenter.Backport.BaseMessageIdentifier<NSWorkspace.Backport.DidLaunchApplicationMessage> {
    /// The identifier of `NSWorkspace.Backport.DidLaunchApplicationMessage`.
    @_disfavoredOverload
    public static var didLaunchApplication: Self { .init() }
}

extension NotificationCenter.Backport.MessageIdentifier
where Self == NotificationCenter.Backport.BaseMessageIdentifier<NSWorkspace.Backport.DidTerminateApplicationMessage> {
    /// The identifier of `NSWorkspace.Backport.DidTerminateApplicationMessage`.
    @_disfavoredOverload
    public static var didTerminateApplication: Self { .init() }
}

extension NotificationCenter.Backport.MessageIdentifier
where Self == NotificationCenter.Backport.BaseMessageIdentifier<NSWorkspace.Backport.DidHideApplicationMessage> {
    /// The identifier of `NSWorkspace.Backport.DidHideApplicationMessage`.
    @_disfavoredOverload
    public static var didHideApplication: Self { .init() }
}

extension NotificationCenter.Backport.MessageIdentifier
where Self == NotificationCenter.Backport.BaseMessageIdentifier<NSWorkspace.Backport.DidUnhideApplicationMessage> {
    /// The identifier of `NSWorkspace.Backport.DidUnhideApplicationMessage`.
    @_disfavoredOverload
    public static var didUnhideApplication: Self { .init() }
}

extension NotificationCenter.Backport.MessageIdentifier
where Self == NotificationCenter.Backport.BaseMessageIdentifier<NSWorkspace.Backport.DidActivateApplicationMessage> {
    /// The identifier of `NSWorkspace.Backport.DidActivateApplicationMessage`.
    @_disfavoredOverload
    public static var didActivateApplication: Self { .init() }
}

extension NotificationCenter.Backport.MessageIdentifier
where Self == NotificationCenter.Backport.BaseMessageIdentifier<NSWorkspace.Backport.DidDeactivateApplicationMessage> {
    /// The identifier of `NSWorkspace.Backport.DidDeactivateApplicationMessage`.
    @_disfavoredOverload
    public static var didDeactivateApplication: Self { .init() }
}

extension NotificationCenter.Backport.MessageIdentifier
where Self == NotificationCenter.Backport.BaseMessageIdentifier<NSWorkspace.Backport.DidMountVolumeMessage> {
    /// The identifier of `NSWorkspace.Backport.DidMountVolumeMessage`.
    @_disfavoredOverload
    public static var didMountVolume: Self { .init() }
}

extension NotificationCenter.Backport.MessageIdentifier
where Self == NotificationCenter.Backport.BaseMessageIdentifier<NSWorkspace.Backport.WillUnmountVolumeMessage> {
    /// The identifier of `NSWorkspace.Backport.WillUnmountVolumeMessage`.
    @_disfavoredOverload
    public static var willUnmountVolume: Self { .init() }
}

extension NotificationCenter.Backport.MessageIdentifier
where Self == NotificationCenter.Backport.BaseMessageIdentifier<NSWorkspace.Backport.DidUnmountVolumeMessage> {
    /// The identifier of `NSWorkspace.Backport.DidUnmountVolumeMessage`.
    @_disfavoredOverload
    public static var didUnmountVolume: Self { .init() }
}

extension NotificationCenter.Backport.MessageIdentifier
where Self == NotificationCenter.Backport.BaseMessageIdentifier<NSWorkspace.Backport.DidRenameVolumeMessage> {
    /// The identifier of `NSWorkspace.Backport.DidRenameVolumeMessage`.
    @_disfavoredOverload
    public static var didRenameVolume: Self { .init() }
}

extension NotificationCenter.Backport.MessageIdentifier
where Self == NotificationCenter.Backport.BaseMessageIdentifier<NSWorkspace.Backport.WillSleepMessage> {
    /// The identifier of `NSWorkspace.Backport.WillSleepMessage`.
    @_disfavoredOverload
    public static var willSleep: Self { .init() }
}

extension NotificationCenter.Backport.MessageIdentifier
where Self == NotificationCenter.Backport.BaseMessageIdentifier<NSWorkspace.Backport.DidWakeMessage> {
    /// The identifier of `NSWorkspace.Backport.DidWakeMessage`.
    @_disfavoredOverload
    public static var didWake: Self { .init() }
}

extension NotificationCenter.Backport.MessageIdentifier
where Self == NotificationCenter.Backport.BaseMessageIdentifier<NSWorkspace.Backport.ScreensDidSleepMessage> {
    /// The identifier of `NSWorkspace.Backport.ScreensDidSleepMessage`.
    @_disfavoredOverload
    public static var screensDidSleep: Self { .init() }
}

extension NotificationCenter.Backport.MessageIdentifier
where Self == NotificationCenter.Backport.BaseMessageIdentifier<NSWorkspace.Backport.ScreensDidWakeMessage> {
    /// The identifier of `NSWorkspace.Backport.ScreensDidWakeMessage`.
    @_disfavoredOverload
    public static var screensDidWake: Self { .init() }
}

extension NotificationCenter.Backport.MessageIdentifier
where Self == NotificationCenter.Backport.BaseMessageIdentifier<NSWorkspace.Backport.SessionDidBecomeActiveMessage> {
    /// The identifier of `NSWorkspace.Backport.SessionDidBecomeActiveMessage`.
    @_disfavoredOverload
    public static var sessionDidBecomeActive: Self { .init() }
}

extension NotificationCenter.Backport.MessageIdentifier
where Self == NotificationCenter.Backport.BaseMessageIdentifier<NSWorkspace.Backport.SessionDidResignActiveMessage> {
    /// The identifier of `NSWorkspace.Backport.SessionDidResignActiveMessage`.
    @_disfavoredOverload
    public static var sessionDidResignActive: Self { .init() }
}

extension NotificationCenter.Backport.MessageIdentifier
where Self == NotificationCenter.Backport.BaseMessageIdentifier<NSWorkspace.Backport.DidChangeFileLabelsMessage> {
    /// The identifier of `NSWorkspace.Backport.DidChangeFileLabelsMessage`.
    @_disfavoredOverload
    public static var didChangeFileLabels: Self { .init() }
}

extension NotificationCenter.Backport.MessageIdentifier
where Self == NotificationCenter.Backport.BaseMessageIdentifier<NSWorkspace.Backport.ActiveSpaceDidChangeMessage> {
    /// The identifier of `NSWorkspace.Backport.ActiveSpaceDidChangeMessage`.
    @_disfavoredOverload
    public static var activeSpaceDidChange: Self { .init() }
}

extension NotificationCenter.Backport.MessageIdentifier
where Self == NotificationCenter.Backport.BaseMessageIdentifier<NSWorkspace.Backport.AccessibilityDisplayOptionsDidChangeMessage> {
    /// The identifier of `NSWorkspace.Backport.AccessibilityDisplayOptionsDidChangeMessage`.
    @_disfavoredOverload
    public static var accessibilityDisplayOptionsDidChange: Self { .init() }
}

#endif
