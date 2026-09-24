#if TabBar && os(macOS)

import AppKit
import Testing
@testable import UIFoundationAppKit

/// Closable tabs titled by position, the shape the example app's demo builds.
private final class ClosableTabsHost: NSObject, TabBar.DataSource, TabBar.Delegate {
    let titles: [String]

    init(tabCount: Int) {
        titles = (0 ..< tabCount).map { "Tab \($0)" }
    }

    func tabBarNumberOfTabs(_ tabBar: TabBar) -> Int { titles.count }
    func tabBar(_ tabBar: TabBar, itemAtIndex index: Int) -> Any { titles[index] }
    func tabBar(_ tabBar: TabBar, titleForItem item: Any) -> String { item as? String ?? "" }

    func tabBar(_ tabBar: TabBar, closeIconForItem item: Any) -> NSImage? {
        NSImage(systemSymbolName: "xmark.circle.fill", accessibilityDescription: nil)
    }

    func tabBar(_ tabBar: TabBar, closePositionForItem item: Any) -> TabBar.ClosePosition { .left }
    func tabBar(_ tabBar: TabBar, canCloseItem item: Any) -> Bool { true }
}

/// A tab bar laid out and drawn in a window that is never shown, asked where a click would go.
@MainActor
private struct TabBarInWindow {
    let window: NSWindow
    let tabBar: TabBar
    /// Held here because the bar holds its data source and delegate weakly.
    let host: ClosableTabsHost

    init(tabCount: Int, width: CGFloat = 720) {
        host = ClosableTabsHost(tabCount: tabCount)
        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: width, height: 100),
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )
        let contentView = NSView()
        window.contentView = contentView

        tabBar = TabBar()
        contentView.addSubview(tabBar)
        NSLayoutConstraint.activate([
            tabBar.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20),
            tabBar.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            tabBar.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            tabBar.heightAnchor.constraint(equalToConstant: TabBar.SystemStyle().tabBarRecommendedHeight),
        ])
        contentView.layoutSubtreeIfNeeded()

        tabBar.dataSource = host
        tabBar.delegate = host
        tabBar.reloadTabs()
        tabBar.selectItemAtIndex(0)

        // A tab places its close button while it draws, and a window that is never shown never
        // draws: `display()` does not reach the tabs. Render the bar once, the way the screen would
        // have before anyone could click it.
        if let bitmap = tabBar.bitmapImageRepForCachingDisplay(in: tabBar.bounds) {
            tabBar.cacheDisplay(in: tabBar.bounds, to: bitmap)
        }
    }

    var tabButtons: [TabButton] {
        func descendants(of view: NSView) -> [NSView] {
            view.subviews.flatMap { [$0] + descendants(of: $0) }
        }
        return descendants(of: tabBar).compactMap { $0 as? TabButton }.sorted { $0.index < $1.index }
    }

    /// The view AppKit hands a click at `point` to: the window's own hit-test.
    func viewReceivingClick(at point: NSPoint) -> NSView? {
        window.contentView?.superview?.hitTest(point)
    }

    /// The class of whatever a click at `point` lands on, for failure messages — printing the view
    /// itself dumps its whole reflection.
    func nameOfViewReceivingClick(at point: NSPoint) -> String {
        viewReceivingClick(at: point).map { String(describing: type(of: $0)) } ?? "nothing"
    }

    /// Where a click on the close button of `tabButton` lands, in window coordinates.
    func closeButtonCenter(of tabButton: TabButton) throws -> (closeButton: NSView, center: NSPoint) {
        let closeButton = try #require(tabButton.subviews.first { $0 is NSButton })
        try #require(!closeButton.frame.isEmpty, "the tab never drew, so its close button was never placed")
        let center = closeButton.convert(NSPoint(x: closeButton.bounds.midX, y: closeButton.bounds.midY), to: nil)
        return (closeButton, center)
    }
}

/// Clicks have to hit-test to the control meant to handle them.
///
/// That is a hard requirement from the macOS 27 SDK on: a stock `NSControl` built against it tracks
/// through a gesture recognizer, and AppKit gathers recognizers only along the superview chain of the
/// hit-tested view (TN3212). The glass behind each tab used to sit in front of the tab in subview
/// order, so it took the hit-test and the close button — a plain `NSButton` — never saw a click. The
/// tab itself kept working only because overriding `mouseDown(with:)` keeps it on the tracking-loop
/// fallback, which is why the break read as "the close button does nothing".
@MainActor
@Suite("TabBar hit-testing")
struct TabBarHitTestingTests {
    @Test("A click on a close button reaches the close button", arguments: [0, 1, 2])
    func closeButtonReceivesItsClick(tabIndex: Int) throws {
        let fixture = TabBarInWindow(tabCount: 3)
        #expect(!fixture.tabBar.isStacking)
        let tabButtons = fixture.tabButtons
        try #require(tabButtons.count == 3)

        let (closeButton, center) = try fixture.closeButtonCenter(of: tabButtons[tabIndex])
        let reachesCloseButton = fixture.viewReceivingClick(at: center) === closeButton
        #expect(reachesCloseButton, "landed on \(fixture.nameOfViewReceivingClick(at: center))")
    }

    @Test("A click anywhere on a tab reaches that tab")
    func everyPointOfATabReachesIt() throws {
        let fixture = TabBarInWindow(tabCount: 3)
        let tabButtons = fixture.tabButtons
        try #require(tabButtons.count == 3)

        var misroutedClicks: [(x: CGFloat, receiver: String)] = []
        for tabButton in tabButtons {
            let frame = tabButton.convert(tabButton.bounds, to: nil)
            for x in stride(from: frame.minX + 0.5, to: frame.maxX, by: 1) {
                let point = NSPoint(x: x, y: frame.midY)
                if fixture.viewReceivingClick(at: point)?.isDescendant(of: tabButton) != true {
                    misroutedClicks.append((x, fixture.nameOfViewReceivingClick(at: point)))
                }
            }
        }
        let misroutedClickCount = misroutedClicks.count
        #expect(misroutedClickCount == 0, "first missed point: \(String(describing: misroutedClicks.first))")
    }

    /// A stacked bar resolves overlapping tabs in `TabBar.hitTest(_:)` itself, so it never had the
    /// problem; this keeps it that way.
    @Test("A stacked bar keeps the frontmost tab's close button reachable")
    func stackedCloseButtonReceivesItsClick() throws {
        let fixture = TabBarInWindow(tabCount: 12)
        try #require(fixture.tabBar.isStacking)
        let frontmostTab = try #require(fixture.tabButtons.first)

        let (closeButton, center) = try fixture.closeButtonCenter(of: frontmostTab)
        let reachesCloseButton = fixture.viewReceivingClick(at: center) === closeButton
        #expect(reachesCloseButton, "landed on \(fixture.nameOfViewReceivingClick(at: center))")
    }
}

#endif
