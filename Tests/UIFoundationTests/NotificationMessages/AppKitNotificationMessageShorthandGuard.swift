#if canImport(AppKit, _version: 2700) && !targetEnvironment(macCatalyst)

import AppKit
import FoundationToolbox
import UIFoundationToolbox

// A compile-time guard; nothing calls it. Every backported AppKit identifier is written once, as the
// shorthand, inside a block where AppKit's own identifier of the same name is available too. Each line
// compiles only while the backport's identifier is `@_disfavoredOverload`: without it the shorthand is
// ambiguous, and so would every consumer's be the moment they imported this library.
//
// The results are discarded on purpose. Binding one to a typed variable, or appending it to a typed
// array, lets the type checker pick the overload by that type, and the line would keep compiling with
// the attribute gone. The subject is always the metatype, because an instance of a subclass can match
// two identifiers at once (`.selectionDidChange` on an `NSOutlineView` is ambiguous in AppKit itself).
//
// The `if canImport(AppKit, _version: 2700)` gate keeps this to SDKs that declare AppKit's messages:
// the macOS 26 SDK carries only the `NSWorkspace` ones.
@MainActor
func observeThroughAppKitsOwnShorthand(_ center: NotificationCenter) {
    if #available(macOS 26, *) {
        _ = center.addObserver(of: NSWorkspace.self, for: .accessibilityDisplayOptionsDidChange) { _ in }
        _ = center.addObserver(of: NSWorkspace.self, for: .activeSpaceDidChange) { _ in }
        _ = center.addObserver(of: NSWorkspace.self, for: .didActivateApplication) { _ in }
        _ = center.addObserver(of: NSWorkspace.self, for: .didChangeFileLabels) { _ in }
        _ = center.addObserver(of: NSWorkspace.self, for: .didDeactivateApplication) { _ in }
        _ = center.addObserver(of: NSWorkspace.self, for: .didHideApplication) { _ in }
        _ = center.addObserver(of: NSWorkspace.self, for: .didLaunchApplication) { _ in }
        _ = center.addObserver(of: NSWorkspace.self, for: .didMountVolume) { _ in }
        _ = center.addObserver(of: NSWorkspace.self, for: .didRenameVolume) { _ in }
        _ = center.addObserver(of: NSWorkspace.self, for: .didTerminateApplication) { _ in }
        _ = center.addObserver(of: NSWorkspace.self, for: .didUnhideApplication) { _ in }
        _ = center.addObserver(of: NSWorkspace.self, for: .didUnmountVolume) { _ in }
        _ = center.addObserver(of: NSWorkspace.self, for: .didWake) { _ in }
        _ = center.addObserver(of: NSWorkspace.self, for: .screensDidSleep) { _ in }
        _ = center.addObserver(of: NSWorkspace.self, for: .screensDidWake) { _ in }
        _ = center.addObserver(of: NSWorkspace.self, for: .sessionDidBecomeActive) { _ in }
        _ = center.addObserver(of: NSWorkspace.self, for: .sessionDidResignActive) { _ in }
        _ = center.addObserver(of: NSWorkspace.self, for: .willLaunchApplication) { _ in }
        _ = center.addObserver(of: NSWorkspace.self, for: .willSleep) { _ in }
        _ = center.addObserver(of: NSWorkspace.self, for: .willUnmountVolume) { _ in }
    }
    if #available(macOS 27, *) {
        _ = center.addObserver(of: NSApplication.self, for: .didBecomeActive) { _ in }
        _ = center.addObserver(of: NSApplication.self, for: .didChangeOcclusionState) { _ in }
        _ = center.addObserver(of: NSApplication.self, for: .didChangeScreenParameters) { _ in }
        _ = center.addObserver(of: NSApplication.self, for: .didFinishRestoringWindows) { _ in }
        _ = center.addObserver(of: NSApplication.self, for: .didHide) { _ in }
        _ = center.addObserver(of: NSApplication.self, for: .didResignActive) { _ in }
        _ = center.addObserver(of: NSApplication.self, for: .didUnhide) { _ in }
        _ = center.addObserver(of: NSApplication.self, for: .didUpdateWindows) { _ in }
        _ = center.addObserver(of: NSApplication.self, for: .protectedDataDidBecomeAvailable) { _ in }
        _ = center.addObserver(of: NSApplication.self, for: .protectedDataWillBecomeUnavailable) { _ in }
        _ = center.addObserver(of: NSApplication.self, for: .willBecomeActive) { _ in }
        _ = center.addObserver(of: NSApplication.self, for: .willFinishLaunching) { _ in }
        _ = center.addObserver(of: NSApplication.self, for: .willHide) { _ in }
        _ = center.addObserver(of: NSApplication.self, for: .willResignActive) { _ in }
        _ = center.addObserver(of: NSApplication.self, for: .willTerminate) { _ in }
        _ = center.addObserver(of: NSApplication.self, for: .willUnhide) { _ in }
        _ = center.addObserver(of: NSApplication.self, for: .willUpdateWindows) { _ in }
        _ = center.addObserver(of: NSBrowser.self, for: .columnConfigurationDidChange) { _ in }
        _ = center.addObserver(of: NSColor.self, for: .systemColorsDidChange) { _ in }
        _ = center.addObserver(of: NSColorList.self, for: .didChange) { _ in }
        _ = center.addObserver(of: NSColorPanel.self, for: .colorDidChange) { _ in }
        _ = center.addObserver(of: NSComboBox.self, for: .selectionDidChange) { _ in }
        _ = center.addObserver(of: NSComboBox.self, for: .selectionIsChanging) { _ in }
        _ = center.addObserver(of: NSComboBox.self, for: .willDismiss) { _ in }
        _ = center.addObserver(of: NSComboBox.self, for: .willPopUp) { _ in }
        _ = center.addObserver(of: NSControl.self, for: .textDidBeginEditing) { _ in }
        _ = center.addObserver(of: NSControl.self, for: .textDidChange) { _ in }
        _ = center.addObserver(of: NSControl.self, for: .textDidEndEditing) { _ in }
        _ = center.addObserver(of: NSFont.self, for: .fontSetChanged) { _ in }
        _ = center.addObserver(of: NSFontCollection.self, for: .didChange) { _ in }
        _ = center.addObserver(of: NSHelpManager.self, for: .contextHelpModeDidActivate) { _ in }
        _ = center.addObserver(of: NSHelpManager.self, for: .contextHelpModeDidDeactivate) { _ in }
        _ = center.addObserver(of: NSImageRep.self, for: .registryDidChange) { _ in }
        _ = center.addObserver(of: NSMenu.self, for: .didAddItem) { _ in }
        _ = center.addObserver(of: NSMenu.self, for: .didBeginTracking) { _ in }
        _ = center.addObserver(of: NSMenu.self, for: .didChangeItem) { _ in }
        _ = center.addObserver(of: NSMenu.self, for: .didEndTracking) { _ in }
        _ = center.addObserver(of: NSMenu.self, for: .didRemoveItem) { _ in }
        _ = center.addObserver(of: NSMenu.self, for: .didSendAction) { _ in }
        _ = center.addObserver(of: NSMenu.self, for: .willSendAction) { _ in }
        _ = center.addObserver(of: NSOutlineView.self, for: .columnDidMove) { _ in }
        _ = center.addObserver(of: NSOutlineView.self, for: .columnDidResize) { _ in }
        _ = center.addObserver(of: NSOutlineView.self, for: .itemDidCollapse) { _ in }
        _ = center.addObserver(of: NSOutlineView.self, for: .itemDidExpand) { _ in }
        _ = center.addObserver(of: NSOutlineView.self, for: .itemWillCollapse) { _ in }
        _ = center.addObserver(of: NSOutlineView.self, for: .itemWillExpand) { _ in }
        _ = center.addObserver(of: NSOutlineView.self, for: .selectionDidChange) { _ in }
        _ = center.addObserver(of: NSOutlineView.self, for: .selectionIsChanging) { _ in }
        _ = center.addObserver(of: NSPopUpButton.self, for: .willPopUp) { _ in }
        _ = center.addObserver(of: NSPopUpButtonCell.self, for: .willPopUp) { _ in }
        _ = center.addObserver(of: NSPopover.self, for: .didClose) { _ in }
        _ = center.addObserver(of: NSPopover.self, for: .didShow) { _ in }
        _ = center.addObserver(of: NSPopover.self, for: .willClose) { _ in }
        _ = center.addObserver(of: NSPopover.self, for: .willShow) { _ in }
        _ = center.addObserver(of: NSRuleEditor.self, for: .rowsDidChange) { _ in }
        _ = center.addObserver(of: NSScreen.self, for: .colorSpaceDidChange) { _ in }
        _ = center.addObserver(of: NSScrollView.self, for: .didEndLiveMagnify) { _ in }
        _ = center.addObserver(of: NSScrollView.self, for: .didEndLiveScroll) { _ in }
        _ = center.addObserver(of: NSScrollView.self, for: .didLiveScroll) { _ in }
        _ = center.addObserver(of: NSScrollView.self, for: .willStartLiveMagnify) { _ in }
        _ = center.addObserver(of: NSScrollView.self, for: .willStartLiveScroll) { _ in }
        _ = center.addObserver(of: NSScroller.self, for: .preferredScrollerStyleDidChange) { _ in }
        _ = center.addObserver(of: NSSpellChecker.self, for: .didChangeAutomaticCapitalization) { _ in }
        _ = center.addObserver(of: NSSpellChecker.self, for: .didChangeAutomaticDashSubstitution) { _ in }
        _ = center.addObserver(of: NSSpellChecker.self, for: .didChangeAutomaticInlinePrediction) { _ in }
        _ = center.addObserver(of: NSSpellChecker.self, for: .didChangeAutomaticPeriodSubstitution) { _ in }
        _ = center.addObserver(of: NSSpellChecker.self, for: .didChangeAutomaticQuoteSubstitution) { _ in }
        _ = center.addObserver(of: NSSpellChecker.self, for: .didChangeAutomaticSpellingCorrection) { _ in }
        _ = center.addObserver(of: NSSpellChecker.self, for: .didChangeAutomaticTextCompletion) { _ in }
        _ = center.addObserver(of: NSSpellChecker.self, for: .didChangeAutomaticTextReplacement) { _ in }
        _ = center.addObserver(of: NSSplitView.self, for: .didResizeSubviews) { _ in }
        _ = center.addObserver(of: NSSplitView.self, for: .willResizeSubviews) { _ in }
        _ = center.addObserver(of: NSTableView.self, for: .columnDidMove) { _ in }
        _ = center.addObserver(of: NSTableView.self, for: .columnDidResize) { _ in }
        _ = center.addObserver(of: NSTableView.self, for: .selectionDidChange) { _ in }
        _ = center.addObserver(of: NSTableView.self, for: .selectionIsChanging) { _ in }
        _ = center.addObserver(of: NSTextAlternatives.self, for: .selectedAlternativeString) { _ in }
        _ = center.addObserver(of: NSTextInputContext.self, for: .keyboardSelectionDidChange) { _ in }
        _ = center.addObserver(of: NSText.self, for: .didBeginEditing) { _ in }
        _ = center.addObserver(of: NSText.self, for: .didChange) { _ in }
        _ = center.addObserver(of: NSTextView.self, for: .didChangeSelection) { _ in }
        _ = center.addObserver(of: NSTextView.self, for: .didChangeTypingAttributes) { _ in }
        _ = center.addObserver(of: NSText.self, for: .didEndEditing) { _ in }
        _ = center.addObserver(of: NSTextView.self, for: .willChangeNotifyingTextView) { _ in }
        _ = center.addObserver(of: NSToolbar.self, for: .didRemoveItem) { _ in }
        _ = center.addObserver(of: NSToolbar.self, for: .willAddItem) { _ in }
        _ = center.addObserver(of: NSView.self, for: .boundsDidChange) { _ in }
        _ = center.addObserver(of: NSView.self, for: .frameDidChange) { _ in }
        _ = center.addObserver(of: NSWindow.self, for: .didBecomeKey) { _ in }
        _ = center.addObserver(of: NSWindow.self, for: .didBecomeMain) { _ in }
        _ = center.addObserver(of: NSWindow.self, for: .didChangeBackingProperties) { _ in }
        _ = center.addObserver(of: NSWindow.self, for: .didChangeOcclusionState) { _ in }
        _ = center.addObserver(of: NSWindow.self, for: .didChangeScreen) { _ in }
        _ = center.addObserver(of: NSWindow.self, for: .didChangeScreenProfile) { _ in }
        _ = center.addObserver(of: NSWindow.self, for: .didDeminiaturize) { _ in }
        _ = center.addObserver(of: NSWindow.self, for: .didEndLiveResize) { _ in }
        _ = center.addObserver(of: NSWindow.self, for: .didEndSheet) { _ in }
        _ = center.addObserver(of: NSWindow.self, for: .didEnterFullScreen) { _ in }
        _ = center.addObserver(of: NSWindow.self, for: .didEnterVersionBrowser) { _ in }
        _ = center.addObserver(of: NSWindow.self, for: .didExitFullScreen) { _ in }
        _ = center.addObserver(of: NSWindow.self, for: .didExitVersionBrowser) { _ in }
        _ = center.addObserver(of: NSWindow.self, for: .didExpose) { _ in }
        _ = center.addObserver(of: NSWindow.self, for: .didMiniaturize) { _ in }
        _ = center.addObserver(of: NSWindow.self, for: .didMove) { _ in }
        _ = center.addObserver(of: NSWindow.self, for: .didResignKey) { _ in }
        _ = center.addObserver(of: NSWindow.self, for: .didResignMain) { _ in }
        _ = center.addObserver(of: NSWindow.self, for: .didResize) { _ in }
        _ = center.addObserver(of: NSWindow.self, for: .didUpdate) { _ in }
        _ = center.addObserver(of: NSWindow.self, for: .willBeginSheet) { _ in }
        _ = center.addObserver(of: NSWindow.self, for: .willClose) { _ in }
        _ = center.addObserver(of: NSWindow.self, for: .willEnterFullScreen) { _ in }
        _ = center.addObserver(of: NSWindow.self, for: .willEnterVersionBrowser) { _ in }
        _ = center.addObserver(of: NSWindow.self, for: .willExitFullScreen) { _ in }
        _ = center.addObserver(of: NSWindow.self, for: .willExitVersionBrowser) { _ in }
        _ = center.addObserver(of: NSWindow.self, for: .willMiniaturize) { _ in }
        _ = center.addObserver(of: NSWindow.self, for: .willMove) { _ in }
        _ = center.addObserver(of: NSWindow.self, for: .willStartLiveResize) { _ in }
    }
}

#endif
