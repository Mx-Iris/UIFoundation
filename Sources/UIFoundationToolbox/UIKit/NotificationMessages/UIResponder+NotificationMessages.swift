#if canImport(UIKit) && !os(watchOS)

import UIKit
import FoundationToolbox

// UIKit's predefined keyboard messages, declared on `UIResponder`. The conventions every file in
// `NotificationMessages/` follows are noted in `Shared/NotificationMessages.swift`.
//
// Their subject is `UIScreen`, not `UIResponder`: UIKit posts the keyboard notifications from the
// screen the keyboard is on. All six share one implementation through an internal protocol,
// `KeyboardNotificationMessageProviding`, reproduced here under UIKit's name. Two of its behaviours
// look like mistakes and are UIKit's own, so they are kept:
//
// - `makeMessage(_:)` needs all six values, and reads the frames as `NSValue` and the curve as
//   `NSNumber` -- what UIKit posts. `makeNotification(_:)` writes them back as Swift values, a `CGRect`
//   and a `UIView.AnimationCurve`, so a notification made from a message does not convert back into
//   one.
// - The curve is the raw `integerValue`, unchecked: UIKit posts curve 7, which has no case.

@available(tvOS, unavailable)
@available(visionOS, unavailable)
extension UIResponder {
    /// Backports of the keyboard messages UIKit declares on `UIResponder` from iOS 26. See
    /// `NotificationCenter.Backport`.
    public enum Backport {}
}

@available(tvOS, unavailable)
@available(visionOS, unavailable)
protocol KeyboardNotificationMessageProviding: NotificationCenter.Backport.MainActorMessage where Subject == UIScreen {
    var beginFrame: CGRect { get }
    var endFrame: CGRect { get }
    var animationDuration: TimeInterval { get }
    var animationCurve: UIView.AnimationCurve { get }
    var isLocal: Bool { get }
    var screen: UIScreen { get }

    init(beginFrame: CGRect, endFrame: CGRect, animationDuration: TimeInterval, animationCurve: UIView.AnimationCurve, isLocal: Bool, screen: UIScreen)
}

