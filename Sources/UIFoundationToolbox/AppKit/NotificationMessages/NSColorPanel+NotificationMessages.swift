#if canImport(AppKit) && !targetEnvironment(macCatalyst)

import AppKit
import FoundationToolbox

// AppKit's predefined `NSColorPanel` message. The conventions every file in `NotificationMessages/`
// follows are noted in `Shared/NotificationMessages.swift`.

extension NSColorPanel {
    /// Backports of the messages AppKit declares on `NSColorPanel` from macOS 27. See
    /// `NotificationCenter.Backport`.
    public enum Backport {}
}

extension NSColorPanel.Backport {
    /// A message that the color panel sends when the current color changes.
    public struct ColorDidChangeMessage: NotificationCenter.Backport.MainActorMessage {
        public typealias Subject = NSColorPanel

        public static var name: Notification.Name {
            NSColorPanel.colorDidChangeNotification
        }

        /// The color panel whose color changed.
        public var colorPanel: NSColorPanel

        public init(colorPanel: NSColorPanel) {
            self.colorPanel = colorPanel
        }

        @MainActor
        public static func makeMessage(_ notification: Notification) -> Self? {
            guard let colorPanel = notification.object as? NSColorPanel else {
                return nil
            }
            return Self(colorPanel: colorPanel)
        }

        @MainActor
        public static func makeNotification(_ message: Self) -> Notification {
            Notification(name: name, object: message.colorPanel, userInfo: nil)
        }
    }
}

extension NotificationCenter.Backport.MessageIdentifier
where Self == NotificationCenter.Backport.BaseMessageIdentifier<NSColorPanel.Backport.ColorDidChangeMessage> {
    /// The identifier of `NSColorPanel.Backport.ColorDidChangeMessage`.
    @_disfavoredOverload
    public static var colorDidChange: Self { .init() }
}

#endif
