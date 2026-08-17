//
//  Ported from the macOS App Store's own navigation stack.
//  Reverse-engineering notes: Researchs/AppStore-Custom-Navigation-Internals.md
//
//  Defines PushViewTransition and PopViewTransition over one shared implementation — the two
//  differ only in which view starts off screen, which one gets the parallax offset, and which
//  way the dimming fades.
//

#if Navigation && os(macOS)

import AppKit

/// The App Store's push and pop, minus the question of which direction it is going.
struct NavigationParallaxTransitionCore {
    enum Operation {
        case push
        case pop
    }

    let operation: Operation
    let containerView: NSView
    let sourceView: NSView
    let destinationView: NSView
    let dimmingView: NavigationDimmingView
    /// `nil` when ``NavigationConfiguration/edgeShadowWidth`` is zero.
    let edgeShadowView: NavigationEdgeShadowView?
    /// The stand-in background under the arriving page on a **push**, or `nil` when it needs none.
    /// A pop uses ``leavingPageBackground`` instead. See ``NavigationPageBackdrop``.
    let pageBackdropView: NSView?

    /// A pop writes the background onto the leaving page itself rather than sliding a view under
    /// it, and puts it back afterwards. `nil` when the page needs none.
    ///
    /// The two directions differ because their starting states do: on a push the arriving page
    /// comes from off screen, so a view can travel in underneath it, while on a pop the leaving
    /// page already fills the container and anything slipped beneath it appears there instantly.
    let leavingPageBackground: LeavingPageBackground?

    /// Carries the leaving page's original background across ``prepare()`` and ``cleanUp(isFinished:)``.
    /// A reference type because the transition itself is a value and neither method mutates it.
    final class LeavingPageBackground {
        let color: NSColor
        var originalColor: CGColor?

        init(color: NSColor) { self.color = color }
    }
    let configuration: NavigationConfiguration
    let referenceRect: CGRect
    let interpolator: ViewPropertyInterpolator

    /// The page that travels the full width: the one arriving on a push, the one leaving on a pop.
    /// The edge shadow rides with it.
    var topView: NSView {
        operation == .push ? destinationView : sourceView
    }

    @MainActor
    init(
        operation: Operation,
        containerView: NSView,
        sourceView: NSView,
        destinationView: NSView,
        configuration: NavigationConfiguration
    ) {
        self.operation = operation
        self.containerView = containerView
        self.sourceView = sourceView
        self.destinationView = destinationView
        self.configuration = configuration
        dimmingView = NavigationDimmingView(color: configuration.dimmingColor)

        let referenceRect = NavigationTransitionGeometry.referenceRect(
            containerBounds: containerView.bounds,
            contentInsets: configuration.contentInsets,
            isFlipped: containerView.isFlipped
        )
        self.referenceRect = referenceRect

        let layoutDirection = containerView.userInterfaceLayoutDirection
        let offscreenRect = NavigationTransitionGeometry.offscreenRect(
            referenceRect: referenceRect,
            layoutDirection: layoutDirection
        )
        let parallaxRect = NavigationTransitionGeometry.parallaxRect(
            referenceRect: referenceRect,
            parallaxFactor: configuration.parallaxFactor,
            layoutDirection: layoutDirection
        )

        let curve = configuration.timing.curve
        var interpolator = ViewPropertyInterpolator(curve: curve)

        // Where each page starts and ends. The one travelling the full width is the arriving page
        // on a push and the leaving page on a pop; the other one only takes the parallax offset.
        let sourceStartRect: CGRect
        let sourceEndRect: CGRect
        let destinationStartRect: CGRect
        let destinationEndRect: CGRect
        let topViewStartRect: CGRect
        let topViewEndRect: CGRect
        switch operation {
        case .push:
            (sourceStartRect, sourceEndRect) = (referenceRect, parallaxRect)
            (destinationStartRect, destinationEndRect) = (offscreenRect, referenceRect)
            (topViewStartRect, topViewEndRect) = (destinationStartRect, destinationEndRect)
            interpolator.append(alphaTransformation(for: dimmingView, from: 0, to: 1, curve: curve))
        case .pop:
            (sourceStartRect, sourceEndRect) = (referenceRect, offscreenRect)
            (destinationStartRect, destinationEndRect) = (parallaxRect, referenceRect)
            (topViewStartRect, topViewEndRect) = (sourceStartRect, sourceEndRect)
            interpolator.append(alphaTransformation(for: dimmingView, from: 1, to: 0, curve: curve))
        }
        interpolator.append(frameTransformation(for: sourceView, from: sourceStartRect, to: sourceEndRect, curve: curve))
        interpolator.append(frameTransformation(for: destinationView, from: destinationStartRect, to: destinationEndRect, curve: curve))

        // The page running the full-width slide is the one that gets a background: the arriving
        // page on a push, the leaving page on a pop. It is the page whose motion the eye follows,
        // and the one that has to look solid so the page behind it does not read through. The other
        // page keeps none.
        switch operation {
        case .push:
            pageBackdropView = Self.makePageBackdrop(for: destinationView, configuration: configuration)
            leavingPageBackground = nil
            if let pageBackdropView {
                interpolator.append(frameTransformation(
                    for: pageBackdropView, from: topViewStartRect, to: topViewEndRect, curve: curve
                ))
            }
        case .pop:
            pageBackdropView = nil
            leavingPageBackground = Self.makeLeavingPageBackground(for: sourceView, configuration: configuration)
        }

        if configuration.edgeShadowWidth > 0 {
            let edgeShadowView = NavigationEdgeShadowView(
                shadowWidth: configuration.edgeShadowWidth,
                darkEdge: NavigationTransitionGeometry.edgeShadowDarkEdge(for: layoutDirection)
            )
            self.edgeShadowView = edgeShadowView
            // The strip hugs the travelling page's leading edge, so it moves with it, and fades
            // out over the transition in both directions the way UIKit's does.
            interpolator.append(frameTransformation(
                for: edgeShadowView,
                from: NavigationTransitionGeometry.edgeShadowRect(
                    alongsideTopViewRect: topViewStartRect,
                    edgeShadowWidth: configuration.edgeShadowWidth,
                    layoutDirection: layoutDirection
                ),
                to: NavigationTransitionGeometry.edgeShadowRect(
                    alongsideTopViewRect: topViewEndRect,
                    edgeShadowWidth: configuration.edgeShadowWidth,
                    layoutDirection: layoutDirection
                ),
                curve: curve
            ))
            interpolator.append(alphaTransformation(for: edgeShadowView, from: 1, to: 0, curve: curve))
        } else {
            edgeShadowView = nil
        }

        self.interpolator = interpolator
    }

