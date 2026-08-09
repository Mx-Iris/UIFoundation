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

        // The page travelling the full width, and where it starts and ends.
        let topViewStartRect: CGRect
        let topViewEndRect: CGRect
        switch operation {
        case .push:
            topViewStartRect = offscreenRect
            topViewEndRect = referenceRect
            interpolator.append(frameTransformation(for: sourceView, from: referenceRect, to: parallaxRect, curve: curve))
            interpolator.append(frameTransformation(for: destinationView, from: offscreenRect, to: referenceRect, curve: curve))
            interpolator.append(alphaTransformation(for: dimmingView, from: 0, to: 1, curve: curve))
        case .pop:
            topViewStartRect = referenceRect
            topViewEndRect = offscreenRect
            interpolator.append(frameTransformation(for: sourceView, from: referenceRect, to: offscreenRect, curve: curve))
            interpolator.append(frameTransformation(for: destinationView, from: parallaxRect, to: referenceRect, curve: curve))
            interpolator.append(alphaTransformation(for: dimmingView, from: 1, to: 0, curve: curve))
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
    public var timing: AnimationTiming { core.configuration.timing }

    public func prepare() { core.prepare() }
    public func apply(_ fraction: CGFloat) { core.apply(fraction) }
    public func cleanUp(isFinished: Bool) { core.cleanUp(isFinished: isFinished) }
}

#endif
