#if Navigation && os(macOS)

import Testing
import AppKit
@testable import UIFoundationAppKit

/// What a transition does to the view hierarchy, driven by hand.
///
/// **Why nothing here runs a real animation.** `NSAnimationContext.runAnimationGroup`'s completion
/// handler never fires inside the `swift test` process — the same code fires it immediately in a
/// plain executable, with or without an `NSApplication`, so it is the harness and not the
/// implementation. Waiting on one only buys a five-second timeout.
///
/// That costs less than it sounds. The transition is a *description*: `prepare()` builds the
/// hierarchy, `apply(_:)` writes the state for a fraction, `cleanUp(isFinished:)` tears it down,
/// and all three are synchronous and asserted below at the fractions that matter. What is not
/// covered is Apple's tweening between them, which is not ours to test. The animated path is
/// exercised by hand in the example app's **Controls ▸ Navigation** demo.
@Suite("Navigation transition run")
@MainActor
struct NavigationTransitionRunTests {

    private final class PageViewController: NSViewController {
        override func loadView() { view = NSView() }
    }

    private func makeContainer() -> NSView {
        NSView(frame: CGRect(x: 0, y: 0, width: 400, height: 300))
    }

    private var fullRect: CGRect { CGRect(x: 0, y: 0, width: 400, height: 300) }

    // MARK: Push

    @Test("Preparing a push stages the incoming page off screen, dimming between the two")
    func pushPreparesTheHierarchy() throws {
        let container = makeContainer()
        let sourceView = NSView(frame: fullRect)
        let destinationView = NSView()
        container.addSubview(sourceView)

        let transition = PushViewTransition(
            containerView: container,
            sourceView: sourceView,
            destinationView: destinationView,
            configuration: .default
        )
        transition.prepare()

        // Back to front: the page leaving, the dim over it, the shadow, the page arriving.
        let edgeShadowView = try #require(transition.edgeShadowView)
        #expect(container.subviews == [sourceView, transition.dimmingView, edgeShadowView, destinationView])
        #expect(transition.dimmingView.frame == fullRect)
        // Seated at zero — nothing has moved and the dim is still clear.
        #expect(sourceView.frame == fullRect)
        #expect(destinationView.frame == CGRect(x: 400, y: 0, width: 400, height: 300))
        #expect(transition.dimmingView.alphaValue == 0)
        // The shadow hugs the arriving page's leading edge. It starts at full strength, which
        // shows nothing: at this point it is off screen along with the page it trails.
        #expect(edgeShadowView.frame == CGRect(x: 391, y: 0, width: 9, height: 300))
        #expect(edgeShadowView.alphaValue == 1)
    }

    @Test("A completed push leaves the incoming page in place and the old one at rest")
    func pushAppliesAndCleansUp() {
        let container = makeContainer()
        let sourceView = NSView(frame: fullRect)
        let destinationView = NSView()
        container.addSubview(sourceView)

        let transition = PushViewTransition(
            containerView: container,
            sourceView: sourceView,
            destinationView: destinationView,
            configuration: .default
        )
        transition.prepare()
        transition.apply(1)

        #expect(destinationView.frame == fullRect)
        // UIKit's parallax: 400 × 0.3.
        #expect(sourceView.frame == CGRect(x: -120, y: 0, width: 400, height: 300))
        #expect(transition.dimmingView.alphaValue == 1)
        // The shadow travelled with the page and faded out on the way.
        #expect(transition.edgeShadowView?.frame == CGRect(x: -9, y: 0, width: 9, height: 300))
        #expect(transition.edgeShadowView?.alphaValue == 0)

        transition.cleanUp(isFinished: true)

        #expect(container.subviews == [destinationView])
        // The parallax offset must not outlive the transition — this view may be pushed again.
        #expect(sourceView.frame == fullRect)
    }

    @Test("Every page taking part is made layer-backed")
    func participatingPagesAreLayerBacked() {
        let container = makeContainer()
        let sourceView = NSView(frame: fullRect)
        let destinationView = NSView()
        container.addSubview(sourceView)

        let transition = PushViewTransition(
            containerView: container,
            sourceView: sourceView,
            destinationView: destinationView,
            configuration: .default
        )
        transition.prepare()

        #expect(sourceView.wantsLayer)
        #expect(destinationView.wantsLayer)
        #expect(transition.dimmingView.wantsLayer)
    }