    @MainActor
    func prepare() {
        sourceView.wantsLayer = true
        destinationView.wantsLayer = true
        dimmingView.wantsLayer = true
        dimmingView.frame = referenceRect

        switch operation {
        case .push:
            // Bottom to top: outgoing view, dimming, incoming view. Only the view leaving is dimmed.
            containerView.addSubview(destinationView)
            containerView.addSubview(dimmingView, positioned: .below, relativeTo: destinationView)
        case .pop:
            // Bottom to top: the view being uncovered, dimming, outgoing view.
            containerView.addSubview(destinationView, positioned: .below, relativeTo: sourceView)
            containerView.addSubview(dimmingView, positioned: .above, relativeTo: destinationView)
        }

        // Directly under the page it trails, so it darkens what that page is about to cover.
        if let edgeShadowView {
            edgeShadowView.wantsLayer = true
            containerView.addSubview(edgeShadowView, positioned: .below, relativeTo: topView)
        }

        // Immediately under the page it stands in for, so it hides whatever that page covers —
        // which is what an opaque page would have done itself.
        if let pageBackdropView {
            pageBackdropView.wantsLayer = true
            containerView.addSubview(pageBackdropView, positioned: .below, relativeTo: topView)
        }

        // A pop writes onto the page instead. `wantsLayer` is on by now, so the layer exists.
        if let leavingPageBackground {
            leavingPageBackground.originalColor = sourceView.layer?.backgroundColor
            sourceView.layer?.backgroundColor = leavingPageBackground.color.cgColor
        }

        apply(0)
    }

    @MainActor
    func apply(_ fraction: CGFloat) {
        interpolator.apply(fraction)
    }

    @MainActor
    func cleanUp(isFinished: Bool) {
        dimmingView.removeFromSuperview()
        edgeShadowView?.removeFromSuperview()
        pageBackdropView?.removeFromSuperview()

        if let leavingPageBackground {
            sourceView.layer?.backgroundColor = leavingPageBackground.originalColor
            // The page may repaint its own background in `updateLayer()`; ask for that pass now so
            // it lands on the restored value rather than whenever something else happens to redraw.
            sourceView.needsDisplay = true
        }
        // Whichever view is not staying goes; both frames are put back so a view that gets
        // reused later does not start life carrying a parallax offset.
        if isFinished {
            sourceView.removeFromSuperview()
        } else {
            destinationView.removeFromSuperview()
        }
        sourceView.frame = referenceRect
        destinationView.frame = referenceRect
    }

    /// Builds the stand-in background for `page`, or `nil` when it needs none.
    @MainActor
    static func makePageBackdrop(
        for page: NSView,
        configuration: NavigationConfiguration
    ) -> NSView? {
        switch configuration.pageBackdrop {
        case .none:
            return nil
        case .automatic:
            guard isSeeThrough(page) else { return nil }
            return NavigationDimmingView(color: .windowBackgroundColor)
        case let .color(color):
            return NavigationDimmingView(color: color)
        case let .view(makeView):
            return makeView()
        }
    }

