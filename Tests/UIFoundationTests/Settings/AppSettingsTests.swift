#if Settings && os(macOS)

import Foundation
import Observation
import SwiftUI
import Testing

@testable import UIFoundationSettings
@testable import UIFoundationSettingsUI

/// Counts writes so a projected-value edit can be shown to persist.
private final class WriteCountingStorage: SettingsStorage, @unchecked Sendable {
    private let lock = NSLock()
    private var recordedSaveCount = 0
    private var storedData: Data?

    var saveCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return recordedSaveCount
    }

    func save(_ data: Data) throws {
        lock.lock()
        defer { lock.unlock() }
        recordedSaveCount += 1
        storedData = data
    }

    func load() throws -> Data {
        lock.lock()
        defer { lock.unlock() }
        guard let storedData else { throw FileSystemSettingsStorage.LoadError.noStoredData }
        return storedData
    }

    func decodedValue<Value: Decodable>(as type: Value.Type) throws -> Value? {
        lock.lock()
        defer { lock.unlock() }
        guard let storedData else { return nil }
        return try JSONDecoder().decode(Value.self, from: storedData)
    }
}

@available(macOS 14.0, *)
@Observable
private final class WrapperTestSettings: PersistentSettings {
    struct General: Codable, Sendable, Equatable {
        var depth = 3
        var isEnabled = false
    }

    var general = General()
    var title = "untitled"

    init() {}

    @MainActor
    func accessPersistedValues() {
        _ = general
        _ = title
    }

    private enum CodingKeys: String, CodingKey {
        case general
        case title
    }

    required init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        general = try container.decodeIfPresent(General.self, forKey: .general) ?? General()
        title = try container.decodeIfPresent(String.self, forKey: .title) ?? "untitled"
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(general, forKey: .general)
        try container.encode(title, forKey: .title)
    }

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
/// on a settings page writes through. The persistence contract depends on that
/// write reaching an observed property of the current settings object.
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

    @Test("a projected-binding write is persisted")
    func projectedBindingWritePersists() async {
        guard #available(macOS 14.0, *) else { return }
        resetStore()
        _ = await waitUntil { WrapperTestSettings.storage.saveCount > 0 }
        let saveCountBefore = WrapperTestSettings.storage.saveCount

        let setting = AppSettings<WrapperTestSettings, Int>(\.general.depth)
        setting.projectedValue.wrappedValue = 42

        let didSave = await waitUntil { WrapperTestSettings.storage.saveCount > saveCountBefore }
        #expect(didSave, "a write through the projected binding never reached the disk")

        let stored = try? WrapperTestSettings.storage.decodedValue(as: WrapperTestSettings.self)
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