    // MARK: Pop

    @Test("Preparing a pop puts the returning page behind, already dimmed")
    func popPreparesTheHierarchy() throws {
        let container = makeContainer()
        let sourceView = NSView(frame: fullRect)
        let destinationView = NSView()
        container.addSubview(sourceView)

        let transition = PopViewTransition(
            containerView: container,
            sourceView: sourceView,
            destinationView: destinationView,
            configuration: .default
        )
        transition.prepare()

        let edgeShadowView = try #require(transition.edgeShadowView)
        #expect(container.subviews == [destinationView, transition.dimmingView, edgeShadowView, sourceView])
        // The returning page starts where the push left it: offset by the parallax amount.
        #expect(destinationView.frame == CGRect(x: -120, y: 0, width: 400, height: 300))
        #expect(transition.dimmingView.alphaValue == 1)
        // On a pop the shadow trails the page on its way out, so it starts against that page.
        #expect(edgeShadowView.frame == CGRect(x: -9, y: 0, width: 9, height: 300))
    }

    @Test("A completed pop sends the top page off screen and clears the dim")
    func popAppliesAndCleansUp() {
        let container = makeContainer()
        let sourceView = NSView(frame: fullRect)
        let destinationView = NSView()
        container.addSubview(sourceView)

        let transition = PopViewTransition(
            containerView: container,
            sourceView: sourceView,
            destinationView: destinationView,
            configuration: .default
        )
        transition.prepare()
        transition.apply(1)

        #expect(sourceView.frame == CGRect(x: 400, y: 0, width: 400, height: 300))
        #expect(destinationView.frame == fullRect)
        #expect(transition.dimmingView.alphaValue == 0)

        transition.cleanUp(isFinished: true)

        #expect(container.subviews == [destinationView])
        #expect(sourceView.frame == fullRect)
    }

    @Test("An abandoned pop puts the page that was on top back at rest")
    func abandonedPopRestoresTheSourcePage() {
        let container = makeContainer()
        let sourceView = NSView(frame: fullRect)
        let destinationView = NSView()
        container.addSubview(sourceView)

        let transition = PopViewTransition(
            containerView: container,
            sourceView: sourceView,
            destinationView: destinationView,
            configuration: .default
        )
        transition.prepare()
        transition.apply(0.4)
        transition.cleanUp(isFinished: false)

        #expect(container.subviews == [sourceView])
        #expect(sourceView.frame == fullRect)
        #expect(destinationView.superview == nil)
    }

    // MARK: Right to left

    @Test("A right-to-left container mirrors the whole transition")
    func rightToLeftMirrors() {
        let container = makeContainer()
        container.userInterfaceLayoutDirection = .rightToLeft
        let sourceView = NSView(frame: fullRect)
        let destinationView = NSView()
        container.addSubview(sourceView)

        let transition = PushViewTransition(
            containerView: container,
            sourceView: sourceView,
            destinationView: destinationView,
            configuration: .default
        )
        transition.prepare()

        #expect(destinationView.frame == CGRect(x: -400, y: 0, width: 400, height: 300))
        transition.apply(1)
        #expect(sourceView.frame == CGRect(x: 120, y: 0, width: 400, height: 300))
    }

    // MARK: Configuration

    @Test("Content insets shrink the rectangle the transition plays in")
    func contentInsetsApplyToTheTransition() {
        let container = makeContainer()
        let sourceView = NSView()
        let destinationView = NSView()
        container.addSubview(sourceView)

        var configuration = NavigationConfiguration()
        configuration.contentInsets = NSEdgeInsets(top: 0, left: 50, bottom: 0, right: 50)
        let transition = PushViewTransition(
            containerView: container,
            sourceView: sourceView,
            destinationView: destinationView,
            configuration: configuration
        )
        transition.prepare()

        #expect(sourceView.frame == CGRect(x: 50, y: 0, width: 300, height: 300))
        #expect(destinationView.frame == CGRect(x: 350, y: 0, width: 300, height: 300))
        transition.apply(1)
        #expect(destinationView.frame == CGRect(x: 50, y: 0, width: 300, height: 300))
        // 300 × 0.3, measured from the inset rectangle: 50 − 90.
        #expect(sourceView.frame == CGRect(x: -40, y: 0, width: 300, height: 300))
    }

