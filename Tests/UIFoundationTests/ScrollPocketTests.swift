#if AppleInternal && os(macOS)

import AppKit
import Testing
import FrameworkToolbox
import UIFoundationAppleInternal

/// Covers the scroll pocket wrappers on `NSScrollView.box`, and the AppKit behaviour their documentation states:
/// when the bottom pocket exists, and what each pocket's height follows. Measured on macOS 27.2.
///
/// The fixture is a scroll view filling a window's content view outside every display, with a flipped document
/// much taller than it, and a plain view along each edge standing in for a bar. Reverse-engineering notes:
/// `Researchs/AppKit-NSScrollView-ScrollPocket-Internals.md`.
@Suite("NSScrollView scroll pockets", .serialized)
@MainActor
struct ScrollPocketTests {
    @available(macOS 26.0, *)
    @Test("There is no bottom pocket until a container is registered on the edge or the edge is always shown")
    func noBottomPocketByDefault() {
        let fixture = Fixture(scrollViewContentInsets: NSEdgeInsets(top: 0, left: 0, bottom: 44, right: 0))
        defer { fixture.tearDown() }

        #expect(fixture.scrollView.box.scrollPocket(on: .bottom) == nil)
    }

    @available(macOS 26.0, *)
    @Test("A container registered on the bottom edge makes a bottom pocket that reaches its far side")
    func registeredContainerMakesBottomPocket() {
        let fixture = Fixture(bottomBarHeight: 20)
        defer { fixture.tearDown() }

        fixture.scrollView.box.registerScrollPocketContainer(fixture.bottomBar, on: .bottom)
        fixture.layOut()

        #expect(fixture.scrollView.box.scrollPocket(on: .bottom)?.frame.height == 20)
    }

    @available(macOS 26.0, *)
    @Test("A registered container is united with the bottom content inset")
    func registeredContainerIsUnitedWithContentInset() {
        let fixture = Fixture(scrollViewContentInsets: NSEdgeInsets(top: 0, left: 0, bottom: 44, right: 0), bottomBarHeight: 20)
        defer { fixture.tearDown() }

        fixture.scrollView.box.registerScrollPocketContainer(fixture.bottomBar, on: .bottom)
        fixture.layOut()

        #expect(fixture.scrollView.box.scrollPocket(on: .bottom)?.frame.height == 44)
    }

    @available(macOS 26.0, *)
    @Test("Unregistering the container takes its height back out of the bottom pocket")
    func unregisteringContainer() {
        let fixture = Fixture(bottomBarHeight: 20)
        defer { fixture.tearDown() }

        fixture.scrollView.box.registerScrollPocketContainer(fixture.bottomBar, on: .bottom)
        fixture.layOut()
        fixture.scrollView.box.unregisterScrollPocketContainer(fixture.bottomBar, on: .bottom)
        fixture.layOut()

        #expect((fixture.scrollView.box.scrollPocket(on: .bottom)?.frame.height ?? 0) == 0)
    }

    @available(macOS 26.0, *)
    @Test("An always shown bottom edge gets a pocket as tall as the scroll view's own bottom content inset")
    func alwaysShownBottomPocketFollowsScrollViewInset() {
        let fixture = Fixture(scrollViewContentInsets: NSEdgeInsets(top: 0, left: 0, bottom: 44, right: 0))
        defer { fixture.tearDown() }

        fixture.scrollView.box.alwaysShownScrollPocketEdges = .bottom
        fixture.layOut()

        #expect(fixture.scrollView.box.alwaysShownScrollPocketEdges == .bottom)
        // One bit per edge, the top's first.
        #expect(fixture.scrollView.alwaysShownPocketEdges == 0b10)
        #expect(fixture.scrollView.box.scrollPocket(on: .bottom)?.frame.height == 44)
    }

    @available(macOS 26.0, *)
    @Test("The clip view's bottom content inset alone leaves the always shown bottom pocket no height")
    func clipViewInsetDoesNotSizeBottomPocket() {
        let fixture = Fixture(clipViewContentInsets: NSEdgeInsets(top: 0, left: 0, bottom: 44, right: 0))
        defer { fixture.tearDown() }

        fixture.scrollView.box.alwaysShownScrollPocketEdges = .bottom
        fixture.layOut()

        #expect(fixture.scrollView.box.scrollPocket(on: .bottom)?.frame.height == 0)
    }

    @available(macOS 26.0, *)
    @Test("A bar that becomes safe area gets both pockets, with the scroll view's automatic insets on")
    func safeAreaSizesBothPockets() {
        let fixture = Fixture(additionalSafeAreaInsets: NSEdgeInsets(top: 80, left: 0, bottom: 44, right: 0))
        defer { fixture.tearDown() }

        fixture.scrollView.box.alwaysShownScrollPocketEdges = [.top, .bottom]
        fixture.layOut()

        #expect(fixture.scrollView.box.scrollPocket(on: .top)?.frame.height == 80)
        #expect(fixture.scrollView.box.scrollPocket(on: .bottom)?.frame.height == 44)
    }

