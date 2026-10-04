#if canImport(UIKit) && !os(watchOS)

import Testing
import UIKit
import FoundationToolbox
import UIFoundationToolbox

/// Holds every backported UIKit message up against UIKit's own (see `NotificationMessageParity.swift`).
/// Runs where the tests can run UIKit without a simulator: Mac Catalyst. UIKit declares its messages
/// from iOS 26, so on an older system the argument list is empty.
///
/// Fixtures carry the value types UIKit itself posts -- `NSNumber`, `NSValue`, `NSString`, `NSArray` --
/// and objects that were allocated but never initialized (`IdentityOnlyObjects`): no `UIScene` or
/// `UIScreen` can be made properly without a running app, and the conversion only casts the object.
@Suite("UIKit notification messages match UIKit's own")
@MainActor
struct UIKitNotificationMessageParityTests {
    @Test("UIKit", arguments: uiKitPairs)
    func uiKit(_ pair: MessagePair) throws {
        try pair.check()
    }

    /// The one conversion that never fails: with no element in the notification, UIKit's own
    /// implementation bridges the missing value to `NSNull` rather than leaving `element` `nil`.
    @Test("ElementFocusedMessage holds NSNull when the notification carries no element")
    func elementFocusedWithoutElement() throws {
        let notification = Notification(name: UIAccessibility.elementFocusedNotification)
        let message = try #require(UIAccessibility.Backport.ElementFocusedMessage.makeMessage(notification))
        #expect(message.element is NSNull)
        if #available(iOS 26, macCatalyst 26, tvOS 26, visionOS 26, *) {
            let uiKitMessage = try #require(UIAccessibility.ElementFocusedMessage.makeMessage(notification))
            #expect(uiKitMessage.element is NSNull)
        }
    }

    /// UIKit posts the reason as an `NSNumber`, and the conversion casts it straight to the
    /// enumeration, which an `NSNumber` does not cast to.
    @Test("A text field's end-editing reason posted as an NSNumber reads as nil")
    func textFieldReasonPostedAsNumber() throws {
        let notification = Notification(
            name: UITextField.textDidEndEditingNotification,
            object: IdentityOnlyObjects.make(UITextField.self),
            userInfo: [UITextField.didEndEditingReasonUserInfoKey: NSNumber(value: 0)]
        )
        let message = try #require(UITextField.Backport.TextDidEndEditingMessage.makeMessage(notification))
        #expect(message.reason == nil)
        if #available(iOS 26, macCatalyst 26, tvOS 26, visionOS 26, *) {
            let uiKitMessage = try #require(UITextField.TextDidEndEditingMessage.makeMessage(notification))
            #expect(uiKitMessage.reason == nil)
        }
    }

    #if os(iOS)
    /// `makeNotification(_:)` writes the frames and the curve as Swift values, while `makeMessage(_:)`
    /// reads them as `NSValue` and `NSNumber` -- so in UIKit, and therefore here, a notification made
    /// from a keyboard message does not convert back into one.
    @Test("A keyboard notification made from a message does not convert back")
    func keyboardMessageRoundTrip() throws {
        let screen = try #require(IdentityOnlyObjects.make(UIScreen.self) as? UIScreen)
        let beginFrame = CGRect(x: 0, y: 600, width: 320, height: 260)
        let endFrame = CGRect(x: 0, y: 340, width: 320, height: 260)
        let message = UIResponder.Backport.KeyboardWillShowMessage(
            beginFrame: beginFrame, endFrame: endFrame, animationDuration: 0.25,
            animationCurve: .easeInOut, isLocal: true, screen: screen
        )
        let notification = UIResponder.Backport.KeyboardWillShowMessage.makeNotification(message)
        #expect(UIResponder.Backport.KeyboardWillShowMessage.makeMessage(notification) == nil)
        if #available(iOS 26, macCatalyst 26, *) {
            let uiKitMessage = UIResponder.KeyboardWillShowMessage(
                beginFrame: beginFrame, endFrame: endFrame, animationDuration: 0.25,
                animationCurve: .easeInOut, isLocal: true, screen: screen
            )
            let uiKitNotification = UIResponder.KeyboardWillShowMessage.makeNotification(uiKitMessage)
            #expect(UIResponder.KeyboardWillShowMessage.makeMessage(uiKitNotification) == nil)
        }
    }
    #endif
}

