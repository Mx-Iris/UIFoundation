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

/// Light / dark switch used by ``IDEIcon`` for selecting adaptive colors.
public enum IDEIconColorScheme: Hashable, CaseIterable, Sendable {
    case light
    case dark
}

/// The blueprint for an IDE icon.

public struct IDEIcon: Hashable {
    /// The icon's content.
    public var content: IDEIconContent

    /// The icon's color.
    public var color: IDEIconColor

    /// The icon's color scheme.
    public var colorScheme: IDEIconColorScheme

    /// The icon's style.
    public var style: IDEIconStyle

    /// The icon's size.
    public var size: CGFloat

    /// Creates a new blueprint for an IDE icon.
    public init(_ text: String, color: IDEIconColor? = nil, colorScheme: IDEIconColorScheme? = nil, style: IDEIconStyle? = nil, size: CGFloat? = nil) {
        self.init(.text(text), color: color, colorScheme: colorScheme, style: style, size: size)
    }

    /// Creates a new blueprint for an IDE icon.
    public init(image: String, bundle: Bundle? = nil, color: IDEIconColor? = nil, colorScheme: IDEIconColorScheme? = nil, style: IDEIconStyle? = nil, size: CGFloat? = nil) {
        self.init(.image(image, bundle: bundle), color: color, colorScheme: colorScheme, style: style, size: size)
    }

    /// Creates a new blueprint for an IDE icon.
    @available(macOS 11.0, *)
    public init(systemImage: String, color: IDEIconColor? = nil, colorScheme: IDEIconColorScheme? = nil, style: IDEIconStyle? = nil, size: CGFloat? = nil) {
        self.init(.systemImage(systemImage), color: color, colorScheme: colorScheme, style: style, size: size)
    }

    /// Creates a new blueprint for an IDE icon.
    private init(_ content: IDEIconContent, color: IDEIconColor? = nil, colorScheme: IDEIconColorScheme? = nil, style: IDEIconStyle? = nil, size: CGFloat? = nil) {
        self.content = content
        self.color = color ?? .purple
        self.colorScheme = colorScheme ?? .dark
        self.style = style ?? .default
        self.size = size ?? IDEIconSize.regular
    }
}

/// Specifies the content of an IDE icon.
public enum IDEIconContent: Hashable {
    /// Text content in the form of a string.
    case text(String)

    /// Image content.
    case image(String, bundle: Bundle?)

    /// System image content.
    case systemImage(String)
}

/// Specifies the style of an IDE icon.
public enum IDEIconStyle: Int, CaseIterable, Sendable {
    case `default`
    case outline
    case simple
    case simpleHighlighted
}

extension IDEIconStyle {
    var fontWeight: NSUIFont.Weight {
        switch self {
        case .simple: return .semibold
        default: return .medium
        }
    }

    var symbolFontWeight: NSUIFont.Weight {
        switch self {
        case .simple: return .semibold
        default: return .regular
        }
    }

    #if canImport(UIKit)
    var symbolWeight: UIImage.SymbolWeight {
        switch self {
        case .simple: return .semibold
        default: return .regular
        }
    }
    #endif
}

#endif
