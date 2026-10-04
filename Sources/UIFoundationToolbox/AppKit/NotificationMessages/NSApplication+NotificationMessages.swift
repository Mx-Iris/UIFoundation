#if canImport(AppKit) && !targetEnvironment(macCatalyst)

import AppKit
import FoundationToolbox

// AppKit's predefined `NSApplication` messages. The conventions every file in `NotificationMessages/`
// follows are noted in `Shared/NotificationMessages.swift`.
//
// None has properties. AppKit implements all seventeen through one internal protocol,
// `StandardNSApplicationMessage`, reproduced here under AppKit's name: converting a notification never
// fails, and making one posts it from `NSApplication.shared`. Two names do not follow the message: the
// window-update messages use `NSApplication.didUpdateNotification` and `willUpdateNotification`.

extension NSApplication {
    /// Backports of the messages AppKit declares on `NSApplication` from macOS 27. See
    /// `NotificationCenter.Backport`.
    public enum Backport {}
}

protocol StandardNSApplicationMessage: NotificationCenter.Backport.MainActorMessage where Subject == NSApplication {
    init()
}

extension StandardNSApplicationMessage {
    @MainActor
    public static func makeMessage(_ notification: Notification) -> Self? {
        Self()
    }

    @MainActor
    public static func makeNotification(_ message: Self) -> Notification {
        Notification(name: name, object: NSApplication.shared, userInfo: nil)
    }
}

extension NSApplication.Backport {
    /// A message that the app sends when it's about to finish launching.
    public struct WillFinishLaunchingMessage: NotificationCenter.Backport.MainActorMessage, StandardNSApplicationMessage {
        public typealias Subject = NSApplication

        public static var name: Notification.Name {
            NSApplication.willFinishLaunchingNotification
        }

        public init() {}
    }

    /// A message that the app sends when it becomes active.
    public struct DidBecomeActiveMessage: NotificationCenter.Backport.MainActorMessage, StandardNSApplicationMessage {
        public typealias Subject = NSApplication

        public static var name: Notification.Name {
            NSApplication.didBecomeActiveNotification
        }

        public init() {}
    }

    /// A message that the app sends when it's about to become active.
    public struct WillBecomeActiveMessage: NotificationCenter.Backport.MainActorMessage, StandardNSApplicationMessage {
        public typealias Subject = NSApplication

        public static var name: Notification.Name {
            NSApplication.willBecomeActiveNotification
        }

        public init() {}
    }

    /// A message that the app sends when it stops being the active app.
    public struct DidResignActiveMessage: NotificationCenter.Backport.MainActorMessage, StandardNSApplicationMessage {
        public typealias Subject = NSApplication

        public static var name: Notification.Name {
            NSApplication.didResignActiveNotification
        }

        public init() {}
    }

    /// A message that the app sends when it's about to stop being the active app.
    public struct WillResignActiveMessage: NotificationCenter.Backport.MainActorMessage, StandardNSApplicationMessage {
        public typealias Subject = NSApplication

        public static var name: Notification.Name {
            NSApplication.willResignActiveNotification
        }

        public init() {}
    }

    /// A message that the app sends when it's hidden.
    public struct DidHideMessage: NotificationCenter.Backport.MainActorMessage, StandardNSApplicationMessage {
        public typealias Subject = NSApplication

        public static var name: Notification.Name {
            NSApplication.didHideNotification
        }

        public init() {}
    }

    /// A message that the app sends when it's about to be hidden.
    public struct WillHideMessage: NotificationCenter.Backport.MainActorMessage, StandardNSApplicationMessage {
        public typealias Subject = NSApplication

        public static var name: Notification.Name {
            NSApplication.willHideNotification
        }

        public init() {}
    }

    /// A message that the app sends when it's made visible again.
    public struct DidUnhideMessage: NotificationCenter.Backport.MainActorMessage, StandardNSApplicationMessage {
        public typealias Subject = NSApplication

        public static var name: Notification.Name {
            NSApplication.didUnhideNotification
        }

        public init() {}
    }

    /// A message that the app sends when it's about to be made visible again.
    public struct WillUnhideMessage: NotificationCenter.Backport.MainActorMessage, StandardNSApplicationMessage {
        public typealias Subject = NSApplication

        public static var name: Notification.Name {
            NSApplication.willUnhideNotification
        }

        public init() {}
    }

    /// A message that the app sends after it updates its windows.
    public struct DidUpdateWindowsMessage: NotificationCenter.Backport.MainActorMessage, StandardNSApplicationMessage {
        public typealias Subject = NSApplication

