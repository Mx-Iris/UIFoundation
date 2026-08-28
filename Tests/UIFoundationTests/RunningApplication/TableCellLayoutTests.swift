#if RunningApplication && os(macOS)

import AppKit
import Testing
@testable import UIFoundationRunningApplication

/// Layout tests for the table style's cell views, and for the badge pill both styles share.
///
/// These cover the half of the picker that `ListRowLayoutTests` does not: that suite pins
/// the geometry of the single list row, while every cell the *table* style builds — icon,
/// label, PID, badge — had no geometric coverage at all. Four layout faults have already
/// reached a screenshot in this code while compiling cleanly and passing every other test,
/// so before the cells are rebuilt on this library's own base classes their geometry needs
/// somewhere to fail.
///
/// The same two rules as the list-row suite apply. Cells are sized by **constraints**, not
/// by assigning a frame — a frame-sized view picks up autoresizing constraints that paper
/// over exactly the ambiguity a real table would surface. And nothing here reads a real
/// process, a real icon, or anything about the machine running the tests.
@Suite("Table cell layout")
@MainActor
struct TableCellLayoutTests {
    static let cellWidth: CGFloat = 220
    static let cellHeight: CGFloat = 28

    /// Hosts a cell at a fixed size the way `NSTableView` does, then lays it out.
    static func host<Cell: NSTableCellView>(
        _ cell: Cell,
        width: CGFloat = cellWidth,
        height: CGFloat = cellHeight,
        configure: (Cell) -> Void = { _ in }
    ) -> Cell {
        let container = NSView(frame: .init(x: 0, y: 0, width: width, height: height))
        cell.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(cell)
        NSLayoutConstraint.activate([
            cell.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            cell.topAnchor.constraint(equalTo: container.topAnchor),
            cell.widthAnchor.constraint(equalToConstant: width),
            cell.heightAnchor.constraint(equalToConstant: height),
        ])
        configure(cell)
        container.layoutSubtreeIfNeeded()
        return cell
    }

    /// A view's frame in `ancestor`'s coordinates, measured as its **alignment rect**.
    ///
    /// This is not a detail worth glossing over: `NSTextField` draws 2pt wider than it
    /// lays out, so its `frame` sits 2pt outside wherever a constraint pinned it. Auto
    /// Layout constrains alignment rects, so asserting on frames here would be asserting
    /// on AppKit's drawing margin rather than on the layout — and would need a fudge
    /// factor that quietly swallows a 2pt regression.
    static func alignmentFrame(_ view: NSView, in ancestor: NSView) -> NSRect {
        let rect = view.alignmentRect(forFrame: view.frame)
        guard let superview = view.superview else { return rect }
        return superview.convert(rect, to: ancestor)
    }

    static func descendants<View: NSView>(ofType type: View.Type, in view: NSView) -> [View] {
        var found: [View] = []
        if let match = view as? View { found.append(match) }
        for subview in view.subviews { found += descendants(ofType: type, in: subview) }
        return found
    }

    static func ambiguousDescendants(of view: NSView, path: String = "") -> [String] {
        let label = path.isEmpty
            ? String(describing: type(of: view))
            : path + " > " + String(describing: type(of: view))
        var found: [String] = view.hasAmbiguousLayout ? [label] : []
        for subview in view.subviews { found += ambiguousDescendants(of: subview, path: label) }
        return found
    }

    // MARK: - Icon Cell

    @Test("The icon is square, sized to the row height, and centred",
          arguments: [CGFloat(20), 28, 44])
    func iconCellGeometry(rowHeight: CGFloat) {
        let cell = Self.host(IconTableCellView(frame: .zero), height: rowHeight)
        guard let imageView = Self.descendants(ofType: NSImageView.self, in: cell).first else {
            Issue.record("expected an image view")
            return
        }
        // Width is bound to the cell's *height*, which is what keeps the icon square
        // regardless of how wide the column gets.
        #expect(imageView.frame.height == rowHeight)
        #expect(imageView.frame.width == rowHeight)
        #expect(abs(imageView.frame.midX - cell.bounds.midX) < 0.5)
        #expect(abs(imageView.frame.midY - cell.bounds.midY) < 0.5)
    }

    @Test("A wide icon column keeps the icon square instead of stretching it")
    func iconStaysSquareInAWideColumn() {
        let cell = Self.host(IconTableCellView(frame: .zero), width: 300, height: 28)
        guard let imageView = Self.descendants(ofType: NSImageView.self, in: cell).first else {
            Issue.record("expected an image view")
            return
        }
        #expect(imageView.frame.width == CGFloat(28))
        #expect(imageView.frame.width < cell.bounds.width)
    }

    // MARK: - Status Icon Cell

