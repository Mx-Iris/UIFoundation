//
//  Ported from the macOS App Store's own navigation stack.
//  Reverse-engineering notes: Researchs/AppStore-Custom-Navigation-Internals.md
//

#if Navigation && os(macOS)

import AppKit

extension NavigationController {

    /// Which way the stack moved, which decides the transition.
    enum StackOperation {
        case push
        case pop
        /// Nothing to animate: an empty side, or the same view controller on top either way.
        case none
    }

    // MARK: Public stack operations

    /// Shows `viewController`, sliding it in from the trailing edge.
    ///
    /// Pushing a view controller that is already on the stack is a programming error and is
    /// ignored — the stack must stay free of duplicates for the pop family to be unambiguous.
    public func pushViewController(_ viewController: NSViewController, animated: Bool) {
        guard !stack.contains(where: { $0 === viewController }) else {
            assertionFailure("\(viewController) is already on the navigation stack")
            return
        }
        setViewControllers(stack + [viewController], animated: animated)
    }

    /// Goes back one level.
    ///
    /// - Returns: The view controller that was removed, or `nil` when only the root was left.
    @discardableResult
    public func popViewController(animated: Bool) -> NSViewController? {
        guard canPop, let removed = stack.last else { return nil }
        setViewControllers(Array(stack.dropLast()), animated: animated)
        return removed
    }

    /// Goes back to `viewController`, removing everything above it.
    ///
    /// - Returns: The view controllers that were removed, outermost last. Empty when
    ///   `viewController` is not on the stack or is already on top.
    @discardableResult
    public func popToViewController(_ viewController: NSViewController, animated: Bool) -> [NSViewController] {
        guard let index = stack.firstIndex(where: { $0 === viewController }), index < stack.count - 1 else {
            return []
        }
        let removed = Array(stack[(index + 1)...])
        setViewControllers(Array(stack[...index]), animated: animated)
        return removed
    }

    /// Goes all the way back to the root.
    ///
    /// - Returns: The view controllers that were removed, outermost last.
    @discardableResult
    public func popToRootViewController(animated: Bool) -> [NSViewController] {
        guard let rootViewController else { return [] }
        return popToViewController(rootViewController, animated: animated)
    }

    /// Replaces the whole stack. Every other stack operation funnels through here.
    ///
    /// Called while a transition is running, the change is **deferred** until that transition
    /// finishes rather than applied on top of it — two transitions driving the same views at once
    /// leave a view stranded off screen. ``viewControllers`` therefore keeps reporting the old
    /// stack until the animation ends.
    public func setViewControllers(_ newStack: [NSViewController], animated: Bool) {
        guard !isTransitioning else {
            pendingStackChange = (newStack, animated)
            return
        }

        let oldStack = stack
        guard !isSameStack(oldStack, newStack) else { return }

        let operation = Self.operation(from: oldStack, to: newStack)
        let fromViewController = oldStack.last
        let toViewController = newStack.last
        let shouldAnimate = animated
            && isViewLoaded
            && view.window != nil
            && operation != .none
            && fromViewController != nil
            && toViewController != nil

        if let toViewController {
            delegate?.navigationController(self, willShow: toViewController, animated: shouldAnimate)
        }

        // Only the difference is re-parented. The App Store detaches and re-attaches the entire
        // stack on every change, which fires appearance callbacks on view controllers that never
        // moved.
        for viewController in oldStack where !newStack.contains(where: { $0 === viewController }) {
            viewController.removeFromParent()
        }
        for viewController in newStack where !oldStack.contains(where: { $0 === viewController }) {
            addChild(viewController)
        }

        stack = newStack

        guard isViewLoaded else {
            notifyDidShow(toViewController, animated: false)
            return
        }

        guard shouldAnimate,
              let fromViewController,
              let toViewController,
              let transition = makeTransition(operation: operation, from: fromViewController, to: toViewController)
        else {
            swapWithoutAnimation(from: fromViewController, to: toViewController)
            notifyDidShow(toViewController, animated: false)
            return
        }

        runTransition(transition) { [weak self] in
            self?.notifyDidShow(toViewController, animated: true)
        }
    }

    // MARK: Internals

    static func operation(from oldStack: [NSViewController], to newStack: [NSViewController]) -> StackOperation {
        guard let oldTop = oldStack.last, let newTop = newStack.last else { return .none }
        if oldTop === newTop { return .none }
        // Landing on something the stack already held means we are going back, however many
        // levels were dropped at once.
        if oldStack.contains(where: { $0 === newTop }) { return .pop }
        return .push
    }

    func makeTransition(
        operation: StackOperation,
        from fromViewController: NSViewController,
        to toViewController: NSViewController
    ) -> (any ViewTransition)? {
        let sourceView = fromViewController.view
        let destinationView = toViewController.view
        switch operation {
        case .none:
            return nil
        case .push:
            if let custom = transitionDelegate?.navigationController(
                self, pushTransitionFrom: sourceView, to: destinationView, in: view
            ) {
                return custom
            }
            return PushViewTransition(
                containerView: view,
                sourceView: sourceView,
                destinationView: destinationView,
                configuration: configuration
            )
        case .pop:
            if let custom = transitionDelegate?.navigationController(
                self, popTransitionFrom: sourceView, to: destinationView, in: view
            ) {
                return custom
            }
            return PopViewTransition(
                containerView: view,
                sourceView: sourceView,
                destinationView: destinationView,
                configuration: configuration
            )
        }
    }

    func runTransition(_ transition: any ViewTransition, completion: @escaping () -> Void) {
        beginTransition()
        transition.prepare()

        var animator = ViewPropertyAnimator(timing: transition.timing)
        animator.addAnimations { transition.apply(1) }
        animator.addCompletion { [weak self] in
            transition.cleanUp(isFinished: true)
            self?.endTransition()
            completion()
        }
        animator.run()
    }

    func beginTransition() {
        isTransitioning = true
    }

    /// Puts the container back in a resting state and drains anything that queued up meanwhile.
    func endTransition() {
        isTransitioning = false
        // A resize during the transition was skipped by `viewDidLayout`; catch up now.
        layOutTopViewController()
        view.window?.recalculateKeyViewLoop()

        guard let pending = pendingStackChange else { return }
        pendingStackChange = nil
        setViewControllers(pending.stack, animated: pending.animated)
    }

    func swapWithoutAnimation(from fromViewController: NSViewController?, to toViewController: NSViewController?) {
        if let fromViewController, fromViewController !== toViewController {
            fromViewController.view.removeFromSuperview()
        }
        if let toViewController {
            toViewController.view.frame = referenceRect
            if toViewController.view.superview !== view {
                view.addSubview(toViewController.view)
            }
        }
        view.window?.recalculateKeyViewLoop()
    }

    func notifyDidShow(_ viewController: NSViewController?, animated: Bool) {
        guard let viewController else { return }
        delegate?.navigationController(self, didShow: viewController, animated: animated)
    }

    private func isSameStack(_ lhs: [NSViewController], _ rhs: [NSViewController]) -> Bool {
        lhs.count == rhs.count && zip(lhs, rhs).allSatisfy { $0 === $1 }
    }
}

#endif
