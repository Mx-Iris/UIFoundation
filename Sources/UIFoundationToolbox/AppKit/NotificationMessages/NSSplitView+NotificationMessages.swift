#if canImport(AppKit) && !targetEnvironment(macCatalyst)

import AppKit
import FoundationToolbox

// AppKit's predefined `NSSplitView` messages. The conventions every file in `NotificationMessages/`
// follows are noted in `Shared/NotificationMessages.swift`.
//
// AppKit runs the same code for both. Only the split view, the notification's object, is required: a
// missing divider index is `nil`, and a missing user-resize flag is `false`, which is also what the
// initializer stores for a `nil` argument. Making a notification writes the divider index only when it
// is set, and the flag always.
//
// The two keys are AppKit globals that no SDK header declares, so their values are spelled out here --
// note that only the second ends in "Key".

extension NSSplitView {
    /// Backports of the messages AppKit declares on `NSSplitView` from macOS 27. See
    /// `NotificationCenter.Backport`.
    public enum Backport {}
}

/// The two resize messages, which share one implementation in AppKit as well.
protocol NSSplitViewResizeSubviewsMessage: NotificationCenter.Backport.MainActorMessage where Subject == NSSplitView {
    var splitView: NSSplitView { get }
    var dividerIndex: Int? { get }
    var userResize: Bool { get }
    init(splitView: NSSplitView, dividerIndex: Int?, userResize: Bool?)
}

extension NSSplitViewResizeSubviewsMessage {
    @MainActor
    public static func makeMessage(_ notification: Notification) -> Self? {
        guard let splitView = notification.object as? NSSplitView else {
            return nil
        }
        return Self(
            splitView: splitView,
            dividerIndex: notification.userInfo?[NSSplitView.Backport.dividerIndexUserInfoKey] as? Int,
            userResize: notification.userInfo?[NSSplitView.Backport.userResizeUserInfoKey] as? Bool ?? false
        )
    }

    @MainActor
    public static func makeNotification(_ message: Self) -> Notification {
        var userInfo: [String: Any] = [:]
        if let dividerIndex = message.dividerIndex {
            userInfo[NSSplitView.Backport.dividerIndexUserInfoKey] = dividerIndex
        }
        userInfo[NSSplitView.Backport.userResizeUserInfoKey] = message.userResize
        return Notification(name: name, object: message.splitView, userInfo: userInfo.isEmpty ? nil : userInfo)
    }
}

extension NSSplitView.Backport {
    /// AppKit's `NSSplitViewDividerIndexKey`, exported but declared in no SDK header.
    static let dividerIndexUserInfoKey = "NSSplitViewDividerIndex"

    /// AppKit's `NSSplitViewUserResizeKey`, exported but declared in no SDK header.
    static let userResizeUserInfoKey = "NSSplitViewUserResizeKey"

    /// A message that a split view sends before it resizes its subviews.
    public struct WillResizeSubviewsMessage: NotificationCenter.Backport.MainActorMessage, NSSplitViewResizeSubviewsMessage {
        public typealias Subject = NSSplitView

        public static var name: Notification.Name {
            NSSplitView.willResizeSubviewsNotification
        }

        /// The split view that is about to resize its subviews.
        public var splitView: NSSplitView

        /// The index of the divider being dragged, if the user is dragging one.
        public var dividerIndex: Int?

        /// A Boolean value that indicates whether the user caused the resize.
        public var userResize: Bool

        public init(splitView: NSSplitView, dividerIndex: Int? = nil, userResize: Bool? = nil) {
            self.splitView = splitView
            self.dividerIndex = dividerIndex
            self.userResize = userResize ?? false
        }
    }

    /// A message that a split view sends after it resizes its subviews.
    public struct DidResizeSubviewsMessage: NotificationCenter.Backport.MainActorMessage, NSSplitViewResizeSubviewsMessage {
        public typealias Subject = NSSplitView

        public static var name: Notification.Name {
            NSSplitView.didResizeSubviewsNotification
        }

        /// The split view that resized its subviews.
        public var splitView: NSSplitView

        /// The index of the divider that was dragged, if the user dragged one.
        public var dividerIndex: Int?

        /// A Boolean value that indicates whether the user caused the resize.
        public var userResize: Bool

        public init(splitView: NSSplitView, dividerIndex: Int? = nil, userResize: Bool? = nil) {
            self.splitView = splitView
            self.dividerIndex = dividerIndex
            self.userResize = userResize ?? false
        }
    }
}

extension NotificationCenter.Backport.MessageIdentifier
where Self == NotificationCenter.Backport.BaseMessageIdentifier<NSSplitView.Backport.WillResizeSubviewsMessage> {
    /// The identifier of `NSSplitView.Backport.WillResizeSubviewsMessage`.
    @_disfavoredOverload
    public static var willResizeSubviews: Self { .init() }
}

extension NotificationCenter.Backport.MessageIdentifier
where Self == NotificationCenter.Backport.BaseMessageIdentifier<NSSplitView.Backport.DidResizeSubviewsMessage> {
    /// The identifier of `NSSplitView.Backport.DidResizeSubviewsMessage`.
    @_disfavoredOverload
    public static var didResizeSubviews: Self { .init() }
}

#endif
