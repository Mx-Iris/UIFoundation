#if Settings && os(macOS)

import Foundation
import Observation

/// Holds an observable settings object and persists it.
///
/// The store observes every property touched by
/// ``SettingsModel/accessPersistedValues()`` and writes the model back to
/// ``SettingsStorage`` a short while after one changes, coalescing bursts into
/// a single write. Hosts never call save after ordinary edits.
///
/// ```swift
/// @Observable
/// final class Settings: PersistentSettings {
///     var general = General()
///     var appearance = Appearance()
///
///     func accessPersistedValues() {
///         _ = general
///         _ = appearance
///     }
///
///     @MainActor
///     static let store = SettingsStore(
///         defaultValue: Settings(),
///         storage: FileSystemSettingsStorage(applicationDirectoryName: "MyApp")
///     )
/// }
/// ```
@available(macOS 14.0, *)
@MainActor
@Observable
public final class SettingsStore<Value: SettingsModel> {
    /// What a ``load()`` attempt did, so hosts can log it. Ignorable.
    public enum LoadOutcome {
        /// Stored settings were decoded and adopted.
        case loaded
        /// Nothing stored yet; the default value is still in effect.
        case noStoredData
        /// Something was stored but could not be read or decoded; the default
        /// value is still in effect and the stored data is left untouched.
        case failed(any Error)
    }

    /// The current settings object.
    ///
    /// Replacing it updates observers and moves persistence observation to the
    /// replacement. Mutating one of its `@Observable` properties preserves
    /// property-level observation granularity.
    public var value: Value

    @ObservationIgnored
    private let storage: any SettingsStorage

    @ObservationIgnored
    private let autoSaveDelay: Duration

    @ObservationIgnored
    private var autoSaveTask: Task<Void, Never>?

    /// Identifies the currently armed one-shot Observation registration. A
    /// newer registration makes callbacks from a replaced model harmless.
    @ObservationIgnored
    private var observationGeneration = 0

    /// - Parameters:
    ///   - defaultValue: Used until ``load()`` replaces it, and kept as-is if
    ///     there is nothing stored.
    ///   - storage: Where to persist.
    ///   - autoSaveDelay: How long to wait after the last change before
    ///     writing. Changes inside one delay window collapse into one write.
    public init(
        defaultValue: Value,
        storage: any SettingsStorage,
        autoSaveDelay: Duration = .seconds(1)
    ) {
        value = defaultValue
        self.storage = storage
        self.autoSaveDelay = autoSaveDelay
        armPersistenceObservation()
    }

    /// Reads stored settings and adopts them, keeping the default value if
    /// there is nothing to read.
    ///
    /// Call once at launch. Run any data migration *after* this returns — the
    /// replacement model is already being observed, so a migration edit takes
    /// the normal auto-save path.
    @discardableResult
    public func load() async -> LoadOutcome {
        let data: Data
        do {
            data = try await storage.load()
        } catch FileSystemSettingsStorage.LoadError.noStoredData {
            return .noStoredData
        } catch {
            return .failed(error)
        }

        do {
            value = try JSONDecoder().decode(Value.self, from: data)
            // Re-arm synchronously before returning. The callback registered on
            // the old object is deferred to the main actor and will discard
            // itself after seeing the newer generation.
            armPersistenceObservation()
            return .loaded
        } catch {
            return .failed(error)
        }
    }

    /// Writes immediately instead of waiting out the auto-save delay, and
    /// cancels the pending write. Use when the app is about to terminate.
    public func save() async throws {
        autoSaveTask?.cancel()
        autoSaveTask = nil

        // A property mutation may have fired Observation's callback but not yet
        // run its deferred main-actor work. Advancing the generation makes that
        // stale callback a no-op, so it cannot schedule a duplicate save after
        // this explicit one.
        armPersistenceObservation()
        try await storage.save(JSONEncoder().encode(value))
    }

    private func armPersistenceObservation() {
        observationGeneration += 1
        let armedGeneration = observationGeneration

        withObservationTracking {
            // Reading `value` observes whole-object replacement. The model hook
            // then reads each persisted @Observable property so in-place edits
            // are observed without collapsing business listeners onto one root
            // value.
            value.accessPersistedValues()
        } onChange: { [weak self] in
            // Observation calls onChange from willSet. Hop to the main actor so
            // the mutation commits before saving and before the one-shot
            // registration is installed again.
            Task { @MainActor [weak self] in
                guard let self, self.observationGeneration == armedGeneration else { return }
                self.scheduleAutoSave()
                self.armPersistenceObservation()
            }
        }
    }

    private func scheduleAutoSave() {
        autoSaveTask?.cancel()
        autoSaveTask = Task { [autoSaveDelay] in
            try? await Task.sleep(for: autoSaveDelay)
            guard !Task.isCancelled else { return }
            try? await save()
        }
    }
}

#endif
