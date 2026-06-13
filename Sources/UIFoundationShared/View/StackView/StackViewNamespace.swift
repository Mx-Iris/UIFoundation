#if canImport(AppKit) && !targetEnvironment(macCatalyst)
import AppKit
#endif

#if canImport(UIKit)
import UIKit
#endif

import UIFoundationTypealias

/// A namespace for stack-specific per-component modifiers, reached through `view.stackView`.
///
/// Keeping these behind `.stackView` avoids polluting every view's API surface. Each modifier stores
/// its value via an associated object (read back during stack assembly) and returns the underlying
/// view, so a plain view stays usable inside the `HStackView` / `VStackView` builders:
///
/// ```swift
/// HStackView {
///     iconView.stackView.gravity(.leading)
///     titleLabel.stackView.fill()
/// }
/// ```
///
/// General-purpose layout helpers (`size` / `minSize` / `maxSize` / `contentHugging` /
/// `contentCompressionResistance`) live in the `.box` namespace, not here.
public struct StackViewNamespace {
    let base: NSUIView

    init(_ base: NSUIView) {
        self.base = base
    }

    /// Sets a custom spacing after this view in the stack.
    @discardableResult
    public func customSpacing(_ customSpacing: CGFloat) -> NSUIView {
        base._customSpacing = customSpacing
        return base
    }

    /// Pins this view to the stack view's cross-axis edges (top/bottom for horizontal stacks,
    /// leading/trailing for vertical stacks), matching `UIStackView.Alignment.fill` semantics for
    /// a single arranged subview.
    ///
    /// AppKit-side constraints are inset by the stack view's `edgeInsets`.
    /// Avoid combining with a conflicting cross-axis size constraint on the same view.
    @discardableResult
    public func fill() -> NSUIView {
        base._fillsCrossAxis = true
        return base
    }

    #if canImport(AppKit) && !targetEnvironment(macCatalyst)
    /// Sets the gravity area this view is added to in an `NSStackView`.
    @discardableResult
    public func gravity(_ gravity: NSStackView.Gravity) -> NSUIView {
        base._gravity = gravity
        return base
    }

    /// Sets the visibility priority used when the `NSStackView` detaches views under pressure.
    @discardableResult
    public func visibilityPriority(_ visibilityPriority: NSStackView.VisibilityPriority) -> NSUIView {
        base._visibilityPriority = visibilityPriority
        return base
    }
    #endif
}

extension NSUIView {
    /// The stack-component modifier namespace for this view (e.g. `view.stackView.fill()`).
    public var stackView: StackViewNamespace {
        StackViewNamespace(self)
    }
}
