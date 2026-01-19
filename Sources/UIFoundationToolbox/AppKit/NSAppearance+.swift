#if canImport(AppKit) && !targetEnvironment(macCatalyst)

import AppKit
import FrameworkToolbox

extension FrameworkToolbox where Base: NSAppearance {
    /// Returns a aqua appearance.
    public static var aqua: NSAppearance {
        NSAppearance(named: .aqua)!
    }

    /// Returns a dark aqua appearance.
    public static var darkAqua: NSAppearance {
        NSAppearance(named: .darkAqua)!
    }

    /// Returns a vibrant light appearance.
    public static var vibrantLight: NSAppearance {
        NSAppearance(named: .vibrantLight)!
    }

    /// Returns a vibrant dark appearance.
    public static var vibrantDark: NSAppearance {
        NSAppearance(named: .vibrantDark)!
    }

    /// Returns a high-contrast version of the standard light system appearance.
    public static var accessibilityHighContrastAqua: NSAppearance {
        NSAppearance(named: .accessibilityHighContrastAqua)!
    }

    /// Returns a high-contrast version of the standard dark system appearance.
    public static var accessibilityHighContrastDarkAqua: NSAppearance {
        NSAppearance(named: .accessibilityHighContrastDarkAqua)!
    }

    /// Returns a high-contrast version of the dark vibrant system appearance.
    public static var accessibilityHighContrastVibrantDark: NSAppearance {
        NSAppearance(named: .accessibilityHighContrastVibrantDark)!
    }

    /// Returns a high-contrast version of the light vibrant system appearance.
    public static var accessibilityHighContrastVibrantLight: NSAppearance {
        NSAppearance(named: .accessibilityHighContrastVibrantLight)!
    }

    /// A Boolean value that indicates whether the appearance is light.
    public var isLight: Bool {
        base.bestMatch(from: [.darkAqua, .aqua]) == .aqua
    }

    /// A Boolean value that indicates whether the appearance is dark.
    public var isDark: Bool {
        base.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
    }
}

#endif
