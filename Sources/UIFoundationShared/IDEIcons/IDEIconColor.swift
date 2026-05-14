#if IDEIcons

// Ported from https://github.com/freysie/ide-icons (MIT License, Copyright © 2022-2023 Freya Alminde)
// AppKit/UIKit port with all SwiftUI dependencies removed.

import Foundation
import CoreGraphics
import UIFoundationTypealias

#if canImport(AppKit) && !targetEnvironment(macCatalyst)
import AppKit
#endif

#if canImport(UIKit)
import UIKit
#endif

/// Specifies the color of an IDE icon.
public enum IDEIconColor: String, CaseIterable, Sendable {
    case monochrome
    case blue
    case brown
    case gray
    case green
    case orange
    case pink
    case purple
    case red
    case teal
    case yellow
}

/// A pair of light / dark colors selected by ``IDEIconColorScheme``.
public struct AdaptiveColor {
    public let lightColor: NSUIColor
    public let darkColor: NSUIColor

    public init(light: NSUIColor, dark: NSUIColor) {
        self.lightColor = light
        self.darkColor = dark
    }

    public subscript(_ scheme: IDEIconColorScheme) -> NSUIColor {
        switch scheme {
        case .light: return lightColor
        case .dark: return darkColor
        }
    }

    #if canImport(AppKit) && !targetEnvironment(macCatalyst)
    public var nsColor: NSColor {
        let light = lightColor
        let dark = darkColor
        return NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? dark : light
        }
    }
    #endif
}

@inline(__always)
private func rgb(_ red: CGFloat, _ green: CGFloat, _ blue: CGFloat, _ alpha: CGFloat = 1) -> NSUIColor {
    #if canImport(AppKit) && !targetEnvironment(macCatalyst)
    return NSColor(srgbRed: red, green: green, blue: blue, alpha: alpha)
    #else
    return UIColor(red: red, green: green, blue: blue, alpha: alpha)
    #endif
}

@inline(__always)
private func grayscale(_ white: CGFloat, _ alpha: CGFloat = 1) -> NSUIColor {
    #if canImport(AppKit) && !targetEnvironment(macCatalyst)
    return NSColor(white: white, alpha: alpha)
    #else
    return UIColor(white: white, alpha: alpha)
    #endif
}

extension IDEIconColor {
    public var backgroundColor: AdaptiveColor {
        switch self {
        case .monochrome: return AdaptiveColor(
                light: .white,
                dark: .black
            )
        case .blue: return AdaptiveColor(
                light: rgb(0.291, 0.588, 0.998),
                dark: rgb(0.01, 0.199, 0.417)
            )
        case .brown: return AdaptiveColor(
                light: rgb(0.714, 0.622, 0.513),
                dark: rgb(0.271, 0.217, 0.15)
            )
        case .gray: return AdaptiveColor(
                light: rgb(0.651, 0.651, 0.667),
                dark: rgb(0.235, 0.235, 0.243)
            )
        case .green: return AdaptiveColor(
                light: rgb(0.031, 0.763, 0.394),
                dark: rgb(0.037, 0.281, 0.075)
            )
        case .orange: return AdaptiveColor(
                light: rgb(0.94, 0.623, 0.283),
                dark: rgb(0.378, 0.223, 0.006)
            )
        case .pink: return AdaptiveColor(
                light: rgb(0.717, 0.309, 0.69),
                dark: rgb(0.274, 0.082, 0.286)
            )
        case .purple: return AdaptiveColor(
                light: rgb(0.704, 0.452, 0.831),
                dark: rgb(0.302, 0.128, 0.393)
            )
        case .red: return AdaptiveColor(
                light: rgb(1, 0.403, 0.389),
                dark: rgb(0.415, 0.089, 0.072)
            )
        case .teal: return AdaptiveColor(
                light: rgb(0.374, 0.684, 0.748),
                dark: rgb(0.123, 0.254, 0.292)
            )
        case .yellow: return AdaptiveColor(
                light: rgb(0.952, 0.85, 0.501),
                dark: rgb(0.384, 0.298, 0.043)
            )
        }
    }

    public var borderColor: AdaptiveColor {
        switch self {
        case .monochrome: return AdaptiveColor(
                light: rgb(0.443, 0.443, 0.462),
                dark: rgb(0.568, 0.564, 0.592)
            )
        case .blue: return AdaptiveColor(
                light: rgb(0.051, 0.439, 0.96),
                dark: rgb(0.077, 0.599, 0.999)
            )
        case .brown: return AdaptiveColor(
                light: rgb(0.636, 0.517, 0.37),
                dark: rgb(0.675, 0.556, 0.409)
            )
        case .gray: return AdaptiveColor(
                light: rgb(0.596, 0.596, 0.616),
                dark: rgb(0.557, 0.556, 0.577)
            )
        case .green: return AdaptiveColor(
                light: rgb(0.103, 0.701, 0.197),
                dark: rgb(0.157, 0.705, 0.238)
            )
        case .orange: return AdaptiveColor(
                light: rgb(0.921, 0.521, 0),
                dark: rgb(0.921, 0.572, 0.028)
            )
        case .pink: return AdaptiveColor(
                light: rgb(0.647, 0.137, 0.615),
                dark: rgb(0.807, 0.231, 0.835)
            )
        case .purple: return AdaptiveColor(
                light: rgb(0.623, 0.293, 0.789),
                dark: rgb(0.801, 0.394, 0.999)
            )
        case .red: return AdaptiveColor(
                light: rgb(0.999, 0.23, 0.19),
                dark: rgb(0.998, 0.272, 0.228)
            )
        case .teal: return AdaptiveColor(
                light: rgb(0.161, 0.601, 0.682),
                dark: rgb(0.339, 0.64, 0.721)
            )
        case .yellow: return AdaptiveColor(
                light: rgb(0.749, 0.658, 0.349),
                dark: rgb(0.929, 0.752, 0.215)
            )
        }
    }

    public var outlineColor: AdaptiveColor {
        AdaptiveColor(
            light: grayscale(0.96, 0.75),
            dark: grayscale(0, 0.5)
        )
    }

    public var simpleColor: NSUIColor {
        switch self {
        case .monochrome: return grayscale(0.85)
        case .blue: return rgb(0, 0.478, 1)
        case .brown: return rgb(0.635, 0.518, 0.369)
        case .gray: return rgb(0.557, 0.557, 0.576)
        case .green: return rgb(0.204, 0.78, 0.349)
        case .orange: return rgb(1, 0.584, 0)
        case .pink: return rgb(1, 0.176, 0.333)
        case .purple: return rgb(0.686, 0.322, 0.871)
        case .red: return rgb(1, 0.231, 0.188)
        case .teal: return rgb(0.353, 0.784, 0.98)
        case .yellow: return rgb(1, 0.584, 0)
        }
    }
}

#endif
