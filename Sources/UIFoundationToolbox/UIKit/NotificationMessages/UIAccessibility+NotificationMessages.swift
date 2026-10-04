#if canImport(UIKit) && !os(watchOS)

import UIKit
import FoundationToolbox

// UIKit's predefined `UIAccessibility` messages. The conventions every file in `NotificationMessages/`
// follows are noted in `Shared/NotificationMessages.swift`.
//
// Use the SDK constants for the names, never a string spelled after the constant: several of them
// carry the text of an older notification -- `voiceOverStatusDidChangeNotification` is
// "UIAccessibilityVoiceOverTouchStatusChanged".
//
// UIKit offers `ElementFocusedMessage` and `AnnouncementDidFinishMessage` on watchOS as well. This
// library does not, because the package does not build for watchOS (its `AssociatedObject` dependency
// fails there), so nothing written for it could be checked.

extension UIAccessibility {
    /// Backports of the messages UIKit declares on `UIAccessibility` from iOS 26. See
    /// `NotificationCenter.Backport`.
    public enum Backport {}
}

extension UIAccessibility.Backport {
    /// A message that the system sends when VoiceOver starts or stops.
    public struct VoiceOverStatusDidChangeMessage: NotificationCenter.Backport.MainActorMessage, PropertylessMainActorMessage {
        public typealias Subject = UIAccessibility

        public static var name: Notification.Name {
            UIAccessibility.voiceOverStatusDidChangeNotification
        }

        public init() {}
    }

    /// A message that the system sends when the system's Mono Audio setting changes.
    public struct MonoAudioStatusDidChangeMessage: NotificationCenter.Backport.MainActorMessage, PropertylessMainActorMessage {
        public typealias Subject = UIAccessibility

        public static var name: Notification.Name {
            UIAccessibility.monoAudioStatusDidChangeNotification
        }

        public init() {}
    }

    /// A message that the system sends when the setting for closed captioning changes.
    public struct ClosedCaptioningStatusDidChangeMessage: NotificationCenter.Backport.MainActorMessage, PropertylessMainActorMessage {
        public typealias Subject = UIAccessibility

        public static var name: Notification.Name {
            UIAccessibility.closedCaptioningStatusDidChangeNotification
        }

        public init() {}
    }

    /// A message that the system sends when the system's Invert Colors setting changes.
    public struct InvertColorsStatusDidChangeMessage: NotificationCenter.Backport.MainActorMessage, PropertylessMainActorMessage {
        public typealias Subject = UIAccessibility

        public static var name: Notification.Name {
            UIAccessibility.invertColorsStatusDidChangeNotification
        }

        public init() {}
    }

    /// A message that the system sends when a Guided Access session starts or ends.
    public struct GuidedAccessStatusDidChangeMessage: NotificationCenter.Backport.MainActorMessage, PropertylessMainActorMessage {
        public typealias Subject = UIAccessibility

        public static var name: Notification.Name {
            UIAccessibility.guidedAccessStatusDidChangeNotification
        }

        public init() {}
    }

    /// A message that the system sends when the system's Bold Text setting changes.
    public struct BoldTextStatusDidChangeMessage: NotificationCenter.Backport.MainActorMessage, PropertylessMainActorMessage {
        public typealias Subject = UIAccessibility

        public static var name: Notification.Name {
            UIAccessibility.boldTextStatusDidChangeNotification
        }

        public init() {}
    }

    /// A message that the system sends when the system's Button Shapes setting changes.
    @available(iOS, introduced: 14.0, deprecated: 26.1)
    @available(macCatalyst, introduced: 14.0, deprecated: 26.1)
    @available(tvOS, introduced: 14.0, deprecated: 26.1)
    @available(visionOS, deprecated: 26.1)
    public struct ButtonShapesEnabledStatusDidChangeMessage: NotificationCenter.Backport.MainActorMessage, PropertylessMainActorMessage {
        public typealias Subject = UIAccessibility

        public static var name: Notification.Name {
            UIAccessibility.buttonShapesEnabledStatusDidChangeNotification
        }

        public init() {}
    }

    /// A message that the system sends when the system's Grayscale setting changes.
    public struct GrayscaleStatusDidChangeMessage: NotificationCenter.Backport.MainActorMessage, PropertylessMainActorMessage {
        public typealias Subject = UIAccessibility

        public static var name: Notification.Name {
            UIAccessibility.grayscaleStatusDidChangeNotification
        }

        public init() {}
    }

    /// A message that the system sends when the system's Reduce Transparency setting changes.
    public struct ReduceTransparencyStatusDidChangeMessage: NotificationCenter.Backport.MainActorMessage, PropertylessMainActorMessage {
        public typealias Subject = UIAccessibility

