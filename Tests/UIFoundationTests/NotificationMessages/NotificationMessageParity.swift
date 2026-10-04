import Testing
import Foundation
import FoundationToolbox

// Holds a backported message type up against the Apple type it stands in for. Shared by the AppKit
// and UIKit suites; each suite lists its pairs and the fixture that makes a complete notification
// for each, and everything else is derived here so every message is checked the same way.
//
// "Equal" means equal as text: every field, the notification's object and every user-info value is
// rendered with `String(reflecting:)` together with its dynamic type. Objects render with their
// address, so the same object compares equal and a different one does not; a Swift `Int` and an
// `NSNumber` holding the same value compare unequal, which is the point -- Apple's
// `makeNotification(_:)` stores one or the other, and the backport has to store the same one.

/// What a complete notification for one message carries. Every case the comparison runs is derived
/// from it.
struct NotificationFixture {
    var object: Any?
    var userInfo: [AnyHashable: Any]

    struct Variant {
        let label: String
        let notification: Notification
    }

    /// The complete notification, then each way of breaking it: no object, an object of an
    /// unrelated class, no user info, and for every key, the key missing and the key holding an
    /// unrelated class.
    func variants(named name: Notification.Name) -> [Variant] {
        var variants: [Variant] = []
        func add(_ label: String, object: Any?, userInfo: [AnyHashable: Any]?) {
            variants.append(Variant(label: label, notification: Notification(name: name, object: object, userInfo: userInfo)))
        }
        add("complete", object: object, userInfo: userInfo)
        add("no object", object: nil, userInfo: userInfo)
        add("an object of an unrelated class", object: NSObject(), userInfo: userInfo)
        add("no user info", object: object, userInfo: nil)
        for key in userInfo.keys {
            var withoutKey = userInfo
            withoutKey[key] = nil
            add("no \(key.base)", object: object, userInfo: withoutKey)
            var mistyped = userInfo
            mistyped[key] = NSObject()
            add("\(key.base) holding an unrelated class", object: object, userInfo: mistyped)
        }
        return variants
    }
}

/// One backported message type and the Apple type it stands in for, as a test argument.
struct MessagePair: Sendable, CustomTestStringConvertible {
    let testDescription: String
    let check: @MainActor @Sendable () throws -> Void
}

@available(macOS 26.0, iOS 26.0, tvOS 26.0, watchOS 26.0, visionOS 26.0, *)
extension MessagePair {
    static func mainActor<Native: NotificationCenter.MainActorMessage, Ported: NotificationCenter.Backport.MainActorMessage>(
        _ native: Native.Type,
        _ ported: Ported.Type,
        object: @escaping @MainActor @Sendable () -> Any? = { nil },
        userInfo: @escaping @MainActor @Sendable () -> [AnyHashable: Any] = { [:] }
    ) -> MessagePair {
        MessagePair(testDescription: String(reflecting: ported)) {
            try MessageParity.expectParity(
                name: (Native.name, Ported.name),
                fixture: NotificationFixture(object: object(), userInfo: userInfo()),
                makeMessage: (
                    { MessageParity.contents(ofMessage: Native.makeMessage($0)) },
                    { MessageParity.contents(ofMessage: Ported.makeMessage($0)) }
                ),
                roundTrip: (
                    { Native.makeMessage($0).map(Native.makeNotification) },
                    { Ported.makeMessage($0).map(Ported.makeNotification) }
                )
            )
        }
    }

    static func asynchronous<Native: NotificationCenter.AsyncMessage, Ported: NotificationCenter.Backport.AsyncMessage>(
        _ native: Native.Type,
        _ ported: Ported.Type,
        object: @escaping @MainActor @Sendable () -> Any? = { nil },
        userInfo: @escaping @MainActor @Sendable () -> [AnyHashable: Any] = { [:] }
    ) -> MessagePair {
        MessagePair(testDescription: String(reflecting: ported)) {
            try MessageParity.expectParity(
                name: (Native.name, Ported.name),
                fixture: NotificationFixture(object: object(), userInfo: userInfo()),
                makeMessage: (
                    { MessageParity.contents(ofMessage: Native.makeMessage($0)) },
                    { MessageParity.contents(ofMessage: Ported.makeMessage($0)) }
                ),
                roundTrip: (
                    { Native.makeMessage($0).map(Native.makeNotification) },
                    { Ported.makeMessage($0).map(Ported.makeNotification) }
                )
            )
        }
    }
}

