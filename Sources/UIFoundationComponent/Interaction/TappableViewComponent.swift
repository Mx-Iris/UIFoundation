//
//  TappableViewComponent.swift
//  UIFoundation
//
//  Ported from lkzhao/UIComponent (created by Luke Zhao on 1/18/24).
//

/// A component that wraps its content in a ``TappableView``.
///
/// Created through ``Component/tappableView(_:)``; there is rarely a reason to
/// build one directly.
public struct TappableViewComponent: Component {
    /// Behaviour inherited from the component tree's environment.
    @Environment(\.tappableViewConfig)
    public var config: TappableViewConfig

    /// The component being made tappable.
    public let component: any Component

    /// Called when the view is clicked (tapped on UIKit).
    public let onTap: ((TappableView) -> Void)?

    /// - Parameters:
    ///   - component: The component to make tappable.
    ///   - onTap: Called on a click.
    public init(component: any Component, onTap: ((TappableView) -> Void)? = nil) {
        self.component = component
        self.onTap = onTap
    }

    public func layout(_ constraint: Constraint) -> TappableViewRenderNode {
        let renderNode = component.layout(constraint)
        return TappableViewRenderNode(
            size: renderNode.size.bound(to: constraint),
            component: component,
            content: renderNode,
            onTap: onTap,
            config: config
        )
    }
}

/// The render node backing a ``TappableViewComponent``.
public struct TappableViewRenderNode: RenderNode {
    /// The size of the render node.
    public let size: CGSize

    /// The component being rendered inside the tappable view.
    public let component: any Component

    /// The laid-out content.
    public let content: any RenderNode

    /// Called when the view is clicked (tapped on UIKit).
    public let onTap: ((TappableView) -> Void)?

    /// The behaviour resolved from the environment at layout time.
    public let config: TappableViewConfig?

    /// Hands the content to the view's own engine.
    ///
    /// The tappable view is a component host in its own right, which is why it
    /// is flipped on AppKit -- see ``TappableView``.
    public func updateView(_ view: TappableView) {
        view.config = config
        view.onTap = onTap
        view.componentEngine.reloadWithExisting(component: component, renderNode: content)
    }

    /// Forwards every context value to the content.
    ///
    /// The wrapper is transparent to `id`, `reuseKey` and `animator`: wrapping a
    /// component in a tappable view must not change how the engine diffs or
    /// recycles it.
    public func contextValue(_ key: RenderNodeContextKey) -> Any? {
        content.contextValue(key)
    }
}

// MARK: - Environment

/// The environment key holding the ``TappableViewConfig`` in force.
public struct TappableViewConfigEnvironmentKey: EnvironmentKey {
    public static var defaultValue: TappableViewConfig {
        get { TappableViewConfig.default }
        set { TappableViewConfig.default = newValue }
    }
}

extension EnvironmentValues {
    /// The ``TappableViewConfig`` in force for this part of the component tree.
    ///
    /// Unset, this reads and writes ``TappableViewConfig/default``.
    public var tappableViewConfig: TappableViewConfig {
        get { self[TappableViewConfigEnvironmentKey.self] }
        set { self[TappableViewConfigEnvironmentKey.self] = newValue }
    }
}

extension Component {
    /// Scopes a ``TappableViewConfig`` to this subtree.
    ///
    /// - Parameter tappableViewConfig: The configuration every ``TappableView``
    ///   below this point inherits, unless it carries one of its own.
    public func tappableViewConfig(_ tappableViewConfig: TappableViewConfig) -> EnvironmentComponent<TappableViewConfig, Self> {
        environment(\.tappableViewConfig, value: tappableViewConfig)
    }
}
