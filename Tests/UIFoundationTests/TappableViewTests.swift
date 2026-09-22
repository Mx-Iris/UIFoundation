#if canImport(AppKit) && !targetEnvironment(macCatalyst)

import Testing
import AppKit
import UIFoundationComponent

/// Coverage for `TappableView` on AppKit.
///
/// Every assertion here guards something that fails *silently*. A real click
/// cannot be driven headlessly -- `NSClickGestureRecognizer` needs a window and
/// a live event stream -- so what is asserted is the wiring a click depends on,
/// plus the two contracts whose breakage produces no error at all: the flipped
/// coordinate space, and context-value transparency.
@Suite("TappableView on AppKit")
@MainActor
struct TappableViewTests {

    // MARK: The coordinate space

    /// A tappable view hosts a component subtree of its own, so it has to draw
    /// top-down like `ComponentView`. Unflipped, the engine would notice and
    /// wrap the content in a flipped container -- one extra view per tappable
    /// area, and nothing would look wrong while it happened.
    @Test("TappableView is flipped, so the engine renders into it directly")
    func tappableViewIsFlipped() {
        let view = TappableView(frame: CGRect(x: 0, y: 0, width: 100, height: 40))
        #expect(view.isFlipped)

        let child = NSView()
        view.componentEngine.component = VStack {
            child.size(width: 100, height: 20)
        }
        view.componentEngine.reloadData()

        // Rendered straight into the view; no interposed container.
        #expect(view.componentEngine.contentView == nil)
        #expect(child.superview === view)
    }

    // MARK: Gesture recognizers are attached on demand

    /// The highlight recognizer is the only one attached unconditionally -- it
    /// drives `isHighlighted`, which a config may act on even with no handlers.
    @Test("Only the highlight recognizer is attached before any handler is set")
    func highlightRecognizerIsAlwaysAttached() {
        let view = TappableView(frame: .zero)
        let recognizers = view.gestureRecognizers

        #expect(recognizers.contains { $0 === view.highlightGestureRecognizer })
        #expect(!recognizers.contains { $0 === view.clickGestureRecognizer })
        #expect(!recognizers.contains { $0 === view.doubleClickGestureRecognizer })
        #expect(!recognizers.contains { $0 === view.longPressGestureRecognizer })
    }

    @Test("Assigning and clearing a handler attaches and detaches its recognizer")
    func handlersAttachAndDetachTheirRecognizers() {
        let view = TappableView(frame: .zero)

        view.onTap = { _ in }
        view.onDoubleTap = { _ in }
        view.onLongPress = { _, _ in }

        #expect(view.gestureRecognizers.contains { $0 === view.clickGestureRecognizer })
        #expect(view.gestureRecognizers.contains { $0 === view.doubleClickGestureRecognizer })
        #expect(view.gestureRecognizers.contains { $0 === view.longPressGestureRecognizer })

        view.onTap = nil
        view.onDoubleTap = nil
        view.onLongPress = nil

        #expect(!view.gestureRecognizers.contains { $0 === view.clickGestureRecognizer })
        #expect(!view.gestureRecognizers.contains { $0 === view.doubleClickGestureRecognizer })
        #expect(!view.gestureRecognizers.contains { $0 === view.longPressGestureRecognizer })
    }

    /// A zero press duration is what makes the highlight land on mouse-down
    /// rather than after AppKit's default half-second. Restore the default and
    /// the highlight simply arrives late, which reads as an unresponsive view.
    @Test("The highlight recognizer reports immediately, not after a delay")
    func highlightRecognizerHasNoPressDelay() {
        let view = TappableView(frame: .zero)
        #expect(view.highlightGestureRecognizer.minimumPressDuration == 0)
        #expect(view.doubleClickGestureRecognizer.numberOfClicksRequired == 2)
    }