    @Test("The spinner sits where the icon does, and only one of the two shows")
    func statusIconSwapsIconAndSpinner() {
        let cell = Self.host(StatusIconTableCellView(frame: .zero))
        guard let spinner = Self.descendants(ofType: NSProgressIndicator.self, in: cell).first,
              let imageView = Self.descendants(ofType: NSImageView.self, in: cell).first else {
            Issue.record("expected a spinner and an image view")
            return
        }
        #expect(spinner.isHidden)
        #expect(!imageView.isHidden)
        #expect(abs(spinner.frame.midX - cell.bounds.midX) < 0.5)
        #expect(abs(spinner.frame.midY - cell.bounds.midY) < 0.5)

        cell.isLoading = true
        cell.layoutSubtreeIfNeeded()
        #expect(!spinner.isHidden)
        #expect(imageView.isHidden)
    }

    @Test("A reused status cell comes back blank")
    func statusIconResetsOnReuse() {
        let cell = Self.host(StatusIconTableCellView(frame: .zero)) {
            $0.isLoading = true
            $0.image = NSImage(size: .init(width: 8, height: 8))
            $0.tintColor = .systemRed
        }
        cell.prepareForReuse()
        #expect(cell.isLoading == false)
        #expect(cell.image == nil)
        #expect(cell.tintColor == nil)
    }

    // MARK: - Label Cells

    @Test("The label is pinned to the leading edge, vertically centred, inside the cell")
    func labelCellGeometry() {
        let cell = Self.host(LabelTableCellView(frame: .zero)) { $0.string = "WindowServer" }
        guard let label = Self.descendants(ofType: NSTextField.self, in: cell).first else {
            Issue.record("expected a label")
            return
        }
        let laidOut = Self.alignmentFrame(label, in: cell)
        #expect(laidOut.minX == CGFloat(0))
        #expect(abs(laidOut.midY - cell.bounds.midY) <= 0.5)
        #expect(laidOut.maxX <= cell.bounds.width)
        #expect(laidOut.minY >= CGFloat(0))
        #expect(laidOut.maxY <= cell.bounds.height)
    }