    @Test("A zero parallax factor keeps the underlying page still")
    func zeroParallaxFactor() {
        let container = makeContainer()
        let sourceView = NSView()
        let destinationView = NSView()
        container.addSubview(sourceView)

        var configuration = NavigationConfiguration()
        configuration.parallaxFactor = 0
        let transition = PushViewTransition(
            containerView: container,
            sourceView: sourceView,
            destinationView: destinationView,
            configuration: configuration
        )
        transition.prepare()
        transition.apply(1)

        #expect(sourceView.frame == fullRect)
    }

    // MARK: Presets

    @Test("The App Store preset drops the edge shadow and slides less far")
    func appStorePreset() {
        let container = makeContainer()
        let sourceView = NSView()
        let destinationView = NSView()
        container.addSubview(sourceView)

        let transition = PushViewTransition(
            containerView: container,
            sourceView: sourceView,
            destinationView: destinationView,
            configuration: .appStore
        )
        transition.prepare()

        #expect(transition.edgeShadowView == nil)
        #expect(container.subviews == [sourceView, transition.dimmingView, destinationView])

        transition.apply(1)
        // 400 × 0.2527, floored — nineteen points short of UIKit's 120.
        #expect(sourceView.frame == CGRect(x: -101, y: 0, width: 400, height: 300))
    }

    @Test("The default preset is UIKit's, not the App Store's")
    func defaultPresetIsUIKit() {
        #expect(NavigationConfiguration.default.parallaxFactor == 0.3)
        #expect(NavigationConfiguration.default.edgeShadowWidth == 9)
        #expect(NavigationConfiguration.default.timing == .uiKitNavigation)
        #expect(NavigationConfiguration.appStore.parallaxFactor == 0.2527)
        #expect(NavigationConfiguration.appStore.edgeShadowWidth == 0)
        #expect(NavigationConfiguration.appStore.timing == .appStoreNavigation)
    }

    @Test("A right-to-left transition puts the shadow on the other side of the page")
    func edgeShadowMirrors() throws {
        let container = makeContainer()
        container.userInterfaceLayoutDirection = .rightToLeft
        let sourceView = NSView()
        let destinationView = NSView()
        container.addSubview(sourceView)

        let transition = PushViewTransition(
            containerView: container,
            sourceView: sourceView,
            destinationView: destinationView,
            configuration: .default
        )
        transition.prepare()

        let edgeShadowView = try #require(transition.edgeShadowView)
        // The page arrives from the left, so the shadow trails on its right.
        #expect(edgeShadowView.frame == CGRect(x: 0, y: 0, width: 9, height: 300))
        transition.apply(1)
        #expect(edgeShadowView.frame == CGRect(x: 400, y: 0, width: 9, height: 300))
    }

    // MARK: Deferral

    @Test("A stack change asked for mid-transition waits for the transition to end")
    func stackChangeDuringTransitionIsDeferred() {
        let root = PageViewController()
        let second = PageViewController()
        let navigationController = NavigationController(rootViewController: root)
        navigationController.view.frame = fullRect
        navigationController.view.layoutSubtreeIfNeeded()

        // Stand in for a running transition. Driving a real one is what the harness cannot do.
        navigationController.isTransitioning = true
        navigationController.pushViewController(second, animated: false)

        #expect(navigationController.viewControllers.count == 1)
        #expect(navigationController.topViewController === root)

        navigationController.endTransition()

        #expect(navigationController.viewControllers.count == 2)
        #expect(navigationController.topViewController === second)
        #expect(second.view.superview === navigationController.view)
        #expect(navigationController.isTransitioning == false)
    }
}

#endif
