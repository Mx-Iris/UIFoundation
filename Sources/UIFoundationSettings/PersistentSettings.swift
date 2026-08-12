#if Settings && os(macOS)

import Foundation

/// A settings model that knows where its own store lives.
///
/// The static store is what lets ``AppSettings`` find the settings from a
/// property wrapper — and what lets code outside SwiftUI reach them through the
/// same door, via ``current``.
///
/// - Important: Conformers **must be value types**. See ``SettingsStore`` for
///   what breaks otherwise.
@available(macOS 14.0, *)
public protocol PersistentSettings: Codable, Sendable {
    @MainActor static var store: SettingsStore<Self> { get }
}

@available(macOS 14.0, *)
extension PersistentSettings {
    /// The current settings — shorthand for `store.value`.
    ///
    /// Read and write these from anywhere on the main actor:
    ///
    /// ```swift
    /// if Settings.current.updates.automaticallyChecks { … }
    /// Settings.current.theme.fontSize += 1
    /// ```
    ///
    /// - Important: Assign through `Settings.current` directly. Copying it into
    ///   a local (`var copy = Settings.current`), mutating that, and forgetting
    ///   to assign back changes nothing and reports no error.
    @MainActor
    public static var current: Self {
        get { store.value }
        set { store.value = newValue }
    }
}

#endif
