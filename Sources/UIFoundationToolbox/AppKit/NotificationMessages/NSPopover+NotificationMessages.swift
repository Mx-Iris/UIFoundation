#if canImport(AppKit) && !targetEnvironment(macCatalyst)

import AppKit
import FoundationToolbox

// AppKit's predefined `NSPopover` messages. The conventions every file in `NotificationMessages/`
// follows are noted in `Shared/NotificationMessages.swift`.
//
// AppKit implements them through two internal protocols, reproduced here under AppKit's names: the show
// messages carry only the popover, the notification's object (`StandardNSPopoverMessage`), and the close
// messages also carry the close reason (`NSPopoverCloseReasonMessage`), cast straight to
// `NSPopover.CloseReason` and written back as one.

extension NSPopover {
    /// Backports of the messages AppKit declares on `NSPopover` from macOS 27. See
    /// `NotificationCenter.Backport`.
    public enum Backport {}
}

/// The messages whose only property is the popover, read from the notification's object.
protocol StandardNSPopoverMessage: NotificationCenter.Backport.MainActorMessage where Subject == NSPopover {
    var popover: NSPopover { get }
    init(popover: NSPopover)
}

extension StandardNSPopoverMessage {
    @MainActor
    public static func makeMessage(_ notification: Notification) -> Self? {
        guard let popover = notification.object as? NSPopover else {
            return nil
        }
        return Self(popover: popover)
    }

    @MainActor
    public static func makeNotification(_ message: Self) -> Notification {
        Notification(name: name, object: message.popover, userInfo: nil)
    }
}

/// The messages that carry the popover and the reason it closes, both required.
protocol NSPopoverCloseReasonMessage: NotificationCenter.Backport.MainActorMessage where Subject == NSPopover {
    var popover: NSPopover { get }
    var closeReason: NSPopover.CloseReason { get }
    init(popover: NSPopover, closeReason: NSPopover.CloseReason)
}

extension NSPopoverCloseReasonMessage {
    @MainActor
    public static func makeMessage(_ notification: Notification) -> Self? {
        guard let popover = notification.object as? NSPopover,
              let userInfo = notification.userInfo,
              let closeReason = userInfo[NSPopover.closeReasonUserInfoKey] as? NSPopover.CloseReason
        else {
            return nil
        }
        return Self(popover: popover, closeReason: closeReason)
    }

    @MainActor
    public static func makeNotification(_ message: Self) -> Notification {
        Notification(name: name, object: message.popover, userInfo: [NSPopover.closeReasonUserInfoKey: message.closeReason])
    }
}

extension NSPopover.Backport {
    /// A message that a popover sends when it's about to show.
    public struct WillShowMessage: NotificationCenter.Backport.MainActorMessage, StandardNSPopoverMessage {
        public typealias Subject = NSPopover

        public static var name: Notification.Name {
            NSPopover.willShowNotification
        }

        /// The popover that is about to show.
        public var popover: NSPopover

        public init(popover: NSPopover) {
            self.popover = popover
        }
    }

    /// A message that a popover sends after it shows.
    public struct DidShowMessage: NotificationCenter.Backport.MainActorMessage, StandardNSPopoverMessage {
        public typealias Subject = NSPopover

        public static var name: Notification.Name {
            NSPopover.didShowNotification
        }

        /// The popover that showed.
        public var popover: NSPopover

        public init(popover: NSPopover) {
            self.popover = popover
        }
    }

    /// A message that a popover sends when it's about to close.
    public struct WillCloseMessage: NotificationCenter.Backport.MainActorMessage, NSPopoverCloseReasonMessage {
        public typealias Subject = NSPopover

        public static var name: Notification.Name {
            NSPopover.willCloseNotification
        }

        /// The popover that is about to close.
        public var popover: NSPopover

        /// The reason the popover is closing.
        public var closeReason: NSPopover.CloseReason

        public init(popover: NSPopover, closeReason: NSPopover.CloseReason) {
            self.popover = popover
            self.closeReason = closeReason
        }
    }

    /// A message that a popover sends after it closes.
    public struct DidCloseMessage: NotificationCenter.Backport.MainActorMessage, NSPopoverCloseReasonMessage {
        public typealias Subject = NSPopover

        public static var name: Notification.Name {
            NSPopover.didCloseNotification
        }

        /// The popover that closed.
        public var popover: NSPopover

        /// The reason the popover closed.
        public var closeReason: NSPopover.CloseReason

        public init(popover: NSPopover, closeReason: NSPopover.CloseReason) {
            self.popover = popover
            self.closeReason = closeReason
        }
    }
}

extension NotificationCenter.Backport.MessageIdentifier
where Self == NotificationCenter.Backport.BaseMessageIdentifier<NSPopover.Backport.WillShowMessage> {
    /// The identifier of `NSPopover.Backport.WillShowMessage`.
    @_disfavoredOverload
    public static var willShow: Self { .init() }
}

extension NotificationCenter.Backport.MessageIdentifier
where Self == NotificationCenter.Backport.BaseMessageIdentifier<NSPopover.Backport.DidShowMessage> {
    /// The identifier of `NSPopover.Backport.DidShowMessage`.
    @_disfavoredOverload
    public static var didShow: Self { .init() }
}

extension NotificationCenter.Backport.MessageIdentifier
where Self == NotificationCenter.Backport.BaseMessageIdentifier<NSPopover.Backport.WillCloseMessage> {
    /// The identifier of `NSPopover.Backport.WillCloseMessage`.
    @_disfavoredOverload
    public static var willClose: Self { .init() }
}

extension NotificationCenter.Backport.MessageIdentifier
where Self == NotificationCenter.Backport.BaseMessageIdentifier<NSPopover.Backport.DidCloseMessage> {
    /// The identifier of `NSPopover.Backport.DidCloseMessage`.
    @_disfavoredOverload
    public static var didClose: Self { .init() }
}

#endif
