#if Settings && os(macOS)

import Foundation
import Observation

/// An observable reference model whose changes a ``SettingsStore`` can persist.
///
/// Observation is access-driven: there is no wildcard operation for observing
/// every property on an object. Implement ``accessPersistedValues()`` by
/// reading each property encoded to storage. The store calls the method inside
/// `withObservationTracking` and automatically re-arms after every mutation.
///
/// ```swift
/// @Observable
/// final class Settings: SettingsModel {
///     var general = General()
///     var appearance = Appearance()
///
///     func accessPersistedValues() {
///         _ = general
///         _ = appearance
///     }
/// }
/// ```
///
/// - Important: Keep this list in sync with the model's encoded properties. A
///   property omitted from the method still encodes during another save, but a
///   change to that property alone cannot trigger auto-save.
@available(macOS 14.0, *)
public protocol SettingsModel: AnyObject, Codable, Observable {
    @MainActor
    func accessPersistedValues()
}

/// A ``SettingsModel`` that publishes the single store used by its application.
///
/// The static store lets ``AppSettings`` and non-SwiftUI code reach the same
/// model without an environment object or dependency container.
@available(macOS 14.0, *)
public protocol PersistentSettings: SettingsModel {
    @MainActor
    static var store: SettingsStore<Self> { get }
}

@available(macOS 14.0, *)
extension PersistentSettings {
    /// The current settings object — shorthand for `store.value`.
    ///
    /// Read or mutate it from the main actor:
    ///
    /// ```swift
    /// if Settings.current.updates.automaticallyChecks { … }
    /// Settings.current.theme.fontSize += 1
    /// ```
    @MainActor
    public static var current: Self {
        get { store.value }
        set { store.value = newValue }
    }
}

#endif
