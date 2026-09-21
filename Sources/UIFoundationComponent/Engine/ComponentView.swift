//
//  ComponentView.swift
//  UIFoundation
//
//  Ported from lkzhao/UIComponent (created by Luke Zhao on 8/27/20), with the
//  AppKit hosts added.
//

#if canImport(AppKit) && !targetEnvironment(macCatalyst)

/// A view that renders components.
///
/// Set ``component`` with your component tree and it renders on the next layout
/// pass; call ``reloadData()`` to force one.
///
/// Most of the API lives on ``ComponentDisplayableView``.
///
/// **Why this class exists on AppKit rather than just any `NSView`**: the layout
/// system places children from the top-left downwards, which is only what
/// AppKit draws if the view is flipped. `NSView` is not, by default. Using this
/// class is the direct path; if you attach ``componentEngine`` to an unflipped
/// view of your own, the engine inserts a flipped container of its own to
/// render into.
open class ComponentView: NSView, ComponentDisplayableView {
    open override var isFlipped: Bool { true }
}

/// A scroll view that renders components.
///
/// **Structurally different from the UIKit version.** `NSScrollView` scrolls a
/// *document view* rather than scrolling itself, and the rendered subviews have
/// to live inside that document view. So this class owns a flipped
/// ``componentDocumentView`` and points ``renderingEngine`` at it. Setting
/// ``component`` on the scroll view does the right thing.
///
/// - Important: Do not reach for `componentEngine` on this class. That property
///   is `NSView`'s, so it hands back an engine attached to the scroll view
///   itself, which renders nothing -- `NSScrollView` manages its own subviews.
///   Use ``component`` and the other ``ComponentDisplayableView`` members, or
///   ``componentDocumentView`` directly.
open class ComponentScrollView: NSScrollView, ComponentDisplayableView {
    /// The flipped document view the component actually renders into.
    public let componentDocumentView: ComponentView

    public var renderingEngine: ComponentEngine {
        componentDocumentView.componentEngine
    }

    public override init(frame frameRect: NSRect) {
        componentDocumentView = ComponentView()
        super.init(frame: frameRect)
        setUpComponentDocumentView()
    }

    public required init?(coder: NSCoder) {
        componentDocumentView = ComponentView()
        super.init(coder: coder)
        setUpComponentDocumentView()
    }

    private func setUpComponentDocumentView() {
        componentDocumentView.frame = CGRect(origin: .zero, size: contentSize)
        documentView = componentDocumentView
    }
}

#else

/// A `NSUIView` that can render components.
/// It provides simple access to the properties and method of the underlying ``ComponentEngine``
///
/// You can set the ``component`` property with your component tree for it to render
/// The render happens on the next layout cycle. But you can call ``reloadData`` to force it to render.
///
/// Most of the code is written in ``ComponentDisplayableView``, since both ``ComponentView``
/// and ``ComponentScrollView`` supports rendering components.
///
/// See ``ComponentDisplayableView`` for usage details.
open class ComponentView: NSUIView, ComponentDisplayableView {
}

/// A `NSUIScrollView` that can render components
/// It provides simple access to the properties and method of the underlying ``ComponentEngine``
///
/// You can set the ``component`` property with your component tree for it to render
/// The render happens on the next layout cycle. But you can call ``reloadData`` to force it to render.
///
/// Most of the code is written in ``ComponentDisplayableView``, since both ``ComponentView``
/// and ``ComponentScrollView`` supports rendering components.
///
/// See ``ComponentDisplayableView`` for usage details.
open class ComponentScrollView: NSUIScrollView, ComponentDisplayableView {
}

#endif
