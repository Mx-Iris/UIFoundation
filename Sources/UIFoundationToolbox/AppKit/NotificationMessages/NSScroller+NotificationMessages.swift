#if canImport(AppKit) && !targetEnvironment(macCatalyst)

import AppKit
import FoundationToolbox

// AppKit's predefined `NSScroller` message. The conventions every file in `NotificationMessages/`
// follows are noted in `Shared/NotificationMessages.swift`.

extension NSScroller {
    /// Backports of the messages AppKit declares on `NSScroller` from macOS 27. See
    /// `NotificationCenter.Backport`.
    public enum Backport {}
}

extension NSScroller.Backport {
    /// A message that the system sends when the preferred scroller style changes.
    public struct PreferredScrollerStyleDidChangeMessage: NotificationCenter.Backport.MainActorMessage, PropertylessMainActorMessage {
        public typealias Subject = NSScroller

        public static var name: Notification.Name {
            NSScroller.preferredScrollerStyleDidChangeNotification
        }

        public init() {}
    }
}

extension NotificationCenter.Backport.MessageIdentifier
where Self == NotificationCenter.Backport.BaseMessageIdentifier<NSScroller.Backport.PreferredScrollerStyleDidChangeMessage> {
    /// The identifier of `NSScroller.Backport.PreferredScrollerStyleDidChangeMessage`.
    @_disfavoredOverload
    public static var preferredScrollerStyleDidChange: Self { .init() }
}

#endif
