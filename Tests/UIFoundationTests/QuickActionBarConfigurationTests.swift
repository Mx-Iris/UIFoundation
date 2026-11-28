#if QuickActionBar && os(macOS)

import AppKit
import Testing
@testable import UIFoundationAppKit

/// `QuickActionBar.Configuration` on its own, without presenting a bar.
@Suite("QuickActionBar Configuration")
@MainActor
struct QuickActionBarConfigurationTests {
    @Test("The default configuration keeps what present(…) used to default to")
    func defaultConfigurationKeepsPresentDefaults() {
        let configuration = QuickActionBar.Configuration()

        #expect(configuration.placeholderText == "Quick Actions")
        #expect(configuration.searchImage === QuickActionBar.DefaultImage)
        #expect(configuration.width == nil)
        #expect(configuration.resultsHeight == nil)
        #expect(configuration.showsKeyboardShortcuts == false)
        #expect(configuration.canBecomeMainWindow == true)
        #expect(configuration.requiredClickCount == .double)
    }

    @Test("The default corner radius is half of the 56-point collapsed bar on macOS 26 and later")
    func defaultCornerRadiusIs28PointsOnMacOS26() {
        guard #available(macOS 26.0, *) else { return }

        #expect(QuickActionBar.Configuration.defaultCornerRadius == 28)
        #expect(QuickActionBar.Configuration().cornerRadius == 28)
    }

    @Test("A bar keeps the configuration it was created with")
    func initializerStoresTheGivenConfiguration() {
        let actionBar = QuickActionBar(configuration: QuickActionBar.Configuration(
            placeholderText: "Open Quickly",
            width: 512,
            resultsHeight: 200,
            cornerRadius: 12,
            showsKeyboardShortcuts: true,
            canBecomeMainWindow: false,
            requiredClickCount: .single
        ))

        #expect(actionBar.configuration.placeholderText == "Open Quickly")
        #expect(actionBar.configuration.width == 512)
        #expect(actionBar.configuration.resultsHeight == 200)
        #expect(actionBar.configuration.cornerRadius == 12)
        #expect(actionBar.configuration.showsKeyboardShortcuts == true)
        #expect(actionBar.configuration.canBecomeMainWindow == false)
        #expect(actionBar.configuration.requiredClickCount == .single)
    }

    @Test("The deprecated requiredClickCount reads and writes the configuration")
    @available(*, deprecated, message: "Exercises the deprecated requiredClickCount.")
    func deprecatedRequiredClickCountForwardsToConfiguration() {
        let actionBar = QuickActionBar()

        actionBar.requiredClickCount = .single
        #expect(actionBar.configuration.requiredClickCount == .single)

        actionBar.configuration.requiredClickCount = .double
        #expect(actionBar.requiredClickCount == .double)
    }
}

/// Presenting with a configuration. These live in the presentation suite so that they never run
/// beside another bar: a bar closes itself when it resigns key or main, and serializing keeps one
/// bar on screen at a time.
@MainActor
extension QuickActionBarPresentationTests {
    @Test("present() with no arguments takes the configuration, not the deprecated overload's defaults")
    func presentWithoutArgumentsUsesTheConfiguredPlaceholder() throws {
        guard NSScreen.main != nil else { return }

        _ = NSApplication.shared
        let actionBar = QuickActionBar()
        actionBar.configuration.placeholderText = "Open Quickly"
        actionBar.present()
        defer { actionBar.cancel() }

        let window = try #require(actionBar.quickActionBarWindow)
        #expect(window.placeholderText == "Open Quickly")
    }

    @Test("The configured width sizes the bar")
    func configuredWidthSizesTheBar() throws {
        guard NSScreen.main != nil else { return }

        _ = NSApplication.shared
        let actionBar = QuickActionBar(configuration: .init(width: 512, resultsHeight: 240))
        actionBar.present()
        defer { actionBar.cancel() }

        let window = try #require(actionBar.quickActionBarWindow)
        // The window carries 40 points of room on each side for the scale animation.
        #expect(window.frame.width == 592)
    }

    @Test("A configuration changed while the bar is open applies to the next presentation")
    func configurationChangedWhilePresentedAppliesToTheNextPresentation() throws {
        guard NSScreen.main != nil else { return }

        _ = NSApplication.shared
        let actionBar = QuickActionBar(configuration: .init(placeholderText: "First", width: 480, resultsHeight: 240))
        actionBar.present()
        let firstWindow = try #require(actionBar.quickActionBarWindow)

        actionBar.configuration.placeholderText = "Second"
        #expect(firstWindow.placeholderText == "First")

        actionBar.cancel()
        actionBar.present()
        defer { actionBar.cancel() }
        let secondWindow = try #require(actionBar.quickActionBarWindow)
        #expect(secondWindow !== firstWindow)
        #expect(secondWindow.placeholderText == "Second")
    }

