#if canImport(AppKit) && !targetEnvironment(macCatalyst)

import Testing
import AppKit
@testable import UIFoundationAppKit
#if AppKitPlus && canImport(AppKitPlus)
import AppKitPlus
#endif

/// Pins which class `LayerBackedViewController` inherits from on each side of the `AppKitPlus`
/// trait, and keeps a canary on the one thing overriding `loadView()` could quietly take away.
///
/// `NSLayerBackedViewController` performs its wiring in `-setView:` -- the view's back reference to
/// its controller, the layout guides, the additional safe-area insets, and the key-value
/// observation behind `viewSafeAreaInsetsDidChange`. Installing the content view by assigning
/// `view` therefore keeps all of it; installing it any other way would keep the hooks silently
/// unwired. `layerBackedView` is the observable consequence: it is `nil` exactly when that path did
/// not recognise the root view.
///
/// Everything else here asserts that *switching the base class changed nothing* -- those tests must
/// pass with the trait on and off alike.
@Suite("LayerBackedViewController")
@MainActor
struct LayerBackedViewControllerTests {
    /// Counts each override so a test can tell "fired once" from "fired on every appearance".
    private final class CountingViewController: LayerBackedViewController<LayerBackedView> {
        private(set) var viewWillFirstAppearCount = 0
        private(set) var viewDidFirstAppearCount = 0
        private(set) var contentViewDidChangeCount = 0

        override func viewWillFirstAppear() {
            super.viewWillFirstAppear()
            viewWillFirstAppearCount += 1
        }

        override func viewDidFirstAppear() {
            super.viewDidFirstAppear()
            viewDidFirstAppearCount += 1
        }

        override func contentViewDidChange(_ oldContentView: LayerBackedView) {
            super.contentViewDidChange(oldContentView)
            contentViewDidChangeCount += 1
        }
    }

    @Test("inherits from NSLayerBackedViewController exactly when the AppKitPlus trait is on")
    func baseClass() {
        #if AppKitPlus && canImport(AppKitPlus)
        #expect(LayerBackedViewController<LayerBackedView>.superclass() == NSLayerBackedViewController.self)
        #else
        #expect(LayerBackedViewController<LayerBackedView>.superclass() == NSViewController.self)
        #endif
    }

    @Test("loadView installs the content view rather than a view of its own")
    func loadViewInstallsContentView() {
        let controller = LayerBackedViewController<LayerBackedView>()

        #expect(!controller.isViewLoaded)
        #expect(controller.view === controller.contentView)
    }

    /// The root view of the overridden `-[NSLayerBackedViewController loadView]` is flexible on both
    /// axes; installing our own must not silently drop that.
    @Test("the installed content view is flexible on both axes")
    func contentViewIsFlexible() {
        let controller = LayerBackedViewController<LayerBackedView>()

        _ = controller.view

        #expect(controller.contentView.autoresizingMask == [.width, .height])
    }

    #if AppKitPlus && canImport(AppKitPlus)
    /// Canary: `layerBackedView` is resolved along the `-setView:` path that also installs the
    /// layout guides, the additional safe-area insets and the safe-area observation. If this goes
    /// `nil`, the six hooks stopped arriving too.
    @Test("overriding loadView keeps AppKitPlus's setView: wiring")
    func setViewWiringSurvivesLoadViewOverride() {
        let controller = LayerBackedViewController<LayerBackedView>()

        _ = controller.view

        #expect(controller.layerBackedView === controller.contentView)
    }
    #endif

    @Test("replacing the content view before the view loads does not load it")
    func replacingContentViewBeforeLoad() {
        let controller = CountingViewController()
        let replacement = LayerBackedView()

        controller.contentView = replacement

        #expect(!controller.isViewLoaded)
        #expect(controller.contentViewDidChangeCount == 0)
        #expect(controller.view === replacement)
    }

    @Test("replacing the content view after the view loads swaps the root view")
    func replacingContentViewAfterLoad() {
        let controller = CountingViewController()
        _ = controller.view
        let replacement = LayerBackedView()

        controller.contentView = replacement

        #expect(controller.contentViewDidChangeCount == 1)
        #expect(controller.view === replacement)
        #expect(replacement.autoresizingMask == [.width, .height])
    }

    /// Must hold on both sides of the trait: with it on these come from AppKitPlus, with it off from
    /// the polyfill in `LayerBackedViewController`, and both fire after `super`.
    @Test("the first-appear hooks fire exactly once")
    func firstAppearHooksFireOnce() {
        let controller = CountingViewController()
        _ = controller.view

        controller.viewWillAppear()
        controller.viewDidAppear()
        controller.viewWillAppear()
        controller.viewDidAppear()

        #expect(controller.viewWillFirstAppearCount == 1)
        #expect(controller.viewDidFirstAppearCount == 1)
    }
}

#endif
