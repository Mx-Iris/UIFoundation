//
//  Ported from the macOS App Store's own navigation stack.
//  Reverse-engineering notes: Researchs/AppStore-Custom-Navigation-Internals.md
//

#if Navigation && os(macOS)

import AppKit

/// A `UINavigationController`-shaped container for AppKit, modelled on the one the macOS App
/// Store built for itself.
///
/// ```swift
/// let navigationController = NavigationController(rootViewController: LibraryViewController())
/// navigationController.pushViewController(DetailViewController(), animated: true)
/// ```
///
/// The stack is the state; everything else follows from it. ``pushViewController(_:animated:)``
/// and the pop family are conveniences over ``setViewControllers(_:animated:)``, which is the one
/// place a change is ever applied.
///
/// ### The container owns child geometry
///
/// Child views are positioned by frame, inside ``NavigationConfiguration/contentInsets``, and
/// resized on every layout pass. Do **not** constrain a child's view to anything outside the
/// navigation controller — Auto Layout inside the child is fine and expected, but an external
/// constraint fights the transition and produces a view that slides back as it slides in.
///
/// ### Children are made layer-backed
///
/// A transition animates by assigning end values under `allowsImplicitAnimation`, so every
/// participating view gets `wantsLayer = true`. A host that cannot tolerate layer backing cannot
/// use the animated paths.
open class NavigationController: NSViewController, NSUserInterfaceValidations {

    // MARK: Stack

    var stack: [NSViewController] = []

    /// The stack, root first. Assigning is the same as ``setViewControllers(_:animated:)`` with
    /// no animation.
    public var viewControllers: [NSViewController] {
        get { stack }
        set { setViewControllers(newValue, animated: false) }
    }

    /// The bottom of the stack.
    public var rootViewController: NSViewController? { stack.first }

    /// The view controller currently on screen.
    public var topViewController: NSViewController? { stack.last }

    /// The top of the innermost nested navigation controller, or ``topViewController`` when there
    /// is no nesting.
    ///
    /// Useful for routing a command at whatever is genuinely in front of the user.
    public var deepestViewController: NSViewController? {
        var candidate = topViewController
        while let nested = candidate as? NavigationController, let deeper = nested.topViewController {
            candidate = deeper
        }
        return candidate
    }

    /// Whether there is anything to go back to.
    public var canPop: Bool { stack.count > 1 }

    /// `true` from the moment a transition is prepared until its clean-up has run.
    ///
    /// Stack changes requested while this is `true` are applied without animation rather than
    /// queued, so a double-click on a row cannot leave two transitions fighting over the same views.
    public internal(set) var isTransitioning = false

    // MARK: Configuration

    /// Timing, parallax, dimming and content insets. Assigning re-lays out the current page.
    ///
    /// A transition already in flight keeps the geometry it started with; yanking the top page to
    /// a new resting frame mid-slide would tear the animation apart. The new values take effect on
    /// the next transition, and `endTransition()` re-lays out with them.
    public var configuration: NavigationConfiguration = .default {
        didSet {
            guard isViewLoaded, !isTransitioning else { return }
            layOutTopViewController()
        }
    }

    /// Whether a two-finger rightward swipe pops the stack. Default `true`.
    public var allowsInteractivePop = true

    public weak var delegate: (any NavigationControllerDelegate)?

    /// Supplies replacement transitions. Consulted before the built-in push and pop.
    public weak var transitionDelegate: (any NavigationControllerTransitionDelegate)?

    /// The interactive pop in flight, if any. See `NavigationController+Swipe.swift`.
    var interactivePopSession: InteractivePopSession?

    /// A stack change asked for while a transition was running, applied once it finishes.
    var pendingStackChange: (stack: [NSViewController], animated: Bool)?

    // MARK: Init

    public init(rootViewController: NSViewController? = nil) {
        super.init(nibName: nil, bundle: nil)
        if let rootViewController {
            stack = [rootViewController]
            addChild(rootViewController)
        }
    }

    override public init(nibName nibNameOrNil: NSNib.Name?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
    }

    @available(*, unavailable)
    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: View lifecycle

    override open func loadView() {
        view = NSView()
    }

    override open func viewDidLoad() {
        super.viewDidLoad()
        guard let topViewController else { return }
        topViewController.view.frame = referenceRect
        view.addSubview(topViewController.view)
    }

    override open func viewDidLayout() {
        super.viewDidLayout()
        // A resize mid-transition would fight the frames CoreAnimation is driving; the transition's
        // completion re-lays out instead.
        guard !isTransitioning else { return }
        layOutTopViewController()
    }

    /// The rectangle child views occupy: the container's bounds, inset.
    var referenceRect: CGRect {
        NavigationTransitionGeometry.referenceRect(
            containerBounds: view.bounds,
            contentInsets: configuration.contentInsets,
            isFlipped: view.isFlipped
        )
    }

    func layOutTopViewController() {
        topViewController?.view.frame = referenceRect
    }

    // MARK: Interactive pop
    //
    // Swift forbids `override` in an extension, so the two responder entry points live here; the
    // work is in `NavigationController+Swipe.swift`.

    override open func wantsScrollEventsForSwipeTracking(on axis: NSEvent.GestureAxis) -> Bool {
        allowsInteractivePop && axis == .horizontal
    }

    override open func scrollWheel(with event: NSEvent) {
        guard beginInteractivePopIfPossible(with: event) else {
            super.scrollWheel(with: event)
            return
        }
    }

    // MARK: Actions

    /// Pops one level, animated. Wire a back button or a ⌘[ menu item to this.
    @IBAction open func navigateBack(_ sender: Any?) {
        popViewController(animated: true)
    }

    open func validateUserInterfaceItem(_ item: any NSValidatedUserInterfaceItem) -> Bool {
        if item.action == #selector(navigateBack(_:)) {
            return canPop
        }
        return true
    }
}

#endif