    @Test("A label too long for the column truncates instead of widening the cell")
    func longLabelTruncatesWithinTheColumn() {
        let text = String(repeating: "com.apple.a.very.long.reverse.dns.identifier/", count: 4)
        let cell = Self.host(LabelTableCellView(frame: .zero)) { $0.string = text }
        guard let label = Self.descendants(ofType: NSTextField.self, in: cell).first else {
            Issue.record("expected a label")
            return
        }
        #expect(label.lineBreakMode == .byTruncatingTail)
        let laidOut = Self.alignmentFrame(label, in: cell)
        #expect(laidOut.maxX <= cell.bounds.width,
                "label overflows: \(laidOut.maxX) vs \(cell.bounds.width)")
        // The text wants far more room than the column has; the cell must not grow for it.
        #expect(label.intrinsicContentSize.width > cell.bounds.width)
    }

    @Test("The full string is offered as a tooltip, since the column may truncate it")
    func labelExposesItsFullTextAsATooltip() {
        let text = "/System/Library/CoreServices/WindowServer"
        let cell = Self.host(LabelTableCellView(frame: .zero)) { $0.string = text }
        #expect(cell.toolTip == text)
    }

    @Test("The PID cell uses monospaced digits in a receded colour")
    func pidCellTypography() {
        // Digits that line up down the column is the entire reason this subclass exists,
        // so it is the one piece of its styling worth pinning.
        let cell = Self.host(PIDTableCellView(frame: .zero)) { $0.string = "1234" }
        #expect(cell.labelColor == .secondaryLabelColor)

        let digits = "0123456789".map { character -> CGFloat in
            (String(character) as NSString)
                .size(withAttributes: [.font: cell.labelFont]).width
        }
        #expect(Set(digits.map { ($0 * 100).rounded() }).count == 1,
                "digit widths differ: \(digits)")
    }

    // MARK: - Badge Cell

    @Test("A badge is pinned to the leading edge and vertically centred")
    func badgeCellGeometry() {
        let cell = Self.host(BadgeTableCellView(frame: .zero)) {
            $0.badge = .init(text: "arm64e", color: .systemIndigo)
        }
        guard let badge = Self.descendants(ofType: BadgeView.self, in: cell).first else {
            Issue.record("expected a badge view")
            return
        }
        #expect(badge.frame.minX == CGFloat(0))
        #expect(abs(badge.frame.midY - cell.bounds.midY) < 0.5)
        #expect(badge.frame.maxX <= cell.bounds.width + 0.5)
        #expect(badge.frame.width > 0)
    }

    @Test("Clearing the badge hides the pill rather than leaving an empty one")
    func clearedBadgeIsHidden() {
        let cell = Self.host(BadgeTableCellView(frame: .zero)) {
            $0.badge = .init(text: "iOS Simulator", color: .systemBlue)
        }
        cell.badge = nil
        cell.layoutSubtreeIfNeeded()
        let visible = Self.descendants(ofType: BadgeView.self, in: cell).filter { !$0.isHidden }
        #expect(visible.isEmpty)
    }

    @Test("A reused badge cell updates its pill in place instead of stacking a new one")
    func badgeCellReusesItsPill() {
        // Cells are reused heavily; building a fresh pill per assignment would pile up
        // subviews on every scroll.
        let cell = Self.host(BadgeTableCellView(frame: .zero)) {
            $0.badge = .init(text: "arm64", color: .systemBlue)
        }
        cell.badge = .init(text: "x86_64", color: .systemOrange)
        cell.layoutSubtreeIfNeeded()
        #expect(Self.descendants(ofType: BadgeView.self, in: cell).count == 1)

        cell.prepareForReuse()
        cell.badge = .init(text: "arm64e", color: .systemIndigo)
        cell.layoutSubtreeIfNeeded()
        #expect(Self.descendants(ofType: BadgeView.self, in: cell).count == 1)
    }

    // MARK: - Badge Pill

    @Test("The pill wraps its label with symmetric padding")
    func badgePillPadding() {
        let badge = BadgeView(badge: .init(text: "Sandboxed", color: .systemGreen))
        let container = NSView(frame: .init(x: 0, y: 0, width: 200, height: 40))
        container.addSubview(badge)
        NSLayoutConstraint.activate([
            badge.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            badge.centerYAnchor.constraint(equalTo: container.centerYAnchor),
        ])
        container.layoutSubtreeIfNeeded()

        guard let label = Self.descendants(ofType: NSTextField.self, in: badge).first else {
            Issue.record("expected a label inside the pill")
            return
        }
        let laidOut = Self.alignmentFrame(label, in: badge)
        #expect(abs(laidOut.minX - 5) <= 0.5)
        #expect(abs(badge.frame.width - laidOut.width - 10) <= 0.5)
        #expect(abs(badge.frame.height - laidOut.height - 3) <= 0.5)
    }

    @Test("The pill hugs its text rather than stretching to fill the space offered")
    func badgePillHugsItsText() {
        let badge = BadgeView(badge: .init(text: "iOS", color: .systemBlue))
        let container = NSView(frame: .init(x: 0, y: 0, width: 400, height: 40))
        container.addSubview(badge)
        NSLayoutConstraint.activate([
            badge.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            badge.trailingAnchor.constraint(lessThanOrEqualTo: container.trailingAnchor),
            badge.centerYAnchor.constraint(equalTo: container.centerYAnchor),
        ])
        container.layoutSubtreeIfNeeded()
        #expect(badge.frame.width < 100, "pill stretched to \(badge.frame.width)")
    }

    // MARK: - Ambiguity

    @Test("Every cell lays out unambiguously")
    func cellsLayOutUnambiguously() {
        var problems: [String] = []
        problems += Self.ambiguousDescendants(of: Self.host(IconTableCellView(frame: .zero)))
        problems += Self.ambiguousDescendants(of: Self.host(StatusIconTableCellView(frame: .zero)))
        problems += Self.ambiguousDescendants(of: Self.host(LabelTableCellView(frame: .zero)) {
            $0.string = "WindowServer"
        })
        problems += Self.ambiguousDescendants(of: Self.host(PIDTableCellView(frame: .zero)) {
            $0.string = "1234"
        })
        problems += Self.ambiguousDescendants(of: Self.host(BadgeTableCellView(frame: .zero)) {
            $0.badge = .init(text: "arm64e", color: .systemIndigo)
        })
        problems += Self.ambiguousDescendants(of: Self.host(BadgeTableCellView(frame: .zero)))
        #expect(problems.isEmpty, "ambiguous: \(problems)")
    }

    // MARK: - Cell Reuse by Class Identity

    @Test("Each column's cell is a distinct class, so the table can reuse by identity")
    func cellClassesAreDistinct() {
        // `makeView(ofClass:)` keys the reuse queue on the class name. Two columns sharing
        // a class would hand each other's populated cells back and forth.
        let classes: [AnyClass] = [
            NameTableCellView.self,
            BundleIdentifierTableCellView.self,
            PIDTableCellView.self,
            ExecutablePathTableCellView.self,
            ArchitectureTableCellView.self,
            PlatformTableCellView.self,
        ]
        let names = classes.map { String(describing: $0) }
        #expect(Set(names).count == names.count, "duplicate cell class names: \(names)")
    }
}

#endif