        public static var name: Notification.Name {
            UIAccessibility.reduceTransparencyStatusDidChangeNotification
        }

        public init() {}
    }

    /// A message that the system sends when the system's Reduce Motion setting changes.
    public struct ReduceMotionStatusDidChangeMessage: NotificationCenter.Backport.MainActorMessage, PropertylessMainActorMessage {
        public typealias Subject = UIAccessibility

        public static var name: Notification.Name {
            UIAccessibility.reduceMotionStatusDidChangeNotification
        }

        public init() {}
    }

    /// A message that the system sends when the system's Increase Contrast setting changes.
    public struct DarkerSystemColorsStatusDidChangeMessage: NotificationCenter.Backport.MainActorMessage, PropertylessMainActorMessage {
        public typealias Subject = UIAccessibility

        public static var name: Notification.Name {
            UIAccessibility.darkerSystemColorsStatusDidChangeNotification
        }

        public init() {}
    }

    /// A message that the system sends when Switch Control starts or stops.
    public struct SwitchControlStatusDidChangeMessage: NotificationCenter.Backport.MainActorMessage, PropertylessMainActorMessage {
        public typealias Subject = UIAccessibility

        public static var name: Notification.Name {
            UIAccessibility.switchControlStatusDidChangeNotification
        }

        public init() {}
    }

    /// A message that the system sends when the system's Speak Selection setting changes.
    public struct SpeakSelectionStatusDidChangeMessage: NotificationCenter.Backport.MainActorMessage, PropertylessMainActorMessage {
        public typealias Subject = UIAccessibility

        public static var name: Notification.Name {
            UIAccessibility.speakSelectionStatusDidChangeNotification
        }

        public init() {}
    }

    /// A message that the system sends when the system's Speak Screen setting changes.
    public struct SpeakScreenStatusDidChangeMessage: NotificationCenter.Backport.MainActorMessage, PropertylessMainActorMessage {
        public typealias Subject = UIAccessibility

        public static var name: Notification.Name {
            UIAccessibility.speakScreenStatusDidChangeNotification
        }

        public init() {}
    }

    /// A message that the system sends when the system's Shake to Undo setting changes.
    public struct ShakeToUndoDidChangeMessage: NotificationCenter.Backport.MainActorMessage, PropertylessMainActorMessage {
        public typealias Subject = UIAccessibility

        public static var name: Notification.Name {
            UIAccessibility.shakeToUndoDidChangeNotification
        }

        public init() {}
    }

    /// A message that the system sends when AssistiveTouch starts or stops.
    public struct AssistiveTouchStatusDidChangeMessage: NotificationCenter.Backport.MainActorMessage, PropertylessMainActorMessage {
        public typealias Subject = UIAccessibility

        public static var name: Notification.Name {
            UIAccessibility.assistiveTouchStatusDidChangeNotification
        }

        public init() {}
    }

    /// A message that the system sends when the hearing device's paired ear changes.
    @available(tvOS, unavailable)
    public struct HearingDevicePairedEarDidChangeMessage: NotificationCenter.Backport.MainActorMessage, PropertylessMainActorMessage {
        public typealias Subject = UIAccessibility

        public static var name: Notification.Name {
            UIAccessibility.hearingDevicePairedEarDidChangeNotification
        }

        public init() {}
    }

    /// A message that an assistive technology sends when it focuses on an accessibility element.
    ///
    /// Converting a notification never fails, and `element` is not `nil` either: when the notification
    /// carries no element, `element` holds `NSNull`. That is UIKit's own behaviour -- its implementation
    /// casts the optional lookup result to `AnyObject` without unwrapping it first, which bridges a
    /// missing value to `NSNull` -- and is reproduced deliberately.
    public struct ElementFocusedMessage: NotificationCenter.Backport.MainActorMessage {
        public typealias Subject = UIAccessibility

        public static var name: Notification.Name {
            UIAccessibility.elementFocusedNotification
        }

        /// The accessibility element that received focus.
        public var element: AnyObject?

        public init(element: AnyObject?) {
            self.element = element
        }

        @MainActor
        public static func makeMessage(_ notification: Notification) -> Self? {
            // Deliberately not unwrapped before the cast; see the type's documentation.
            Self(element: notification.userInfo?[UIAccessibility.focusedElementUserInfoKey] as? AnyObject)
        }

        @MainActor
        public static func makeNotification(_ message: Self) -> Notification {
            Notification(
                name: name,
                object: nil,
                userInfo: [UIAccessibility.focusedElementUserInfoKey: message.element as Any]
            )
        }
    }

    /// A message that the system sends when an assistive technology finishes making an announcement.
    public struct AnnouncementDidFinishMessage: NotificationCenter.Backport.MainActorMessage {
        public typealias Subject = UIAccessibility

