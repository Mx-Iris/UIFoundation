#if RunningApplication && os(macOS)

import AppKit
import UIFoundationUtilities

/// A marker rendered to the right of a list row's title.
///
/// Badges are deliberately rendered only when they carry information: a platform badge is
/// omitted for the host platform, and the sandbox badge appears only for sandboxed items.
/// Rendering every value the way a table column must is what produced the wall of repeated
/// "macOS" and the wall of red crosses that this style exists to remove.
struct ListRowBadge: Equatable {
    var text: String
    /// Tint for both the label and — at low alpha — the pill behind it.
    var color: NSColor
}

extension Platform {
    /// Badge tint, one hue per OS family.
    ///
    /// A simulator shares its family's colour rather than getting one of its own: the
    /// label already says "Simulator", and giving iOS and iOS Simulator different hues
    /// would mean the colour no longer answers "which platform is this".
    ///
    /// Deliberately no `default` branch — a new platform must be assigned a colour here
    /// rather than silently inheriting one.
    var badgeColor: NSColor {
        switch self {
        case .macOS, .macOSExclaveCore, .macOSExclaveKit: .systemYellow
        case .iOS, .iOSSimulator, .iOSExclaveCore, .iOSExclaveKit: .systemBlue
        case .tvOS, .tvOSSimulator, .tvOSExclaveCore, .tvOSExclaveKit: .systemPurple
        case .watchOS, .watchOSSimulator, .watchOSExclaveCore, .watchOSExclaveKit: .systemPink
        case .visionOS, .visionOSSimulator, .visionOSExclaveCore, .visionOSExclaveKit: .systemIndigo
        case .macCatalyst: .systemTeal
        case .driverKit: .systemBrown
        // The three below never surface in a process list — they are not ordinary BSD
        // processes — so they draw from what is left rather than from distinct hues.
        // `systemCyan` and `systemMint` would suit them better but need macOS 12.
        case .bridgeOS: .systemGreen
        case .firmware: .systemRed
        case .securityEnclaveOS: .systemGray
        case .unknown: .systemOrange
        }
    }
}

/// A pill carrying a short label. Shared by both presentation styles.
final class BadgeView: NSView {
    private let label = NSTextField(labelWithString: "")

    init(badge: ListRowBadge) {
        super.init(frame: .zero)
        wantsLayer = true
        layer?.cornerRadius = 4
        translatesAutoresizingMaskIntoConstraints = false
        setContentCompressionResistancePriority(.required, for: .horizontal)
        setContentHuggingPriority(.required, for: .horizontal)

        addSubview(label)
        label.font = .systemFont(ofSize: 10, weight: .semibold)
        label.makeConstraints { make in
            make.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 5)
            trailingAnchor.constraint(equalTo: make.trailingAnchor, constant: 5)
            make.topAnchor.constraint(equalTo: topAnchor, constant: 1.5)
            bottomAnchor.constraint(equalTo: make.bottomAnchor, constant: 1.5)
        }
        configure(with: badge)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// Updating in place rather than rebuilding, since table cells are reused heavily.
    func configure(with badge: ListRowBadge) {
        label.stringValue = badge.text
        label.textColor = badge.color
        layer?.backgroundColor = badge.color.withAlphaComponent(0.16).cgColor
    }

    /// Re-resolve the dynamic colours, which `cgColor` snapshots at assignment time.
    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        if let color = label.textColor {
            layer?.backgroundColor = color.withAlphaComponent(0.16).cgColor
        }
    }
}


extension Architecture {
    /// Badge tint. The ARM variants are the norm on Apple silicon -- measured at 71% of
    /// all processes -- so they stay in one cool family and differ only by hue, while a
    /// non-native architecture is what actually deserves to catch the eye.
    ///
    /// No `default` branch: a new architecture must be given a colour here.
    var badgeColor: NSColor {
        switch self {
        case .arm64: .systemBlue
        case .arm64e: .systemIndigo
        // Running x86_64 or i386 on this machine means translation -- worth noticing.
        case .x86_64, .i386: .systemOrange
        case .ppc, .ppc64: .systemBrown
        case .unknown: .secondaryLabelColor
        }
    }
}

#endif