    @available(macOS 26.0, *)
    @Test("The top pocket follows the top safe area inset, not the top content inset")
    func topPocketFollowsSafeAreaNotContentInset() {
        let fixture = Fixture(scrollViewContentInsets: NSEdgeInsets(top: 80, left: 0, bottom: 0, right: 0))
        defer { fixture.tearDown() }

        fixture.scrollView.box.alwaysShownScrollPocketEdges = .top
        fixture.layOut()

        #expect((fixture.scrollView.box.scrollPocket(on: .top)?.frame.height ?? 0) == 0)
    }

    @available(macOS 26.0, *)
    @Test("Both pocket styles start at 0 and read back what is set")
    func pocketStyles() {
        let fixture = Fixture()
        defer { fixture.tearDown() }

        #expect(fixture.scrollView.box.scrollPocketStyle(on: .top) == 0)
        #expect(fixture.scrollView.box.scrollPocketStyle(on: .bottom) == 0)

        fixture.scrollView.box.setScrollPocketStyle(2, on: .top)

        #expect(fixture.scrollView.box.scrollPocketStyle(on: .top) == 2)
        #expect(fixture.scrollView.box.scrollPocketStyle(on: .bottom) == 0)
    }

    /// The values `_scrollPocketElementStyle`'s documentation lists. They are AppKit's private numbering, so a
    /// failure here means a new OS changed them: re-read them and update the header, not this test alone.
    @available(macOS 26.0, *)
    @Test("AppKit's own views answer the element styles the header lists")
    func elementStyles() throws {
        let accessoryWrapperClass = try #require(
            NSClassFromString("_NSSplitViewItemAccessoryViewWrapper") as? NSView.Type,
            "AppKit renamed the split view item accessory wrapper"
        )

        #expect(NSView()._scrollPocketElementStyle == -1)
        #expect(NSStackView()._scrollPocketElementStyle == -1)
        #expect(NSControl()._scrollPocketElementStyle == 0)
        #expect(NSGlassEffectView()._scrollPocketElementStyle == 1)
        #expect(accessoryWrapperClass.init(frame: .zero)._scrollPocketElementStyle == NSView.barScrollPocketElementStyle)
        #expect(NSButton()._scrollPocketElementStyle == 3)
        #expect(NSTextField()._scrollPocketElementStyle == 3)
        #expect(NSSegmentedControl()._scrollPocketElementStyle == 3)
    }
}

// MARK: - Fixture

extension ScrollPocketTests {
    @MainActor
    final class Fixture {
        let window: NSWindow
        let scrollView: NSScrollView
        let topBar: NSView
        let bottomBar: NSView

        init(
            scrollViewContentInsets: NSEdgeInsets? = nil,
            clipViewContentInsets: NSEdgeInsets? = nil,
            additionalSafeAreaInsets: NSEdgeInsets? = nil,
            topBarHeight: CGFloat = 30,
            bottomBarHeight: CGFloat = 20
        ) {
            let bounds = NSRect(x: 0, y: 0, width: 300, height: 600)
            window = NSWindow(
                contentRect: bounds.offsetBy(dx: -6000, dy: -6000),
                styleMask: [.titled],
                backing: .buffered,
                defer: false
            )
            window.isReleasedWhenClosed = false
            let containerView = NSView(frame: bounds)
            window.contentView = containerView

            scrollView = NSScrollView(frame: bounds)
            scrollView.autoresizingMask = [.width, .height]
            scrollView.documentView = FlippedDocumentView(frame: NSRect(x: 0, y: 0, width: 300, height: 3000))
            scrollView.hasVerticalScroller = true
            // The window's content view is not flipped: its top edge is its maximum Y.
            topBar = NSView(frame: NSRect(x: 0, y: bounds.maxY - topBarHeight, width: bounds.width, height: topBarHeight))
            bottomBar = NSView(frame: NSRect(x: 0, y: 0, width: bounds.width, height: bottomBarHeight))
            containerView.addSubview(scrollView)
            containerView.addSubview(topBar)
            containerView.addSubview(bottomBar)

            if let scrollViewContentInsets {
                scrollView.automaticallyAdjustsContentInsets = false
                scrollView.contentInsets = scrollViewContentInsets
            }
            if let clipViewContentInsets {
                scrollView.contentView.automaticallyAdjustsContentInsets = false
                scrollView.contentView.contentInsets = clipViewContentInsets
            }
            if let additionalSafeAreaInsets {
                scrollView.additionalSafeAreaInsets = additionalSafeAreaInsets
            }

            window.orderFrontRegardless()
            layOut()
        }

        /// What the window does at the end of a run loop turn.
        func layOut() {
            window.contentView?.layoutSubtreeIfNeeded()
            window.displayIfNeeded()
        }

        func tearDown() {
            window.orderOut(nil)
        }
    }

    private final class FlippedDocumentView: NSView {
        override var isFlipped: Bool { true }
    }
}

#endif
