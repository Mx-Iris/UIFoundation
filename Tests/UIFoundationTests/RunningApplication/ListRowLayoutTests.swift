#if RunningApplication && os(macOS)

import AppKit
import Testing
@testable import UIFoundationRunningApplication

/// Layout tests for the list row.
///
/// These are the one place the suite steps outside pure functions, because the bug they
/// exist for could not be reached any other way: the row's text column was constrained
/// with an upper bound instead of being pinned to the trailing edge, so it collapsed to
/// its intrinsic width and the labels — deliberately low on compression resistance so they
/// truncate instead of widening the row — rendered as six characters and an ellipsis, on a
/// row over a thousand points wide. Everything compiled, and every configuration test
/// passed.
///
/// They are still deterministic and environment-independent: nothing here reads a real
/// process, a real icon, or anything about the machine running the tests.
@Suite("List row layout")
@MainActor
struct ListRowLayoutTests {
    static let rowWidth: CGFloat = 800
    static let rowHeight: CGFloat = 44

    /// Sizes the row the way `NSTableView` does — with required width and height
    /// constraints (`NSView-Encapsulated-Layout-*`) rather than by assigning a frame.
    /// The distinction matters: a frame-sized row picks up autoresizing constraints that
    /// paper over ambiguity the real table would surface.
    static func makeRow(
        title: String = "com.apple.WindowServer",
        subtitle: String = "com.apple.windowserver  ·  1234  ·  arm64e",
        badges: [ListRowBadge] = [],
        showsIcon: Bool = true,
        iconSize: CGFloat = 28,
        width: CGFloat = rowWidth
    ) -> ListRowTableCellView {
        let container = NSView(frame: .init(x: 0, y: 0, width: width, height: rowHeight))
        let row = ListRowTableCellView(frame: .zero)
        row.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(row)
        NSLayoutConstraint.activate([
            row.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            row.widthAnchor.constraint(equalToConstant: width),
            row.topAnchor.constraint(equalTo: container.topAnchor),
            row.heightAnchor.constraint(equalToConstant: rowHeight),
        ])

        row.iconSize = iconSize
        row.showsIcon = showsIcon
        row.title = title
        row.subtitle = subtitle
        row.badges = badges
        container.layoutSubtreeIfNeeded()
        return row
    }

    static func textFields(in view: NSView) -> [NSTextField] {
        var found: [NSTextField] = []
        if let field = view as? NSTextField { found.append(field) }
        for subview in view.subviews { found += textFields(in: subview) }
        return found
    }

    /// A label's frame is expressed in its stack view's coordinates, so anything
    /// comparing positions across the row has to convert first.
    static func frameInRow(_ view: NSView, _ row: NSView) -> NSRect {
        view.convert(view.bounds, to: row)
    }

    /// Badge views are private, so they are found through the text they carry.
    static func badgeView(withText text: String, in row: NSView) -> NSView? {
        textFields(in: row).first { $0.stringValue == text }?.superview
    }

    /// Title and subtitle, identified by their content rather than by reaching into
    /// private properties.
    static func labels(in row: ListRowTableCellView) -> (title: NSTextField?, subtitle: NSTextField?) {
        let fields = textFields(in: row)
        return (
            fields.first { $0.stringValue.hasPrefix("com.apple.WindowServer") },
            fields.first { $0.stringValue.contains("arm64e") }
        )
    }