@available(tvOS, unavailable)
@available(visionOS, unavailable)
extension KeyboardNotificationMessageProviding {
    @MainActor
    public static func makeMessage(_ notification: Notification) -> Self? {
        guard let userInfo = notification.userInfo,
              let beginFrame = userInfo[UIResponder.keyboardFrameBeginUserInfoKey] as? NSValue,
              let endFrame = userInfo[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue,
              let animationDuration = userInfo[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double,
              let animationCurve = userInfo[UIResponder.keyboardAnimationCurveUserInfoKey] as? NSNumber,
              let isLocal = userInfo[UIResponder.keyboardIsLocalUserInfoKey] as? Bool,
              let screen = notification.object as? UIScreen
        else {
            return nil
        }
        return Self(
            beginFrame: beginFrame.cgRectValue,
            endFrame: endFrame.cgRectValue,
            animationDuration: animationDuration,
            // Never `nil`: an imported, non-frozen enum takes any raw value, as UIKit's own store does.
            animationCurve: UIView.AnimationCurve(rawValue: animationCurve.intValue)!,
            isLocal: isLocal,
            screen: screen
        )
    }

    @MainActor
    public static func makeNotification(_ message: Self) -> Notification {
        Notification(
            name: name,
            object: message.screen,
            userInfo: [
                UIResponder.keyboardFrameBeginUserInfoKey: message.beginFrame,
                UIResponder.keyboardFrameEndUserInfoKey: message.endFrame,
                UIResponder.keyboardAnimationDurationUserInfoKey: message.animationDuration,
                UIResponder.keyboardAnimationCurveUserInfoKey: message.animationCurve,
                UIResponder.keyboardIsLocalUserInfoKey: message.isLocal,
            ]
        )
    }
}

@available(tvOS, unavailable)
@available(visionOS, unavailable)
extension UIResponder.Backport {
    /// A message that the system sends immediately before it displays the keyboard.
    public struct KeyboardWillShowMessage: NotificationCenter.Backport.MainActorMessage, KeyboardNotificationMessageProviding {
        public typealias Subject = UIScreen

        public static var name: Notification.Name {
            UIResponder.keyboardWillShowNotification
        }

        /// The keyboard's frame at the start of the animation, in the screen's coordinate space.
        public var beginFrame: CGRect

        /// The keyboard's frame at the end of the animation, in the screen's coordinate space.
        public var endFrame: CGRect

        /// The duration of the keyboard's animation, in seconds.
        public var animationDuration: TimeInterval

        /// The animation curve the system uses to animate the keyboard.
        public var animationCurve: UIView.AnimationCurve

        /// A Boolean value that indicates whether the keyboard belongs to the current app.
        public var isLocal: Bool

        /// The screen that displays the keyboard.
        public var screen: UIScreen

        public init(beginFrame: CGRect, endFrame: CGRect, animationDuration: TimeInterval, animationCurve: UIView.AnimationCurve, isLocal: Bool, screen: UIScreen) {
            self.beginFrame = beginFrame
            self.endFrame = endFrame
            self.animationDuration = animationDuration
            self.animationCurve = animationCurve
            self.isLocal = isLocal
            self.screen = screen
        }
    }

    /// A message that the system sends immediately after it displays the keyboard.
    public struct KeyboardDidShowMessage: NotificationCenter.Backport.MainActorMessage, KeyboardNotificationMessageProviding {
        public typealias Subject = UIScreen

        public static var name: Notification.Name {
            UIResponder.keyboardDidShowNotification
        }

        /// The keyboard's frame at the start of the animation, in the screen's coordinate space.
        public var beginFrame: CGRect

        /// The keyboard's frame at the end of the animation, in the screen's coordinate space.
        public var endFrame: CGRect

        /// The duration of the keyboard's animation, in seconds.
        public var animationDuration: TimeInterval

        /// The animation curve the system uses to animate the keyboard.
        public var animationCurve: UIView.AnimationCurve

        /// A Boolean value that indicates whether the keyboard belongs to the current app.
        public var isLocal: Bool

        /// The screen that displays the keyboard.
        public var screen: UIScreen

        public init(beginFrame: CGRect, endFrame: CGRect, animationDuration: TimeInterval, animationCurve: UIView.AnimationCurve, isLocal: Bool, screen: UIScreen) {
            self.beginFrame = beginFrame
            self.endFrame = endFrame
            self.animationDuration = animationDuration
            self.animationCurve = animationCurve
            self.isLocal = isLocal
            self.screen = screen
        }
    }

    /// A message that the system sends immediately before it dismisses the keyboard.
    public struct KeyboardWillHideMessage: NotificationCenter.Backport.MainActorMessage, KeyboardNotificationMessageProviding {
        public typealias Subject = UIScreen

        public static var name: Notification.Name {
            UIResponder.keyboardWillHideNotification
        }

        /// The keyboard's frame at the start of the animation, in the screen's coordinate space.
        public var beginFrame: CGRect

        /// The keyboard's frame at the end of the animation, in the screen's coordinate space.
        public var endFrame: CGRect

        /// The duration of the keyboard's animation, in seconds.
        public var animationDuration: TimeInterval

        /// The animation curve the system uses to animate the keyboard.
        public var animationCurve: UIView.AnimationCurve

        /// A Boolean value that indicates whether the keyboard belongs to the current app.
        public var isLocal: Bool

        /// The screen that displays the keyboard.
        public var screen: UIScreen

        public init(beginFrame: CGRect, endFrame: CGRect, animationDuration: TimeInterval, animationCurve: UIView.AnimationCurve, isLocal: Bool, screen: UIScreen) {
            self.beginFrame = beginFrame
            self.endFrame = endFrame
            self.animationDuration = animationDuration
            self.animationCurve = animationCurve
            self.isLocal = isLocal
            self.screen = screen
        }
    }

    /// A message that the system sends immediately after it dismisses the keyboard.
    public struct KeyboardDidHideMessage: NotificationCenter.Backport.MainActorMessage, KeyboardNotificationMessageProviding {
        public typealias Subject = UIScreen

        public static var name: Notification.Name {
            UIResponder.keyboardDidHideNotification
        }

        /// The keyboard's frame at the start of the animation, in the screen's coordinate space.
        public var beginFrame: CGRect

        /// The keyboard's frame at the end of the animation, in the screen's coordinate space.
        public var endFrame: CGRect

        /// The duration of the keyboard's animation, in seconds.
        public var animationDuration: TimeInterval

        /// The animation curve the system uses to animate the keyboard.
        public var animationCurve: UIView.AnimationCurve

        /// A Boolean value that indicates whether the keyboard belongs to the current app.
        public var isLocal: Bool

        /// The screen that displays the keyboard.
        public var screen: UIScreen

        public init(beginFrame: CGRect, endFrame: CGRect, animationDuration: TimeInterval, animationCurve: UIView.AnimationCurve, isLocal: Bool, screen: UIScreen) {
            self.beginFrame = beginFrame
            self.endFrame = endFrame
            self.animationDuration = animationDuration
            self.animationCurve = animationCurve
            self.isLocal = isLocal
            self.screen = screen
        }
    }

    /// A message that the system sends immediately before a change in the keyboard's frame.
    public struct KeyboardWillChangeFrameMessage: NotificationCenter.Backport.MainActorMessage, KeyboardNotificationMessageProviding {
        public typealias Subject = UIScreen

        public static var name: Notification.Name {
            UIResponder.keyboardWillChangeFrameNotification
        }

        /// The keyboard's frame at the start of the animation, in the screen's coordinate space.
        public var beginFrame: CGRect

        /// The keyboard's frame at the end of the animation, in the screen's coordinate space.
        public var endFrame: CGRect

        /// The duration of the keyboard's animation, in seconds.
        public var animationDuration: TimeInterval

        /// The animation curve the system uses to animate the keyboard.
        public var animationCurve: UIView.AnimationCurve

        /// A Boolean value that indicates whether the keyboard belongs to the current app.
        public var isLocal: Bool

        /// The screen that displays the keyboard.
        public var screen: UIScreen

        public init(beginFrame: CGRect, endFrame: CGRect, animationDuration: TimeInterval, animationCurve: UIView.AnimationCurve, isLocal: Bool, screen: UIScreen) {
            self.beginFrame = beginFrame
            self.endFrame = endFrame
            self.animationDuration = animationDuration
            self.animationCurve = animationCurve
            self.isLocal = isLocal
            self.screen = screen
        }
    }

    /// A message that the system sends immediately after a change in the keyboard's frame.
    public struct KeyboardDidChangeFrameMessage: NotificationCenter.Backport.MainActorMessage, KeyboardNotificationMessageProviding {
        public typealias Subject = UIScreen

        public static var name: Notification.Name {
            UIResponder.keyboardDidChangeFrameNotification
        }

        /// The keyboard's frame at the start of the animation, in the screen's coordinate space.
        public var beginFrame: CGRect

        /// The keyboard's frame at the end of the animation, in the screen's coordinate space.
        public var endFrame: CGRect

        /// The duration of the keyboard's animation, in seconds.
        public var animationDuration: TimeInterval

        /// The animation curve the system uses to animate the keyboard.
        public var animationCurve: UIView.AnimationCurve

        /// A Boolean value that indicates whether the keyboard belongs to the current app.
        public var isLocal: Bool

        /// The screen that displays the keyboard.
        public var screen: UIScreen

        public init(beginFrame: CGRect, endFrame: CGRect, animationDuration: TimeInterval, animationCurve: UIView.AnimationCurve, isLocal: Bool, screen: UIScreen) {
            self.beginFrame = beginFrame
            self.endFrame = endFrame
            self.animationDuration = animationDuration
            self.animationCurve = animationCurve
            self.isLocal = isLocal
            self.screen = screen
        }
    }
}

@available(tvOS, unavailable)
@available(visionOS, unavailable)
extension NotificationCenter.Backport.MessageIdentifier
where Self == NotificationCenter.Backport.BaseMessageIdentifier<UIResponder.Backport.KeyboardWillShowMessage> {
    /// The identifier of `UIResponder.Backport.KeyboardWillShowMessage`.
    @_disfavoredOverload
    public static var keyboardWillShow: Self { .init() }
}

@available(tvOS, unavailable)
@available(visionOS, unavailable)
extension NotificationCenter.Backport.MessageIdentifier
where Self == NotificationCenter.Backport.BaseMessageIdentifier<UIResponder.Backport.KeyboardDidShowMessage> {
    /// The identifier of `UIResponder.Backport.KeyboardDidShowMessage`.
    @_disfavoredOverload
    public static var keyboardDidShow: Self { .init() }
}

@available(tvOS, unavailable)
@available(visionOS, unavailable)
extension NotificationCenter.Backport.MessageIdentifier
where Self == NotificationCenter.Backport.BaseMessageIdentifier<UIResponder.Backport.KeyboardWillHideMessage> {
    /// The identifier of `UIResponder.Backport.KeyboardWillHideMessage`.
    @_disfavoredOverload
    public static var keyboardWillHide: Self { .init() }
}

@available(tvOS, unavailable)
@available(visionOS, unavailable)
extension NotificationCenter.Backport.MessageIdentifier
where Self == NotificationCenter.Backport.BaseMessageIdentifier<UIResponder.Backport.KeyboardDidHideMessage> {
    /// The identifier of `UIResponder.Backport.KeyboardDidHideMessage`.
    @_disfavoredOverload
    public static var keyboardDidHide: Self { .init() }
}

@available(tvOS, unavailable)
@available(visionOS, unavailable)
extension NotificationCenter.Backport.MessageIdentifier
where Self == NotificationCenter.Backport.BaseMessageIdentifier<UIResponder.Backport.KeyboardWillChangeFrameMessage> {
    /// The identifier of `UIResponder.Backport.KeyboardWillChangeFrameMessage`.
    @_disfavoredOverload
    public static var keyboardWillChangeFrame: Self { .init() }
}

@available(tvOS, unavailable)
@available(visionOS, unavailable)
extension NotificationCenter.Backport.MessageIdentifier
where Self == NotificationCenter.Backport.BaseMessageIdentifier<UIResponder.Backport.KeyboardDidChangeFrameMessage> {
    /// The identifier of `UIResponder.Backport.KeyboardDidChangeFrameMessage`.
    @_disfavoredOverload
    public static var keyboardDidChangeFrame: Self { .init() }
}

#endif
