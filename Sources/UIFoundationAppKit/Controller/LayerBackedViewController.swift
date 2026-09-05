#if canImport(AppKit) && !targetEnvironment(macCatalyst)

import AppKit
#if AppKitPlus && canImport(AppKitPlus)
import AppKitPlus

/// The class `LayerBackedViewController` inherits from.
///
/// With the `AppKitPlus` trait on, this is `NSLayerBackedViewController` -- AppKitPlus's port of
/// UXKit's `UXViewController`, the controller-side counterpart to the `NSLayerBackedView` that
/// `LayerBackedView` already inherits from. What it contributes is the wiring `-setView:` performs
/// (the view's back reference to its controller, the layout guides, the additional safe-area
/// insets, and the key-value observation behind `viewSafeAreaInsetsDidChange`) plus six hooks
/// AppKit itself offers nowhere to put: `viewWillFirstLayout` / `viewDidFirstLayout`,
/// `viewWillFirstAppear` / `viewDidFirstAppear`, `viewUpdateLayer` and
/// `viewSafeAreaInsetsDidChange`.
public typealias LayerBackedViewControllerBase = NSLayerBackedViewController
#else
/// The class `LayerBackedViewController` inherits from -- plain `NSViewController` unless the
/// `AppKitPlus` trait is on, in which case it becomes `NSLayerBackedViewController`.
public typealias LayerBackedViewControllerBase = NSViewController
#endif

/// A view controller whose root view is a `LayerBackedView`, created in code.
///
/// Same shape as ``XiblessViewController`` -- a typed `contentView` built by an `@autoclosure`
/// factory, installed in `loadView()` -- with two differences: the content view is constrained to
/// `LayerBackedView` rather than any view, and the base class follows the `AppKitPlus` trait.
///
/// With the trait on, this is the controller half of what Evolution 0017 did to the view half:
/// pages built on this class reach AppKitPlus's containers (`NSNavigationController` and friends)
/// already carrying the wiring those containers expect, instead of being a plain
/// `NSViewController` that happens to hold a layer-backed view.
///
/// ## The four hooks that are not polyfilled
///
/// With the trait **off** the base class is `NSViewController`, which has none of the six hooks
/// listed on ``LayerBackedViewControllerBase``. Two of them -- `viewWillFirstAppear` and
/// `viewDidFirstAppear` -- are reproduced below, because a controller can drive them by itself
/// from `viewWillAppear()` / `viewDidAppear()` and a flag, in the same order AppKitPlus uses
/// (`super` first, then the flag, then the hook). Overriding those two therefore compiles on both
/// sides of the trait.
///
/// The other four -- `viewWillFirstLayout`, `viewDidFirstLayout`, `viewUpdateLayer` and
/// `viewSafeAreaInsetsDidChange` -- are driven by the *view*, and `LayerBackedView` has no channel
/// back to its controller. **A subclass overriding one of them has to wrap the override in
/// `#if AppKitPlus && canImport(AppKitPlus)`**, or it will not compile with the trait off.
///
/// ## Overriding `loadView()` is safe
///
/// `NSLayerBackedViewController` performs all of its wiring in `-setView:`, not in `-loadView`
/// (measured against AppKitPlus 0.2.1). Installing the content view by assigning `view` therefore
/// keeps every hook attached -- `LayerBackedViewControllerTests` keeps a canary on it via
/// `layerBackedView`, which is `nil` exactly when that path did not recognise the root view.
///
/// The one thing the overridden `-loadView` also did is reproduced here: the root view gets
/// `autoresizingMask = [.width, .height]`.
open class LayerBackedViewController<View: LayerBackedView>: LayerBackedViewControllerBase {
    public lazy var contentView: View = contentViewGenerator() {
        didSet {
            // Skip while the view is unloaded — `loadView()` will pick up the new value
            // through the lazy var when it eventually runs. Doing work here would
            // prematurely access `self.view`, force-trigger `loadView()`, and (in
            // subclasses that wire subviews against `self.view`) install duplicate
            // constraints when the outer caller's work resumes.
            guard isViewLoaded else { return }
            contentViewDidChange(oldValue)
        }
    }

    private let contentViewGenerator: () -> View

    public init(viewGenerator: @autoclosure @escaping () -> View = View()) {
        self.contentViewGenerator = viewGenerator
        super.init(nibName: nil, bundle: nil)
        commonInit()
    }

    @available(*, unavailable)
    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    open func commonInit() {}

    open override func loadView() {
        installContentView()
    }

    /// Called from `contentView`'s `didSet` only after the view is loaded. Subclasses
    /// override this to rewire their hierarchy and do not need to guard against the
    /// unloaded state themselves.
    open func contentViewDidChange(_ oldContentView: View) {
        installContentView()
    }

    private func installContentView() {
        contentView.autoresizingMask = [.width, .height]
        view = contentView
    }

    #if !(AppKitPlus && canImport(AppKitPlus))
    private var hasSentViewWillFirstAppear = false
    private var hasSentViewDidFirstAppear = false

    /// Called the **first** time the view appears and no other time, after `super.viewWillAppear()`
    /// has run.
    ///
    /// Polyfill of `NSLayerBackedViewController`'s hook of the same name, for builds with the
    /// `AppKitPlus` trait off.
    open func viewWillFirstAppear() {}

    /// Called the **first** time the view appears and no other time, after `super.viewDidAppear()`
    /// has run.
    ///
    /// Polyfill of `NSLayerBackedViewController`'s hook of the same name, for builds with the
    /// `AppKitPlus` trait off.
    open func viewDidFirstAppear() {}

    open override func viewWillAppear() {
        super.viewWillAppear()

        guard !hasSentViewWillFirstAppear else { return }
        hasSentViewWillFirstAppear = true
        viewWillFirstAppear()
    }

    open override func viewDidAppear() {
        super.viewDidAppear()

        guard !hasSentViewDidFirstAppear else { return }
        hasSentViewDidFirstAppear = true
        viewDidFirstAppear()
    }
    #endif
}

#endif