    @Test("The text column reaches the trailing edge of the row")
    func textColumnSpansTheRow() {
        let row = Self.makeRow()
        let (title, subtitle) = Self.labels(in: row)

        guard let title, let subtitle else {
            Issue.record("expected a title and a subtitle label")
            return
        }

        // With the icon at 28pt plus an 8pt gap, the text has ~764pt to work with. The
        // regression collapsed these to a few dozen points.
        let availableWidth = Self.rowWidth - 28 - 8
        #expect(subtitle.frame.width >= availableWidth - 1,
                "subtitle width \(subtitle.frame.width), expected about \(availableWidth)")
        #expect(Self.frameInRow(title, row).maxX <= Self.rowWidth + 1)
        #expect(title.frame.width > 100, "title width \(title.frame.width)")
    }

    @Test("A long title is not truncated when the row has room for it")
    func longTitleFitsWhenThereIsRoom() {
        let longTitle = "com.apple.WindowServer.with.a.rather.long.identifier"
        let row = Self.makeRow(title: longTitle)
        guard let title = Self.textFields(in: row).first(where: { $0.stringValue == longTitle }) else {
            Issue.record("expected the title label")
            return
        }
        // The label must be at least as wide as the text wants to be.
        let intrinsicWidth = title.intrinsicContentSize.width
        #expect(title.frame.width >= min(intrinsicWidth, Self.rowWidth - 36) - 1,
                "title width \(title.frame.width) vs intrinsic \(intrinsicWidth)")
    }

    @Test("Badges sit next to the title, not at the far edge of the row")
    func badgesFollowTheTitle() {
        let row = Self.makeRow(badges: [.init(text: "iOS Simulator", color: .systemBlue)])
        guard let title = Self.labels(in: row).title else {
            Issue.record("expected the title label")
            return
        }
        guard let badge = Self.badgeView(withText: "iOS Simulator", in: row) else {
            Issue.record("expected a badge view")
            return
        }
        let badgeOrigin = Self.frameInRow(badge, row).minX
        let titleEnd = Self.frameInRow(title, row).maxX
        #expect(badgeOrigin >= titleEnd - 1, "badge at \(badgeOrigin), title ends at \(titleEnd)")
        // The whole point of the spacer: the badge must not be flung to the right edge.
        #expect(badgeOrigin < Self.rowWidth / 2,
                "badge at \(badgeOrigin) drifted toward the trailing edge")
    }

    @Test("Hiding the icon gives its space back to the text")
    func textStartsAtTheEdgeWithoutAnIcon() {
        let withIcon = Self.makeRow(showsIcon: true)
        let withoutIcon = Self.makeRow(showsIcon: false)

        guard let iconedSubtitle = Self.labels(in: withIcon).subtitle,
              let barefaceSubtitle = Self.labels(in: withoutIcon).subtitle else {
            Issue.record("expected subtitles in both rows")
            return
        }
        #expect(Self.frameInRow(barefaceSubtitle, withoutIcon).minX
                    < Self.frameInRow(iconedSubtitle, withIcon).minX)
        #expect(barefaceSubtitle.frame.width > iconedSubtitle.frame.width)
    }

    static func ambiguousDescendants(of view: NSView, path: String = "") -> [String] {
        let label = path.isEmpty
            ? String(describing: type(of: view))
            : path + " > " + String(describing: type(of: view))
        var found: [String] = view.hasAmbiguousLayout ? [label] : []
        for subview in view.subviews { found += ambiguousDescendants(of: subview, path: label) }
        return found
    }

    @Test("A row lays out unambiguously, with and without badges", arguments: [
        [ListRowBadge](),
        [.init(text: "iOS Simulator", color: .systemBlue)],
        [.init(text: "Mac Catalyst", color: .systemTeal), .init(text: "Sandboxed", color: .systemGreen)],
    ])
    func rowLaysOutUnambiguously(badges: [ListRowBadge]) {
        let row = Self.makeRow(badges: badges)
        let problems = Self.ambiguousDescendants(of: row)
        #expect(problems.isEmpty, "ambiguous: \(problems)")
    }

    static func stackViews(in view: NSView) -> [NSStackView] {
        var found: [NSStackView] = []
        if let stack = view as? NSStackView { found.append(stack) }
        for subview in view.subviews { found += stackViews(in: subview) }
        return found
    }

    @Test("An empty badge container is hidden, not left as an unsized visible stack")
    func emptyBadgeContainerIsHidden() {
        // A visible NSStackView with no arranged subviews has nothing to derive its height
        // from, which is what Xcode reports as "Height and vertical position are ambiguous
        // for NSStackView" -- once per row, on every row without a badge.
        let row = Self.makeRow(badges: [])
        let emptyVisibleStacks = Self.stackViews(in: row)
            .filter { !$0.isHidden && $0.arrangedSubviews.isEmpty }
        #expect(emptyVisibleStacks.isEmpty,
                "\(emptyVisibleStacks.count) empty stack view(s) left visible")
    }

    @Test("A row that loses its badges hides the container again")
    func badgeContainerHidesWhenBadgesAreCleared() {
        let row = Self.makeRow(badges: [.init(text: "iOS Simulator", color: .systemBlue)])
        row.badges = []
        row.layoutSubtreeIfNeeded()
        let emptyVisibleStacks = Self.stackViews(in: row)
            .filter { !$0.isHidden && $0.arrangedSubviews.isEmpty }
        #expect(emptyVisibleStacks.isEmpty)
    }

    @Test("Icon size drives the icon's frame", arguments: [CGFloat(20), 28, 40])
    func iconSizeIsHonoured(size: CGFloat) {
        let row = Self.makeRow(iconSize: size)
        guard let imageView = row.subviews.compactMap({ $0 as? NSImageView }).first else {
            Issue.record("expected an image view")
            return
        }
        #expect(imageView.frame.width == size)
        #expect(imageView.frame.height == size)
    }
}

#endif
