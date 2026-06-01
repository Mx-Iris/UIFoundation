#if canImport(AppKit) && !targetEnvironment(macCatalyst)
import AppKit
#endif

#if canImport(UIKit)
import UIKit
#endif

import UIFoundationTypealias

/// Cross-axis alignment for `HStackView` / `VStackView`, unified across AppKit and UIKit.
///
/// This replaces the old `NSUIStackViewAlignment` typealias, which mapped to
/// `NSLayoutConstraint.Attribute` on AppKit and `UIStackView.Alignment` on UIKit
/// with mismatched semantics — most importantly, AppKit had no `.fill` analogue.
///
/// On AppKit, `.fill` is emulated by clearing `NSStackView.alignment` and adding explicit
/// cross-axis pinning constraints (top+bottom or leading+trailing) to each arranged subview.
/// On UIKit, the value is forwarded directly to `UIStackView.Alignment`.
public enum StackViewAlignment: Hashable, Sendable {
    case fill
    case leading
    case trailing
    case top
    case bottom
    case center
    case firstBaseline
    case lastBaseline
}

extension StackViewAlignment {
    #if canImport(AppKit) && !targetEnvironment(macCatalyst)
    /// AppKit horizontal stack defaults to centerY, vertical to centerX — preserved here.
    public static let defaultValue: Self = .center
    #endif

    #if canImport(UIKit)
    /// UIKit `UIStackView` defaults to `.fill` on both axes — preserved here.
    public static let defaultValue: Self = .fill
    #endif
}

#if canImport(AppKit) && !targetEnvironment(macCatalyst)
extension StackViewAlignment {
    /// Maps to a `NSLayoutConstraint.Attribute` for `NSStackView.alignment`.
    ///
    /// `.fill` and axis-inapplicable cases return `.notAnAttribute`; `.fill` requires
    /// additional per-view pinning constraints, handled at stack assembly time.
    @usableFromInline
    @inlinable
    func attribute(for orientation: NSUserInterfaceLayoutOrientation) -> NSLayoutConstraint.Attribute {
        switch (self, orientation) {
        case (.fill, _):
            return .notAnAttribute
        case (.center, .horizontal):
            return .centerY
        case (.center, .vertical):
            return .centerX
        case (.leading, .vertical):
            return .leading
        case (.trailing, .vertical):
            return .trailing
        case (.top, .horizontal):
            return .top
        case (.bottom, .horizontal):
            return .bottom
        case (.firstBaseline, .horizontal):
            return .firstBaseline
        case (.lastBaseline, .horizontal):
            return .lastBaseline
        case (.leading, .horizontal),
             (.trailing, .horizontal),
             (.top, .vertical),
             (.bottom, .vertical),
             (.firstBaseline, .vertical),
             (.lastBaseline, .vertical):
            return .notAnAttribute
        @unknown default:
            return .notAnAttribute
        }
    }

    /// `true` when the alignment requires cross-axis pinning constraints on each arranged subview.
    @usableFromInline
    @inlinable
    var requiresCrossAxisFill: Bool {
        self == .fill
    }
}
#endif

#if canImport(UIKit)
extension StackViewAlignment {
    /// Maps to a `UIStackView.Alignment` for the given axis.
    ///
    /// `.leading` / `.trailing` are nonsensical on horizontal stacks and fall back to
    /// `.top` / `.bottom`; `.top` / `.bottom` / `.firstBaseline` / `.lastBaseline` are
    /// nonsensical on vertical stacks and fall back to `.leading` / `.trailing` / `.fill`.
    @usableFromInline
    @inlinable
    func uiStackAlignment(for axis: NSLayoutConstraint.Axis) -> UIStackView.Alignment {
        switch (self, axis) {
        case (.fill, _):
            return .fill
        case (.center, _):
            return .center
        case (.leading, .vertical):
            return .leading
        case (.trailing, .vertical):
            return .trailing
        case (.leading, .horizontal):
            return .top
        case (.trailing, .horizontal):
            return .bottom
        case (.top, .horizontal):
            return .top
        case (.bottom, .horizontal):
            return .bottom
        case (.firstBaseline, .horizontal):
            return .firstBaseline
        case (.lastBaseline, .horizontal):
            return .lastBaseline
        case (.top, .vertical),
             (.bottom, .vertical),
             (.firstBaseline, .vertical),
             (.lastBaseline, .vertical):
            return .fill
        @unknown default:
            return .fill
        }
    }
}
#endif
