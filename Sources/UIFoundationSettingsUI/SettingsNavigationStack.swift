#if Settings && (os(iOS) || os(visionOS))

import SwiftUI

/// The settings pages as iOS presents them: a list of the pages, each row
/// pushing its content, with a Done button on the list.
///
/// The counterpart of the macOS settings window's sidebar. A UIKit app
/// presents it through ``SettingsViewController``; a SwiftUI app can put it
/// in a sheet directly:
///
/// ```swift
/// .sheet(isPresented: $showsSettings) {
///     SettingsNavigationStack {
///         SettingsPage("Theme", plainSymbol: "paintpalette") { ThemeSettingsView() }
///     }
/// }
/// ```
@available(iOS 17.0, macCatalyst 17.0, visionOS 1.0, *)
public struct SettingsNavigationStack: View {
    /// The size the list draws each page's icon at — the size of the icons in
    /// the system Settings app's list.
    static let rowIconSize: CGFloat = 29

    private let title: String
    private let pages: [SettingsPage]
    private let onDone: (() -> Void)?

    @Environment(\.dismiss) private var dismiss

    /// - Parameters:
    ///   - title: The list's navigation title. Localize this in the host
    ///     application.
    ///   - onDone: What the Done button does. When `nil`, it dismisses the
    ///     presentation the stack is in.
    ///   - pages: The list's rows, in order.
    public init(
        title: String = "Settings",
        onDone: (() -> Void)? = nil,
        @SettingsPageBuilder pages: () -> [SettingsPage]
    ) {
        self.init(title: title, onDone: onDone, pages: pages())
    }

    init(title: String, onDone: (() -> Void)?, pages: [SettingsPage]) {
        self.title = title
        self.onDone = onDone
        self.pages = pages
    }

    public var body: some View {
        NavigationStack {
            List(pages) { page in
                NavigationLink(value: page.id) {
                    Label {
                        Text(page.title)
                    } icon: {
                        SettingsPageIcon(page.icon, size: Self.rowIconSize)
                    }
                }
            }
            .navigationTitle(title)
            .navigationDestination(for: SettingsPage.ID.self) { pageID in
                if let page = pages.first(where: { $0.id == pageID }) {
                    page.content
                        .navigationTitle(page.title)
                        .navigationBarTitleDisplayMode(.inline)
                }
            }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        if let onDone {
                            onDone()
                        } else {
                            dismiss()
                        }
                    } label: {
                        // `bundle: #bundle`: without it the lookup goes to
                        // `Bundle.main` and silently renders the key.
                        Text("Done", bundle: #bundle, comment: "Button that closes the settings presented on iOS.")
                    }
                }
            }
        }
    }
}

#endif
