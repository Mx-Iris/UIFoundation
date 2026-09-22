#if canImport(AppKit) && !targetEnvironment(macCatalyst)

import Testing
import AppKit
import UIFoundationComponent
import UIFoundationToolbox

/// Scrolling behaviour of `ComponentScrollView` on AppKit.
///
/// The engine renders only what intersects the visible frame, and on AppKit
/// that frame is the *clip view's* bounds -- which moves as the user scrolls.
/// So every scroll has to produce a fresh render, or the rows that come into
/// view arrive empty. Nothing about that failure is loud: the scroll itself
/// works, the scroller thumb moves, and the area simply stays blank.
@Suite("ComponentScrollView rendering on AppKit")
@MainActor
struct ComponentScrollViewRenderingTests {

    private static let rowHeight: CGFloat = 30
    private static let rowCount = 20
    private static let viewportHeight: CGFloat = 100

    private func makeScrollView() -> ComponentScrollView {
        let scrollView = ComponentScrollView(
            frame: CGRect(x: 0, y: 0, width: 200, height: Self.viewportHeight)
        )
        scrollView.component = VStack {
            for index in 0..<Self.rowCount {
                NSView()
                    .size(width: 200, height: Self.rowHeight)
                    .id("row-\(index)")
            }
        }
        scrollView.reloadData()
        scrollView.layoutSubtreeIfNeeded()
        return scrollView
    }

    private func visibleRowIndices(_ scrollView: ComponentScrollView) -> [Int] {
        scrollView.renderingEngine.visibleRenderables
            .compactMap { Int($0.id.replacingOccurrences(of: "row-", with: "")) }
            .sorted()
    }

    /// The content is six times the viewport, so the engine must be culling.
    /// Without this the scroll test below would pass for the wrong reason.
    @Test("Only the rows within the viewport are rendered")
    func cullsToTheViewport() {
        let scrollView = makeScrollView()
        let visible = visibleRowIndices(scrollView)

        #expect(!visible.isEmpty)
        #expect(visible.count < Self.rowCount)
        #expect(visible.first == 0)
    }

    /// The document view has to be as tall as the content, or there is nothing
    /// to scroll to in the first place.
    @Test("The document view grows to the content height")
    func documentViewMatchesContentHeight() {
        let scrollView = makeScrollView()
        let expected = Self.rowHeight * CGFloat(Self.rowCount)
        #expect(scrollView.componentDocumentView.frame.height == expected)
    }

    /// The regression this suite exists for: scroll, and the rows that come
    /// into view have to actually be there.
    @Test("Scrolling renders the rows that come into view")
    func scrollingRendersNewlyVisibleRows() {
        let scrollView = makeScrollView()
        let before = visibleRowIndices(scrollView)

        // Halfway down: rows 10 and onwards should be on screen.
        let offset = Self.rowHeight * 10
        scrollView.contentView.setBoundsOrigin(CGPoint(x: 0, y: offset))
        scrollView.reflectScrolledClipView(scrollView.contentView)
        // The clip view posts its bounds change on the main queue, so give the
        // engine the layout pass it asked for.
        RunLoop.main.run(until: Date().addingTimeInterval(0.05))
        scrollView.componentDocumentView.layoutSubtreeIfNeeded()

        let after = visibleRowIndices(scrollView)

        #expect(!after.isEmpty)
        #expect(after != before)
        #expect(after.contains(10))
        // And the rows that scrolled away are gone.
        #expect(!after.contains(0))
    }

    // MARK: - Nested hosts

    /// A `.view()`-wrapped subtree renders a *second* engine, on a view that is
    /// merely somewhere inside the scroll view rather than being its document
    /// view. That engine asks its host what its viewport is, and the answer has
    /// to come back in the host's own coordinate space.
    ///
    /// It did not: `viewportBounds` handed back the clip view's bounds for
    /// anything with an `enclosingScrollView`, so a nested host was told its
    /// viewport began at the scrolled position of a space it does not live in.
    /// Scroll past that host's own height and the rectangle stopped
    /// intersecting its content, which the engine read as "nothing is visible"
    /// -- every nested wrapper that came into view arrived empty. At the top of
    /// the document the two spaces happen to coincide, so the bug was invisible
    /// until the first scroll.
    @Test("A nested .view() wrapper still renders its content after scrolling")
    func nestedWrappersSurviveScrolling() {
        let window = NSWindow(
            contentRect: CGRect(x: 0, y: 0, width: 200, height: Self.viewportHeight),
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )
        let scrollView = ComponentScrollView(
            frame: CGRect(x: 0, y: 0, width: 200, height: Self.viewportHeight)
        )
        window.contentView = scrollView
        // The nested content has to be a *culling* container. `Insets` and the
        // other pass-through nodes hand back every child whatever rectangle
        // they are asked about, so a wrapper holding only those would render
        // correctly even with a nonsensical visible frame -- and the test would
        // pass against the bug.
        scrollView.component = VStack {
            for index in 0 ..< Self.rowCount {
                VStack(spacing: 0) {
                    NSView().size(width: 200, height: (Self.rowHeight - 10) / 2)
                    NSView().size(width: 200, height: (Self.rowHeight - 10) / 2)
                }
                .inset(5)
                .view()
                .id("row-\(index)")
            }
        }
        scrollView.layoutSubtreeIfNeeded()

        func wrappedSubviewCounts() -> [Int] {
            scrollView.renderingEngine.visibleViews.map(\.subviews.count)
        }

        let before = wrappedSubviewCounts()
        #expect(!before.isEmpty)
        #expect(before.allSatisfy { $0 == 2 })

        scrollView.contentView.setBoundsOrigin(CGPoint(x: 0, y: Self.rowHeight * 10))
        scrollView.reflectScrolledClipView(scrollView.contentView)
        RunLoop.main.run(until: Date().addingTimeInterval(0.05))
        scrollView.componentDocumentView.layoutSubtreeIfNeeded()

        let after = wrappedSubviewCounts()
        #expect(!after.isEmpty)
        #expect(after.allSatisfy { $0 == 2 })
    }

    /// The document view is the one host whose viewport *is* the clip view's
    /// bounds -- that is the whole reason the special case exists. Without this
    /// the fix above could be "correct" by disabling culling everywhere.
    @Test("The document view still reports the clip view as its viewport")
    func documentViewReportsTheClipViewport() {
        let scrollView = makeScrollView()
        scrollView.contentView.setBoundsOrigin(CGPoint(x: 0, y: 120))
        scrollView.reflectScrolledClipView(scrollView.contentView)

        let documentView = scrollView.componentDocumentView
        #expect(documentView.box.viewportBounds == scrollView.contentView.bounds)
        #expect(documentView.box.viewportBounds.origin.y == 120)

        // Anything deeper answers for itself.
        let nested = NSView(frame: CGRect(x: 0, y: 400, width: 50, height: 50))
        documentView.addSubview(nested)
        #expect(nested.box.viewportBounds == nested.bounds)
    }
}

#endif