        public static var name: Notification.Name {
            UIAccessibility.announcementDidFinishNotification
        }

        /// The text of the announcement.
        public var announcement: String

        /// A Boolean value that indicates whether the announcement finished successfully.
        public var wasSuccessful: Bool

        public init(announcement: String, wasSuccessful: Bool) {
            self.announcement = announcement
            self.wasSuccessful = wasSuccessful
        }

        @MainActor
        public static func makeMessage(_ notification: Notification) -> Self? {
            guard let userInfo = notification.userInfo,
                  let announcement = userInfo[UIAccessibility.announcementStringValueUserInfoKey] as? String,
                  let wasSuccessful = userInfo[UIAccessibility.announcementWasSuccessfulUserInfoKey] as? Bool
            else {
                return nil
            }
            return Self(announcement: announcement, wasSuccessful: wasSuccessful)
        }

        @MainActor
        public static func makeNotification(_ message: Self) -> Notification {
            Notification(
                name: name,
                object: nil,
                userInfo: [
                    UIAccessibility.announcementStringValueUserInfoKey: message.announcement,
                    UIAccessibility.announcementWasSuccessfulUserInfoKey: message.wasSuccessful,
                ]
            )
        }
    }
}

extension NotificationCenter.Backport.MessageIdentifier
where Self == NotificationCenter.Backport.BaseMessageIdentifier<UIAccessibility.Backport.VoiceOverStatusDidChangeMessage> {
    /// The identifier of `UIAccessibility.Backport.VoiceOverStatusDidChangeMessage`.
    @_disfavoredOverload
    public static var voiceOverStatusDidChange: Self { .init() }
}

extension NotificationCenter.Backport.MessageIdentifier
where Self == NotificationCenter.Backport.BaseMessageIdentifier<UIAccessibility.Backport.MonoAudioStatusDidChangeMessage> {
    /// The identifier of `UIAccessibility.Backport.MonoAudioStatusDidChangeMessage`.
    @_disfavoredOverload
    public static var monoAudioStatusDidChange: Self { .init() }
}

extension NotificationCenter.Backport.MessageIdentifier
where Self == NotificationCenter.Backport.BaseMessageIdentifier<UIAccessibility.Backport.ClosedCaptioningStatusDidChangeMessage> {
    /// The identifier of `UIAccessibility.Backport.ClosedCaptioningStatusDidChangeMessage`.
    @_disfavoredOverload
    public static var closedCaptioningStatusDidChange: Self { .init() }
}

extension NotificationCenter.Backport.MessageIdentifier
where Self == NotificationCenter.Backport.BaseMessageIdentifier<UIAccessibility.Backport.InvertColorsStatusDidChangeMessage> {
    /// The identifier of `UIAccessibility.Backport.InvertColorsStatusDidChangeMessage`.
    @_disfavoredOverload
    public static var invertColorsStatusDidChange: Self { .init() }
}

extension NotificationCenter.Backport.MessageIdentifier
where Self == NotificationCenter.Backport.BaseMessageIdentifier<UIAccessibility.Backport.GuidedAccessStatusDidChangeMessage> {
    /// The identifier of `UIAccessibility.Backport.GuidedAccessStatusDidChangeMessage`.
    @_disfavoredOverload
    public static var guidedAccessStatusDidChange: Self { .init() }
}

extension NotificationCenter.Backport.MessageIdentifier
where Self == NotificationCenter.Backport.BaseMessageIdentifier<UIAccessibility.Backport.BoldTextStatusDidChangeMessage> {
    /// The identifier of `UIAccessibility.Backport.BoldTextStatusDidChangeMessage`.
    @_disfavoredOverload
    public static var boldTextStatusDidChange: Self { .init() }
}

@available(iOS, introduced: 14.0, deprecated: 26.1)
@available(macCatalyst, introduced: 14.0, deprecated: 26.1)
@available(tvOS, introduced: 14.0, deprecated: 26.1)
@available(visionOS, deprecated: 26.1)
extension NotificationCenter.Backport.MessageIdentifier
where Self == NotificationCenter.Backport.BaseMessageIdentifier<UIAccessibility.Backport.ButtonShapesEnabledStatusDidChangeMessage> {
    /// The identifier of `UIAccessibility.Backport.ButtonShapesEnabledStatusDidChangeMessage`.
    @_disfavoredOverload
    public static var buttonShapesEnabledStatusDidChange: Self { .init() }
}

extension NotificationCenter.Backport.MessageIdentifier
where Self == NotificationCenter.Backport.BaseMessageIdentifier<UIAccessibility.Backport.GrayscaleStatusDidChangeMessage> {
    /// The identifier of `UIAccessibility.Backport.GrayscaleStatusDidChangeMessage`.
    @_disfavoredOverload
    public static var grayscaleStatusDidChange: Self { .init() }
}

