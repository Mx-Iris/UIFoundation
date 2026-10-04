#if canImport(AppKit) && !targetEnvironment(macCatalyst)

import AppKit
import FoundationToolbox

// AppKit's predefined `NSBrowser` message. The conventions every file in `NotificationMessages/` follows
// are noted in `Shared/NotificationMessages.swift`.

extension NSBrowser {
    /// Backports of the messages AppKit declares on `NSBrowser` from macOS 27. See
    /// `NotificationCenter.Backport`.
    public enum Backport {}
}

extension NSBrowser.Backport {
    /// A message that a browser sends when the width of one of its columns changes.
    public struct ColumnConfigurationDidChangeMessage: NotificationCenter.Backport.MainActorMessage {
        public typealias Subject = NSBrowser

        public static var name: Notification.Name {
            NSBrowser.columnConfigurationDidChangeNotification
        }

        /// The browser whose column configuration changed.
        public var browser: NSBrowser

        public init(browser: NSBrowser) {
            self.browser = browser
        }

        @MainActor
        public static func makeMessage(_ notification: Notification) -> Self? {
            guard let browser = notification.object as? NSBrowser else {
                return nil
            }
            return Self(browser: browser)
        }

        @MainActor
        public static func makeNotification(_ message: Self) -> Notification {
            Notification(name: name, object: message.browser, userInfo: nil)
        }
    }
}

extension NotificationCenter.Backport.MessageIdentifier
where Self == NotificationCenter.Backport.BaseMessageIdentifier<NSBrowser.Backport.ColumnConfigurationDidChangeMessage> {
    /// The identifier of `NSBrowser.Backport.ColumnConfigurationDidChangeMessage`.
    @_disfavoredOverload
    public static var columnConfigurationDidChange: Self { .init() }
}

#endif