private let uiKitPairs: [MessagePair] = {
    guard #available(iOS 26, macCatalyst 26, tvOS 26, visionOS 26, *) else { return [] }

    func object(_ objectClass: NSObject.Type) -> @MainActor @Sendable () -> Any? {
        { IdentityOnlyObjects.make(objectClass) }
    }
    let keyboard: @MainActor @Sendable () -> [AnyHashable: Any] = {
        [
            UIResponder.keyboardFrameBeginUserInfoKey: NSValue(cgRect: CGRect(x: 0, y: 900, width: 400, height: 300)),
            UIResponder.keyboardFrameEndUserInfoKey: NSValue(cgRect: CGRect(x: 0, y: 600, width: 400, height: 300)),
            UIResponder.keyboardAnimationDurationUserInfoKey: NSNumber(value: 0.25),
            // 7 is the curve UIKit posts for the keyboard, and has no case of its own.
            UIResponder.keyboardAnimationCurveUserInfoKey: NSNumber(value: 7),
            UIResponder.keyboardIsLocalUserInfoKey: NSNumber(value: true),
        ]
    }
    let focusUpdate: @MainActor @Sendable () -> [AnyHashable: Any] = {
        [
            UIFocusSystem.focusUpdateContextUserInfoKey: IdentityOnlyObjects.make(UIFocusUpdateContext.self),
            UIFocusSystem.animationCoordinatorUserInfoKey: IdentityOnlyObjects.make(UIFocusAnimationCoordinator.self),
        ]
    }

    var pairs: [MessagePair] = [
        .mainActor(UIResponder.KeyboardWillShowMessage.self, UIResponder.Backport.KeyboardWillShowMessage.self, object: object(UIScreen.self), userInfo: keyboard),
        .mainActor(UIResponder.KeyboardDidShowMessage.self, UIResponder.Backport.KeyboardDidShowMessage.self, object: object(UIScreen.self), userInfo: keyboard),
        .mainActor(UIResponder.KeyboardWillHideMessage.self, UIResponder.Backport.KeyboardWillHideMessage.self, object: object(UIScreen.self), userInfo: keyboard),
        .mainActor(UIResponder.KeyboardDidHideMessage.self, UIResponder.Backport.KeyboardDidHideMessage.self, object: object(UIScreen.self), userInfo: keyboard),
        .mainActor(UIResponder.KeyboardWillChangeFrameMessage.self, UIResponder.Backport.KeyboardWillChangeFrameMessage.self, object: object(UIScreen.self), userInfo: keyboard),
        .mainActor(UIResponder.KeyboardDidChangeFrameMessage.self, UIResponder.Backport.KeyboardDidChangeFrameMessage.self, object: object(UIScreen.self), userInfo: keyboard),

        .mainActor(UIAccessibility.VoiceOverStatusDidChangeMessage.self, UIAccessibility.Backport.VoiceOverStatusDidChangeMessage.self),
        .mainActor(UIAccessibility.MonoAudioStatusDidChangeMessage.self, UIAccessibility.Backport.MonoAudioStatusDidChangeMessage.self),
        .mainActor(UIAccessibility.ClosedCaptioningStatusDidChangeMessage.self, UIAccessibility.Backport.ClosedCaptioningStatusDidChangeMessage.self),
        .mainActor(UIAccessibility.InvertColorsStatusDidChangeMessage.self, UIAccessibility.Backport.InvertColorsStatusDidChangeMessage.self),
        .mainActor(UIAccessibility.GuidedAccessStatusDidChangeMessage.self, UIAccessibility.Backport.GuidedAccessStatusDidChangeMessage.self),
        .mainActor(UIAccessibility.BoldTextStatusDidChangeMessage.self, UIAccessibility.Backport.BoldTextStatusDidChangeMessage.self),
        .mainActor(UIAccessibility.GrayscaleStatusDidChangeMessage.self, UIAccessibility.Backport.GrayscaleStatusDidChangeMessage.self),
        .mainActor(UIAccessibility.ReduceTransparencyStatusDidChangeMessage.self, UIAccessibility.Backport.ReduceTransparencyStatusDidChangeMessage.self),
        .mainActor(UIAccessibility.ReduceMotionStatusDidChangeMessage.self, UIAccessibility.Backport.ReduceMotionStatusDidChangeMessage.self),
        .mainActor(UIAccessibility.DarkerSystemColorsStatusDidChangeMessage.self, UIAccessibility.Backport.DarkerSystemColorsStatusDidChangeMessage.self),
        .mainActor(UIAccessibility.SwitchControlStatusDidChangeMessage.self, UIAccessibility.Backport.SwitchControlStatusDidChangeMessage.self),
        .mainActor(UIAccessibility.SpeakSelectionStatusDidChangeMessage.self, UIAccessibility.Backport.SpeakSelectionStatusDidChangeMessage.self),
        .mainActor(UIAccessibility.SpeakScreenStatusDidChangeMessage.self, UIAccessibility.Backport.SpeakScreenStatusDidChangeMessage.self),
        .mainActor(UIAccessibility.ShakeToUndoDidChangeMessage.self, UIAccessibility.Backport.ShakeToUndoDidChangeMessage.self),
        .mainActor(UIAccessibility.AssistiveTouchStatusDidChangeMessage.self, UIAccessibility.Backport.AssistiveTouchStatusDidChangeMessage.self),
        .mainActor(UIAccessibility.HearingDevicePairedEarDidChangeMessage.self, UIAccessibility.Backport.HearingDevicePairedEarDidChangeMessage.self),
        .mainActor(UIAccessibility.ElementFocusedMessage.self, UIAccessibility.Backport.ElementFocusedMessage.self, userInfo: {
            [UIAccessibility.focusedElementUserInfoKey: IdentityOnlyObjects.make(UIView.self)]
        }),
        .mainActor(UIAccessibility.AnnouncementDidFinishMessage.self, UIAccessibility.Backport.AnnouncementDidFinishMessage.self, userInfo: {
            [
                UIAccessibility.announcementStringValueUserInfoKey: "Saved" as NSString,
                UIAccessibility.announcementWasSuccessfulUserInfoKey: NSNumber(value: true),
            ]
        }),

        .mainActor(UIApplication.DidFinishLaunchingMessage.self, UIApplication.Backport.DidFinishLaunchingMessage.self),
        .mainActor(UIApplication.DidBecomeActiveMessage.self, UIApplication.Backport.DidBecomeActiveMessage.self),
        .mainActor(UIApplication.DidEnterBackgroundMessage.self, UIApplication.Backport.DidEnterBackgroundMessage.self),
        .mainActor(UIApplication.WillEnterForegroundMessage.self, UIApplication.Backport.WillEnterForegroundMessage.self),
        .mainActor(UIApplication.WillResignActiveMessage.self, UIApplication.Backport.WillResignActiveMessage.self),
        .mainActor(UIApplication.WillTerminateMessage.self, UIApplication.Backport.WillTerminateMessage.self),
        .mainActor(UIApplication.DidReceiveMemoryWarningMessage.self, UIApplication.Backport.DidReceiveMemoryWarningMessage.self),
        .mainActor(UIApplication.SignificantTimeChangeMessage.self, UIApplication.Backport.SignificantTimeChangeMessage.self),
        .mainActor(UIApplication.BackgroundRefreshStatusDidChangeMessage.self, UIApplication.Backport.BackgroundRefreshStatusDidChangeMessage.self),
        .mainActor(UIApplication.UserDidTakeScreenshotMessage.self, UIApplication.Backport.UserDidTakeScreenshotMessage.self),
        .mainActor(UIApplication.ProtectedDataDidBecomeAvailableMessage.self, UIApplication.Backport.ProtectedDataDidBecomeAvailableMessage.self),
        .mainActor(UIApplication.ProtectedDataWillBecomeUnavailableMessage.self, UIApplication.Backport.ProtectedDataWillBecomeUnavailableMessage.self),

        .mainActor(UIDevice.BatteryLevelDidChangeMessage.self, UIDevice.Backport.BatteryLevelDidChangeMessage.self),
        .mainActor(UIDevice.BatteryStateDidChangeMessage.self, UIDevice.Backport.BatteryStateDidChangeMessage.self),
        .mainActor(UIDevice.OrientationDidChangeMessage.self, UIDevice.Backport.OrientationDidChangeMessage.self),
        .mainActor(UIDevice.ProximityStateDidChangeMessage.self, UIDevice.Backport.ProximityStateDidChangeMessage.self),

        .mainActor(UIPasteboard.ChangedMessage.self, UIPasteboard.Backport.ChangedMessage.self, object: object(UIPasteboard.self), userInfo: {
            [
                UIPasteboard.changedTypesAddedUserInfoKey: ["public.utf8-plain-text"] as NSArray,
                UIPasteboard.changedTypesRemovedUserInfoKey: ["public.png"] as NSArray,
            ]
        }),
        .mainActor(UIPasteboard.RemovedMessage.self, UIPasteboard.Backport.RemovedMessage.self, object: object(UIPasteboard.self)),

        .mainActor(UITextInputMode.CurrentInputModeDidChangeMessage.self, UITextInputMode.Backport.CurrentInputModeDidChangeMessage.self),

        .mainActor(UIScene.WillConnectMessage.self, UIScene.Backport.WillConnectMessage.self, object: object(UIScene.self)),
        .mainActor(UIScene.WillEnterForegroundMessage.self, UIScene.Backport.WillEnterForegroundMessage.self, object: object(UIScene.self)),
        .mainActor(UIScene.DidActivateMessage.self, UIScene.Backport.DidActivateMessage.self, object: object(UIScene.self)),
        .mainActor(UIScene.WillDeactivateMessage.self, UIScene.Backport.WillDeactivateMessage.self, object: object(UIScene.self)),
        .mainActor(UIScene.DidEnterBackgroundMessage.self, UIScene.Backport.DidEnterBackgroundMessage.self, object: object(UIScene.self)),
        .mainActor(UIScene.SystemProtectionDidChangeMessage.self, UIScene.Backport.SystemProtectionDidChangeMessage.self, object: object(UIScene.self)),

        .mainActor(UIWindow.DidBecomeVisibleMessage.self, UIWindow.Backport.DidBecomeVisibleMessage.self, object: object(UIWindow.self)),
        .mainActor(UIWindow.DidBecomeHiddenMessage.self, UIWindow.Backport.DidBecomeHiddenMessage.self, object: object(UIWindow.self)),
        .mainActor(UIWindow.DidBecomeKeyMessage.self, UIWindow.Backport.DidBecomeKeyMessage.self, object: object(UIWindow.self)),
        .mainActor(UIWindow.DidResignKeyMessage.self, UIWindow.Backport.DidResignKeyMessage.self, object: object(UIWindow.self)),

        .mainActor(UIScreen.BrightnessDidChangeMessage.self, UIScreen.Backport.BrightnessDidChangeMessage.self, object: object(UIScreen.self)),
        .mainActor(UIScreen.ModeDidChangeMessage.self, UIScreen.Backport.ModeDidChangeMessage.self, object: object(UIScreen.self)),
        .mainActor(UIScreen.CapturedDidChangeMessage.self, UIScreen.Backport.CapturedDidChangeMessage.self, object: object(UIScreen.self)),
        .mainActor(UIScreen.ReferenceDisplayModeStatusDidChangeMessage.self, UIScreen.Backport.ReferenceDisplayModeStatusDidChangeMessage.self, object: object(UIScreen.self)),

        .mainActor(UITextView.TextDidBeginEditingMessage.self, UITextView.Backport.TextDidBeginEditingMessage.self, object: object(UITextView.self)),
        .mainActor(UITextView.TextDidChangeMessage.self, UITextView.Backport.TextDidChangeMessage.self, object: object(UITextView.self)),
        .mainActor(UITextView.TextDidEndEditingMessage.self, UITextView.Backport.TextDidEndEditingMessage.self, object: object(UITextView.self)),

        .mainActor(UITextField.TextDidBeginEditingMessage.self, UITextField.Backport.TextDidBeginEditingMessage.self, object: object(UITextField.self)),
        .mainActor(UITextField.TextDidChangeMessage.self, UITextField.Backport.TextDidChangeMessage.self, object: object(UITextField.self)),
        // UIKit posts the reason as an NSNumber, which is exactly the case that reads back as nil.
        .mainActor(UITextField.TextDidEndEditingMessage.self, UITextField.Backport.TextDidEndEditingMessage.self, object: object(UITextField.self), userInfo: {
            [UITextField.didEndEditingReasonUserInfoKey: NSNumber(value: 0)]
        }),

        .mainActor(UIFocusSystem.DidUpdateMessage.self, UIFocusSystem.Backport.DidUpdateMessage.self, object: object(UIFocusSystem.self), userInfo: focusUpdate),
        .mainActor(UIFocusSystem.MovementDidFailMessage.self, UIFocusSystem.Backport.MovementDidFailMessage.self, object: object(UIFocusSystem.self), userInfo: focusUpdate),

        .mainActor(UIDocument.StateChangedMessage.self, UIDocument.Backport.StateChangedMessage.self, object: object(UIDocument.self)),
        .mainActor(UIViewController.ShowDetailTargetDidChangeMessage.self, UIViewController.Backport.ShowDetailTargetDidChangeMessage.self, object: object(UIViewController.self)),
        .mainActor(UITableView.SelectionDidChangeMessage.self, UITableView.Backport.SelectionDidChangeMessage.self, object: object(UITableView.self)),
        .mainActor(UIContentSizeCategory.DidChangeMessage.self, UIContentSizeCategory.Backport.DidChangeMessage.self, object: object(UIScreen.self), userInfo: {
            [UIContentSizeCategory.newValueUserInfoKey: UIContentSizeCategory.extraLarge.rawValue as NSString]
        }),
        .mainActor(UIPointerLockState.DidChangeMessage.self, UIPointerLockState.Backport.DidChangeMessage.self, object: object(UIPointerLockState.self), userInfo: {
            [UIPointerLockState.sceneUserInfoKey: IdentityOnlyObjects.make(UIScene.self)]
        }),
    ]
    pairs.append(contentsOf: deprecatedPairs(from: UIKitDeprecatedMessagePairs.self))
    return pairs
}()

/// Reaches the pairs of messages UIKit has deprecated without a deprecation warning: Swift checks a call
/// through a protocol requirement against the requirement, not against the deprecated witness.
private protocol DeprecatedMessagePairs {
    static var pairs: [MessagePair] { get }
}

private enum UIKitDeprecatedMessagePairs: DeprecatedMessagePairs {
    @available(*, deprecated, message: "Holds messages UIKit deprecated in 26.1 up against UIKit's own.")
    static var pairs: [MessagePair] {
        guard #available(iOS 26, macCatalyst 26, tvOS 26, visionOS 26, *) else { return [] }
        return [
            .mainActor(UIAccessibility.ButtonShapesEnabledStatusDidChangeMessage.self, UIAccessibility.Backport.ButtonShapesEnabledStatusDidChangeMessage.self),
        ]
    }
}

private func deprecatedPairs<Provider: DeprecatedMessagePairs>(from provider: Provider.Type) -> [MessagePair] {
    Provider.pairs
}

#endif
