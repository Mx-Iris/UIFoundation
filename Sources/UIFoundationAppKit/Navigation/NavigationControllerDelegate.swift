//
//  Ported from the macOS App Store's own navigation stack.
//  Reverse-engineering notes: Researchs/AppStore-Custom-Navigation-Internals.md
//

#if Navigation && os(macOS)

import AppKit

/// Notified as the stack changes.
///
/// Both callbacks fire for every change that shows a different view controller, animated or not,
/// which is where a host hangs its own chrome — a title, a back button, a breadcrumb.
@MainActor
public protocol NavigationControllerDelegate: AnyObject {
    /// Sent before the new top view controller is shown; its view may not be on screen yet.
    func navigationController(
        _ navigationController: NavigationController,
        willShow viewController: NSViewController,
        animated: Bool
    )

    /// Sent once the new top view controller is settled and any animation has finished.
    ///
    /// A cancelled interactive pop never reaches here — the stack did not change.
    func navigationController(
        _ navigationController: NavigationController,
        didShow viewController: NSViewController,
        animated: Bool
    )
}

extension NavigationControllerDelegate {
    public func navigationController(
        _ navigationController: NavigationController,
        willShow viewController: NSViewController,
        animated: Bool
    ) {}

    public func navigationController(
        _ navigationController: NavigationController,
        didShow viewController: NSViewController,
        animated: Bool
    ) {}
}

/// Supplies transitions in place of the built-in push and pop.
///
/// Return `nil` from either method to keep the default look for that direction.
@MainActor
public protocol NavigationControllerTransitionDelegate: AnyObject {
    func navigationController(
        _ navigationController: NavigationController,
        pushTransitionFrom sourceView: NSView,
        to destinationView: NSView,
        in containerView: NSView
    ) -> (any ViewTransition)?

    func navigationController(
        _ navigationController: NavigationController,
        popTransitionFrom sourceView: NSView,
        to destinationView: NSView,
        in containerView: NSView
    ) -> (any ViewTransition)?
}

extension NavigationControllerTransitionDelegate {
    public func navigationController(
        _ navigationController: NavigationController,
        pushTransitionFrom sourceView: NSView,
        to destinationView: NSView,
        in containerView: NSView
    ) -> (any ViewTransition)? { nil }

    public func navigationController(
        _ navigationController: NavigationController,
        popTransitionFrom sourceView: NSView,
        to destinationView: NSView,
        in containerView: NSView
    ) -> (any ViewTransition)? { nil }
}

#endif
