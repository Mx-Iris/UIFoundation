#if canImport(AppKit) && !targetEnvironment(macCatalyst)

import AppKit
import FoundationToolbox

// AppKit's predefined `NSScrollView` messages. The conventions every file in `NotificationMessages/`
// follows are noted in `Shared/NotificationMessages.swift`.
//
// All five carry nothing but the scroll view, which is the notification's object, and AppKit implements
// them through one internal protocol, `StandardNSScrollViewMessage`, reproduced here under AppKit's name.

extension NSScrollView {
    /// Backports of the messages AppKit declares on `NSScrollView` from macOS 27. See
    /// `NotificationCenter.Backport`.
    public enum Backport {}
}

/// The messages whose only property is the scroll view, read from the notification's object.
protocol StandardNSScrollViewMessage: NotificationCenter.Backport.MainActorMessage where Subject == NSScrollView {
    var scrollView: NSScrollView { get }
    init(scrollView: NSScrollView)
}

extension StandardNSScrollViewMessage {
    @MainActor
    public static func makeMessage(_ notification: Notification) -> Self? {
        guard let scrollView = notification.object as? NSScrollView else {
            return nil
        }
        return Self(scrollView: scrollView)
    }

    @MainActor
    public static func makeNotification(_ message: Self) -> Notification {
        Notification(name: name, object: message.scrollView, userInfo: nil)
    }
}

extension NSScrollView.Backport {
    /// A message that a scroll view sends at the beginning of a magnify gesture.
    public struct WillStartLiveMagnifyMessage: NotificationCenter.Backport.MainActorMessage, StandardNSScrollViewMessage {
        public typealias Subject = NSScrollView

        public static var name: Notification.Name {
            NSScrollView.willStartLiveMagnifyNotification
        }

        /// The scroll view that is starting to magnify.
        public var scrollView: NSScrollView

        public init(scrollView: NSScrollView) {
            self.scrollView = scrollView
        }
    }

    /// A message that a scroll view sends at the end of a magnify gesture.
    public struct DidEndLiveMagnifyMessage: NotificationCenter.Backport.MainActorMessage, StandardNSScrollViewMessage {
        public typealias Subject = NSScrollView

        public static var name: Notification.Name {
            NSScrollView.didEndLiveMagnifyNotification
        }

        /// The scroll view that finished magnifying.
        public var scrollView: NSScrollView

        public init(scrollView: NSScrollView) {
            self.scrollView = scrollView
        }
    }

    /// A message that a scroll view sends at the beginning of user-initiated live scroll tracking.
    public struct WillStartLiveScrollMessage: NotificationCenter.Backport.MainActorMessage, StandardNSScrollViewMessage {
        public typealias Subject = NSScrollView

        public static var name: Notification.Name {
            NSScrollView.willStartLiveScrollNotification
        }

        /// The scroll view that is starting to scroll.
        public var scrollView: NSScrollView

        public init(scrollView: NSScrollView) {
            self.scrollView = scrollView
        }
    }

    /// A message that a scroll view sends after it changes its bounds during live scroll tracking.
    public struct DidLiveScrollMessage: NotificationCenter.Backport.MainActorMessage, StandardNSScrollViewMessage {
        public typealias Subject = NSScrollView

        public static var name: Notification.Name {
            NSScrollView.didLiveScrollNotification
        }

        /// The scroll view that scrolled.
        public var scrollView: NSScrollView

        public init(scrollView: NSScrollView) {
            self.scrollView = scrollView
        }
    }

    /// A message that a scroll view sends at the end of live scroll tracking.
    public struct DidEndLiveScrollMessage: NotificationCenter.Backport.MainActorMessage, StandardNSScrollViewMessage {
        public typealias Subject = NSScrollView

        public static var name: Notification.Name {
            NSScrollView.didEndLiveScrollNotification
        }

        /// The scroll view that finished scrolling.
        public var scrollView: NSScrollView

        public init(scrollView: NSScrollView) {
            self.scrollView = scrollView
        }
    }
}

extension NotificationCenter.Backport.MessageIdentifier
where Self == NotificationCenter.Backport.BaseMessageIdentifier<NSScrollView.Backport.WillStartLiveMagnifyMessage> {
    /// The identifier of `NSScrollView.Backport.WillStartLiveMagnifyMessage`.
    @_disfavoredOverload
    public static var willStartLiveMagnify: Self { .init() }
}

extension NotificationCenter.Backport.MessageIdentifier
where Self == NotificationCenter.Backport.BaseMessageIdentifier<NSScrollView.Backport.DidEndLiveMagnifyMessage> {
    /// The identifier of `NSScrollView.Backport.DidEndLiveMagnifyMessage`.
    @_disfavoredOverload
    public static var didEndLiveMagnify: Self { .init() }
}

extension NotificationCenter.Backport.MessageIdentifier
where Self == NotificationCenter.Backport.BaseMessageIdentifier<NSScrollView.Backport.WillStartLiveScrollMessage> {
    /// The identifier of `NSScrollView.Backport.WillStartLiveScrollMessage`.
    @_disfavoredOverload
    public static var willStartLiveScroll: Self { .init() }
}

extension NotificationCenter.Backport.MessageIdentifier
where Self == NotificationCenter.Backport.BaseMessageIdentifier<NSScrollView.Backport.DidLiveScrollMessage> {
    /// The identifier of `NSScrollView.Backport.DidLiveScrollMessage`.
    @_disfavoredOverload
    public static var didLiveScroll: Self { .init() }
}

extension NotificationCenter.Backport.MessageIdentifier
where Self == NotificationCenter.Backport.BaseMessageIdentifier<NSScrollView.Backport.DidEndLiveScrollMessage> {
    /// The identifier of `NSScrollView.Backport.DidEndLiveScrollMessage`.
    @_disfavoredOverload
    public static var didEndLiveScroll: Self { .init() }
}

#endif