    /// Presented for single clicks and switched to double afterwards, a single click still
    /// activates; presented for double clicks and switched to single, it does not.
    @Test(
        "A row click activates by the click count the bar was presented with",
        arguments: [true, false]
    )
    func rowClickUsesThePresentedClickCount(presentedForSingleClick: Bool) throws {
        guard NSScreen.main != nil else { return }

        _ = NSApplication.shared
        let contentSource = ActivationRecordingContentSource.make()
        let presentedClickCount: QuickActionBar.RequiredClickCount = presentedForSingleClick ? .single : .double
        let actionBar = QuickActionBar(configuration: .init(width: 480, resultsHeight: 240, requiredClickCount: presentedClickCount))
        actionBar.contentSource = contentSource
        actionBar.present()
        defer { actionBar.cancel() }
        actionBar.configuration.requiredClickCount = presentedForSingleClick ? .double : .single

        // Pushing results selects the first row, as the bar does for a search.
        actionBar.provideResultIdentifiers(["alpha", "beta"])
        let window = try #require(actionBar.quickActionBarWindow)
        let resultsTable = try #require(Self.firstDescendant(ofType: NSTableView.self, in: window.results))

        // Send the table's single-click action rather than clicking: a posted click ends the
        // test runner on macOS 27.2. The table has no target, so a click's action travels the
        // responder chain to the results view; this window is never key in a test process, so the
        // action goes to the results view directly.
        #expect(resultsTable.target == nil)
        resultsTable.sendAction(resultsTable.action, to: window.results)

        #expect(contentSource.activatedItems == (presentedForSingleClick ? ["alpha"] : []))
    }

    @Test("The deprecated present writes its arguments into the configuration")
    @available(*, deprecated, message: "Exercises the deprecated present(…).")
    func deprecatedPresentWritesItsArgumentsIntoTheConfiguration() throws {
        guard NSScreen.main != nil else { return }

        _ = NSApplication.shared
        let actionBar = QuickActionBar()
        actionBar.present(
            placeholderText: "Legacy",
            width: 480,
            height: 200,
            showKeyboardShortcuts: true,
            canBecomeMainWindow: false
        )
        defer { actionBar.cancel() }

        #expect(actionBar.configuration.placeholderText == "Legacy")
        #expect(actionBar.configuration.searchImage === QuickActionBar.DefaultImage)
        #expect(actionBar.configuration.width == 480)
        #expect(actionBar.configuration.resultsHeight == 200)
        #expect(actionBar.configuration.showsKeyboardShortcuts == true)
        #expect(actionBar.configuration.canBecomeMainWindow == false)
        let window = try #require(actionBar.quickActionBarWindow)
        #expect(window.placeholderText == "Legacy")
        #expect(window.canBecomeMain == false)
    }

    @Test("The deprecated present leaves the corner radius and click count as configured")
    @available(*, deprecated, message: "Exercises the deprecated present(…).")
    func deprecatedPresentLeavesCornerRadiusAlone() {
        guard NSScreen.main != nil else { return }

        _ = NSApplication.shared
        let actionBar = QuickActionBar(configuration: .init(cornerRadius: 12, requiredClickCount: .single))
        actionBar.present(placeholderText: "Legacy", width: 480, height: 200)
        defer { actionBar.cancel() }

        #expect(actionBar.configuration.cornerRadius == 12)
        #expect(actionBar.configuration.requiredClickCount == .single)
    }

    // MARK: - Helpers

    private static func firstDescendant<View: NSView>(ofType viewType: View.Type, in rootView: NSView) -> View? {
        for subview in rootView.subviews {
            if let matchingView = subview as? View {
                return matchingView
            }
            if let matchingView = firstDescendant(ofType: viewType, in: subview) {
                return matchingView
            }
        }
        return nil
    }
}

/// Supplies a plain row for every item and records the items the bar activates.
///
/// Every instance is kept alive for the rest of the run. The bar holds its content source weakly
/// and its results view traps if the content source is gone when results arrive.
private final class ActivationRecordingContentSource: NSObject, QuickActionBarContentSource {
    @MainActor private static var everyInstance: [ActivationRecordingContentSource] = []

    @MainActor static func make() -> ActivationRecordingContentSource {
        let contentSource = ActivationRecordingContentSource()
        everyInstance.append(contentSource)
        return contentSource
    }

    private(set) var activatedItems: [AnyHashable] = []

    func quickActionBar(_ quickActionBar: QuickActionBar, itemsForSearchTermTask task: QuickActionBar.SearchTask) {
        task.complete(with: [])
    }

    func quickActionBar(_ quickActionBar: QuickActionBar, viewForItem item: AnyHashable, searchTerm: String) -> NSView? {
        NSTextField(labelWithString: "\(item)")
    }

    func quickActionBar(_ quickActionBar: QuickActionBar, didActivateItem item: AnyHashable) {
        activatedItems.append(item)
    }
}

#endif
