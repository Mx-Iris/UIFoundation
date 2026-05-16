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
public enum IDEIconColor: String, Sendable {
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
    case indigo
    case mint
    case cyan
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
    return NSUIColor(red: red, green: green, blue: blue, alpha: alpha)
}

@inline(__always)
private func grayscale(_ white: CGFloat, _ alpha: CGFloat = 1) -> NSUIColor {
    return NSUIColor(white: white, alpha: alpha)
}

@inline(__always)
private func dynamicColor(light: NSUIColor, dark: NSUIColor) -> NSUIColor {
    #if canImport(AppKit) && !targetEnvironment(macCatalyst)
    return NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? dark : light
    }
    #elseif canImport(UIKit)
    return UIColor { traits in
        traits.userInterfaceStyle == .dark ? dark : light
    }
    #else
    return light
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
        case .indigo: return AdaptiveColor(
                light: rgb(0.498, 0.494, 0.925),
                dark: rgb(0.106, 0.103, 0.376)
            )
        case .mint: return AdaptiveColor(
                light: rgb(0.227, 0.821, 0.789),
                dark: rgb(0.018, 0.281, 0.268)
            )
        case .cyan: return AdaptiveColor(
                light: rgb(0.380, 0.751, 0.952),
                dark: rgb(0.043, 0.243, 0.345)
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
        case .indigo: return AdaptiveColor(
                light: rgb(0.298, 0.290, 0.785),
                dark: rgb(0.408, 0.400, 0.901)
            )
        case .mint: return AdaptiveColor(
                light: rgb(0.013, 0.621, 0.595),
                dark: rgb(0.122, 0.781, 0.745)
            )
        case .cyan: return AdaptiveColor(
                light: rgb(0.118, 0.601, 0.860),
                dark: rgb(0.211, 0.701, 0.918)
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
        case .blue: return .systemBlue
        case .brown: return .systemBrown
        case .gray: return .systemGray
        case .green: return .systemGreen
        case .orange: return .systemOrange
        case .pink: return .systemPink
        case .purple: return .systemPurple
        case .red: return .systemRed
        case .teal: return .systemTeal
        case .yellow: return .systemYellow
        case .indigo: return .systemIndigo
        case .mint:
            if #available(macOS 12.0, iOS 15.0, tvOS 15.0, *) {
                return .systemMint
            }
            return dynamicColor(
                light: rgb(0.000, 0.784, 0.702),
                dark: rgb(0.000, 0.855, 0.765)
            )
        case .cyan:
            if #available(macOS 12.0, iOS 15.0, tvOS 15.0, *) {
                return .systemCyan
            }
            return dynamicColor(
                light: rgb(0.000, 0.753, 0.910),
                dark: rgb(0.235, 0.827, 0.996)
            )
        }
    }
}

#endif
