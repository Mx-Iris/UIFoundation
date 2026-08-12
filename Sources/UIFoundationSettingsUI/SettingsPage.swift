#if Settings && os(macOS)

import SwiftUI

/// One entry in the settings window's sidebar, paired with the view it shows.
///
/// ```swift
/// SettingsPage("General", symbol: "gearshape") { GeneralPage() }
/// SettingsPage("Theme", symbol: "paintpalette", tint: .purple) { ThemePage() }
/// ```
@available(macOS 14.0, *)
public struct SettingsPage: Identifiable {
    /// What the sidebar draws next to a page title.
    ///
    /// The first three shapes draw a rounded, tinted badge in the System
    /// Settings manner; ``plainSymbol(_:tint:)`` draws the glyph on its own.
    ///
    /// - Note: New cases may be added; do not exhaustively switch over this
    ///   from outside the module.
    public enum Icon {
        /// An SF Symbol on a tinted badge, falling back to an asset of the same
        /// name when the symbol does not exist on the running system.
        case symbol(String, tint: Color?)
        /// Short text on a tinted badge — an abbreviation or a single glyph.
        case text(String, tint: Color?)
        /// A ready-made image, drawn edge to edge over a material backing.
        case image(Image)
        /// A bare SF Symbol: no badge, no shadow. `tint` defaults to the
        /// primary label colour, so the sidebar reads as a plain icon list
        /// rather than a grid of coloured tiles.
        ///
        /// Note this is not the same as passing `.clear` to ``symbol(_:tint:)``:
        /// that clears the badge but keeps its shadow, which then falls on the
        /// glyph itself.
        case plainSymbol(String, tint: Color? = nil)
    }

    /// Identifies the page for selection. Defaults to the title, so pass an
    /// explicit one whenever the title is localized — otherwise the selection
    /// breaks the moment the app runs in another language.
    public let id: String
    public let title: String
    public let icon: Icon

    private let contentBuilder: @MainActor () -> AnyView

    public init<Content: View>(
        _ title: String,
        id: String? = nil,
        symbol: String,
        tint: Color? = nil,
        @ViewBuilder content: @MainActor @escaping () -> Content
    ) {
        self.init(title, id: id, icon: .symbol(symbol, tint: tint), content: content)
    }

    /// A page whose sidebar entry is a bare glyph rather than a tinted badge.
    public init<Content: View>(
        _ title: String,
        id: String? = nil,
        plainSymbol: String,
        tint: Color? = nil,
        @ViewBuilder content: @MainActor @escaping () -> Content
    ) {
        self.init(title, id: id, icon: .plainSymbol(plainSymbol, tint: tint), content: content)
    }

    public init<Content: View>(
        _ title: String,
        id: String? = nil,
        icon: Icon,
        @ViewBuilder content: @MainActor @escaping () -> Content
    ) {
        self.id = id ?? title
        self.title = title
        self.icon = icon
        self.contentBuilder = { AnyView(content()) }
    }

    @MainActor
    var content: AnyView { contentBuilder() }
}

/// Builds the settings window's page list.
@available(macOS 14.0, *)
@resultBuilder
public enum SettingsPageBuilder {
    public static func buildBlock(_ components: [SettingsPage]...) -> [SettingsPage] {
        components.flatMap(\.self)
    }

    public static func buildExpression(_ expression: SettingsPage) -> [SettingsPage] {
        [expression]
    }

    public static func buildExpression(_ expression: [SettingsPage]) -> [SettingsPage] {
        expression
    }

    public static func buildOptional(_ component: [SettingsPage]?) -> [SettingsPage] {
        component ?? []
    }

    public static func buildEither(first component: [SettingsPage]) -> [SettingsPage] {
        component
    }

    public static func buildEither(second component: [SettingsPage]) -> [SettingsPage] {
        component
    }

    public static func buildArray(_ components: [[SettingsPage]]) -> [SettingsPage] {
        components.flatMap(\.self)
    }
}

#endif
