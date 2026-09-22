//
//  TappableView+Config.swift
//  UIFoundation
//
//  Ported from lkzhao/UIComponent (created by Luke Zhao on 6/8/21).
//

/// Behaviour shared by every ``TappableView``.
///
/// Set ``default`` once to give an app-wide highlight style, or scope one to a
/// subtree with ``Component/tappableViewConfig(_:)``. A view's own
/// ``TappableView/config`` wins over both.
public struct TappableViewConfig {
    /// The configuration used by any ``TappableView`` that carries none of its own.
    public static var `default`: TappableViewConfig = TappableViewConfig()

    /// Applies the highlight state. Called whenever ``TappableView/isHighlighted`` flips.
    public var onHighlightChanged: ((TappableView, Bool) -> Void)?

    /// Called before the view's own `onTap`, for behaviour every tappable view shares.
    public var didTap: ((TappableView) -> Void)?

    /// - Parameters:
    ///   - onHighlightChanged: Called when the highlight state changes.
    ///   - didTap: Called before the view's own tap handler.
    public init(
        onHighlightChanged: ((TappableView, Bool) -> Void)? = nil,
        didTap: ((TappableView) -> Void)? = nil
    ) {
        self.onHighlightChanged = onHighlightChanged
        self.didTap = didTap
    }
}
