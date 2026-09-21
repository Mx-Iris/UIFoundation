extension Component {
    /// Wraps the component in a `NSUIView`.
    /// - Returns: A `ViewWrapperComponent` that renders the component within a NSUIView.
    public func view() -> ViewWrapperComponent<NSUIView> {
        ViewWrapperComponent(component: self)
    }

    /// Wraps the component in a `View`.
    /// - Parameter viewType: The type of view to use as the wrapper.
    /// - Returns: A `ViewWrapperComponent` that renders the component within a `View`.
    public func view<View: NSUIView>(as viewType: View.Type) -> ViewWrapperComponent<View> {
        ViewWrapperComponent(component: self)
    }

    /// Wraps the component in a `NSUIScrollView`.
    /// - Returns: A `ViewWrapperComponent` that renders the component within a `NSUIScrollView`.
    public func scrollView() -> ViewWrapperComponent<NSUIScrollView> {
        ViewWrapperComponent(component: self)
    }

    /// Wraps the component in a `NSUIVisualEffectView`.
    public func visualEffectView() -> ViewWrapperComponent<NSUIVisualEffectView> {
        ViewWrapperComponent<NSUIVisualEffectView>(component: self)
    }
}