@MainActor
enum MessageParity {
    /// Compares the two `name`s, the two `makeMessage(_:)` over every variant of the fixture, and the
    /// two `makeNotification(_:)` applied to what each side made of the complete notification. Each
    /// side's notification is then fed to both `makeMessage(_:)` as one more variant, which covers the
    /// value types a notification built in Swift carries rather than the ones AppKit and UIKit post.
    static func expectParity(
        name: (native: Notification.Name, ported: Notification.Name),
        fixture: NotificationFixture,
        makeMessage: (native: @MainActor (Notification) -> [String]?, ported: @MainActor (Notification) -> [String]?),
        roundTrip: (native: @MainActor (Notification) -> Notification?, ported: @MainActor (Notification) -> Notification?)
    ) throws {
        #expect(name.ported == name.native, "name")

        var variants = fixture.variants(named: name.native)
        for variant in variants {
            #expect(makeMessage.ported(variant.notification) == makeMessage.native(variant.notification), "makeMessage, \(variant.label)")
        }

        let complete = variants[0].notification
        let nativeNotification = try #require(roundTrip.native(complete), "Apple's makeMessage(_:) rejects the complete fixture, so the fixture is wrong")
        let portedNotification = try #require(roundTrip.ported(complete), "makeMessage(_:) rejects the complete fixture")
        #expect(contents(ofNotification: portedNotification) == contents(ofNotification: nativeNotification), "makeNotification")

        variants = [
            NotificationFixture.Variant(label: "Apple's makeNotification output", notification: nativeNotification),
            NotificationFixture.Variant(label: "the backport's makeNotification output", notification: portedNotification),
        ]
        for variant in variants {
            #expect(makeMessage.ported(variant.notification) == makeMessage.native(variant.notification), "makeMessage, \(variant.label)")
        }
    }

    /// Every field of a message, or `nil` for no message.
    nonisolated static func contents(ofMessage message: Any?) -> [String]? {
        guard let message else { return nil }
        return Mirror(reflecting: message).children.map { child in
            "\(child.label ?? "_") = \(describe(child.value))"
        }
    }

    /// A notification's name, object and every user-info entry, sorted so dictionary order does not
    /// matter.
    nonisolated static func contents(ofNotification notification: Notification) -> [String] {
        var lines = [
            "name = \(notification.name.rawValue)",
            "object = \(notification.object.map(describe) ?? "nil")",
        ]
        for (key, value) in notification.userInfo ?? [:] {
            lines.append("userInfo[\(describe(key.base))] = \(describe(value))")
        }
        return lines.sorted()
    }

    /// Renders a value with its dynamic type. An optional is unwrapped first, so `Optional.none` and a
    /// missing value stay distinguishable. A Foundation value object -- a number, a string, a URL, a
    /// collection -- renders by value, since two copies of the same number are equal however they were
    /// made. Any other object renders by identity, without calling its `description`: fixtures use
    /// objects that were never initialized (see `IdentityOnlyObjects`), and asking one to describe
    /// itself would run code against state no initializer set up.
    nonisolated static func describe(_ value: Any) -> String {
        let typeName = String(reflecting: type(of: value))
        let mirror = Mirror(reflecting: value)
        if mirror.displayStyle == .optional {
            guard let wrapped = mirror.children.first?.value else {
                return "nil as \(typeName)"
            }
            return "\(describe(wrapped)) wrapped as \(typeName)"
        }
        if type(of: value) is AnyClass, !isFoundationValueObject(value) {
            return "\(typeName) at \(ObjectIdentifier(value as AnyObject).debugDescription)"
        }
        return "\(String(reflecting: value)) as \(typeName)"
    }

    private nonisolated static func isFoundationValueObject(_ value: Any) -> Bool {
        value is NSValue || value is NSString || value is NSURL || value is NSArray || value is NSDictionary || value is NSNull
    }
}

/// Objects a fixture needs only for their identity, allocated without running an initializer, so that
/// a class whose initializers need a running app -- `UIScene`, `UIScreen`, `UIFocusSystem` -- can still
/// be a notification's object. A message's `makeMessage(_:)` only casts the object and stores it, so an
/// uninitialized instance of the right class is all it looks at. The instances are kept alive for the
/// whole run, because their `dealloc` would run against state no initializer set up.
@MainActor
enum IdentityOnlyObjects {
    private static var instances: [AnyObject] = []

    static func make(_ objectClass: NSObject.Type) -> AnyObject {
        let instance = (objectClass as AnyObject).perform(NSSelectorFromString("alloc")).takeRetainedValue()
        instances.append(instance)
        return instance
    }
}
