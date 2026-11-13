#if AppleInternal && os(macOS)

import AppKit
import Testing
import FrameworkToolbox
import UIFoundationAppleInternal

/// Covers the scroll pocket wrappers on `NSScrollView.box` and `NSView.box.titlebarBackdropGroupName`, and the AppKit
/// behaviour their documentation states: when the bottom pocket exists, what each pocket's height follows, and which
/// backdrop group the pockets under the title bar blur in. Measured on macOS 27.2.
///
/// `Fixture` is a scroll view filling a window's content view outside every display, with a flipped document much
/// taller than it, and a plain view along each edge standing in for a bar; `TitlebarFixture` is two such scroll
/// views side by side under a toolbar. Reverse-engineering notes: `Researchs/AppKit-NSScrollView-ScrollPocket-Internals.md`.
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

    // MARK: Backdrop groups under the title bar

    /// What `titlebarBackdropGroupName` exists for. A failure here means AppKit stopped sharing the group, and the
    /// guide's account of the flat title bar needs checking again.
    @available(macOS 26.0, *)
    @Test("Scroll views side by side under the title bar blur in one backdrop group by default")
    func panesShareTheTitlebarGroupByDefault() throws {
        let fixture = TitlebarFixture()
        defer { fixture.tearDown() }

        let leadingGroupName = try #require(fixture.contentBlurGroupName(of: fixture.leadingScrollView))
        let trailingGroupName = try #require(fixture.contentBlurGroupName(of: fixture.trailingScrollView))
        #expect(leadingGroupName == trailingGroupName)
    }

    @available(macOS 26.0, *)
    @Test("A group named on a view around a scroll view is the one its title bar pocket blurs in")
    func namedGroupSeparatesThePanes() {
        let fixture = TitlebarFixture(namesGroups: true)
        defer { fixture.tearDown() }

        #expect(fixture.contentBlurGroupName(of: fixture.leadingScrollView) == "LeadingPane")
        #expect(fixture.contentBlurGroupName(of: fixture.trailingScrollView) == "TrailingPane")
    }

    @available(macOS 26.0, *)
    @Test("A pocket made after the group is named, for a scroll view swapped in, takes the name")
    func pocketMadeLaterTakesTheName() {
        let fixture = TitlebarFixture(namesGroups: true)
        defer { fixture.tearDown() }

        let replacement = fixture.replaceTrailingScrollView()

        #expect(fixture.contentBlurGroupName(of: replacement) == "TrailingPane")
    }

    @available(macOS 26.0, *)
    @Test("Naming a group on a hierarchy already on screen moves the pockets inside into it")
    func namingOnScreenMovesThePockets() {
        let fixture = TitlebarFixture()
        defer { fixture.tearDown() }

        fixture.trailingPane.box.titlebarBackdropGroupName = "TrailingPane"
        fixture.layOut()

        #expect(fixture.contentBlurGroupName(of: fixture.trailingScrollView) == "TrailingPane")
        #expect(fixture.contentBlurGroupName(of: fixture.leadingScrollView) != "TrailingPane")
    }

    // MARK: Stand-alone pockets

    @available(macOS 26.0, *)
    @Test("A scroll pocket view is a hard pocket filling it, with no separator and a capture view of its own")
    func scrollPocketViewDefaults() throws {
        let fixture = TitlebarFixture(frontPocket: true)
        defer { fixture.tearDown() }
        let frontPocket = try #require(fixture.frontPocket)
        let pocket = try #require(frontPocket.subviews.first as? NSScrollPocket)

        #expect(frontPocket.style == ScrollPocketView.hardStyle)
        #expect(frontPocket.allowsSeparator == false)
        #expect(pocket.edge == NSScrollView.ScrollPocketEdge.top.rawValue)
        #expect(pocket.frame == frontPocket.bounds)
        #expect(frontPocket.captureView === pocket.captureView)
        // The hard recipe's content blur, on macOS 27.2.
        #expect(fixture.backdropLayers(of: frontPocket).contains { $0.name == "HardPocketContentBlur" && !$0.isHidden })
    }

    @available(macOS 26.0, *)
    @Test("A scroll pocket view laid over scroll views side by side blurs them in a group of its own")
    func scrollPocketViewBlursInItsOwnGroup() throws {
        let fixture = TitlebarFixture(frontPocket: true)
        defer { fixture.tearDown() }
        let frontPocket = try #require(fixture.frontPocket)

        frontPocket.backdropGroupName = "Front"
        fixture.layOut()

        #expect(frontPocket.backdropGroupName == "Front")
        let contentBlur = try #require(fixture.backdropLayers(of: frontPocket).first { $0.name?.contains("ContentBlur") == true && !$0.isHidden })
        #expect(contentBlur.groupName == "Front")
        #expect(contentBlur.groupName != fixture.contentBlurGroupName(of: fixture.leadingScrollView))
    }

    @available(macOS 26.0, *)
    @Test("A scroll pocket view takes no clicks, and refuses the styles AppKit traps on")
    func scrollPocketViewTakesNoClicksAndRefusesTrappingStyles() throws {
        let frontPocket = ScrollPocketView(edge: .top)
        frontPocket.frame = NSRect(x: 0, y: 0, width: 200, height: 50)

        #expect(frontPocket.hitTest(NSPoint(x: 100, y: 25)) == nil)

        frontPocket.style = 3
        #expect(frontPocket.style == ScrollPocketView.hardStyle)
        frontPocket.style = 0
        #expect(frontPocket.style == 0)
    }

    @available(macOS 26.0, *)
    @Test("A view names no group until one is set, and nil goes back to none")
    func titlebarBackdropGroupNameReadsBack() {
        let view = NSView()

        #expect(view.box.titlebarBackdropGroupName == nil)

        view.box.titlebarBackdropGroupName = "Pane"
        #expect(view.box.titlebarBackdropGroupName == "Pane")

        view.box.titlebarBackdropGroupName = nil
        #expect(view.box.titlebarBackdropGroupName == nil)
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

    /// Two panes side by side filling a window whose toolbar overlaps its content, each a plain view holding a
    /// scroll view that fills it — the shape of an editor split in two. Both scroll views reach the title bar,
    /// so AppKit registers the title bar with each one's top pocket. With `frontPocket`, a `ScrollPocketView` lies
    /// over both along the toolbar's strip, its capture view at the back, as Xcode lays one over its editor area.
    @MainActor
    final class TitlebarFixture {
        let window: NSWindow
        let leadingPane: NSView
        let trailingPane: NSView
        private(set) var leadingScrollView: NSScrollView
        private(set) var trailingScrollView: NSScrollView
        private(set) var frontPocket: ScrollPocketView?

        init(namesGroups: Bool = false, frontPocket hasFrontPocket: Bool = false) {
            let bounds = NSRect(x: 0, y: 0, width: 800, height: 500)
            window = NSWindow(
                contentRect: bounds.offsetBy(dx: -6000, dy: -6000),
                styleMask: [.titled, .closable, .resizable, .fullSizeContentView],
                backing: .buffered,
                defer: false
            )
            window.isReleasedWhenClosed = false
            window.toolbar = NSToolbar(identifier: "ScrollPocketTests.TitlebarFixture")
            window.toolbarStyle = .unified
            let containerView = NSView(frame: bounds)
            window.contentView = containerView

            leadingPane = NSView(frame: NSRect(x: 0, y: 0, width: bounds.width / 2, height: bounds.height))
            leadingPane.autoresizingMask = [.width, .height, .maxXMargin]
            trailingPane = NSView(frame: NSRect(x: bounds.width / 2, y: 0, width: bounds.width / 2, height: bounds.height))
            trailingPane.autoresizingMask = [.width, .height, .minXMargin]
            containerView.addSubview(leadingPane)
            containerView.addSubview(trailingPane)
            if namesGroups {
                leadingPane.box.titlebarBackdropGroupName = "LeadingPane"
                trailingPane.box.titlebarBackdropGroupName = "TrailingPane"
            }
            leadingScrollView = Self.makeScrollView(filling: leadingPane)
            trailingScrollView = Self.makeScrollView(filling: trailingPane)

            window.orderFrontRegardless()
            layOut()

            if hasFrontPocket {
                let toolbarDepth = containerView.safeAreaInsets.top
                let strip = NSRect(x: 0, y: bounds.maxY - toolbarDepth, width: bounds.width, height: toolbarDepth)
                let frontPocket = ScrollPocketView(edge: .top)
                frontPocket.frame = strip
                frontPocket.autoresizingMask = [.width, .minYMargin]
                if let captureView = frontPocket.captureView {
                    captureView.frame = strip
                    captureView.autoresizingMask = [.width, .minYMargin]
                    containerView.addSubview(captureView, positioned: .below, relativeTo: nil)
                }
                containerView.addSubview(frontPocket)
                self.frontPocket = frontPocket
                layOut()
            }
        }

        /// Puts a new scroll view in the trailing pane in place of the one there, as an editor pane swaps the
        /// content of its active tab.
        func replaceTrailingScrollView() -> NSScrollView {
            trailingScrollView.removeFromSuperview()
            trailingScrollView = Self.makeScrollView(filling: trailingPane)
            layOut()
            return trailingScrollView
        }

        /// The group the top pocket of `scrollView` blurs what scrolls under the title bar in: that of its backdrop
        /// layer blurring the content, `ThinFilmContentBlurFill` on macOS 27.2.
        func contentBlurGroupName(of scrollView: NSScrollView) -> String? {
            guard let pocketLayer = scrollView.box.scrollPocket(on: .top)?.layer else { return nil }
            return Self.backdropLayers(in: pocketLayer)
                .first { $0.name?.contains("ContentBlur") == true && !$0.isHidden }?
                .groupName
        }

        /// What the window does at the end of a run loop turn, and then the Core Animation commit in which AppKit
        /// builds the pockets' layers.
        func layOut() {
            window.contentView?.layoutSubtreeIfNeeded()
            window.displayIfNeeded()
            CATransaction.flush()
            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        }

        func tearDown() {
            window.orderOut(nil)
        }

        private static func makeScrollView(filling pane: NSView) -> NSScrollView {
            let scrollView = NSScrollView(frame: pane.bounds)
            scrollView.autoresizingMask = [.width, .height]
            scrollView.documentView = FlippedDocumentView(frame: NSRect(x: 0, y: 0, width: pane.bounds.width, height: 3000))
            scrollView.hasVerticalScroller = true
            pane.addSubview(scrollView)
            return scrollView
        }

        func backdropLayers(of view: NSView) -> [CABackdropLayer] {
            view.layer.map { Self.backdropLayers(in: $0) } ?? []
        }

        private static func backdropLayers(in layer: CALayer) -> [CABackdropLayer] {
            ((layer as? CABackdropLayer).map { [$0] } ?? []) + (layer.sublayers ?? []).flatMap { backdropLayers(in: $0) }
        }
    }
}

#endif
