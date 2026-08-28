#if RunningApplication && os(macOS)

import AppKit
import Testing
@testable import UIFoundationRunningApplication

/// The badge palette and the table cell that renders it.
///
/// The palettes themselves are exhaustive switches with no `default`, so a new platform or
/// architecture cannot compile without being assigned a colour. What the compiler cannot
/// check is whether the colours are actually distinguishable from each other — which is
/// the whole complaint these badges answer: every non-simulator platform used to share one
/// grey, leaving Mac Catalyst and DriverKit indistinguishable.
@Suite("Badges")
struct BadgeTests {
    // MARK: - Architecture Palette

    @Test("The architectures that occur together are distinguishable")
    func architectureColoursAreDistinct() {
        // Measured across 1428 processes: arm64e 41.7%, arm64 29.4%, x86_64 0.1%.
        let occurring: [Architecture] = [.arm64, .arm64e, .x86_64]
        let colours = occurring.map(\.badgeColor)
        #expect(Set(colours).count == occurring.count, "\(colours)")
    }

    @Test("A translated architecture is not tinted like the native ones")
    func translatedArchitectureStandsApart() {
        // Running x86_64 on Apple silicon means Rosetta, which is the interesting case.
        #expect(Architecture.x86_64.badgeColor != Architecture.arm64.badgeColor)
        #expect(Architecture.x86_64.badgeColor != Architecture.arm64e.badgeColor)
    }

    // MARK: - Platform Palette

    @Test("Platforms seen in a real process list are mutually distinguishable")
    func platformColoursAreDistinct() {
        let occurring: [Platform] = [.macOS, .iOSSimulator, .macCatalyst, .driverKit]
        let colours = occurring.map(\.badgeColor)
        #expect(Set(colours).count == occurring.count, "\(colours)")
    }

    // MARK: - Table Cell

    @MainActor
    @Test("The badge cell renders and clears its badge")
    func badgeCellRendersAndClears() {
        let cell = BadgeTableCellView(frame: .init(x: 0, y: 0, width: 120, height: 28))
        cell.badge = .init(text: "iOS Simulator", color: .systemBlue)
        cell.layoutSubtreeIfNeeded()

        let labels = cell.subviews
            .flatMap(\.subviews)
            .compactMap { $0 as? NSTextField }
        #expect(labels.map(\.stringValue) == ["iOS Simulator"])
        #expect(labels.first?.textColor == .systemBlue)

        // Reuse must not leave the previous row's badge showing.
        cell.prepareForReuse()
        cell.layoutSubtreeIfNeeded()
        let visibleBadges = cell.subviews.filter { !$0.isHidden }
        #expect(visibleBadges.isEmpty, "a reused cell still shows \(visibleBadges.count) badge(s)")
    }

    @MainActor
    @Test("Re-badging an existing cell updates in place rather than stacking views")
    func rebadgingReusesTheSameView() {
        let cell = BadgeTableCellView(frame: .init(x: 0, y: 0, width: 120, height: 28))
        cell.badge = .init(text: "Mac Catalyst", color: .systemTeal)
        let afterFirst = cell.subviews.count
        cell.badge = .init(text: "DriverKit", color: .systemBrown)
        cell.layoutSubtreeIfNeeded()

        #expect(cell.subviews.count == afterFirst, "badge views accumulated on reuse")
        let labels = cell.subviews.flatMap(\.subviews).compactMap { $0 as? NSTextField }
        #expect(labels.map(\.stringValue) == ["DriverKit"])
    }

    // MARK: - PID

    @MainActor
    @Test("PID uses monospaced digits so the column lines up")
    func pidUsesMonospacedDigits() {
        // Not a badge: a pill would suggest the number classifies the row the way a
        // platform does, when it only identifies it.
        let cell = PIDTableCellView(frame: .init(x: 0, y: 0, width: 60, height: 28))
        cell.string = "1234"
        #expect(cell.labelColor == .secondaryLabelColor)

        // `monospacedDigitSystemFont` only fixes the digit advance; it sets no monospace
        // trait and keeps the system font's name, so the font itself is what to compare.
        let expected = NSFont.monospacedDigitSystemFont(
            ofSize: cell.labelFont.pointSize,
            weight: .regular
        )
        #expect(cell.labelFont == expected, "font is \(cell.labelFont)")

        // What it is actually for: equal-width digits keep the column aligned.
        let attributes: [NSAttributedString.Key: Any] = [.font: cell.labelFont]
        let narrowDigits = ("1111" as NSString).size(withAttributes: attributes).width
        let wideDigits = ("8888" as NSString).size(withAttributes: attributes).width
        #expect(abs(narrowDigits - wideDigits) < 0.01,
                "digits do not share an advance: \(narrowDigits) vs \(wideDigits)")
    }
}

#endif
