#if canImport(AppKit) && !targetEnvironment(macCatalyst)

import AppKit
import FoundationToolbox

// AppKit's predefined `NSView` messages. The conventions every file in `NotificationMessages/` follows
// are noted in `Shared/NotificationMessages.swift`.
//
// Both carry nothing but the view, which is the notification's object, and AppKit implements them
// through one internal protocol, `StandardNSViewMessage`, reproduced here under AppKit's name.

extension NSView {
    /// Backports of the messages AppKit declares on `NSView` from macOS 27. See
    /// `NotificationCenter.Backport`.
    public enum Backport {}
}

/// The messages whose only property is the view, read from the notification's object.
protocol StandardNSViewMessage: NotificationCenter.Backport.MainActorMessage where Subject == NSView {
    var view: NSView { get }
    init(view: NSView)
}

extension StandardNSViewMessage {
    @MainActor
    public static func makeMessage(_ notification: Notification) -> Self? {
        guard let view = notification.object as? NSView else {
            return nil
        }
        return Self(view: view)
    }

    @MainActor
    public static func makeNotification(_ message: Self) -> Notification {
        Notification(name: name, object: message.view, userInfo: nil)
    }
}

extension NSView.Backport {
    /// A message that a view sends when its frame rectangle changes, if it posts frame changes.
    public struct FrameDidChangeMessage: NotificationCenter.Backport.MainActorMessage, StandardNSViewMessage {
        public typealias Subject = NSView

        public static var name: Notification.Name {
            NSView.frameDidChangeNotification
        }

        /// The view whose frame changed.
        public var view: NSView

        public init(view: NSView) {
            self.view = view
        }
    }

    /// A message that a view sends when its bounds rectangle changes, if it posts bounds changes.
    public struct BoundsDidChangeMessage: NotificationCenter.Backport.MainActorMessage, StandardNSViewMessage {
        public typealias Subject = NSView

        public static var name: Notification.Name {
            NSView.boundsDidChangeNotification
        }

        /// The view whose bounds changed.
        public var view: NSView

        public init(view: NSView) {
            self.view = view
        }
    }
}

extension NotificationCenter.Backport.MessageIdentifier
where Self == NotificationCenter.Backport.BaseMessageIdentifier<NSView.Backport.FrameDidChangeMessage> {
    /// The identifier of `NSView.Backport.FrameDidChangeMessage`.
    @_disfavoredOverload
    public static var frameDidChange: Self { .init() }
}

extension NotificationCenter.Backport.MessageIdentifier
where Self == NotificationCenter.Backport.BaseMessageIdentifier<NSView.Backport.BoundsDidChangeMessage> {
    /// The identifier of `NSView.Backport.BoundsDidChangeMessage`.
    @_disfavoredOverload
    public static var boundsDidChange: Self { .init() }
}

#endif
