#if os(iOS)

import UIKit
import FoundationToolbox
import UIFoundationToolbox

// A compile-time guard; nothing calls it. The UIKit counterpart of
// `AppKitNotificationMessageShorthandGuard.swift` -- read that file for why every line is written the way
// it is. `os(iOS)` covers Mac Catalyst, where the UIKit tests run, and keeps out the platforms on which
// some of these messages are unavailable.
@MainActor
func observeThroughUIKitsOwnShorthand(_ center: NotificationCenter) {
    if #available(iOS 26, macCatalyst 26, *) {
        _ = center.addObserver(of: UIAccessibility.self, for: .announcementDidFinish) { _ in }
        _ = center.addObserver(of: UIAccessibility.self, for: .assistiveTouchStatusDidChange) { _ in }
        _ = center.addObserver(of: UIAccessibility.self, for: .boldTextStatusDidChange) { _ in }
        _ = center.addObserver(of: UIAccessibility.self, for: .closedCaptioningStatusDidChange) { _ in }
        _ = center.addObserver(of: UIAccessibility.self, for: .darkerSystemColorsStatusDidChange) { _ in }
        _ = center.addObserver(of: UIAccessibility.self, for: .elementFocused) { _ in }
        _ = center.addObserver(of: UIAccessibility.self, for: .grayscaleStatusDidChange) { _ in }
        _ = center.addObserver(of: UIAccessibility.self, for: .guidedAccessStatusDidChange) { _ in }
        _ = center.addObserver(of: UIAccessibility.self, for: .hearingDevicePairedEarDidChange) { _ in }
        _ = center.addObserver(of: UIAccessibility.self, for: .invertColorsStatusDidChange) { _ in }
        _ = center.addObserver(of: UIAccessibility.self, for: .monoAudioStatusDidChange) { _ in }
        _ = center.addObserver(of: UIAccessibility.self, for: .reduceMotionStatusDidChange) { _ in }
        _ = center.addObserver(of: UIAccessibility.self, for: .reduceTransparencyStatusDidChange) { _ in }
        _ = center.addObserver(of: UIAccessibility.self, for: .shakeToUndoDidChange) { _ in }
        _ = center.addObserver(of: UIAccessibility.self, for: .speakScreenStatusDidChange) { _ in }
        _ = center.addObserver(of: UIAccessibility.self, for: .speakSelectionStatusDidChange) { _ in }
        _ = center.addObserver(of: UIAccessibility.self, for: .switchControlStatusDidChange) { _ in }
        _ = center.addObserver(of: UIAccessibility.self, for: .voiceOverStatusDidChange) { _ in }
        _ = center.addObserver(of: UIApplication.self, for: .backgroundRefreshStatusDidChange) { _ in }
        _ = center.addObserver(of: UIApplication.self, for: .didBecomeActive) { _ in }
        _ = center.addObserver(of: UIApplication.self, for: .didEnterBackground) { _ in }
        _ = center.addObserver(of: UIApplication.self, for: .didFinishLaunching) { _ in }
        _ = center.addObserver(of: UIApplication.self, for: .didReceiveMemoryWarning) { _ in }
        _ = center.addObserver(of: UIApplication.self, for: .protectedDataDidBecomeAvailable) { _ in }
        _ = center.addObserver(of: UIApplication.self, for: .protectedDataWillBecomeUnavailable) { _ in }
        _ = center.addObserver(of: UIApplication.self, for: .significantTimeChange) { _ in }
        _ = center.addObserver(of: UIApplication.self, for: .userDidTakeScreenshot) { _ in }
        _ = center.addObserver(of: UIApplication.self, for: .willEnterForeground) { _ in }
        _ = center.addObserver(of: UIApplication.self, for: .willResignActive) { _ in }
        _ = center.addObserver(of: UIApplication.self, for: .willTerminate) { _ in }
        _ = center.addObserver(of: UIScreen.self, for: .contentSizeCategoryDidChange) { _ in }
        _ = center.addObserver(of: UIDevice.self, for: .batteryLevelDidChange) { _ in }
        _ = center.addObserver(of: UIDevice.self, for: .batteryStateDidChange) { _ in }
        _ = center.addObserver(of: UIDevice.self, for: .orientationDidChange) { _ in }
        _ = center.addObserver(of: UIDevice.self, for: .proximityStateDidChange) { _ in }
        _ = center.addObserver(of: UIDocument.self, for: .stateChanged) { _ in }
        _ = center.addObserver(of: UIFocusSystem.self, for: .didUpdate) { _ in }
        _ = center.addObserver(of: UIFocusSystem.self, for: .movementDidFail) { _ in }
        _ = center.addObserver(of: UIPasteboard.self, for: .changed) { _ in }
        _ = center.addObserver(of: UIPasteboard.self, for: .removed) { _ in }
        _ = center.addObserver(of: UIPointerLockState.self, for: .didChange) { _ in }
        _ = center.addObserver(of: UIScreen.self, for: .keyboardDidChangeFrame) { _ in }
        _ = center.addObserver(of: UIScreen.self, for: .keyboardDidHide) { _ in }
        _ = center.addObserver(of: UIScreen.self, for: .keyboardDidShow) { _ in }
        _ = center.addObserver(of: UIScreen.self, for: .keyboardWillChangeFrame) { _ in }
        _ = center.addObserver(of: UIScreen.self, for: .keyboardWillHide) { _ in }
        _ = center.addObserver(of: UIScreen.self, for: .keyboardWillShow) { _ in }
        _ = center.addObserver(of: UIScene.self, for: .didActivate) { _ in }
        _ = center.addObserver(of: UIScene.self, for: .didEnterBackground) { _ in }
        _ = center.addObserver(of: UIScene.self, for: .systemProtectionDidChange) { _ in }
        _ = center.addObserver(of: UIScene.self, for: .willConnect) { _ in }
        _ = center.addObserver(of: UIScene.self, for: .willDeactivate) { _ in }
        _ = center.addObserver(of: UIScene.self, for: .willEnterForeground) { _ in }
        _ = center.addObserver(of: UIScreen.self, for: .brightnessDidChange) { _ in }
        _ = center.addObserver(of: UIScreen.self, for: .capturedDidChange) { _ in }
        _ = center.addObserver(of: UIScreen.self, for: .modeDidChange) { _ in }
        _ = center.addObserver(of: UIScreen.self, for: .referenceDisplayModeStatusDidChange) { _ in }
        _ = center.addObserver(of: UITableView.self, for: .selectionDidChange) { _ in }
        _ = center.addObserver(of: UITextField.self, for: .textDidBeginEditing) { _ in }
        _ = center.addObserver(of: UITextField.self, for: .textDidChange) { _ in }
        _ = center.addObserver(of: UITextField.self, for: .textDidEndEditing) { _ in }
        _ = center.addObserver(of: UITextInputMode.self, for: .currentInputModeDidChange) { _ in }
        _ = center.addObserver(of: UITextView.self, for: .textDidBeginEditing) { _ in }
        _ = center.addObserver(of: UITextView.self, for: .textDidChange) { _ in }
        _ = center.addObserver(of: UITextView.self, for: .textDidEndEditing) { _ in }
        _ = center.addObserver(of: UIViewController.self, for: .showDetailTargetDidChange) { _ in }
        _ = center.addObserver(of: UIWindow.self, for: .didBecomeHidden) { _ in }
        _ = center.addObserver(of: UIWindow.self, for: .didBecomeKey) { _ in }
        _ = center.addObserver(of: UIWindow.self, for: .didBecomeVisible) { _ in }
        _ = center.addObserver(of: UIWindow.self, for: .didResignKey) { _ in }
    }
}

/// The deprecated message, apart: a deprecated function may use a deprecated declaration without a
/// warning, and as long as nothing calls this one, it raises none either.
@available(*, deprecated, message: "Guards an identifier UIKit deprecated in 26.1; never call it.")
@MainActor
func observeDeprecatedMessagesThroughUIKitsOwnShorthand(_ center: NotificationCenter) {
    if #available(iOS 26, macCatalyst 26, *) {
        _ = center.addObserver(of: UIAccessibility.self, for: .buttonShapesEnabledStatusDidChange) { _ in }
    }
}

#endif
