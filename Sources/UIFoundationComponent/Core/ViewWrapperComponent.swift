//  Created by Luke Zhao on 8/23/20.

/// Wraps a `component` inside a `NSUIView`.
///
/// This is used to power the `.view()` and `.scrollView()` modifiers.
public struct ViewWrapperComponent<View: NSUIView>: Component {
    let component: any Component
    public init(component: any Component) {
        self.component = component
    }
    public func layout(_ constraint: Constraint) -> ViewWrapperRenderNode<View> {
        let renderNode = component.layout(constraint)
        return ViewWrapperRenderNode(size: renderNode.size.bound(to: constraint),
                                     component: component,
                                     content: renderNode)
    }
}

/// RenderNode for the `ViewWrapperComponent`
public struct ViewWrapperRenderNode<View: NSUIView>: RenderNode {
    public let size: CGSize
    public let component: any Component
    public let content: any RenderNode

    public func updateView(_ view: View) {
        if let view = view as? ViewWrapperComponentView {
            view.contentComponentEngine.reloadWithExisting(component: component, renderNode: content)
        } else {
            view.componentEngine.reloadWithExisting(component: component, renderNode: content)
        }
    }

    public func contextValue(_ key: RenderNodeContextKey) -> Any? {
        content.contextValue(key)
    }
}

public protocol ViewWrapperComponentView: NSUIView {
    var contentComponentEngine: ComponentEngine { get }
}

#if canImport(AppKit) && !targetEnvironment(macCatalyst)
// NSVisualEffectView has no `contentView` of its own -- subviews are added
// directly to it, so the engine hosts on the effect view itself.
extension NSVisualEffectView: ViewWrapperComponentView {
    public var contentComponentEngine: ComponentEngine {
        componentEngine
    }
}

// `NSScrollView` scrolls a *document view*; anything added to the scroll view
// itself neither scrolls nor reliably stays visible, because AppKit owns that
// subview list (clip view, scrollers). So the wrapper has to reach the document
// view's engine -- which is exactly what `renderingEngine` answers.
//
// Without this conformance `.scrollView()` compiles, renders, and silently
// produces a non-scrolling pile of views.
extension ComponentScrollView: ViewWrapperComponentView {
    public var contentComponentEngine: ComponentEngine {
        renderingEngine
    }
}
#endif

#if canImport(UIKit)
extension UIVisualEffectView: ViewWrapperComponentView {
    public var contentComponentEngine: ComponentEngine {
        contentView.componentEngine
    }
}
#endif
