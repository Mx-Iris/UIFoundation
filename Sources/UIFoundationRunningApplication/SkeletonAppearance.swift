#if RunningApplication && os(macOS)

import AppKit

// MARK: - SkeletonAppearance

/// Tunable knobs for the loading skeleton's colors, shapes, sizes, and shimmer.
/// All properties have sensible defaults; override individual fields to nudge
/// alignment, contrast, or animation feel.
public struct SkeletonAppearance {
    /// How the icon-style placeholder picks its width/height.
    public enum IconSizeMode {
        /// Fill the row height exactly — matches `IconTableCellView`.
        case fillCellHeight
        /// Use a fixed point size.
        case fixed(CGFloat)
        /// Use `cellHeight - 2 * inset` (clamped to >= 0).
        case insetBy(CGFloat)

        func size(forCellHeight cellHeight: CGFloat) -> CGFloat {
            switch self {
            case .fillCellHeight: return cellHeight
            case .fixed(let value): return value
            case .insetBy(let inset): return max(0, cellHeight - 2 * inset)
            }
        }
    }

    // Colors
    public var baseColor: NSColor
    public var highlightColor: NSColor

    // Corner radius per style
    public var iconCornerRadius: CGFloat
    public var textCornerRadius: CGFloat

    // Icon-style placeholder geometry
    public var iconSizeMode: IconSizeMode
    /// Positive values move the icon placeholder up, matching AppKit's
    /// unflipped cell coordinates.
    public var iconVerticalOffset: CGFloat

    // Text-style placeholder geometry
    public var textBarHeight: CGFloat
    public var textBarLeadingInset: CGFloat
    public var textBarTrailingInset: CGFloat
    /// Positive values move the text placeholder up, matching AppKit's
    /// unflipped cell coordinates.
    public var textBarVerticalOffset: CGFloat

    /// Width fractions for text-style placeholders. Looked up as
    /// `textBarWidthFractions[rowIndex % rows.count][columnIndex % cols.count]`.
    /// Use a non-uniform pattern to suggest text of varying lengths.
    public var textBarWidthFractions: [[CGFloat]]

    // Shimmer animation
    public var shimmerDuration: TimeInterval
    public var shimmerRowStagger: TimeInterval
    public var shimmerColumnStagger: TimeInterval

    /// Number of placeholder rows to show. When `nil`, the row count is derived
    /// from the table's visible height so the skeleton fills the viewport.
    public var placeholderRowCount: Int?

    public init(
        baseColor: NSColor = NSColor.tertiaryLabelColor.withAlphaComponent(0.32),
        highlightColor: NSColor = NSColor.labelColor.withAlphaComponent(0.14),
        iconCornerRadius: CGFloat = 5,
        textCornerRadius: CGFloat = 3,
        iconSizeMode: IconSizeMode = .fillCellHeight,
        iconVerticalOffset: CGFloat = 0,
        textBarHeight: CGFloat = 10,
        textBarLeadingInset: CGFloat = 0,
        textBarTrailingInset: CGFloat = 0,
        textBarVerticalOffset: CGFloat = 0,
        textBarWidthFractions: [[CGFloat]] = SkeletonAppearance.defaultTextBarWidthFractions,
        shimmerDuration: TimeInterval = 1.4,
        shimmerRowStagger: TimeInterval = 0.08,
        shimmerColumnStagger: TimeInterval = 0.05,
        placeholderRowCount: Int? = nil,
    ) {
        self.baseColor = baseColor
        self.highlightColor = highlightColor
        self.iconCornerRadius = iconCornerRadius
        self.textCornerRadius = textCornerRadius
        self.iconSizeMode = iconSizeMode
        self.iconVerticalOffset = iconVerticalOffset
        self.textBarHeight = textBarHeight
        self.textBarLeadingInset = textBarLeadingInset
        self.textBarTrailingInset = textBarTrailingInset
        self.textBarVerticalOffset = textBarVerticalOffset
        self.textBarWidthFractions = textBarWidthFractions
        self.shimmerDuration = shimmerDuration
        self.shimmerRowStagger = shimmerRowStagger
        self.shimmerColumnStagger = shimmerColumnStagger
        self.placeholderRowCount = placeholderRowCount
    }

    public static let defaultTextBarWidthFractions: [[CGFloat]] = [
        [0.78, 0.55, 0.60, 0.70, 0.50, 0.65],
        [0.60, 0.78, 0.55, 0.65, 0.70, 0.50],
        [0.85, 0.50, 0.72, 0.55, 0.65, 0.75],
        [0.55, 0.82, 0.60, 0.75, 0.50, 0.70],
        [0.70, 0.65, 0.78, 0.50, 0.82, 0.55],
        [0.65, 0.72, 0.55, 0.80, 0.60, 0.68],
    ]

    /// Width fraction for the placeholder at the given grid position.
    func textBarWidthFraction(rowIndex: Int, columnIndex: Int) -> CGFloat {
        guard !textBarWidthFractions.isEmpty else { return 0.7 }
        let fractionRow = textBarWidthFractions[rowIndex % textBarWidthFractions.count]
        guard !fractionRow.isEmpty else { return 0.7 }
        return fractionRow[columnIndex % fractionRow.count]
    }

    /// Shimmer phase offset for the given grid position. Staggering per row and
    /// per column makes the highlight read as a diagonal wave instead of all
    /// placeholders pulsing in unison.
    func shimmerPhaseOffset(rowIndex: Int, columnIndex: Int) -> CFTimeInterval {
        -(Double(rowIndex) * shimmerRowStagger + Double(columnIndex) * shimmerColumnStagger)
    }
}

// MARK: - SkeletonColumnDescriptor

/// Describes how one table column renders while the skeleton is showing.
struct SkeletonColumnDescriptor {
    enum Style {
        case icon
        case text
    }

    var identifier: String
    var style: Style
    var alignment: NSTextAlignment
}

#endif
