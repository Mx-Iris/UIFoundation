#if RunningApplication && os(macOS)

import AppKit
import UIFoundationAppKit
import UIFoundationUtilities

class IconTableCellView: TableCellView {
    var tintColor: NSColor? {
        didSet {
            iconImageView.contentTintColor = tintColor
        }
    }

    var image: NSImage? {
        didSet {
            iconImageView.image = image
        }
    }

    fileprivate let iconImageView = NSImageView()

    override func setup() {
        super.setup()

        addSubview(iconImageView)
        iconImageView.makeConstraints { make in
            make.centerYAnchor.constraint(equalTo: centerYAnchor)
            make.centerXAnchor.constraint(equalTo: centerXAnchor)
            make.heightAnchor.constraint(equalTo: heightAnchor)
            // Width follows the *height*, which is what keeps the icon square however
            // wide the column is dragged.
            make.widthAnchor.constraint(equalTo: heightAnchor)
        }
    }
}

class StatusIconTableCellView: IconTableCellView {
    var isLoading: Bool = false {
        didSet {
            iconImageView.isHidden = isLoading
            if isLoading {
                spinner.startAnimation(nil)
            } else {
                spinner.stopAnimation(nil)
            }
            spinner.isHidden = !isLoading
        }
    }

    private let spinner = NSProgressIndicator()

    override func setup() {
        super.setup()

        addSubview(spinner)
        spinner.style = .spinning
        spinner.controlSize = .small
        spinner.isHidden = true
        spinner.makeConstraints { make in
            make.centerYAnchor.constraint(equalTo: centerYAnchor)
            make.centerXAnchor.constraint(equalTo: centerXAnchor)
        }
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        isLoading = false
        image = nil
        tintColor = nil
    }
}

class NameTableCellView: LabelTableCellView {}

class BundleIdentifierTableCellView: LabelTableCellView {}

/// PID is an identifier, not a classification, so it gets no badge — a pill would imply
/// the number groups rows the way a platform or architecture does. Monospaced digits line
/// up down the column instead, in a receded colour.
class PIDTableCellView: LabelTableCellView {
    override func setup() {
        super.setup()

        labelFont = .monospacedDigitSystemFont(ofSize: 12, weight: .regular)
        labelColor = .secondaryLabelColor
    }
}

/// Renders one badge, for the table columns that carry a classification rather than
/// free text. Distinct subclasses per column so `NSTableView` can reuse by class identity.
class BadgeTableCellView: TableCellView {
    var badge: ListRowBadge? {
        didSet {
            guard badge != oldValue else { return }
            apply()
        }
    }

    private var badgeView: BadgeView?

    private func apply() {
        guard let badge else {
            badgeView?.isHidden = true
            return
        }
        if let badgeView {
            badgeView.isHidden = false
            badgeView.configure(with: badge)
            return
        }
        let view = BadgeView(badge: badge)
        addSubview(view)
        view.makeConstraints { make in
            make.leadingAnchor.constraint(equalTo: leadingAnchor)
            make.centerYAnchor.constraint(equalTo: centerYAnchor)
            make.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor)
        }
        badgeView = view
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        badge = nil
    }
}

class ArchitectureTableCellView: BadgeTableCellView {}

class PlatformTableCellView: BadgeTableCellView {}

class ExecutablePathTableCellView: LabelTableCellView {}

class LabelTableCellView: TableCellView {
    var string: String? {
        didSet {
            label.stringValue = string ?? ""
            toolTip = label.stringValue
        }
    }

    var labelFont: NSFont {
        get { label.font ?? .systemFont(ofSize: 12) }
        set { label.font = newValue }
    }

    var labelColor: NSColor {
        get { label.textColor ?? .labelColor }
        set { label.textColor = newValue }
    }

    private let label = NSTextField(labelWithString: "")

    override func setup() {
        super.setup()

        addSubview(label)
        label.font = .systemFont(ofSize: 12, weight: .regular)
        label.lineBreakMode = .byTruncatingTail
        label.makeConstraints { make in
            make.centerYAnchor.constraint(equalTo: centerYAnchor)
            make.leadingAnchor.constraint(equalTo: leadingAnchor)
            make.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor)
            make.topAnchor.constraint(greaterThanOrEqualTo: topAnchor)
            make.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor)
        }
    }
}

#endif
