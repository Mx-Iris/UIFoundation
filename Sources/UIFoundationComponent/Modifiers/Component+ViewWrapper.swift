extension Component {
    #if canImport(AppKit) && !targetEnvironment(macCatalyst)
    /// Wraps the component in a view.
    ///
    /// - Note: This hands back ``ComponentView`` rather than a plain `NSView`,
    ///   because the wrapper's content is rendered through
    ///   `reloadWithExisting(component:renderNode:)` -- a path that does not go
    ///   through `reloadData()` and therefore never installs the flipped
    ///   container an unflipped host would need. A plain `NSView` wrapper
    ///   renders its content outside the visible frame and shows nothing at
    ///   all, with no error. UIKit needs no such distinction.
    public func view() -> ViewWrapperComponent<ComponentView> {
        ViewWrapperComponent(component: self)
    }
    #else
    /// Wraps the component in a `NSUIView`.
    /// - Returns: A `ViewWrapperComponent` that renders the component within a NSUIView.
    public func view() -> ViewWrapperComponent<NSUIView> {
        ViewWrapperComponent(component: self)
    }
    #endif

    /// Wraps the component in a `View`.
    /// - Parameter viewType: The type of view to use as the wrapper.
    /// - Returns: A `ViewWrapperComponent` that renders the component within a `View`.
    public func view<View: NSUIView>(as viewType: View.Type) -> ViewWrapperComponent<View> {
        ViewWrapperComponent(component: self)
    }

    #if canImport(AppKit) && !targetEnvironment(macCatalyst)
    /// Wraps the component in a scrolling container.
    ///
    /// - Note: This hands back ``ComponentScrollView`` rather than a bare
    ///   `NSScrollView`. A plain one cannot host a component tree at all --
    ///   `NSScrollView` scrolls a document view and owns its own subviews, so
    ///   the rendered views would sit there without scrolling. UIKit needs no
    ///   such distinction, which is why the two platforms differ here.
    public func scrollView() -> ViewWrapperComponent<ComponentScrollView> {
        ViewWrapperComponent(component: self)
    }
    #else
    /// Wraps the component in a `NSUIScrollView`.
    /// - Returns: A `ViewWrapperComponent` that renders the component within a `NSUIScrollView`.
    public func scrollView() -> ViewWrapperComponent<NSUIScrollView> {
        ViewWrapperComponent(component: self)
    }
    #endif

    /// Wraps the component in a `NSUIVisualEffectView`.
    public func visualEffectView() -> ViewWrapperComponent<NSUIVisualEffectView> {
        ViewWrapperComponent<NSUIVisualEffectView>(component: self)
    }
}
