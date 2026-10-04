#if canImport(UIKit) && !os(watchOS)

import UIKit
import FoundationToolbox

// UIKit's predefined `UIContentSizeCategory` message. The conventions every file in
// `NotificationMessages/` follows are noted in `Shared/NotificationMessages.swift`.
//
// Two things differ from what the name suggests, both UIKit's own: the subject is `UIScreen`, the
// notification's object, and the identifier is `.contentSizeCategoryDidChange` rather than
// `.didChange`. The new category arrives as a plain `String`. Both values are required.

@available(visionOS, unavailable)
extension UIContentSizeCategory {
    /// Backports of the messages UIKit declares on `UIContentSizeCategory` from iOS 26. See
    /// `NotificationCenter.Backport`.
    public enum Backport {}
}

@available(visionOS, unavailable)
extension UIContentSizeCategory.Backport {
    /// A message that the system sends when the user changes the preferred content size setting.
    public struct DidChangeMessage: NotificationCenter.Backport.MainActorMessage {
        public typealias Subject = UIScreen

        public static var name: Notification.Name {
            UIContentSizeCategory.didChangeNotification
        }

        /// The new preferred content size category, as its raw value.
        public var contentSize: String

        /// The screen whose content size category changed.
        public var screen: UIScreen

        public init(contentSize: String, screen: UIScreen) {
            self.contentSize = contentSize
            self.screen = screen
        }

        @MainActor
        public static func makeMessage(_ notification: Notification) -> Self? {
            guard let contentSize = notification.userInfo?[UIContentSizeCategory.newValueUserInfoKey] as? String,
                  let screen = notification.object as? UIScreen
            else {
                return nil
            }
            return Self(contentSize: contentSize, screen: screen)
        }

        @MainActor
        public static func makeNotification(_ message: Self) -> Notification {
            Notification(
                name: name,
                object: message.screen,
                userInfo: [UIContentSizeCategory.newValueUserInfoKey: message.contentSize]
            )
        }
    }
}

@available(visionOS, unavailable)
extension NotificationCenter.Backport.MessageIdentifier
where Self == NotificationCenter.Backport.BaseMessageIdentifier<UIContentSizeCategory.Backport.DidChangeMessage> {
    /// The identifier of `UIContentSizeCategory.Backport.DidChangeMessage`.
    @_disfavoredOverload
    public static var contentSizeCategoryDidChange: Self { .init() }
}

#endif