extension NotificationCenter.Backport.MessageIdentifier
where Self == NotificationCenter.Backport.BaseMessageIdentifier<UIAccessibility.Backport.ReduceTransparencyStatusDidChangeMessage> {
    /// The identifier of `UIAccessibility.Backport.ReduceTransparencyStatusDidChangeMessage`.
    @_disfavoredOverload
    public static var reduceTransparencyStatusDidChange: Self { .init() }
}

extension NotificationCenter.Backport.MessageIdentifier
where Self == NotificationCenter.Backport.BaseMessageIdentifier<UIAccessibility.Backport.ReduceMotionStatusDidChangeMessage> {
    /// The identifier of `UIAccessibility.Backport.ReduceMotionStatusDidChangeMessage`.
    @_disfavoredOverload
    public static var reduceMotionStatusDidChange: Self { .init() }
}

extension NotificationCenter.Backport.MessageIdentifier
where Self == NotificationCenter.Backport.BaseMessageIdentifier<UIAccessibility.Backport.DarkerSystemColorsStatusDidChangeMessage> {
    /// The identifier of `UIAccessibility.Backport.DarkerSystemColorsStatusDidChangeMessage`.
    @_disfavoredOverload
    public static var darkerSystemColorsStatusDidChange: Self { .init() }
}

extension NotificationCenter.Backport.MessageIdentifier
where Self == NotificationCenter.Backport.BaseMessageIdentifier<UIAccessibility.Backport.SwitchControlStatusDidChangeMessage> {
    /// The identifier of `UIAccessibility.Backport.SwitchControlStatusDidChangeMessage`.
    @_disfavoredOverload
    public static var switchControlStatusDidChange: Self { .init() }
}

extension NotificationCenter.Backport.MessageIdentifier
where Self == NotificationCenter.Backport.BaseMessageIdentifier<UIAccessibility.Backport.SpeakSelectionStatusDidChangeMessage> {
    /// The identifier of `UIAccessibility.Backport.SpeakSelectionStatusDidChangeMessage`.
    @_disfavoredOverload
    public static var speakSelectionStatusDidChange: Self { .init() }
}

extension NotificationCenter.Backport.MessageIdentifier
where Self == NotificationCenter.Backport.BaseMessageIdentifier<UIAccessibility.Backport.SpeakScreenStatusDidChangeMessage> {
    /// The identifier of `UIAccessibility.Backport.SpeakScreenStatusDidChangeMessage`.
    @_disfavoredOverload
    public static var speakScreenStatusDidChange: Self { .init() }
}

extension NotificationCenter.Backport.MessageIdentifier
where Self == NotificationCenter.Backport.BaseMessageIdentifier<UIAccessibility.Backport.ShakeToUndoDidChangeMessage> {
    /// The identifier of `UIAccessibility.Backport.ShakeToUndoDidChangeMessage`.
    @_disfavoredOverload
    public static var shakeToUndoDidChange: Self { .init() }
}

extension NotificationCenter.Backport.MessageIdentifier
where Self == NotificationCenter.Backport.BaseMessageIdentifier<UIAccessibility.Backport.AssistiveTouchStatusDidChangeMessage> {
    /// The identifier of `UIAccessibility.Backport.AssistiveTouchStatusDidChangeMessage`.
    @_disfavoredOverload
    public static var assistiveTouchStatusDidChange: Self { .init() }
}

@available(tvOS, unavailable)
extension NotificationCenter.Backport.MessageIdentifier
where Self == NotificationCenter.Backport.BaseMessageIdentifier<UIAccessibility.Backport.HearingDevicePairedEarDidChangeMessage> {
    /// The identifier of `UIAccessibility.Backport.HearingDevicePairedEarDidChangeMessage`.
    @_disfavoredOverload
    public static var hearingDevicePairedEarDidChange: Self { .init() }
}

extension NotificationCenter.Backport.MessageIdentifier
where Self == NotificationCenter.Backport.BaseMessageIdentifier<UIAccessibility.Backport.ElementFocusedMessage> {
    /// The identifier of `UIAccessibility.Backport.ElementFocusedMessage`.
    @_disfavoredOverload
    public static var elementFocused: Self { .init() }
}

extension NotificationCenter.Backport.MessageIdentifier
where Self == NotificationCenter.Backport.BaseMessageIdentifier<UIAccessibility.Backport.AnnouncementDidFinishMessage> {
    /// The identifier of `UIAccessibility.Backport.AnnouncementDidFinishMessage`.
    @_disfavoredOverload
    public static var announcementDidFinish: Self { .init() }
}

#endif
