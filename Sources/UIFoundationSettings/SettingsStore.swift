#if Settings && os(macOS)

import Foundation
import Observation

/// Holds an application's settings and persists them.
///
/// The store owns one value and writes it back to ``SettingsStorage`` a short
/// while after it changes, coalescing bursts into a single write. Hosts never
/// call save: mutating the value is enough.
///
/// ```swift
/// struct Settings: PersistentSettings {
///     var general = General()
///
///     @MainActor
///     static let store = SettingsStore(
///         defaultValue: Settings(),
///         storage: FileSystemSettingsStorage(applicationDirectoryName: "MyApp")
///     )
/// }
/// ```
///
/// - Important: `Value` **must be a value type**. Auto-saving hangs off
///   `value`'s `didSet`, which only fires when the property itself is assigned.
///   With a struct, `store.value.general.x = 1` reads-modifies-writes the whole
///   property and therefore saves; with a class it mutates the object in place,
///   `didSet` stays silent, and **settings are never written to disk**. Nothing
///   in the type system catches this.
@available(macOS 14.0, *)
@MainActor
@Observable
public final class SettingsStore<Value: Codable & Sendable> {
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

    /// The current settings. Assigning anything reachable from here schedules a
    /// save.
    public var value: Value {
        didSet { scheduleAutoSave() }
    }

    @ObservationIgnored
    private let storage: any SettingsStorage

    @ObservationIgnored
    private let autoSaveDelay: Duration

    @ObservationIgnored
    private var autoSaveTask: Task<Void, Never>?

    /// Suppresses the auto-save that adopting a freshly loaded value would
    /// otherwise trigger — writing back what we just read is pure waste.
    @ObservationIgnored
    private var isApplyingStoredValue = false

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
        self.value = defaultValue
        self.storage = storage
        self.autoSaveDelay = autoSaveDelay
    }

    /// Reads stored settings and adopts them, keeping the default value if
    /// there is nothing to read.
    ///
    /// Call once at launch. Run any data migration *after* this returns —
    /// mutating ``value`` there takes the normal path, so the migrated result
    /// gets saved on its own.
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
            let decoded = try JSONDecoder().decode(Value.self, from: data)
            isApplyingStoredValue = true
            value = decoded
            isApplyingStoredValue = false
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
        try await storage.save(JSONEncoder().encode(value))
    }

    private func scheduleAutoSave() {
        guard !isApplyingStoredValue else { return }
        autoSaveTask?.cancel()
        autoSaveTask = Task { [autoSaveDelay] in
            try? await Task.sleep(for: autoSaveDelay)
            guard !Task.isCancelled else { return }
            try? await save()
        }
    }
}

#endif
