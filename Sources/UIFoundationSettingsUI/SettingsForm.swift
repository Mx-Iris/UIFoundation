#if Settings && (os(macOS) || os(iOS) || os(visionOS))

import SwiftUI

/// A settings page's body: a grouped `Form`, matching System Settings.
///
/// ```swift
/// SettingsForm {
///     Section {
///         Toggle("Check for Updates Automatically", isOn: $automaticallyChecks)
///     } header: {
///         Text("Updates")
///     }
/// }
/// ```
@available(macOS 14.0, iOS 17.0, macCatalyst 17.0, visionOS 1.0, *)
public struct SettingsForm<Content: View>: View {
    @ViewBuilder private let content: Content

    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    public var body: some View {
        Form {
            content
        }
        .formStyle(.grouped)
    }
}

#endif
