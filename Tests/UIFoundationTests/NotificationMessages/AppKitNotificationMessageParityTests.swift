#if canImport(AppKit) && !targetEnvironment(macCatalyst)

import Testing
import AppKit
import FoundationToolbox
import UIFoundationToolbox

/// Holds every backported AppKit message up against AppKit's own: the same `name`, the same
/// `makeMessage(_:)` result for a complete notification and for every way of breaking it, and the
/// same `makeNotification(_:)` output (see `NotificationMessageParity.swift`).
///
/// AppKit declares the `NSWorkspace` messages from macOS 26 and the rest from macOS 27, so on an
/// older system the argument lists are empty. Fixtures carry the value types AppKit itself posts --
/// `NSString`, `NSURL`, `NSNumber` -- rather than Swift values.
@Suite("AppKit notification messages match AppKit's own")
@MainActor
struct AppKitNotificationMessageParityTests {
    @Test("NSWorkspace", arguments: workspacePairs)
    func workspace(_ pair: MessagePair) throws {
        try pair.check()
    }

    #if canImport(AppKit, _version: 2700)
    @Test("Everything but NSWorkspace", arguments: appKitPairs)
    func appKit(_ pair: MessagePair) throws {
        try pair.check()
    }
    #endif

    /// AppKit posts the visibility as an `NSNumber` (measured on macOS 27.0), and the conversion casts
    /// it straight to `NSFontCollection.Visibility`, which an `NSNumber` does not cast to.
    @Test("A visibility posted as an NSNumber reads as nil")
    func fontCollectionVisibilityPostedAsNumber() throws {
        let notification = Notification(
            name: NSFontCollection.didChangeNotification,
            object: IdentityOnlyObjects.make(NSFontCollection.self),
            userInfo: [
                NSFontCollection.actionUserInfoKey: NSFontCollection.ActionTypeKey.shown.rawValue as NSString,
                NSFontCollection.visibilityUserInfoKey: NSNumber(value: NSFontCollection.Visibility.process.rawValue),
            ]
        )
        let message = try #require(NSFontCollection.Backport.DidChangeMessage.makeMessage(notification))
        #expect(message.visibility == nil)
        #if canImport(AppKit, _version: 2700)
        if #available(macOS 27, *) {
            let appKitMessage = try #require(NSFontCollection.DidChangeMessage.makeMessage(notification))
            #expect(appKitMessage.visibility == nil)
        }
        #endif
    }
}

