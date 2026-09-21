#if canImport(AppKit) && !targetEnvironment(macCatalyst)

import Testing
import AppKit
import UIFoundationComponent

/// Coordinate-system coverage for the ported component layout system on AppKit.
///
/// The layout system computes frames with the origin at the top-left, growing
/// downwards -- UIKit's convention. `NSView` draws from the bottom-left unless
/// it is flipped, so without a flipped container every layout would render
/// upside down: the first child of a `VStack` would sit at the bottom of the
/// host and the last one at the top.
///
/// Nothing about that failure mode is a crash or a compile error, and a stack
/// whose children happen to fill the host exactly looks correct either way.
/// These assertions are what distinguish the two.
@Suite("Component layout coordinates on AppKit")
struct ComponentLayoutCoordinateTests {

    private static let hostSize = CGSize(width: 100, height: 300)
    private static let childHeight: CGFloat = 50

    /// Builds a two-child vertical stack of fixed-height views.
    private func makeStackedChildren() -> (first: NSView, second: NSView, component: any Component) {
        let first = NSView()
        let second = NSView()
        let component = VStack {
            first.size(width: Self.hostSize.width, height: Self.childHeight)
            second.size(width: Self.hostSize.width, height: Self.childHeight)
        }
        return (first, second, component)
    }

    // MARK: A flipped host renders directly

    @Test("ComponentView is flipped, so the first child lands at the top")
    func flippedHostPlacesFirstChildAtTop() {
        let host = ComponentView(frame: CGRect(origin: .zero, size: Self.hostSize))
        let (first, second, component) = makeStackedChildren()

        host.component = component
        host.reloadData()

        #expect(host.isFlipped)
        // Rendered straight into the host -- no extra container is needed.
        #expect(host.renderingEngine.contentView == nil)
        #expect(first.superview === host)

        #expect(first.frame.origin.y == CGFloat(0))
        #expect(second.frame.origin.y == Self.childHeight)
    }

    // MARK: An unflipped host gets a flipped container

    @Test("An unflipped host renders into a flipped container instead of upside down")
    func unflippedHostGetsFlippedContainer() {
        let host = NSView(frame: CGRect(origin: .zero, size: Self.hostSize))
        let (first, second, component) = makeStackedChildren()

        host.componentEngine.component = component
        host.componentEngine.reloadData()

        #expect(!host.isFlipped)

        let container = host.componentEngine.contentView
        #expect(container != nil)
        #expect(container?.isFlipped == true)
        // Children go into the container, not straight onto the host.
        #expect(first.superview === container)

        // Inside the flipped container the ordering is top-down again.
        #expect(first.frame.origin.y == CGFloat(0))
        #expect(second.frame.origin.y == Self.childHeight)
    }

    /// The container is only as tall as its content, and an unflipped host puts
    /// the origin at the *bottom* -- so a container placed at `.zero` would sit
    /// against the bottom edge with the content floating below where the layout
    /// system thinks it is. It has to be pinned to the top instead.
    @Test("The flipped container is pinned to the top of an unflipped host")
    func flippedContainerIsPinnedToTop() throws {
        let host = NSView(frame: CGRect(origin: .zero, size: Self.hostSize))
        let (_, _, component) = makeStackedChildren()

        host.componentEngine.component = component
        host.componentEngine.reloadData()
        host.layout()

        let container = try #require(host.componentEngine.contentView)
        let contentHeight = Self.childHeight * 2
        #expect(container.frame.height == contentHeight)
        // Top edge of the host, expressed in the host's bottom-left space.
        #expect(container.frame.origin.y == Self.hostSize.height - contentHeight)
        #expect(container.frame.maxY == Self.hostSize.height)
    }

    // MARK: A flipped host is left alone

    @Test("A host that is already flipped gets no container of its own")
    func alreadyFlippedHostIsNotWrapped() {
        let host = FlippedTestView(frame: CGRect(origin: .zero, size: Self.hostSize))
        let (first, _, component) = makeStackedChildren()

        host.componentEngine.component = component
        host.componentEngine.reloadData()

        #expect(host.componentEngine.contentView == nil)
        #expect(first.superview === host)
        #expect(first.frame.origin.y == CGFloat(0))
    }
}

/// A caller-provided flipped view, standing in for a host that already draws
/// top-down without using `ComponentView`.
private final class FlippedTestView: NSView {
    override var isFlipped: Bool { true }
}

#endif
