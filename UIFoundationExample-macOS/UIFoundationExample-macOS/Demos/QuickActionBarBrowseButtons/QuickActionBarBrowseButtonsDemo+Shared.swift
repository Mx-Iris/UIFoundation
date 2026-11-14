//
//  QuickActionBarBrowseButtonsDemo+Shared.swift
//  UIFoundationExample-macOS
//

import AppKit
import UniformTypeIdentifiers

/// What the three browse button examples share: symbol images, the rows their bars list, and the
/// made-up documents and colour tags the launcher and the tags example browse.
enum BrowseExample {
    /// A system symbol, or a close public one on a system that lacks it.
    static func symbol(_ name: String, fallback: String? = nil, title: String) -> NSImage {
        NSImage(systemSymbolName: name, accessibilityDescription: title)
            ?? fallback.flatMap { NSImage(systemSymbolName: $0, accessibilityDescription: title) }
            ?? NSImage()
    }

    /// A row of a bar's list: an icon, the title with the part the query matched set in bold, and a
    /// line of detail. Each of `tags` adds a dot of its colour after the title.
    static func row(
        icon: NSImage?,
        title: String,
        detail: String,
        searchTerm: String,
        tags: [BrowseExampleTag] = []
    ) -> NSView {
        let iconView = NSImageView()
        iconView.image = icon
        iconView.imageScaling = .scaleProportionallyUpOrDown
        // Tints symbols only; application and document icons keep their colours.
        iconView.contentTintColor = .secondaryLabelColor
        iconView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            iconView.widthAnchor.constraint(equalToConstant: 28),
            iconView.heightAnchor.constraint(equalToConstant: 28),
        ])

        let titleLabel = NSTextField(labelWithAttributedString: highlightedTitle(title, matching: searchTerm))
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        let tagDotViews: [NSView] = tags.map { tag in
            let dotView = NSImageView(image: tag.dotImage(diameter: 9))
            dotView.translatesAutoresizingMaskIntoConstraints = false
            dotView.widthAnchor.constraint(equalToConstant: 9).isActive = true
            dotView.heightAnchor.constraint(equalToConstant: 9).isActive = true
            return dotView
        }
        let titleStackView = NSStackView(views: [titleLabel] + tagDotViews)
        titleStackView.orientation = .horizontal
        titleStackView.alignment = .centerY
        titleStackView.spacing = 4

        let detailLabel = NSTextField(labelWithString: detail)
        detailLabel.font = .systemFont(ofSize: 11)
        detailLabel.textColor = .secondaryLabelColor
        detailLabel.lineBreakMode = .byTruncatingMiddle
        detailLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        let textStackView = NSStackView(views: [titleStackView, detailLabel])
        textStackView.orientation = .vertical
        textStackView.alignment = .leading
        textStackView.spacing = 1

        let rowStackView = NSStackView(views: [iconView, textStackView])
        rowStackView.orientation = .horizontal
        rowStackView.alignment = .centerY
        rowStackView.spacing = 10
        rowStackView.edgeInsets = NSEdgeInsets(top: 4, left: 22, bottom: 4, right: 22)
        return rowStackView
    }

    /// A row naming the group below it. The examples never let the list select one.
    static func headingRow(_ title: String) -> NSView {
        let headingLabel = NSTextField(labelWithString: title.uppercased())
        headingLabel.font = .systemFont(ofSize: 11, weight: .semibold)
        headingLabel.textColor = .tertiaryLabelColor

        let rowStackView = NSStackView(views: [headingLabel])
        rowStackView.orientation = .horizontal
        rowStackView.edgeInsets = NSEdgeInsets(top: 6, left: 22, bottom: 0, right: 22)
        return rowStackView
    }

    private static func highlightedTitle(_ title: String, matching searchTerm: String) -> NSAttributedString {
        let attributedTitle = NSMutableAttributedString(
            string: title,
            attributes: [
                .font: NSFont.systemFont(ofSize: 14),
                .foregroundColor: NSColor.labelColor,
            ]
        )
        if !searchTerm.isEmpty, let matchedRange = title.range(of: searchTerm, options: .caseInsensitive) {
            attributedTitle.addAttribute(
                .font,
                value: NSFont.systemFont(ofSize: 14, weight: .bold),
                range: NSRange(matchedRange, in: title)
            )
        }
        return attributedTitle
    }
}

/// The heading above a group of rows.
struct BrowseExampleHeading: Hashable {
    let title: String
}

/// A colour tag, as Finder has them.
enum BrowseExampleTag: CaseIterable, Hashable {
    case red
    case orange
    case yellow
    case green
    case blue
    case purple

    var title: String {
        switch self {
        case .red: "Red"
        case .orange: "Orange"
        case .yellow: "Yellow"
        case .green: "Green"
        case .blue: "Blue"
        case .purple: "Purple"
        }
    }

    var color: NSColor {
        switch self {
        case .red: .systemRed
        case .orange: .systemOrange
        case .yellow: .systemYellow
        case .green: .systemGreen
        case .blue: .systemBlue
        case .purple: .systemPurple
        }
    }

    /// A dot of the tag's colour. It is drawn each time it is shown, so the colour follows the
    /// appearance, and it is not a template image, so nothing tints it.
    func dotImage(diameter: CGFloat) -> NSImage {
        let color = color
        let image = NSImage(size: NSSize(width: diameter, height: diameter), flipped: false) { bounds in
            color.setFill()
            NSBezierPath(ovalIn: bounds).fill()
            return true
        }
        image.accessibilityDescription = title
        return image
    }
}

/// A document only this demo knows about. Nothing is on disk, so activating one just logs it.
struct BrowseExampleDocument: Hashable {
    let name: String
    let folder: String
    let tags: [BrowseExampleTag]

    /// The icon Finder shows for the document's type.
    var icon: NSImage {
        let contentType = UTType(filenameExtension: (name as NSString).pathExtension) ?? .data
        return NSWorkspace.shared.icon(for: contentType)
    }

    static let all: [BrowseExampleDocument] = [
        BrowseExampleDocument(name: "Quarterly Report.numbers", folder: "Documents › Finance", tags: [.green]),
        BrowseExampleDocument(name: "Budget 2027.xlsx", folder: "Documents › Finance", tags: [.green, .red]),
        BrowseExampleDocument(name: "Launch Keynote.key", folder: "Documents › Presentations", tags: [.red, .blue]),
        BrowseExampleDocument(name: "Design Review Notes.md", folder: "Documents › Notes", tags: [.purple, .blue]),
        BrowseExampleDocument(name: "Onboarding Checklist.pages", folder: "Documents", tags: [.yellow]),
        BrowseExampleDocument(name: "Invoice 2026-11.pdf", folder: "Downloads", tags: [.orange]),
        BrowseExampleDocument(name: "Team Offsite.ics", folder: "Downloads", tags: [.red]),
        BrowseExampleDocument(name: "Holiday Photos.zip", folder: "Desktop", tags: [.yellow]),
        BrowseExampleDocument(name: "App Icon.png", folder: "Desktop › Assets", tags: [.purple]),
        BrowseExampleDocument(name: "Release Script.sh", folder: "Developer › Scripts", tags: [.orange, .blue]),
    ]
}
