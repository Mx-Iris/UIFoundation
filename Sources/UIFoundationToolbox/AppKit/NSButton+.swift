#if canImport(AppKit) && !targetEnvironment(macCatalyst)

import AppKit
import FrameworkToolbox

extension NSButton {
    public convenience init(
        title: String = "",
        titleColor: NSColor = .labelColor,
        titleFont: NSFont = .systemFont(ofSize: 14),
        alternateTitle: String = "",
        alternateTitleColor: NSColor = .labelColor,
        alternateTitleFont: NSFont = .systemFont(ofSize: 14),
        image: NSImage? = nil,
        alternateImage: NSImage? = nil,
    ) {
        self.init(frame: .zero)
        self.attributedTitle = NSAttributedString(string: title, attributes: [.font: titleFont, .foregroundColor: titleColor])
        self.attributedAlternateTitle = NSAttributedString(string: alternateTitle, attributes: [.font: alternateTitleFont, .foregroundColor: alternateTitleColor])
        self.image = image
        self.alternateImage = alternateImage
    }
}

extension FrameworkToolbox where Base: NSButton {
    public static func `init`(
        title: String = "",
        titleColor: NSColor = .labelColor,
        titleFont: NSFont = .systemFont(ofSize: 14),
        alternateTitle: String = "",
        alternateTitleColor: NSColor = .labelColor,
        alternateTitleFont: NSFont = .systemFont(ofSize: 14),
        image: NSImage? = nil,
        alternateImage: NSImage? = nil,
    ) -> Base {
        let base = Base()
        base.attributedTitle = NSAttributedString(string: title, attributes: [.font: titleFont, .foregroundColor: titleColor])
        base.attributedAlternateTitle = NSAttributedString(string: alternateTitle, attributes: [.font: alternateTitleFont, .foregroundColor: alternateTitleColor])
        base.image = image
        base.alternateImage = alternateImage
        return base
    }
}

extension FrameworkToolbox where Base: NSButton {
    @inlinable
    public var buttonCell: NSButtonCell? {
        base.cell as? NSButtonCell
    }
}

extension FrameworkToolbox where Base == Bool {
    @inlinable
    public var controlState: NSControl.StateValue {
        base ? .on : .off
    }
}

extension NSControl.StateValue: @retroactive ExpressibleByBooleanLiteral {
    @inlinable
    public init(booleanLiteral value: BooleanLiteralType) {
        self = value ? .on : .off
    }
}

extension FrameworkToolbox where Base: NSButton {
    /// A semantic role describing a button's purpose within its context.
    ///
    /// Assigning a role through `box.role` configures the button's
    /// `keyEquivalent` and `hasDestructiveAction` to match the behavior
    /// AppKit applies to system-standard buttons.
    public enum Role: Int, Sendable, CaseIterable {
        /// A button with no special behavior. Clears the key equivalent.
        case normal

        /// The default button of its context, triggered by the Return key.
        case primary

        /// The cancel button of its context, triggered by the Escape key.
        case cancel

        /// A button that performs a destructive action, marked with
        /// `hasDestructiveAction`.
        case destructive
    }

    /// The semantic role of the button.
    ///
    /// This is a computed view over the button's `keyEquivalent` and
    /// `hasDestructiveAction`; there is no separate stored state, so the
    /// role always reflects the button's current configuration.
    ///
    /// Assigning a role updates the underlying button to mirror AppKit's
    /// standard configuration for that role:
    ///
    /// - `.primary` sets `keyEquivalent` to Return (`"\r"`).
    /// - `.cancel` sets `keyEquivalent` to Escape (`"\u{1b}"`).
    /// - `.destructive` enables `hasDestructiveAction` and clears `keyEquivalent`.
    /// - `.normal` clears `keyEquivalent`.
    ///
    /// `hasDestructiveAction` is reset before every assignment, so switching
    /// away from `.destructive` also clears the flag. The flag requires
    /// macOS 11; on macOS 10.15 a `.destructive` button is reported as
    /// `.normal`.
    @inlinable
    public var role: Role {
        get {
            switch base.keyEquivalent {
            case "\r":
                return .primary
            case "\u{1b}":
                return .cancel
            default:
                if #available(macOS 11.0, *), base.hasDestructiveAction {
                    return .destructive
                }
                return .normal
            }
        }
        nonmutating set {
            // Reset the destructive state first, then derive the key
            // equivalent from the role — mirroring AppKit's own handling.
            if #available(macOS 11.0, *) {
                base.hasDestructiveAction = false
            }

            switch newValue {
            case .primary:
                base.keyEquivalent = "\r"
            case .cancel:
                base.keyEquivalent = "\u{1b}"
            case .destructive:
                if #available(macOS 11.0, *) {
                    base.hasDestructiveAction = true
                }
                base.keyEquivalent = ""
            case .normal:
                base.keyEquivalent = ""
            }
        }
    }
}

#endif
