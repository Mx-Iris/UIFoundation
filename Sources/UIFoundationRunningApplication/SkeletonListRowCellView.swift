#if RunningApplication && os(macOS)

import AppKit
import UIFoundationAppKit

/// Placeholder cell for the list style: an icon square with two stacked text bars,
/// mirroring the shape of ``ListRowTableCellView``.
///
/// The list style has a single full-width column, so unlike the table style its skeleton
/// cannot be one placeholder per column. The two text bars stand in for column indices 0
/// and 1 when reading ``SkeletonAppearance``, which is what lets the whole existing set of
/// shimmer and width tuning apply here unchanged — no skeleton API had to grow for this.
@available(macOS 11.0, *)
final class SkeletonListRowCellView: TableCellView {
    var skeletonAppearance: SkeletonAppearance = .init() {
        didSet {
            for placeholder in placeholders {
                placeholder.applyAppearance(skeletonAppearance)
            }
            applyCornerRadii()
            needsLayout = true
        }
    }

    var iconSize: CGFloat = 22 {
        didSet {
            guard iconSize != oldValue else { return }
            needsLayout = true
        }
    }

    var showsIcon: Bool = true {
        didSet {
            guard showsIcon != oldValue else { return }
            iconPlaceholder.isHidden = !showsIcon
            needsLayout = true
        }
    }

    /// Width of the title bar as a fraction of the available text width.
    var titleWidthFraction: CGFloat = 0.42 {
        didSet {
            guard titleWidthFraction != oldValue else { return }
            needsLayout = true
        }
    }

    /// Width of the subtitle bar. Wider than the title by default, because a subtitle
    /// carries a PID, an architecture and a path.
    var subtitleWidthFraction: CGFloat = 0.78 {
        didSet {
            guard subtitleWidthFraction != oldValue else { return }
            needsLayout = true
        }
    }

    private let iconPlaceholder = SkeletonPlaceholderView()
    private let titlePlaceholder = SkeletonPlaceholderView()
    private let subtitlePlaceholder = SkeletonPlaceholderView()

    private var placeholders: [SkeletonPlaceholderView] {
        [iconPlaceholder, titlePlaceholder, subtitlePlaceholder]
    }

    override func setup() {
        super.setup()
        for placeholder in placeholders {
            addSubview(placeholder)
            placeholder.applyAppearance(skeletonAppearance)
        }
        applyCornerRadii()
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        stopAnimating()
    }

    override func layout() {
        super.layout()

        let leadingInset = skeletonAppearance.textBarLeadingInset
        let trailingInset = skeletonAppearance.textBarTrailingInset
        let barHeight = skeletonAppearance.textBarHeight

        var textLeading = leadingInset
        if showsIcon {
            iconPlaceholder.frame = .init(
                x: leadingInset,
                y: (bounds.height - iconSize) / 2 + skeletonAppearance.iconVerticalOffset,
                width: iconSize,
                height: iconSize
            )
            textLeading = leadingInset + iconSize + 8
        } else {
            iconPlaceholder.frame = .zero
        }

        let availableWidth = max(0, bounds.width - textLeading - trailingInset)
        // Two bars plus the gap between them, centred as a block on the row.
        let barGap: CGFloat = 5
        let blockHeight = barHeight * 2 + barGap
        let blockTop = (bounds.height - blockHeight) / 2 + skeletonAppearance.textBarVerticalOffset

        titlePlaceholder.frame = .init(
            x: textLeading,
            y: blockTop,
            width: availableWidth * titleWidthFraction,
            height: barHeight
        )
        subtitlePlaceholder.frame = .init(
            x: textLeading,
            y: blockTop + barHeight + barGap,
            width: availableWidth * subtitleWidthFraction,
            height: barHeight
        )
    }

    /// - Parameters:
    ///   - iconPhase: shimmer offset for the icon square.
    ///   - titlePhase: shimmer offset for the title bar — column index 0.
    ///   - subtitlePhase: shimmer offset for the subtitle bar — column index 1.
    func startAnimating(iconPhase: CFTimeInterval, titlePhase: CFTimeInterval, subtitlePhase: CFTimeInterval) {
        iconPlaceholder.startAnimating(offset: iconPhase)
        titlePlaceholder.startAnimating(offset: titlePhase)
        subtitlePlaceholder.startAnimating(offset: subtitlePhase)
    }

    func stopAnimating() {
        for placeholder in placeholders {
            placeholder.stopAnimating()
        }
    }

    private func applyCornerRadii() {
        iconPlaceholder.cornerRadius = skeletonAppearance.iconCornerRadius
        titlePlaceholder.cornerRadius = skeletonAppearance.textCornerRadius
        subtitlePlaceholder.cornerRadius = skeletonAppearance.textCornerRadius
    }
}

#endif
