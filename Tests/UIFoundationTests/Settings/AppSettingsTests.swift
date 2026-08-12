#if Settings && os(macOS)

import Foundation
import SwiftUI
import Testing

@testable import UIFoundationSettings

/// Counts writes so a projected-value edit can be shown to persist.
private actor WriteCountingStorage: SettingsStorage {
    private(set) var saveCount = 0
    private var storedData: Data?

    func save(_ data: Data) async throws {
        saveCount += 1
        storedData = data
    }

    func load() async throws -> Data {
        guard let storedData else { throw FileSystemSettingsStorage.LoadError.noStoredData }
        return storedData
    }

    func decodedValue<Value: Decodable>(as type: Value.Type) throws -> Value? {
        guard let storedData else { return nil }
        return try JSONDecoder().decode(Value.self, from: storedData)
    }
}

@available(macOS 14.0, *)
private struct WrapperTestSettings: PersistentSettings, Equatable {
    struct General: Codable, Sendable, Equatable {
        var depth = 3
        var isEnabled = false
    }

    var general = General()
    var title = "untitled"

    @MainActor
    static let storage = WriteCountingStorage()

    @MainActor
    static let store = SettingsStore(
        defaultValue: WrapperTestSettings(),
        storage: storage,
        autoSaveDelay: .milliseconds(40)
    )
}

@MainActor
private func waitUntil(
    attempts: Int = 300,
    _ condition: @MainActor () async -> Bool
) async -> Bool {
    for _ in 0 ..< attempts {
        if await condition() { return true }
        try? await Task.sleep(for: .milliseconds(10))
    }
    return await condition()
}

/// Covers the property wrapper's two doors into the store.
///
/// The projected value matters most: it is the one every `Toggle` and `Picker`
/// on a settings page writes through, and the auto-save contract depends on the
/// write landing as an assignment to `store.value` rather than an in-place
/// mutation somewhere below it. Nothing else in the suite exercises that path.
@MainActor
@Suite("AppSettings")
struct AppSettingsTests {

    private func resetStore() {
        guard #available(macOS 14.0, *) else { return }
        WrapperTestSettings.store.value = WrapperTestSettings()
    }

    @Test("the wrapped value reads and writes through the key path")
    func wrappedValueRoundTrips() {
        guard #available(macOS 14.0, *) else { return }
        resetStore()

        let setting = AppSettings<WrapperTestSettings, Int>(\.general.depth)
        #expect(setting.wrappedValue == 3)

        setting.wrappedValue = 9
        #expect(WrapperTestSettings.current.general.depth == 9)
        #expect(setting.wrappedValue == 9)
    }

    @Test("a section key path exposes the whole section")
    func sectionKeyPath() {
        guard #available(macOS 14.0, *) else { return }
        resetStore()

        let setting = AppSettings<WrapperTestSettings, WrapperTestSettings.General>(\.general)
        setting.wrappedValue.isEnabled = true

        #expect(WrapperTestSettings.current.general.isEnabled)
        #expect(WrapperTestSettings.current.general.depth == 3, "editing one field disturbed another")
    }

    @Test("the projected binding reads the current value")
    func projectedBindingReads() {
        guard #available(macOS 14.0, *) else { return }
        resetStore()
        WrapperTestSettings.current.title = "read me"

        let setting = AppSettings<WrapperTestSettings, String>(\.title)
        #expect(setting.projectedValue.wrappedValue == "read me")
    }

    @Test("writing through the projected binding reaches the store")
    func projectedBindingWrites() {
        guard #available(macOS 14.0, *) else { return }
        resetStore()

        let setting = AppSettings<WrapperTestSettings, Bool>(\.general.isEnabled)
        setting.projectedValue.wrappedValue = true

        #expect(WrapperTestSettings.current.general.isEnabled)
    }

    /// The contract that makes the whole design work: a binding write has to
    /// land as an assignment to `store.value`, because that is what `didSet`
    /// hangs the auto-save off. A binding that mutated something below `value`
    /// in place would read back correctly and silently never persist.
    @Test("a projected-binding write is persisted")
    func projectedBindingWritePersists() async {
        guard #available(macOS 14.0, *) else { return }
        resetStore()
        _ = await waitUntil { await WrapperTestSettings.storage.saveCount > 0 }
        let saveCountBefore = await WrapperTestSettings.storage.saveCount

        let setting = AppSettings<WrapperTestSettings, Int>(\.general.depth)
        setting.projectedValue.wrappedValue = 42

        let didSave = await waitUntil { await WrapperTestSettings.storage.saveCount > saveCountBefore }
        #expect(didSave, "a write through the projected binding never reached the disk")

        let stored = try? await WrapperTestSettings.storage.decodedValue(as: WrapperTestSettings.self)
        #expect(stored?.general.depth == 42)
    }

    @Test("the binding writes back only the addressed field")
    func projectedBindingIsNarrow() {
        guard #available(macOS 14.0, *) else { return }
        resetStore()
        WrapperTestSettings.current.title = "keep me"

        let setting = AppSettings<WrapperTestSettings, Int>(\.general.depth)
        setting.projectedValue.wrappedValue = 7

        #expect(WrapperTestSettings.current.general.depth == 7)
        #expect(WrapperTestSettings.current.title == "keep me", "the binding clobbered a sibling field")
        #expect(!WrapperTestSettings.current.general.isEnabled)
    }
}

#endif
