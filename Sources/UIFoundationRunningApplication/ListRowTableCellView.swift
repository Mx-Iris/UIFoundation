#if RunningApplication && os(macOS)

import AppKit
import UIFoundationAppKit
import UIFoundationShared
import UIFoundationUtilities

enum ListRowColumn {
    /// Identifier of the single full-width column backing the list style.
    ///
    /// Lives here rather than on the picker because that type is generic, and Swift does
    /// not allow static stored properties in generic types.
    static let identifier = "listRow"
}

/// The single full-width cell backing the list style: an icon, a title with trailing
/// badges, and a subtitle carrying the remaining fields.
///
/// The subtitle truncates in the middle rather than at the tail, because for an executable
/// path the tail is the part worth reading.
final class ListRowTableCellView: TableCellView {
    private let iconImageView = NSImageView()
    private let titleLabel = NSTextField(labelWithString: "")
    private let subtitleLabel = NSTextField(labelWithString: "")

    /// Rebuilt on every `badges` assignment, so it stays an imperative `NSStackView`
    /// rather than a declarative `HStackView`: the latter's content is fixed at init.
    private let badgeStackView = NSStackView()

    // No trailing spacer is needed: a gravity-areas stack does not stretch its arranged
    // subviews, so the title and badge stay packed at the leading edge even though the
    // row itself spans the full width.
    private lazy var titleRowStackView = HStackView(alignment: .center, spacing: 6) {
        titleLabel
        badgeStackView
    }

    private lazy var textStackView = VStackView(alignment: .leading, spacing: 1) {
        titleRowStackView
        subtitleLabel
    }

    private var iconWidthConstraint: NSLayoutConstraint?
    private var iconHeightConstraint: NSLayoutConstraint?
    private var iconLeadingConstraint: NSLayoutConstraint?
    private var textLeadingToIconConstraint: NSLayoutConstraint?
    private var textLeadingToEdgeConstraint: NSLayoutConstraint?

    var iconSize: CGFloat = 22 {
        didSet {
            guard iconSize != oldValue else { return }
            iconWidthConstraint?.constant = iconSize
            iconHeightConstraint?.constant = iconSize
        }
    }

    var image: NSImage? {
        didSet {
            iconImageView.image = image
            updateIconVisibility()
        }
    }

    /// Whether the row reserves space for an icon at all. False when `.icon` is absent
    /// from the configured fields, so the text starts at the leading edge.
    var showsIcon: Bool = true {
        didSet {
            guard showsIcon != oldValue else { return }
            updateIconVisibility()
        }
    }

    var title: String? {
        didSet {
            titleLabel.stringValue = title ?? ""
        }
    }

    var subtitle: String? {
        didSet {
            subtitleLabel.stringValue = subtitle ?? ""
            subtitleLabel.isHidden = (subtitle ?? "").isEmpty
            toolTip = [title, subtitle].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: "\n")
        }
    }

    var badges: [ListRowBadge] = [] {
        didSet {
            guard badges != oldValue else { return }
            rebuildBadges()
        }
    }

    override func setup() {
        super.setup()

        iconImageView.imageScaling = .scaleProportionallyUpOrDown
        addSubview(iconImageView)

        titleLabel.font = .systemFont(ofSize: 13, weight: .medium)
        titleLabel.textColor = .labelColor
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        subtitleLabel.font = .systemFont(ofSize: 11, weight: .regular)
        subtitleLabel.textColor = .secondaryLabelColor
        // The tail of a path is the informative half, so give up the middle instead.
        subtitleLabel.lineBreakMode = .byTruncatingMiddle
        subtitleLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        badgeStackView.orientation = .horizontal
        badgeStackView.spacing = 4
        badgeStackView.alignment = .centerY
        // Hidden up front, not just when badges are cleared: `badges` starts empty, so
        // assigning an empty array is a no-op that never reaches `rebuildBadges`. Left
        // visible, an empty stack view has no way to derive its height, which AppKit
        // reports as ambiguous layout once per badge-less row.
        badgeStackView.isHidden = true
        badgeStackView.setContentCompressionResistancePriority(.required, for: .horizontal)
        badgeStackView.setContentHuggingPriority(.required, for: .horizontal)

        addSubview(textStackView)

        // These five are held onto because `showsIcon` and `iconSize` re-drive them, so
        // they are built explicitly rather than through `makeConstraints`.
        let iconWidth = iconImageView.widthAnchor.constraint(equalToConstant: iconSize)
        let iconHeight = iconImageView.heightAnchor.constraint(equalToConstant: iconSize)
        let iconLeading = iconImageView.leadingAnchor.constraint(equalTo: leadingAnchor)
        let textLeadingToIcon = textStackView.leadingAnchor.constraint(equalTo: iconImageView.trailingAnchor, constant: 8)
        let textLeadingToEdge = textStackView.leadingAnchor.constraint(equalTo: leadingAnchor)
        iconWidthConstraint = iconWidth
        iconHeightConstraint = iconHeight
        iconLeadingConstraint = iconLeading
        textLeadingToIconConstraint = textLeadingToIcon
        textLeadingToEdgeConstraint = textLeadingToEdge

        iconImageView.makeConstraints { make in
            iconLeading
            iconWidth
            iconHeight
            make.centerYAnchor.constraint(equalTo: centerYAnchor)
        }

        textStackView.makeConstraints { make in
            textLeadingToIcon
            // Pinned, not bounded: an upper bound alone lets the stack shrink to its
            // intrinsic width, and the labels -- deliberately low on compression
            // resistance so they truncate rather than push the row wider -- collapse to
            // an ellipsis even when the row is 1500pt across.
            make.trailingAnchor.constraint(equalTo: trailingAnchor)
            make.centerYAnchor.constraint(equalTo: centerYAnchor)
            make.topAnchor.constraint(greaterThanOrEqualTo: topAnchor)
            bottomAnchor.constraint(greaterThanOrEqualTo: make.bottomAnchor)

            titleRowStackView.widthAnchor.constraint(equalTo: make.widthAnchor)
            subtitleLabel.widthAnchor.constraint(equalTo: make.widthAnchor)
        }
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        image = nil
        title = nil
        subtitle = nil
        badges = []
    }

    private func updateIconVisibility() {
        let visible = showsIcon
        iconImageView.isHidden = !visible
        iconWidthConstraint?.constant = visible ? iconSize : 0
        textLeadingToIconConstraint?.isActive = visible
        textLeadingToEdgeConstraint?.isActive = !visible
    }

    private func rebuildBadges() {
        for view in badgeStackView.arrangedSubviews {
            badgeStackView.removeArrangedSubview(view)
            view.removeFromSuperview()
        }
        for badge in badges {
            badgeStackView.addArrangedSubview(BadgeView(badge: badge))
        }
        badgeStackView.isHidden = badges.isEmpty
    }
}

#endif