        public static var name: Notification.Name {
            NSApplication.didUpdateNotification
        }

        public init() {}
    }

    /// A message that the app sends when it's about to update its windows.
    public struct WillUpdateWindowsMessage: NotificationCenter.Backport.MainActorMessage, StandardNSApplicationMessage {
        public typealias Subject = NSApplication

        public static var name: Notification.Name {
            NSApplication.willUpdateNotification
        }

        public init() {}
    }

    /// A message that the app sends when it's about to terminate.
    public struct WillTerminateMessage: NotificationCenter.Backport.MainActorMessage, StandardNSApplicationMessage {
        public typealias Subject = NSApplication

        public static var name: Notification.Name {
            NSApplication.willTerminateNotification
        }

        public init() {}
    }

    /// A message that the app sends when the configuration of the displays attached to the computer changes.
    public struct DidChangeScreenParametersMessage: NotificationCenter.Backport.MainActorMessage, StandardNSApplicationMessage {
        public typealias Subject = NSApplication

        public static var name: Notification.Name {
            NSApplication.didChangeScreenParametersNotification
        }

        public init() {}
    }

    /// A message that the app sends when its occlusion state changes.
    public struct DidChangeOcclusionStateMessage: NotificationCenter.Backport.MainActorMessage, StandardNSApplicationMessage {
        public typealias Subject = NSApplication

        public static var name: Notification.Name {
            NSApplication.didChangeOcclusionStateNotification
        }

        public init() {}
    }

    /// A message that the app sends when it finishes restoring its windows.
    public struct DidFinishRestoringWindowsMessage: NotificationCenter.Backport.MainActorMessage, StandardNSApplicationMessage {
        public typealias Subject = NSApplication

        public static var name: Notification.Name {
            NSApplication.didFinishRestoringWindowsNotification
        }

        public init() {}
    }

    /// A message that the app sends when protected files become available for it to access.
    public struct ProtectedDataDidBecomeAvailableMessage: NotificationCenter.Backport.MainActorMessage, StandardNSApplicationMessage {
        public typealias Subject = NSApplication

        public static var name: Notification.Name {
            .NSApplicationProtectedDataDidBecomeAvailable
        }

        public init() {}
    }

    /// A message that the app sends when protected files are about to become unavailable for it to access.
    public struct ProtectedDataWillBecomeUnavailableMessage: NotificationCenter.Backport.MainActorMessage, StandardNSApplicationMessage {
        public typealias Subject = NSApplication

        public static var name: Notification.Name {
            .NSApplicationProtectedDataWillBecomeUnavailable
        }

        public init() {}
    }
}

extension NotificationCenter.Backport.MessageIdentifier
where Self == NotificationCenter.Backport.BaseMessageIdentifier<NSApplication.Backport.WillFinishLaunchingMessage> {
    /// The identifier of `NSApplication.Backport.WillFinishLaunchingMessage`.
    @_disfavoredOverload
    public static var willFinishLaunching: Self { .init() }
}

extension NotificationCenter.Backport.MessageIdentifier
where Self == NotificationCenter.Backport.BaseMessageIdentifier<NSApplication.Backport.DidBecomeActiveMessage> {
    /// The identifier of `NSApplication.Backport.DidBecomeActiveMessage`.
    @_disfavoredOverload
    public static var didBecomeActive: Self { .init() }
}

extension NotificationCenter.Backport.MessageIdentifier
where Self == NotificationCenter.Backport.BaseMessageIdentifier<NSApplication.Backport.WillBecomeActiveMessage> {
    /// The identifier of `NSApplication.Backport.WillBecomeActiveMessage`.
    @_disfavoredOverload
    public static var willBecomeActive: Self { .init() }
}

extension NotificationCenter.Backport.MessageIdentifier
where Self == NotificationCenter.Backport.BaseMessageIdentifier<NSApplication.Backport.DidResignActiveMessage> {
    /// The identifier of `NSApplication.Backport.DidResignActiveMessage`.
    @_disfavoredOverload
    public static var didResignActive: Self { .init() }
}

extension NotificationCenter.Backport.MessageIdentifier
where Self == NotificationCenter.Backport.BaseMessageIdentifier<NSApplication.Backport.WillResignActiveMessage> {
    /// The identifier of `NSApplication.Backport.WillResignActiveMessage`.
    @_disfavoredOverload
    public static var willResignActive: Self { .init() }
}

