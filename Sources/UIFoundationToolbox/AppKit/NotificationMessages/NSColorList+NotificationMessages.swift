#if canImport(AppKit) && !targetEnvironment(macCatalyst)

import AppKit
import FoundationToolbox

// AppKit's predefined `NSColorList` message. The conventions every file in `NotificationMessages/`
// follows are noted in `Shared/NotificationMessages.swift`.

extension NSColorList {
    /// Backports of the messages AppKit declares on `NSColorList` from macOS 27. See
    /// `NotificationCenter.Backport`.
    public enum Backport {}
}

extension NSColorList.Backport {
    /// A message that a color list sends when it changes.
    public struct DidChangeMessage: NotificationCenter.Backport.MainActorMessage {
        public typealias Subject = NSColorList

        public static var name: Notification.Name {
            NSColorList.didChangeNotification
        }

        /// The color list that changed.
        public var colorList: NSColorList

        public init(colorList: NSColorList) {
            self.colorList = colorList
        }

        @MainActor
        public static func makeMessage(_ notification: Notification) -> Self? {
            guard let colorList = notification.object as? NSColorList else {
                return nil
            }
            return Self(colorList: colorList)
        }

        @MainActor
        public static func makeNotification(_ message: Self) -> Notification {
            Notification(name: name, object: message.colorList, userInfo: nil)
        }
    }
}

extension NotificationCenter.Backport.MessageIdentifier
where Self == NotificationCenter.Backport.BaseMessageIdentifier<NSColorList.Backport.DidChangeMessage> {
    /// The identifier of `NSColorList.Backport.DidChangeMessage`.
    @_disfavoredOverload
    public static var didChange: Self { .init() }
}

#endif
