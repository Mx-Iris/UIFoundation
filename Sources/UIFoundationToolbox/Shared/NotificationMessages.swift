// Conventions for the predefined messages in `AppKit/NotificationMessages/` and
// `UIKit/NotificationMessages/`, one file per subject type. They port the typed messages AppKit and
// UIKit declare for their own notifications -- AppKit from macOS 27 (`NSWorkspace`'s from 26), UIKit
// from iOS 26 -- onto FrameworkToolbox's `NotificationCenter.Backport`, so that they work on every
// system this package supports. The `appkit-uikit-notification-messages` proposal has the reasoning;
// `Researchs/AppKit-UIKit-NotificationMessages-Internals.md` has the evidence, message by message.
//
// - A message is `<Subject>.Backport.<Apple's name>`, and its identifier has Apple's name, so moving
//   to Apple's API is deleting `Backport.`.
// - Every identifier is `@_disfavoredOverload`. Without it the shorthand is ambiguous wherever Apple's
//   identifier of the same name is available too, so merely importing this library would break Apple's
//   own call sites. With it, the backport still wins where Apple's is unavailable, because an
//   unavailable declaration scores worse than a disfavored one. `AppKitNotificationMessageShorthandGuard`
//   and its UIKit counterpart in the tests stop compiling if one goes missing.
// - `name`, `makeMessage(_:)` and `makeNotification(_:)` reproduce Apple's binaries: AppKit 2775.10.103
//   and the Mac Catalyst build of UIKitCore 9127.0.84, both from macOS 27.0. Unlike most of Foundation's
//   messages, a message with properties converts a notification to `nil` as soon as a required one is
//   missing or of the wrong type -- the notification's object included -- and an observer then never runs.
//   Eleven messages also have optional properties, which are `nil` when missing instead; each says so.
// - Where Apple shares one implementation between several messages, so does this library, through an
//   internal protocol named after AppKit's or UIKit's own where they have one. A message without
//   properties still needs a `makeMessage(_:)` from somewhere: the protocol's default returns `nil` and
//   would silently drop every notification the system posts.
// - Availability follows the notification's constant, not the gate on Apple's types. Unavailability
//   and deprecation are copied from Apple's declarations.
// - Like Apple's, the messages do not conform to `Sendable` unless their protocol requires it.

import FoundationToolbox

/// A main-actor message without properties: `makeMessage(_:)` returns `Self()` whatever the
/// notification carries, and `makeNotification(_:)` is the protocol's default, a notification with the
/// message's name and nothing else. Every UIKit message without properties is implemented exactly so.
protocol PropertylessMainActorMessage: NotificationCenter.Backport.MainActorMessage {
    init()
}

extension PropertylessMainActorMessage {
    @MainActor
    public static func makeMessage(_ notification: Notification) -> Self? {
        Self()
    }
}
