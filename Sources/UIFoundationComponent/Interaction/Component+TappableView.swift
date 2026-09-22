//
//  Component+TappableView.swift
//  UIFoundation
//
//  Ported from lkzhao/UIComponent.
//
//  Upstream's two `tappableView(configuration:_:)` overloads are deprecated
//  there and are deliberately not ported -- this library never shipped them, so
//  carrying them over would invent a deprecation out of nothing. Use
//  `.tappableView(_:).tappableViewConfig(_:)`.
//

extension Component {
    /// Wraps this component in a ``TappableView``.
    ///
    /// Further behaviour is set through `@dynamicMemberLookup`, which reaches
    /// every writable property on ``TappableView`` directly:
    ///
    /// ```swift
    /// someComponent
    ///     .tappableView { view in print("clicked") }
    ///     .onLongPress { view, recognizer in … }
    ///     .contextMenuProvider { view in NSMenu(…) }
    /// ```
    ///
    /// - Parameter onTap: Called on a click (a tap on UIKit).
    public func tappableView(
        _ onTap: @escaping (TappableView) -> Void
    ) -> TappableViewComponent {
        TappableViewComponent(component: self, onTap: onTap)
    }

    /// Wraps this component in a ``TappableView``.
    ///
    /// - Parameter onTap: Called on a click (a tap on UIKit).
    public func tappableView(
        _ onTap: @escaping () -> Void
    ) -> TappableViewComponent {
        tappableView { _ in onTap() }
    }
}
