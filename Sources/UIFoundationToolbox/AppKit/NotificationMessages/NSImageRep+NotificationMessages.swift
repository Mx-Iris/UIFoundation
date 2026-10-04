#if canImport(AppKit) && !targetEnvironment(macCatalyst)

import AppKit
import FoundationToolbox

// AppKit's predefined `NSImageRep` message. The conventions every file in `NotificationMessages/`
// follows are noted in `Shared/NotificationMessages.swift`.

extension NSImageRep {
    /// Backports of the messages AppKit declares on `NSImageRep` from macOS 27. See
    /// `NotificationCenter.Backport`.
    public enum Backport {}
}

extension NSImageRep.Backport {
    /// A message that the system sends when the registry of image representation classes changes.
    ///
    /// The object must be an image representation, as AppKit's own implementation requires. AppKit
    /// posts the class it registers or unregisters as the object, and a class is not an instance, so a
    /// notification AppKit itself posts converts to `nil` -- in AppKit's implementation as well.
    public struct RegistryDidChangeMessage: NotificationCenter.Backport.MainActorMessage {
        public typealias Subject = NSImageRep

        public static var name: Notification.Name {
            NSImageRep.registryDidChangeNotification
        }

        /// The image representation the registry changed for.
        public var imageRep: NSImageRep

        public init(imageRep: NSImageRep) {
            self.imageRep = imageRep
        }

        @MainActor
        public static func makeMessage(_ notification: Notification) -> Self? {
            guard let imageRep = notification.object as? NSImageRep else {
                return nil
            }
            return Self(imageRep: imageRep)
        }

        @MainActor
        public static func makeNotification(_ message: Self) -> Notification {
            Notification(name: name, object: message.imageRep, userInfo: nil)
        }
    }
}

extension NotificationCenter.Backport.MessageIdentifier
where Self == NotificationCenter.Backport.BaseMessageIdentifier<NSImageRep.Backport.RegistryDidChangeMessage> {
    /// The identifier of `NSImageRep.Backport.RegistryDidChangeMessage`.
    @_disfavoredOverload
    public static var registryDidChange: Self { .init() }
}

#endif
