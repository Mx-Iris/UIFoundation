#if QuickActionBar && os(macOS)

import AppKit
import Testing
@testable import UIFoundationAppKit

/// The browse buttons beside the search field, and the glass they bud out of (macOS 26 and later).
///
/// These live in the presentation suite so that they never run beside another bar: a bar closes
/// itself when it resigns key or main, and serializing keeps one bar on screen at a time.
@MainActor
extension QuickActionBarPresentationTests {
    @Test("Without browse items the platter's glass spans the whole bar")
    func platterSpansTheBarWithoutBrowseItems() throws {
        guard #available(macOS 26.0, *), NSScreen.main != nil else { return }

        let actionBar = makeBrowseButtonActionBar()
        defer { actionBar.cancel() }
        let window = try #require(actionBar.quickActionBarWindow)
        window.contentView?.layoutSubtreeIfNeeded()

        let glassPlatterView = try #require(window.primaryView?.glassPlatterView)
        #expect(glassPlatterView.platterGlass.frame.width == 640)
        #expect(glassPlatterView.platterGlass.frame.height == glassPlatterView.bounds.height)
        #expect(glassPlatterView.platterGlass.enclosingGlassEffectContainer != nil)
    }

    @Test("A click on the search field still reaches it through the glass container")
    func searchFieldReceivesClicks() throws {
        guard #available(macOS 26.0, *), NSScreen.main != nil else { return }

        let actionBar = makeBrowseButtonActionBar()
        defer { actionBar.cancel() }
        let window = try #require(actionBar.quickActionBarWindow)
        window.contentView?.layoutSubtreeIfNeeded()

        let searchField = window.editLabel
        let pointInWindow = searchField.convert(NSPoint(x: searchField.bounds.midX, y: searchField.bounds.midY), to: nil)
        let hitView = try #require(window.contentView?.superview?.hitTest(pointInWindow))

        #expect(hitView === searchField || hitView.isDescendant(of: searchField))
    }

    // MARK: - Helpers

    private func makeBrowseButtonActionBar() -> QuickActionBar {
        _ = NSApplication.shared
        let actionBar = QuickActionBar()
        actionBar.present(width: 640, height: 240)
        return actionBar
    }
}

@available(macOS 26.0, *)
private extension NSView {
    /// The nearest glass effect container above this view, the one that merges its glass.
    var enclosingGlassEffectContainer: NSGlassEffectContainerView? {
        var ancestor = superview
        while let currentAncestor = ancestor {
            if let container = currentAncestor as? NSGlassEffectContainerView {
                return container
            }
            ancestor = currentAncestor.superview
        }
        return nil
    }
}

#endif