private let workspacePairs: [MessagePair] = {
    guard #available(macOS 26, *) else { return [] }
    let workspace: @MainActor @Sendable () -> Any? = { NSWorkspace.shared }
    let application: @MainActor @Sendable () -> [AnyHashable: Any] = {
        [NSWorkspace.applicationUserInfoKey: NSRunningApplication.current]
    }
    let volume: @MainActor @Sendable () -> [AnyHashable: Any] = {
        [
            NSWorkspace.localizedVolumeNameUserInfoKey: "Backup" as NSString,
            NSWorkspace.volumeURLUserInfoKey: NSURL(fileURLWithPath: "/Volumes/Backup"),
        ]
    }
    let renamedVolume: @MainActor @Sendable () -> [AnyHashable: Any] = {
        [
            NSWorkspace.localizedVolumeNameUserInfoKey: "Archive" as NSString,
            NSWorkspace.volumeURLUserInfoKey: NSURL(fileURLWithPath: "/Volumes/Archive"),
            NSWorkspace.oldLocalizedVolumeNameUserInfoKey: "Backup" as NSString,
            NSWorkspace.oldVolumeURLUserInfoKey: NSURL(fileURLWithPath: "/Volumes/Backup"),
        ]
    }
    return [
        .mainActor(NSWorkspace.WillLaunchApplicationMessage.self, NSWorkspace.Backport.WillLaunchApplicationMessage.self, object: workspace, userInfo: application),
        .mainActor(NSWorkspace.DidLaunchApplicationMessage.self, NSWorkspace.Backport.DidLaunchApplicationMessage.self, object: workspace, userInfo: application),
        .mainActor(NSWorkspace.DidTerminateApplicationMessage.self, NSWorkspace.Backport.DidTerminateApplicationMessage.self, object: workspace, userInfo: application),
        .mainActor(NSWorkspace.DidHideApplicationMessage.self, NSWorkspace.Backport.DidHideApplicationMessage.self, object: workspace, userInfo: application),
        .mainActor(NSWorkspace.DidUnhideApplicationMessage.self, NSWorkspace.Backport.DidUnhideApplicationMessage.self, object: workspace, userInfo: application),
        .mainActor(NSWorkspace.DidActivateApplicationMessage.self, NSWorkspace.Backport.DidActivateApplicationMessage.self, object: workspace, userInfo: application),
        .mainActor(NSWorkspace.DidDeactivateApplicationMessage.self, NSWorkspace.Backport.DidDeactivateApplicationMessage.self, object: workspace, userInfo: application),
        .mainActor(NSWorkspace.DidMountVolumeMessage.self, NSWorkspace.Backport.DidMountVolumeMessage.self, object: workspace, userInfo: volume),
        .mainActor(NSWorkspace.WillUnmountVolumeMessage.self, NSWorkspace.Backport.WillUnmountVolumeMessage.self, object: workspace, userInfo: volume),
        .mainActor(NSWorkspace.DidUnmountVolumeMessage.self, NSWorkspace.Backport.DidUnmountVolumeMessage.self, object: workspace, userInfo: volume),
        .mainActor(NSWorkspace.DidRenameVolumeMessage.self, NSWorkspace.Backport.DidRenameVolumeMessage.self, object: workspace, userInfo: renamedVolume),
        .mainActor(NSWorkspace.WillSleepMessage.self, NSWorkspace.Backport.WillSleepMessage.self, object: workspace),
        .mainActor(NSWorkspace.DidWakeMessage.self, NSWorkspace.Backport.DidWakeMessage.self, object: workspace),
        .asynchronous(NSWorkspace.ScreensDidSleepMessage.self, NSWorkspace.Backport.ScreensDidSleepMessage.self, object: workspace),
        .asynchronous(NSWorkspace.ScreensDidWakeMessage.self, NSWorkspace.Backport.ScreensDidWakeMessage.self, object: workspace),
        .mainActor(NSWorkspace.SessionDidBecomeActiveMessage.self, NSWorkspace.Backport.SessionDidBecomeActiveMessage.self, object: workspace),
        .mainActor(NSWorkspace.SessionDidResignActiveMessage.self, NSWorkspace.Backport.SessionDidResignActiveMessage.self, object: workspace),
        .mainActor(NSWorkspace.DidChangeFileLabelsMessage.self, NSWorkspace.Backport.DidChangeFileLabelsMessage.self, object: workspace),
        .asynchronous(NSWorkspace.ActiveSpaceDidChangeMessage.self, NSWorkspace.Backport.ActiveSpaceDidChangeMessage.self, object: workspace),
        .mainActor(NSWorkspace.AccessibilityDisplayOptionsDidChangeMessage.self, NSWorkspace.Backport.AccessibilityDisplayOptionsDidChangeMessage.self, object: workspace),
    ]
}()

#if canImport(AppKit, _version: 2700)