extension NotificationCenter.Backport.MessageIdentifier
where Self == NotificationCenter.Backport.BaseMessageIdentifier<NSApplication.Backport.DidHideMessage> {
    /// The identifier of `NSApplication.Backport.DidHideMessage`.
    @_disfavoredOverload
    public static var didHide: Self { .init() }
}

extension NotificationCenter.Backport.MessageIdentifier
where Self == NotificationCenter.Backport.BaseMessageIdentifier<NSApplication.Backport.WillHideMessage> {
    /// The identifier of `NSApplication.Backport.WillHideMessage`.
    @_disfavoredOverload
    public static var willHide: Self { .init() }
}

extension NotificationCenter.Backport.MessageIdentifier
where Self == NotificationCenter.Backport.BaseMessageIdentifier<NSApplication.Backport.DidUnhideMessage> {
    /// The identifier of `NSApplication.Backport.DidUnhideMessage`.
    @_disfavoredOverload
    public static var didUnhide: Self { .init() }
}

extension NotificationCenter.Backport.MessageIdentifier
where Self == NotificationCenter.Backport.BaseMessageIdentifier<NSApplication.Backport.WillUnhideMessage> {
    /// The identifier of `NSApplication.Backport.WillUnhideMessage`.
    @_disfavoredOverload
    public static var willUnhide: Self { .init() }
}

extension NotificationCenter.Backport.MessageIdentifier
where Self == NotificationCenter.Backport.BaseMessageIdentifier<NSApplication.Backport.DidUpdateWindowsMessage> {
    /// The identifier of `NSApplication.Backport.DidUpdateWindowsMessage`.
    @_disfavoredOverload
    public static var didUpdateWindows: Self { .init() }
}

extension NotificationCenter.Backport.MessageIdentifier
where Self == NotificationCenter.Backport.BaseMessageIdentifier<NSApplication.Backport.WillUpdateWindowsMessage> {
    /// The identifier of `NSApplication.Backport.WillUpdateWindowsMessage`.
    @_disfavoredOverload
    public static var willUpdateWindows: Self { .init() }
}

extension NotificationCenter.Backport.MessageIdentifier
where Self == NotificationCenter.Backport.BaseMessageIdentifier<NSApplication.Backport.WillTerminateMessage> {
    /// The identifier of `NSApplication.Backport.WillTerminateMessage`.
    @_disfavoredOverload
    public static var willTerminate: Self { .init() }
}

extension NotificationCenter.Backport.MessageIdentifier
where Self == NotificationCenter.Backport.BaseMessageIdentifier<NSApplication.Backport.DidChangeScreenParametersMessage> {
    /// The identifier of `NSApplication.Backport.DidChangeScreenParametersMessage`.
    @_disfavoredOverload
    public static var didChangeScreenParameters: Self { .init() }
}

extension NotificationCenter.Backport.MessageIdentifier
where Self == NotificationCenter.Backport.BaseMessageIdentifier<NSApplication.Backport.DidChangeOcclusionStateMessage> {
    /// The identifier of `NSApplication.Backport.DidChangeOcclusionStateMessage`.
    @_disfavoredOverload
    public static var didChangeOcclusionState: Self { .init() }
}

extension NotificationCenter.Backport.MessageIdentifier
where Self == NotificationCenter.Backport.BaseMessageIdentifier<NSApplication.Backport.DidFinishRestoringWindowsMessage> {
    /// The identifier of `NSApplication.Backport.DidFinishRestoringWindowsMessage`.
    @_disfavoredOverload
    public static var didFinishRestoringWindows: Self { .init() }
}

extension NotificationCenter.Backport.MessageIdentifier
where Self == NotificationCenter.Backport.BaseMessageIdentifier<NSApplication.Backport.ProtectedDataDidBecomeAvailableMessage> {
    /// The identifier of `NSApplication.Backport.ProtectedDataDidBecomeAvailableMessage`.
    @_disfavoredOverload
    public static var protectedDataDidBecomeAvailable: Self { .init() }
}

extension NotificationCenter.Backport.MessageIdentifier
where Self == NotificationCenter.Backport.BaseMessageIdentifier<NSApplication.Backport.ProtectedDataWillBecomeUnavailableMessage> {
    /// The identifier of `NSApplication.Backport.ProtectedDataWillBecomeUnavailableMessage`.
    @_disfavoredOverload
    public static var protectedDataWillBecomeUnavailable: Self { .init() }
}

#endif
