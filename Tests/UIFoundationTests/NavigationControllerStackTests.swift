#if Navigation && os(macOS)

import Testing
import AppKit
@testable import UIFoundationAppKit

/// Stack behaviour, exercised through the non-animated path.
///
/// A navigation controller with no window never animates, so every assertion here settles
/// synchronously and none of it needs a run loop.
@Suite("Navigation controller stack")
@MainActor
struct NavigationControllerStackTests {

    private final class PageViewController: NSViewController {
        override func loadView() { view = NSView() }
    }

    private final class RecordingDelegate: NavigationControllerDelegate {
        private(set) var willShow: [ObjectIdentifier] = []
        private(set) var didShow: [ObjectIdentifier] = []

        func navigationController(
            _ navigationController: NavigationController,
            willShow viewController: NSViewController,
            animated: Bool
        ) {
            willShow.append(ObjectIdentifier(viewController))
        }

        func navigationController(
            _ navigationController: NavigationController,
            didShow viewController: NSViewController,
            animated: Bool
        ) {
            didShow.append(ObjectIdentifier(viewController))
        }
    }

    private func makeNavigationController(
        rootViewController: NSViewController
    ) -> NavigationController {
        let navigationController = NavigationController(rootViewController: rootViewController)
        navigationController.view.frame = CGRect(x: 0, y: 0, width: 400, height: 300)
        navigationController.view.layoutSubtreeIfNeeded()
        return navigationController
    }

    // MARK: Installing the root

    @Test("The root's view is installed when the container loads")
    func rootIsInstalled() {
        let root = PageViewController()
        let navigationController = makeNavigationController(rootViewController: root)

        #expect(navigationController.topViewController === root)
        #expect(navigationController.rootViewController === root)
        #expect(root.view.superview === navigationController.view)
        #expect(navigationController.children.contains { $0 === root })
        #expect(navigationController.canPop == false)
    }

    @Test("A container with no root shows nothing")
    func emptyContainer() {
        let navigationController = NavigationController()
        navigationController.view.frame = CGRect(x: 0, y: 0, width: 400, height: 300)

        #expect(navigationController.topViewController == nil)
        #expect(navigationController.viewControllers.isEmpty)
        #expect(navigationController.popViewController(animated: false) == nil)
    }

    // MARK: Push and pop

    @Test("Pushing swaps the visible view and grows the stack")
    func push() {
        let root = PageViewController()
        let detail = PageViewController()
        let navigationController = makeNavigationController(rootViewController: root)

        navigationController.pushViewController(detail, animated: false)

        #expect(navigationController.viewControllers.count == 2)
        #expect(navigationController.topViewController === detail)
        #expect(detail.view.superview === navigationController.view)
        #expect(root.view.superview == nil)
        #expect(navigationController.canPop)
    }

    @Test("Popping returns the removed view controller and puts the previous one back")
    func pop() {
        let root = PageViewController()
        let detail = PageViewController()
        let navigationController = makeNavigationController(rootViewController: root)
        navigationController.pushViewController(detail, animated: false)

        let popped = navigationController.popViewController(animated: false)

        #expect(popped === detail)
        #expect(navigationController.topViewController === root)
        #expect(root.view.superview === navigationController.view)
        #expect(detail.view.superview == nil)
        #expect(navigationController.children.contains { $0 === detail } == false)
    }

    @Test("Popping the root alone does nothing")
    func popRoot() {
        let root = PageViewController()
        let navigationController = makeNavigationController(rootViewController: root)

        #expect(navigationController.popViewController(animated: false) == nil)
        #expect(navigationController.viewControllers.count == 1)
    }

    @Test("Popping to a view controller removes everything above it, outermost last")
    func popToViewController() {
        let root = PageViewController()
        let middle = PageViewController()
        let detail = PageViewController()
        let navigationController = makeNavigationController(rootViewController: root)
        navigationController.pushViewController(middle, animated: false)
        navigationController.pushViewController(detail, animated: false)

        let removed = navigationController.popToViewController(middle, animated: false)

        #expect(removed.count == 1)
        #expect(removed.first === detail)
        #expect(navigationController.topViewController === middle)
        #expect(navigationController.viewControllers.count == 2)
    }

    @Test("Popping to a view controller that is not on the stack changes nothing")
    func popToUnknownViewController() {
        let root = PageViewController()
        let stranger = PageViewController()
        let navigationController = makeNavigationController(rootViewController: root)
        navigationController.pushViewController(PageViewController(), animated: false)

        #expect(navigationController.popToViewController(stranger, animated: false).isEmpty)
        #expect(navigationController.viewControllers.count == 2)
    }

    @Test("Popping to the root unwinds however many levels are stacked")
    func popToRoot() {
        let root = PageViewController()
        let navigationController = makeNavigationController(rootViewController: root)
        navigationController.pushViewController(PageViewController(), animated: false)
        navigationController.pushViewController(PageViewController(), animated: false)
        navigationController.pushViewController(PageViewController(), animated: false)

        let removed = navigationController.popToRootViewController(animated: false)

        #expect(removed.count == 3)
        #expect(navigationController.topViewController === root)
        #expect(navigationController.children.count == 1)
    }