private let appKitPairs: [MessagePair] = {
    guard #available(macOS 27, *) else { return [] }

    func object(_ objectClass: NSObject.Type) -> @MainActor @Sendable () -> Any? {
        { IdentityOnlyObjects.make(objectClass) }
    }
    let application: @MainActor @Sendable () -> Any? = { NSApplication.shared }
    let spellChecker: @MainActor @Sendable () -> Any? = { NSSpellChecker.shared }
    let columnMove: @MainActor @Sendable () -> [AnyHashable: Any] = {
        ["NSOldColumn": NSNumber(value: 2), "NSNewColumn": NSNumber(value: 0)]
    }
    let columnResize: @MainActor @Sendable () -> [AnyHashable: Any] = {
        ["NSTableColumn": IdentityOnlyObjects.make(NSTableColumn.self), "NSOldWidth": NSNumber(value: 120.5)]
    }
    let outlineItem: @MainActor @Sendable () -> [AnyHashable: Any] = {
        ["NSObject": "Folder" as NSString]
    }
    let fieldEditor: @MainActor @Sendable () -> [AnyHashable: Any] = {
        ["NSFieldEditor": IdentityOnlyObjects.make(NSTextView.self)]
    }
    let menuItemIndex: @MainActor @Sendable () -> [AnyHashable: Any] = {
        ["NSMenuItemIndex": NSNumber(value: 3)]
    }
    let popoverCloseReason: @MainActor @Sendable () -> [AnyHashable: Any] = {
        [NSPopover.closeReasonUserInfoKey: NSPopover.CloseReason.standard.rawValue as NSString]
    }
    let splitViewResize: @MainActor @Sendable () -> [AnyHashable: Any] = {
        ["NSSplitViewDividerIndex": NSNumber(value: 1), "NSSplitViewUserResizeKey": NSNumber(value: true)]
    }

    return [
        .mainActor(NSApplication.WillFinishLaunchingMessage.self, NSApplication.Backport.WillFinishLaunchingMessage.self, object: application),
        .mainActor(NSApplication.DidBecomeActiveMessage.self, NSApplication.Backport.DidBecomeActiveMessage.self, object: application),
        .mainActor(NSApplication.WillBecomeActiveMessage.self, NSApplication.Backport.WillBecomeActiveMessage.self, object: application),
        .mainActor(NSApplication.DidResignActiveMessage.self, NSApplication.Backport.DidResignActiveMessage.self, object: application),
        .mainActor(NSApplication.WillResignActiveMessage.self, NSApplication.Backport.WillResignActiveMessage.self, object: application),
        .mainActor(NSApplication.DidHideMessage.self, NSApplication.Backport.DidHideMessage.self, object: application),
        .mainActor(NSApplication.WillHideMessage.self, NSApplication.Backport.WillHideMessage.self, object: application),
        .mainActor(NSApplication.DidUnhideMessage.self, NSApplication.Backport.DidUnhideMessage.self, object: application),
        .mainActor(NSApplication.WillUnhideMessage.self, NSApplication.Backport.WillUnhideMessage.self, object: application),
        .mainActor(NSApplication.DidUpdateWindowsMessage.self, NSApplication.Backport.DidUpdateWindowsMessage.self, object: application),
        .mainActor(NSApplication.WillUpdateWindowsMessage.self, NSApplication.Backport.WillUpdateWindowsMessage.self, object: application),
        .mainActor(NSApplication.WillTerminateMessage.self, NSApplication.Backport.WillTerminateMessage.self, object: application),
        .mainActor(NSApplication.DidChangeScreenParametersMessage.self, NSApplication.Backport.DidChangeScreenParametersMessage.self, object: application),
        .mainActor(NSApplication.DidChangeOcclusionStateMessage.self, NSApplication.Backport.DidChangeOcclusionStateMessage.self, object: application),
        .mainActor(NSApplication.DidFinishRestoringWindowsMessage.self, NSApplication.Backport.DidFinishRestoringWindowsMessage.self, object: application),
        .mainActor(NSApplication.ProtectedDataDidBecomeAvailableMessage.self, NSApplication.Backport.ProtectedDataDidBecomeAvailableMessage.self, object: application),
        .mainActor(NSApplication.ProtectedDataWillBecomeUnavailableMessage.self, NSApplication.Backport.ProtectedDataWillBecomeUnavailableMessage.self, object: application),

        .mainActor(NSSpellChecker.DidChangeAutomaticSpellingCorrectionMessage.self, NSSpellChecker.Backport.DidChangeAutomaticSpellingCorrectionMessage.self, object: spellChecker),
        .mainActor(NSSpellChecker.DidChangeAutomaticTextReplacementMessage.self, NSSpellChecker.Backport.DidChangeAutomaticTextReplacementMessage.self, object: spellChecker),
        .mainActor(NSSpellChecker.DidChangeAutomaticQuoteSubstitutionMessage.self, NSSpellChecker.Backport.DidChangeAutomaticQuoteSubstitutionMessage.self, object: spellChecker),
        .mainActor(NSSpellChecker.DidChangeAutomaticDashSubstitutionMessage.self, NSSpellChecker.Backport.DidChangeAutomaticDashSubstitutionMessage.self, object: spellChecker),
        .mainActor(NSSpellChecker.DidChangeAutomaticCapitalizationMessage.self, NSSpellChecker.Backport.DidChangeAutomaticCapitalizationMessage.self, object: spellChecker),
        .mainActor(NSSpellChecker.DidChangeAutomaticPeriodSubstitutionMessage.self, NSSpellChecker.Backport.DidChangeAutomaticPeriodSubstitutionMessage.self, object: spellChecker),
        .mainActor(NSSpellChecker.DidChangeAutomaticTextCompletionMessage.self, NSSpellChecker.Backport.DidChangeAutomaticTextCompletionMessage.self, object: spellChecker),
        .mainActor(NSSpellChecker.DidChangeAutomaticInlinePredictionMessage.self, NSSpellChecker.Backport.DidChangeAutomaticInlinePredictionMessage.self, object: spellChecker),

        .mainActor(NSFont.FontSetChangedMessage.self, NSFont.Backport.FontSetChangedMessage.self),
        .mainActor(NSColor.SystemColorsDidChangeMessage.self, NSColor.Backport.SystemColorsDidChangeMessage.self),
        .mainActor(NSScroller.PreferredScrollerStyleDidChangeMessage.self, NSScroller.Backport.PreferredScrollerStyleDidChangeMessage.self),
        .mainActor(NSTextInputContext.KeyboardSelectionDidChangeMessage.self, NSTextInputContext.Backport.KeyboardSelectionDidChangeMessage.self),
        .mainActor(NSHelpManager.ContextHelpModeDidActivateMessage.self, NSHelpManager.Backport.ContextHelpModeDidActivateMessage.self, object: { NSHelpManager.shared }),
        .mainActor(NSHelpManager.ContextHelpModeDidDeactivateMessage.self, NSHelpManager.Backport.ContextHelpModeDidDeactivateMessage.self, object: { NSHelpManager.shared }),

        .mainActor(NSWindow.DidBecomeKeyMessage.self, NSWindow.Backport.DidBecomeKeyMessage.self, object: object(NSWindow.self)),
        .mainActor(NSWindow.DidBecomeMainMessage.self, NSWindow.Backport.DidBecomeMainMessage.self, object: object(NSWindow.self)),
        .mainActor(NSWindow.DidChangeScreenMessage.self, NSWindow.Backport.DidChangeScreenMessage.self, object: object(NSWindow.self)),
        .mainActor(NSWindow.DidDeminiaturizeMessage.self, NSWindow.Backport.DidDeminiaturizeMessage.self, object: object(NSWindow.self)),
        .mainActor(NSWindow.DidMiniaturizeMessage.self, NSWindow.Backport.DidMiniaturizeMessage.self, object: object(NSWindow.self)),
        .mainActor(NSWindow.DidMoveMessage.self, NSWindow.Backport.DidMoveMessage.self, object: object(NSWindow.self)),
        .mainActor(NSWindow.DidResignKeyMessage.self, NSWindow.Backport.DidResignKeyMessage.self, object: object(NSWindow.self)),
        .mainActor(NSWindow.DidResignMainMessage.self, NSWindow.Backport.DidResignMainMessage.self, object: object(NSWindow.self)),
        .mainActor(NSWindow.DidResizeMessage.self, NSWindow.Backport.DidResizeMessage.self, object: object(NSWindow.self)),
        .mainActor(NSWindow.DidUpdateMessage.self, NSWindow.Backport.DidUpdateMessage.self, object: object(NSWindow.self)),
        .mainActor(NSWindow.WillCloseMessage.self, NSWindow.Backport.WillCloseMessage.self, object: object(NSWindow.self)),
        .mainActor(NSWindow.WillMiniaturizeMessage.self, NSWindow.Backport.WillMiniaturizeMessage.self, object: object(NSWindow.self)),
        .mainActor(NSWindow.WillMoveMessage.self, NSWindow.Backport.WillMoveMessage.self, object: object(NSWindow.self)),
        .mainActor(NSWindow.WillBeginSheetMessage.self, NSWindow.Backport.WillBeginSheetMessage.self, object: object(NSWindow.self)),
        .mainActor(NSWindow.DidEndSheetMessage.self, NSWindow.Backport.DidEndSheetMessage.self, object: object(NSWindow.self)),
        .mainActor(NSWindow.DidChangeScreenProfileMessage.self, NSWindow.Backport.DidChangeScreenProfileMessage.self, object: object(NSWindow.self)),
        .mainActor(NSWindow.WillStartLiveResizeMessage.self, NSWindow.Backport.WillStartLiveResizeMessage.self, object: object(NSWindow.self)),
        .mainActor(NSWindow.DidEndLiveResizeMessage.self, NSWindow.Backport.DidEndLiveResizeMessage.self, object: object(NSWindow.self)),
        .mainActor(NSWindow.WillEnterFullScreenMessage.self, NSWindow.Backport.WillEnterFullScreenMessage.self, object: object(NSWindow.self)),
        .mainActor(NSWindow.DidEnterFullScreenMessage.self, NSWindow.Backport.DidEnterFullScreenMessage.self, object: object(NSWindow.self)),
        .mainActor(NSWindow.WillExitFullScreenMessage.self, NSWindow.Backport.WillExitFullScreenMessage.self, object: object(NSWindow.self)),
        .mainActor(NSWindow.DidExitFullScreenMessage.self, NSWindow.Backport.DidExitFullScreenMessage.self, object: object(NSWindow.self)),
        .mainActor(NSWindow.WillEnterVersionBrowserMessage.self, NSWindow.Backport.WillEnterVersionBrowserMessage.self, object: object(NSWindow.self)),
        .mainActor(NSWindow.DidEnterVersionBrowserMessage.self, NSWindow.Backport.DidEnterVersionBrowserMessage.self, object: object(NSWindow.self)),
        .mainActor(NSWindow.WillExitVersionBrowserMessage.self, NSWindow.Backport.WillExitVersionBrowserMessage.self, object: object(NSWindow.self)),
        .mainActor(NSWindow.DidExitVersionBrowserMessage.self, NSWindow.Backport.DidExitVersionBrowserMessage.self, object: object(NSWindow.self)),
        .mainActor(NSWindow.DidChangeOcclusionStateMessage.self, NSWindow.Backport.DidChangeOcclusionStateMessage.self, object: object(NSWindow.self)),
        .mainActor(NSWindow.DidExposeMessage.self, NSWindow.Backport.DidExposeMessage.self, object: object(NSWindow.self), userInfo: {
            ["NSExposedRect": NSValue(rect: NSRect(x: 10, y: 20, width: 300, height: 200))]
        }),
        .mainActor(NSWindow.DidChangeBackingPropertiesMessage.self, NSWindow.Backport.DidChangeBackingPropertiesMessage.self, object: object(NSWindow.self), userInfo: {
            [NSWindow.oldScaleFactorUserInfoKey: NSNumber(value: 1.0), NSWindow.oldColorSpaceUserInfoKey: NSColorSpace.sRGB]
        }),

        .mainActor(NSComboBox.SelectionDidChangeMessage.self, NSComboBox.Backport.SelectionDidChangeMessage.self, object: object(NSComboBox.self)),
        .mainActor(NSComboBox.SelectionIsChangingMessage.self, NSComboBox.Backport.SelectionIsChangingMessage.self, object: object(NSComboBox.self)),
        .mainActor(NSComboBox.WillDismissMessage.self, NSComboBox.Backport.WillDismissMessage.self, object: object(NSComboBox.self)),
        .mainActor(NSComboBox.WillPopUpMessage.self, NSComboBox.Backport.WillPopUpMessage.self, object: object(NSComboBox.self)),

        .mainActor(NSMenu.WillSendActionMessage.self, NSMenu.Backport.WillSendActionMessage.self, object: object(NSMenu.self)),
        .mainActor(NSMenu.DidSendActionMessage.self, NSMenu.Backport.DidSendActionMessage.self, object: object(NSMenu.self)),
        .mainActor(NSMenu.DidAddItemMessage.self, NSMenu.Backport.DidAddItemMessage.self, object: object(NSMenu.self), userInfo: menuItemIndex),
        .mainActor(NSMenu.DidRemoveItemMessage.self, NSMenu.Backport.DidRemoveItemMessage.self, object: object(NSMenu.self), userInfo: menuItemIndex),
        .mainActor(NSMenu.DidChangeItemMessage.self, NSMenu.Backport.DidChangeItemMessage.self, object: object(NSMenu.self), userInfo: menuItemIndex),
        .mainActor(NSMenu.DidBeginTrackingMessage.self, NSMenu.Backport.DidBeginTrackingMessage.self, object: object(NSMenu.self)),
        .mainActor(NSMenu.DidEndTrackingMessage.self, NSMenu.Backport.DidEndTrackingMessage.self, object: object(NSMenu.self)),

        .mainActor(NSView.FrameDidChangeMessage.self, NSView.Backport.FrameDidChangeMessage.self, object: object(NSView.self)),
        .mainActor(NSView.BoundsDidChangeMessage.self, NSView.Backport.BoundsDidChangeMessage.self, object: object(NSView.self)),

        .mainActor(NSScrollView.WillStartLiveMagnifyMessage.self, NSScrollView.Backport.WillStartLiveMagnifyMessage.self, object: object(NSScrollView.self)),
        .mainActor(NSScrollView.DidEndLiveMagnifyMessage.self, NSScrollView.Backport.DidEndLiveMagnifyMessage.self, object: object(NSScrollView.self)),
        .mainActor(NSScrollView.WillStartLiveScrollMessage.self, NSScrollView.Backport.WillStartLiveScrollMessage.self, object: object(NSScrollView.self)),
        .mainActor(NSScrollView.DidLiveScrollMessage.self, NSScrollView.Backport.DidLiveScrollMessage.self, object: object(NSScrollView.self)),
        .mainActor(NSScrollView.DidEndLiveScrollMessage.self, NSScrollView.Backport.DidEndLiveScrollMessage.self, object: object(NSScrollView.self)),

        .mainActor(NSRuleEditor.RowsDidChangeMessage.self, NSRuleEditor.Backport.RowsDidChangeMessage.self, object: object(NSRuleEditor.self)),

        .mainActor(NSTableView.SelectionDidChangeMessage.self, NSTableView.Backport.SelectionDidChangeMessage.self, object: object(NSTableView.self)),
        .mainActor(NSTableView.SelectionIsChangingMessage.self, NSTableView.Backport.SelectionIsChangingMessage.self, object: object(NSTableView.self)),
        .mainActor(NSTableView.ColumnDidMoveMessage.self, NSTableView.Backport.ColumnDidMoveMessage.self, object: object(NSTableView.self), userInfo: columnMove),
        .mainActor(NSTableView.ColumnDidResizeMessage.self, NSTableView.Backport.ColumnDidResizeMessage.self, object: object(NSTableView.self), userInfo: columnResize),

        .mainActor(NSOutlineView.SelectionDidChangeMessage.self, NSOutlineView.Backport.SelectionDidChangeMessage.self, object: object(NSOutlineView.self)),
        .mainActor(NSOutlineView.SelectionIsChangingMessage.self, NSOutlineView.Backport.SelectionIsChangingMessage.self, object: object(NSOutlineView.self)),
        .mainActor(NSOutlineView.ColumnDidMoveMessage.self, NSOutlineView.Backport.ColumnDidMoveMessage.self, object: object(NSOutlineView.self), userInfo: columnMove),
        .mainActor(NSOutlineView.ColumnDidResizeMessage.self, NSOutlineView.Backport.ColumnDidResizeMessage.self, object: object(NSOutlineView.self), userInfo: columnResize),
        .mainActor(NSOutlineView.ItemWillExpandMessage.self, NSOutlineView.Backport.ItemWillExpandMessage.self, object: object(NSOutlineView.self), userInfo: outlineItem),
        .mainActor(NSOutlineView.ItemDidExpandMessage.self, NSOutlineView.Backport.ItemDidExpandMessage.self, object: object(NSOutlineView.self), userInfo: outlineItem),
        .mainActor(NSOutlineView.ItemWillCollapseMessage.self, NSOutlineView.Backport.ItemWillCollapseMessage.self, object: object(NSOutlineView.self), userInfo: outlineItem),
        .mainActor(NSOutlineView.ItemDidCollapseMessage.self, NSOutlineView.Backport.ItemDidCollapseMessage.self, object: object(NSOutlineView.self), userInfo: outlineItem),

        .mainActor(NSControl.TextDidBeginEditingMessage.self, NSControl.Backport.TextDidBeginEditingMessage.self, object: object(NSTextField.self), userInfo: fieldEditor),
        .mainActor(NSControl.TextDidChangeMessage.self, NSControl.Backport.TextDidChangeMessage.self, object: object(NSTextField.self), userInfo: fieldEditor),
        .mainActor(NSControl.TextDidEndEditingMessage.self, NSControl.Backport.TextDidEndEditingMessage.self, object: object(NSTextField.self), userInfo: fieldEditor),

        .mainActor(NSPopover.WillShowMessage.self, NSPopover.Backport.WillShowMessage.self, object: object(NSPopover.self)),
        .mainActor(NSPopover.DidShowMessage.self, NSPopover.Backport.DidShowMessage.self, object: object(NSPopover.self)),
        .mainActor(NSPopover.WillCloseMessage.self, NSPopover.Backport.WillCloseMessage.self, object: object(NSPopover.self), userInfo: popoverCloseReason),
        .mainActor(NSPopover.DidCloseMessage.self, NSPopover.Backport.DidCloseMessage.self, object: object(NSPopover.self), userInfo: popoverCloseReason),

        // The editing messages' subject is NSText; a text view is one, as is every field editor.
        .mainActor(NSTextView.DidBeginEditingMessage.self, NSTextView.Backport.DidBeginEditingMessage.self, object: object(NSTextView.self)),
        .mainActor(NSTextView.DidChangeMessage.self, NSTextView.Backport.DidChangeMessage.self, object: object(NSTextView.self)),
        .mainActor(NSTextView.DidEndEditingMessage.self, NSTextView.Backport.DidEndEditingMessage.self, object: object(NSTextView.self), userInfo: {
            [NSText.movementUserInfoKey: NSNumber(value: NSTextMovement.tab.rawValue)]
        }),
        .mainActor(NSTextView.WillChangeNotifyingTextViewMessage.self, NSTextView.Backport.WillChangeNotifyingTextViewMessage.self, object: object(NSTextView.self), userInfo: {
            [
                "NSOldNotifyingTextView": IdentityOnlyObjects.make(NSTextView.self),
                "NSNewNotifyingTextView": IdentityOnlyObjects.make(NSTextView.self),
            ]
        }),
        .mainActor(NSTextView.DidChangeSelectionMessage.self, NSTextView.Backport.DidChangeSelectionMessage.self, object: object(NSTextView.self), userInfo: {
            ["NSOldSelectedCharacterRange": NSValue(range: NSRange(location: 4, length: 2))]
        }),
        .mainActor(NSTextView.DidChangeTypingAttributesMessage.self, NSTextView.Backport.DidChangeTypingAttributesMessage.self, object: object(NSTextView.self)),

        .mainActor(NSBrowser.ColumnConfigurationDidChangeMessage.self, NSBrowser.Backport.ColumnConfigurationDidChangeMessage.self, object: object(NSBrowser.self)),
        .mainActor(NSColorList.DidChangeMessage.self, NSColorList.Backport.DidChangeMessage.self, object: object(NSColorList.self)),
        .mainActor(NSColorPanel.ColorDidChangeMessage.self, NSColorPanel.Backport.ColorDidChangeMessage.self, object: object(NSColorPanel.self)),
        .mainActor(NSImageRep.RegistryDidChangeMessage.self, NSImageRep.Backport.RegistryDidChangeMessage.self, object: object(NSBitmapImageRep.self)),
        .mainActor(NSPopUpButton.WillPopUpMessage.self, NSPopUpButton.Backport.WillPopUpMessage.self, object: object(NSPopUpButton.self)),
        .mainActor(NSPopUpButtonCell.WillPopUpMessage.self, NSPopUpButtonCell.Backport.WillPopUpMessage.self, object: object(NSPopUpButtonCell.self)),
        .mainActor(NSScreen.ColorSpaceDidChangeMessage.self, NSScreen.Backport.ColorSpaceDidChangeMessage.self, object: object(NSScreen.self)),
        .mainActor(NSTextAlternatives.SelectedAlternativeStringMessage.self, NSTextAlternatives.Backport.SelectedAlternativeStringMessage.self, object: object(NSTextAlternatives.self), userInfo: {
            ["NSAlternativeString": "their" as NSString]
        }),

        .mainActor(NSSplitView.WillResizeSubviewsMessage.self, NSSplitView.Backport.WillResizeSubviewsMessage.self, object: object(NSSplitView.self), userInfo: splitViewResize),
        .mainActor(NSSplitView.DidResizeSubviewsMessage.self, NSSplitView.Backport.DidResizeSubviewsMessage.self, object: object(NSSplitView.self), userInfo: splitViewResize),

        .mainActor(NSFontCollection.DidChangeMessage.self, NSFontCollection.Backport.DidChangeMessage.self, object: object(NSFontCollection.self), userInfo: {
            [
                NSFontCollection.actionUserInfoKey: NSFontCollection.ActionTypeKey.renamed.rawValue as NSString,
                NSFontCollection.nameUserInfoKey: "Headings" as NSString,
                NSFontCollection.oldNameUserInfoKey: "Titles" as NSString,
                NSFontCollection.visibilityUserInfoKey: NSNumber(value: NSFontCollection.Visibility.user.rawValue),
            ]
        }),

        .mainActor(NSToolbar.WillAddItemMessage.self, NSToolbar.Backport.WillAddItemMessage.self, object: object(NSToolbar.self), userInfo: {
            ["item": IdentityOnlyObjects.make(NSToolbarItem.self), "newIndex": NSNumber(value: 4)]
        }),
        .mainActor(NSToolbar.DidRemoveItemMessage.self, NSToolbar.Backport.DidRemoveItemMessage.self, object: object(NSToolbar.self), userInfo: {
            ["item": IdentityOnlyObjects.make(NSToolbarItem.self)]
        }),
    ]
}()

#endif

#endif
