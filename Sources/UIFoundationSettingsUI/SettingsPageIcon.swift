#if Settings && os(macOS)

import AppKit
import SwiftUI

/// The icon the settings sidebar draws next to a page title — a rounded tinted
/// badge, or a bare glyph for ``SettingsPage/Icon/plainSymbol(_:tint:)``.
@available(macOS 14.0, *)
public struct SettingsPageIcon: View {
    private let icon: SettingsPage.Icon
    private let size: CGFloat

    public init(_ icon: SettingsPage.Icon, size: CGFloat = 20) {
        self.icon = icon
        self.size = size
    }

    public var body: some View {
        switch icon {
        case .plainSymbol(let name, let tint):
            Self.image(named: name)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .foregroundStyle(tint ?? .primary)
                .frame(width: size, height: size)
        case .symbol,
             .text,
             .image:
            badge
        }
    }

    private var badge: some View {
        RoundedRectangle(cornerRadius: size / 4, style: .continuous)
            .fill(background)
            .overlay { badgeContent }
            .clipShape(RoundedRectangle(cornerRadius: size / 4, style: .continuous))
            .shadow(color: .black.opacity(0.25), radius: size / 40, y: size / 40)
            .frame(width: size, height: size)
    }

    @ViewBuilder
    private var badgeContent: some View {
        switch icon {
        case .symbol(let name, _):
            Self.image(named: name)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .foregroundStyle(.primary)
                .padding(size / 8)
        case .text(let text, let textColor):
            Text(text)
                .font(.system(size: size * 0.65))
                .foregroundStyle(textColor ?? .primary)
        case .image(let image):
            image
                .resizable()
                .aspectRatio(contentMode: .fill)
        case .plainSymbol:
            // Handled above; never reached.
            EmptyView()
        }
    }

    private var background: AnyShapeStyle {
        switch icon {
        case .symbol(_, let tint),
             .text(_, let tint):
            AnyShapeStyle((tint ?? .accentColor).gradient)
        case .image:
            AnyShapeStyle(.regularMaterial)
        case .plainSymbol:
            AnyShapeStyle(.clear)
        }
    }

    /// Prefers the SF Symbol, falling back to an asset catalog image of the
    /// same name — so a host can ship its own glyph for a name the running
    /// system does not know.
    private static func image(named name: String) -> Image {
        if NSImage(systemSymbolName: name, accessibilityDescription: nil) != nil {
            Image(systemName: name)
        } else {
            Image(name)
        }
    }
}

#endif