    /// The colour a pop writes onto the leaving page, or `nil` when it needs none.
    @MainActor
    static func makeLeavingPageBackground(
        for leavingPage: NSView,
        configuration: NavigationConfiguration
    ) -> LeavingPageBackground? {
        switch configuration.pageBackdrop {
        case .none:
            return nil
        case .automatic:
            guard isSeeThrough(leavingPage) else { return nil }
            return LeavingPageBackground(color: .windowBackgroundColor)
        case let .color(color):
            return LeavingPageBackground(color: color)
        case .view:
            // A host-built view cannot be written onto a page; fall back to the standard fill.
            guard isSeeThrough(leavingPage) else { return nil }
            return LeavingPageBackground(color: .windowBackgroundColor)
        }
    }

    /// Whether a page would let the one underneath show through it.
    ///
    /// Read before ``prepare()`` turns layer backing on, so a page with no layer at all counts as
    /// see-through — it certainly has no layer background. A page that paints an opaque background
    /// in `draw(_:)` also counts, and gets a backdrop it then completely hides.
    private static func isSeeThrough(_ view: NSView) -> Bool {
        if view.isOpaque { return false }
        guard let backgroundColor = view.layer?.backgroundColor else { return true }
        return backgroundColor.alpha < 1
    }
}

@MainActor
private func frameTransformation(
    for view: NSView,
    from fromRect: CGRect,
    to toRect: CGRect,
    curve: TimingCurve
) -> KeyPathTransformation<NSView, CGRect> {
    KeyPathTransformation(
        target: view,
        property: \NSView.frame,
        interpolator: Interpolator(fromValue: fromRect, toValue: toRect, curve: curve)
    )
}

@MainActor
private func alphaTransformation(
    for view: NSView,
    from fromAlpha: CGFloat,
    to toAlpha: CGFloat,
    curve: TimingCurve
) -> KeyPathTransformation<NSView, CGFloat> {
    KeyPathTransformation(
        target: view,
        property: \NSView.alphaValue,
        interpolator: Interpolator(fromValue: fromAlpha, toValue: toAlpha, curve: curve)
    )
}

/// The incoming view slides in from the trailing edge over the full container width while the
/// outgoing view drifts the other way by ``NavigationConfiguration/parallaxFactor`` of that
/// width, darkening as it goes.
public struct PushViewTransition: InteractiveViewTransition {
    let core: NavigationParallaxTransitionCore

    public init(
        containerView: NSView,
        sourceView: NSView,
        destinationView: NSView,
        configuration: NavigationConfiguration = .default
    ) {
        core = NavigationParallaxTransitionCore(
            operation: .push,
            containerView: containerView,
            sourceView: sourceView,
            destinationView: destinationView,
            configuration: configuration
        )
    }

    public var containerView: NSView { core.containerView }
    public var sourceView: NSView { core.sourceView }
    public var destinationView: NSView { core.destinationView }
    /// The layer laid over the outgoing view. Exposed so a custom transition can build on it.
    public var dimmingView: NSView { core.dimmingView }
    /// The soft strip trailing the incoming view's leading edge, or `nil` when
    /// ``NavigationConfiguration/edgeShadowWidth`` is zero.
    public var edgeShadowView: NSView? { core.edgeShadowView }
    /// The stand-in background under the arriving view, or `nil` when it needs none.
    public var pageBackdropView: NSView? { core.pageBackdropView }
    public var timing: AnimationTiming { core.configuration.timing }

    public func prepare() { core.prepare() }
    public func apply(_ fraction: CGFloat) { core.apply(fraction) }
    public func cleanUp(isFinished: Bool) { core.cleanUp(isFinished: isFinished) }
}

/// ``PushViewTransition`` run backwards: the top view slides out past the trailing edge while the
/// one underneath returns from its parallax offset and its dimming lifts.
public struct PopViewTransition: InteractiveViewTransition {
    let core: NavigationParallaxTransitionCore

    public init(
        containerView: NSView,
        sourceView: NSView,
        destinationView: NSView,
        configuration: NavigationConfiguration = .default
    ) {
        core = NavigationParallaxTransitionCore(
            operation: .pop,
            containerView: containerView,
            sourceView: sourceView,
            destinationView: destinationView,
            configuration: configuration
        )
    }

    public var containerView: NSView { core.containerView }
    public var sourceView: NSView { core.sourceView }
    public var destinationView: NSView { core.destinationView }
    /// The layer laid over the returning view. Exposed so a custom transition can build on it.
    public var dimmingView: NSView { core.dimmingView }
    /// The soft strip trailing the outgoing view's leading edge, or `nil` when
    /// ``NavigationConfiguration/edgeShadowWidth`` is zero.
    public var edgeShadowView: NSView? { core.edgeShadowView }
    /// Always `nil`: a pop writes the background onto the outgoing view itself and restores it
    /// afterwards, rather than sliding a view underneath.
    public var pageBackdropView: NSView? { core.pageBackdropView }
    public var timing: AnimationTiming { core.configuration.timing }

    public func prepare() { core.prepare() }
    public func apply(_ fraction: CGFloat) { core.apply(fraction) }
    public func cleanUp(isFinished: Bool) { core.cleanUp(isFinished: isFinished) }
}

#endif