    /// The highlight recognizer observes the press; it must never win it away
    /// from the click recognizer.
    @Test("The highlight recognizer runs alongside every other recognizer")
    func highlightRecognizerNeverExcludesAnother() {
        let view = TappableView(frame: .zero)
        let delegate = view.highlightGestureRecognizer.delegate
        #expect(delegate === view)

        #expect(
            delegate?.gestureRecognizer?(
                view.highlightGestureRecognizer,
                shouldRecognizeSimultaneouslyWith: view.clickGestureRecognizer
            ) == true
        )
        #expect(
            delegate?.gestureRecognizer?(
                view.clickGestureRecognizer,
                shouldRecognizeSimultaneouslyWith: view.highlightGestureRecognizer
            ) == true
        )
    }

    // MARK: Config resolution

    /// `didTap` runs before the view's own handler -- that ordering is the whole
    /// point of having a shared config, and reversing it would let per-view code
    /// act before the shared behaviour.
    @Test("The config's didTap runs before the view's own onTap")
    func configDidTapPrecedesOnTap() {
        let view = TappableView(frame: .zero)
        var order: [String] = []

        view.config = TappableViewConfig(didTap: { _ in order.append("config") })
        view.onTap = { _ in order.append("view") }
        view.didTap()

        #expect(order == ["config", "view"])
    }

    @Test("A view's own config wins over the process-wide default")
    func viewConfigOverridesDefault() {
        let originalDefault = TappableViewConfig.default
        defer { TappableViewConfig.default = originalDefault }

        var defaultFired = false
        var ownFired = false
        TappableViewConfig.default = TappableViewConfig(didTap: { _ in defaultFired = true })

        let view = TappableView(frame: .zero)
        view.config = TappableViewConfig(didTap: { _ in ownFired = true })
        view.didTap()

        #expect(ownFired)
        #expect(!defaultFired)
    }

    @Test("With no config of its own, the view falls back to the default")
    func defaultConfigAppliesWhenViewHasNone() {
        let originalDefault = TappableViewConfig.default
        defer { TappableViewConfig.default = originalDefault }

        var highlightStates: [Bool] = []
        TappableViewConfig.default = TappableViewConfig(
            onHighlightChanged: { _, isHighlighted in highlightStates.append(isHighlighted) }
        )

        let view = TappableView(frame: .zero)
        view.isHighlighted = true
        view.isHighlighted = true   // No change -- must not notify again.
        view.isHighlighted = false

        #expect(highlightStates == [true, false])
    }

    // MARK: Right-click menu

    @Test("menu(for:) hands back the provider's menu")
    func contextMenuProviderSuppliesTheMenu() throws {
        let view = TappableView(frame: .zero)
        let menu = NSMenu(title: "Provided")
        view.contextMenuProvider = { _ in menu }

        let event = try #require(
            NSEvent.mouseEvent(
                with: .rightMouseDown,
                location: .zero,
                modifierFlags: [],
                timestamp: 0,
                windowNumber: 0,
                context: nil,
                eventNumber: 0,
                clickCount: 1,
                pressure: 1
            )
        )

        #expect(view.menu(for: event) === menu)

        view.contextMenuProvider = nil
        #expect(view.menu(for: event) == nil)
    }

    // MARK: Render node transparency

    /// Wrapping a component in a tappable view must not change how the engine
    /// identifies or recycles it. If `contextValue` stopped forwarding, `id`
    /// and `reuseKey` would come back nil and the diff would fall back to
    /// positional matching -- no error, just wrong views after a reorder.
    @Test("The tappable wrapper forwards id and reuseKey from its content")
    func renderNodeForwardsContextValues() {
        let wrapped = NSView()
            .size(width: 50, height: 50)
            .id("content-id")
            .reuseKey("content-reuse")

        let plain = wrapped.layout(Constraint(maxSize: CGSize(width: 100, height: 100)))
        let tappable = wrapped
            .tappableView { }
            .layout(Constraint(maxSize: CGSize(width: 100, height: 100)))

        #expect(tappable.contextValue(.id) as? String == plain.contextValue(.id) as? String)
        #expect(tappable.contextValue(.id) as? String == "content-id")
        #expect(tappable.contextValue(.reuseKey) as? String == "content-reuse")
    }

    /// The wrapper reports the content's size, so putting a tappable view around
    /// something must not change the layout around it.
    @Test("The tappable wrapper reports the content's size unchanged")
    func renderNodeKeepsContentSize() {
        let constraint = Constraint(maxSize: CGSize(width: 200, height: 200))
        let content = NSView().size(width: 60, height: 30)

        let plainSize = content.layout(constraint).size
        let tappableSize = content.tappableView { }.layout(constraint).size

        #expect(tappableSize == plainSize)
        #expect(tappableSize == CGSize(width: 60, height: 30))
    }

    // MARK: Environment

    @Test("tappableViewConfig scopes a config to the subtree")
    func environmentConfigReachesTheRenderNode() {
        var scopedFired = false
        let scoped = TappableViewConfig(didTap: { _ in scopedFired = true })

        let host = ComponentView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
        host.component = NSView()
            .size(width: 100, height: 40)
            .tappableView { }
            .tappableViewConfig(scoped)
        host.reloadData()

        let tappableView = try? #require(host.subviews.compactMap { $0 as? TappableView }.first)
        tappableView?.didTap()

        #expect(scopedFired)
    }
}

#endif