    // MARK: Containment

    @Test("Child view controllers track the stack, and only the difference is re-parented")
    func containmentTracksStack() {
        let root = PageViewController()
        let detail = PageViewController()
        let navigationController = makeNavigationController(rootViewController: root)

        navigationController.pushViewController(detail, animated: false)
        #expect(navigationController.children.count == 2)

        // Replacing only the top must leave the root's parent relationship untouched.
        let replacement = PageViewController()
        navigationController.setViewControllers([root, replacement], animated: false)
        #expect(navigationController.children.count == 2)
        #expect(navigationController.children.contains { $0 === root })
        #expect(navigationController.children.contains { $0 === replacement })
        #expect(navigationController.children.contains { $0 === detail } == false)
    }

    @Test("`deepestViewController` walks through nested navigation controllers")
    func deepestViewController() {
        let leaf = PageViewController()
        let inner = NavigationController(rootViewController: leaf)
        let outer = makeNavigationController(rootViewController: PageViewController())
        outer.pushViewController(inner, animated: false)

        #expect(outer.topViewController === inner)
        #expect(outer.deepestViewController === leaf)
    }

    // MARK: Layout

    @Test("Content insets shrink the page")
    func contentInsetsApplyToChildren() {
        let root = PageViewController()
        let navigationController = makeNavigationController(rootViewController: root)

        navigationController.configuration.contentInsets = NSEdgeInsets(top: 10, left: 20, bottom: 30, right: 40)

        #expect(root.view.frame == CGRect(x: 20, y: 30, width: 340, height: 260))
    }

    @Test("Changing the configuration mid-transition leaves the running slide alone")
    func configurationChangeDuringTransitionDoesNotDisturbTheSlide() {
        let root = PageViewController()
        let navigationController = makeNavigationController(rootViewController: root)

        // Stand in for a transition in flight, with the page parked partway through its slide.
        navigationController.isTransitioning = true
        let midSlideFrame = CGRect(x: -50, y: 0, width: 400, height: 300)
        root.view.frame = midSlideFrame

        // Dragging a slider in a settings pane does exactly this, one tick at a time.
        navigationController.configuration.parallaxFactor = 0.5

        #expect(root.view.frame == midSlideFrame)

        // The new geometry lands once the transition is over, not before.
        navigationController.endTransition()
        #expect(root.view.frame == CGRect(x: 0, y: 0, width: 400, height: 300))
    }

    @Test("Resizing the container resizes the page")
    func resizeRelaysOutTheTopPage() {
        let root = PageViewController()
        let navigationController = makeNavigationController(rootViewController: root)

        navigationController.view.frame = CGRect(x: 0, y: 0, width: 640, height: 480)
        navigationController.view.layoutSubtreeIfNeeded()

        #expect(root.view.frame == CGRect(x: 0, y: 0, width: 640, height: 480))
    }

    // MARK: Delegate

    @Test("The delegate hears about every change, in order")
    func delegateCallbacks() {
        let root = PageViewController()
        let detail = PageViewController()
        let navigationController = makeNavigationController(rootViewController: root)
        let delegate = RecordingDelegate()
        navigationController.delegate = delegate

        navigationController.pushViewController(detail, animated: false)
        navigationController.popViewController(animated: false)

        #expect(delegate.willShow == [ObjectIdentifier(detail), ObjectIdentifier(root)])
        #expect(delegate.didShow == [ObjectIdentifier(detail), ObjectIdentifier(root)])
    }

    @Test("Setting the same stack again is a no-op")
    func settingAnIdenticalStackDoesNothing() {
        let root = PageViewController()
        let navigationController = makeNavigationController(rootViewController: root)
        let delegate = RecordingDelegate()
        navigationController.delegate = delegate

        navigationController.setViewControllers([root], animated: false)

        #expect(delegate.willShow.isEmpty)
        #expect(delegate.didShow.isEmpty)
    }

    // MARK: Operation classification

    @Test("Going somewhere new is a push; landing back on something the stack held is a pop")
    func operationClassification() {
        let first = PageViewController()
        let second = PageViewController()
        let third = PageViewController()

        #expect(NavigationController.operation(from: [first], to: [first, second]) == .push)
        #expect(NavigationController.operation(from: [first, second], to: [first]) == .pop)
        // Several levels at once still reads as going back.
        #expect(NavigationController.operation(from: [first, second, third], to: [first]) == .pop)
        // A replacement of the top is forward motion.
        #expect(NavigationController.operation(from: [first, second], to: [first, third]) == .push)
        #expect(NavigationController.operation(from: [first], to: [first]) == .none)
        #expect(NavigationController.operation(from: [], to: [first]) == .none)
        #expect(NavigationController.operation(from: [first], to: []) == .none)
    }
}

#endif
