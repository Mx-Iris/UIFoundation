//  Created by Luke Zhao on 2016-02-12.

/// A helper protocol that provides easier access to the underlying component engine's methods
public protocol ComponentDisplayableView: NSUIView {
    /// The engine that actually renders this view's component.
    ///
    /// Defaults to the view's own engine, which is what every host wants on
    /// UIKit and what `ComponentView` wants on both platforms. AppKit's
    /// `ComponentScrollView` overrides it to point at its document view:
    /// `NSScrollView` cannot host rendered subviews itself, so its engine lives
    /// one level down.
    var renderingEngine: ComponentEngine { get }
}

extension ComponentDisplayableView {
    public var renderingEngine: ComponentEngine { componentEngine }
}

/// Extension to provide easier access to the underlying component engine's methods
extension ComponentDisplayableView {

    /// The component to be rendered by this component displayable view.
    public var component: (any Component)? {
        get { renderingEngine.component }
        set { renderingEngine.component = newValue }
    }

    /// The default animator for the component being rendered by this view.
    public var animator: Animator {
        get { renderingEngine.animator }
        set { renderingEngine.animator = newValue }
    }

    /// The axes where a bounds size change should trigger a reload.
    public var reloadOnSizeChangeAxes: ComponentEngine.ReloadAxis {
        get { renderingEngine.reloadOnSizeChangeAxes }
        set { renderingEngine.reloadOnSizeChangeAxes = newValue }
    }

    /// A closure that is called after the first reload.
    public var onFirstReload: ((NSUIView) -> Void)? {
        get { renderingEngine.onFirstReload }
        set { renderingEngine.onFirstReload = newValue }
    }

    /// The render node associated with the current component.
    public var renderNode: (any RenderNode)? {
        renderingEngine.renderNode
    }

    /// The visible frame insets that are applied to the viewport before fetching the views from the renderNode.
    public var visibleFrameInsets: NSUIEdgeInsets {
        get { renderingEngine.visibleFrameInsets }
        set { renderingEngine.visibleFrameInsets = newValue }
    }

    /// The number of times this view has reloaded.
    public var reloadCount: Int {
        renderingEngine.reloadCount
    }

    /// A Boolean value indicating whether this view is scheduled to reload during the next layout cycle.
    public var needsReload: Bool {
        renderingEngine.needsReload
    }

    /// A Boolean value indicating whether this view is scheduled to render during the next layout cycle.
    public var needsRender: Bool {
        renderingEngine.needsRender
    }

    /// A Boolean value indicating whether this view is currently reloading.
    public var isReloading: Bool {
        renderingEngine.isReloading
    }

    /// A Boolean value indicating whether this view is currently rendering.
    public var isRendering: Bool {
        renderingEngine.isRendering
    }

    /// A Boolean value indicating whether this view has reloaded at least once.
    public var hasReloaded: Bool { reloadCount > 0 }

    /// The views that are currently visible and being rendered by this view.
    public var visibleViews: [NSUIView] {
        renderingEngine.visibleViews
    }

    /// The renderables that are currently visible and being rendered by this view.
    public var visibleRenderable: [Renderable] {
        renderingEngine.visibleRenderables
    }

    /// The bounds of this view when the last render occurred.
    public var lastRenderBounds: CGRect {
        renderingEngine.lastRenderBounds
    }

    /// The content offset changes since the last reload.
    public var contentOffsetDelta: CGPoint {
        renderingEngine.contentOffsetDelta
    }

    /// Marks this view as needing a reload.
    public func setNeedsReload() {
        renderingEngine.setNeedsReload()
    }

    /// Marks this view as needing a render.
    public func setNeedsRender() {
        renderingEngine.setNeedsRender()
    }

    /// Ensures that the zoom view is centered.
    public func ensureZoomViewIsCentered() {
        renderingEngine.ensureZoomViewIsCentered()
    }

    /// Reloads the data and optionally adjusts the content offset.
    public func reloadData(contentOffsetAdjustFn: (() -> CGPoint)? = nil) {
        renderingEngine.reloadData(contentOffsetAdjustFn: contentOffsetAdjustFn)
    }

    /// Returns the view at a given point if it exists within the visible views.
    public func view(at point: CGPoint) -> NSUIView? {
        renderingEngine.view(at: point)
    }

    /// Returns the frame associated with a given identifier if it exists within the render node.
    public func frame(id: String) -> CGRect? {
        renderingEngine.frame(id: id)
    }

    /// Returns the visible view associated with a given identifier if it exists within the visible renderables.
    public func visibleView(id: String) -> NSUIView? {
        renderingEngine.visibleView(id: id)
    }
}

extension ComponentDisplayableView where Self: NSUIScrollView {
    public var contentView: NSUIView? {
        get { renderingEngine.contentView }
        set { renderingEngine.contentView = newValue }
    }

    @discardableResult public func scrollTo(id: String, animated: Bool) -> Bool {
        renderingEngine.scrollTo(id: id, animated: animated)
    }
}
