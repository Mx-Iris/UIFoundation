#if canImport(AppKit) && !targetEnvironment(macCatalyst)

import AppKit
import FoundationToolbox

// AppKit's predefined `NSHelpManager` messages. The conventions every file in `NotificationMessages/`
// follows are noted in `Shared/NotificationMessages.swift`.
//
// Neither has properties, but making a notification posts it from `NSHelpManager.shared` -- unlike the
// other messages without properties outside `NSApplication`, `NSSpellChecker` and `NSWorkspace`, which
// post from no object at all.

extension NSHelpManager {
    /// Backports of the messages AppKit declares on `NSHelpManager` from macOS 27. See
    /// `NotificationCenter.Backport`.
    public enum Backport {}
}

/// The two context-help messages, which share one implementation in AppKit as well.
protocol NSHelpManagerContextHelpModeMessage: NotificationCenter.Backport.MainActorMessage where Subject == NSHelpManager {
    init()
}

extension NSHelpManagerContextHelpModeMessage {
    @MainActor
    public static func makeMessage(_ notification: Notification) -> Self? {
        Self()
    }

    @MainActor
    public static func makeNotification(_ message: Self) -> Notification {
        Notification(name: name, object: NSHelpManager.shared, userInfo: nil)
    }
}

extension NSHelpManager.Backport {
    /// A message that the help manager sends when context-sensitive help mode becomes active.
    public struct ContextHelpModeDidActivateMessage: NotificationCenter.Backport.MainActorMessage, NSHelpManagerContextHelpModeMessage {
        public typealias Subject = NSHelpManager

        public static var name: Notification.Name {
            NSHelpManager.contextHelpModeDidActivateNotification
        }

        public init() {}
    }

    /// A message that the help manager sends when context-sensitive help mode ends.
    public struct ContextHelpModeDidDeactivateMessage: NotificationCenter.Backport.MainActorMessage, NSHelpManagerContextHelpModeMessage {
        public typealias Subject = NSHelpManager

        public static var name: Notification.Name {
            NSHelpManager.contextHelpModeDidDeactivateNotification
        }

        public init() {}
    }
}

extension NotificationCenter.Backport.MessageIdentifier
where Self == NotificationCenter.Backport.BaseMessageIdentifier<NSHelpManager.Backport.ContextHelpModeDidActivateMessage> {
    /// The identifier of `NSHelpManager.Backport.ContextHelpModeDidActivateMessage`.
    @_disfavoredOverload
    public static var contextHelpModeDidActivate: Self { .init() }
}

extension NotificationCenter.Backport.MessageIdentifier
where Self == NotificationCenter.Backport.BaseMessageIdentifier<NSHelpManager.Backport.ContextHelpModeDidDeactivateMessage> {
    /// The identifier of `NSHelpManager.Backport.ContextHelpModeDidDeactivateMessage`.
    @_disfavoredOverload
    public static var contextHelpModeDidDeactivate: Self { .init() }
}

#endif
