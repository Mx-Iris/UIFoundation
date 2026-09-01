#if Settings && os(macOS)

import Foundation
import Observation
import Testing

@testable import UIFoundationSettings

/// Records every write so tests can count them, and plays back the last one.
///
/// Implements only the synchronous `SettingsStorage` pair — the synchronous
/// methods witness the async requirements too, which is exactly the
/// conformance shape real storages use.
private final class RecordingStorage: SettingsStorage, @unchecked Sendable {
    private let lock = NSLock()
    private var recordedSaveCount = 0
    private var storedData: Data?

    init(initialData: Data? = nil) {
        self.storedData = initialData
    }

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

@Observable
private final class DemoSettings: SettingsModel, Equatable {
    struct General: Codable, Sendable, Equatable {
        var depth = 3
        var isEnabled = false
    }

    var general = General()
    var title = "untitled"

    init(general: General = General(), title: String = "untitled") {
        self.general = general
        self.title = title
    }

    @MainActor
    func accessPersistedValues() {
        _ = general
        _ = title
    }

    static func == (left: DemoSettings, right: DemoSettings) -> Bool {
        left.general == right.general && left.title == right.title
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
}

private final class ObservationChangeRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var recordedChangeCount = 0

    var changeCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return recordedChangeCount
    }

    func recordChange() {
        lock.lock()
        recordedChangeCount += 1
        lock.unlock()
    }
}

/// Long enough for the debounce to elapse, short enough not to drag the suite.
private let autoSaveDelay = Duration.milliseconds(40)

/// Polls instead of sleeping a fixed span.
///
/// The auto-save task is main-actor isolated, so a fixed sleep is only long
/// enough when the main thread happens to be idle — and it is not: tests run in
/// parallel, and the settings-window suite drives real window layout on the same
/// actor. A fixed wait made this suite pass alone and fail in a full run.
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

/// Waits out the debounce plus a margin, for assertions that something did
/// *not* happen — where there is no state change to poll for.
@MainActor
private func waitPastAutoSave() async {
    try? await Task.sleep(for: autoSaveDelay * 6)
}

@MainActor
@Suite("SettingsStore")
struct SettingsStoreTests {
    @Test("an observed property ignores an unrelated settings change")
    func propertyObservationIsNarrow() {
        guard #available(macOS 14.0, *) else { return }
        let storage = RecordingStorage()
        let store = SettingsStore(defaultValue: DemoSettings(), storage: storage)
        let changeRecorder = ObservationChangeRecorder()

        withObservationTracking {
            _ = store.value.general
        } onChange: {
            changeRecorder.recordChange()
        }

        store.value.title = "unrelated"
        #expect(changeRecorder.changeCount == 0)

        store.value.general.depth = 8
        #expect(changeRecorder.changeCount == 1)
    }

    @Test("replacing the settings object notifies existing readers")
    func replacementObservationWorks() {
        guard #available(macOS 14.0, *) else { return }
        let storage = RecordingStorage()
        let store = SettingsStore(defaultValue: DemoSettings(), storage: storage)
        let changeRecorder = ObservationChangeRecorder()

        withObservationTracking {
            _ = store.value.general.depth
        } onChange: {
            changeRecorder.recordChange()
        }

        store.value = DemoSettings(title: "replacement")
        #expect(changeRecorder.changeCount == 1)
    }

    @Test("a nested property write triggers a save")
    func nestedWriteSaves() async throws {
        guard #available(macOS 14.0, *) else { return }
        let storage = RecordingStorage()
        let store = SettingsStore(defaultValue: DemoSettings(), storage: storage, autoSaveDelay: autoSaveDelay)

        store.value.general.depth = 7

        #expect(await waitUntil { storage.saveCount == 1 }, "the write was never persisted")
        let persisted = try storage.decodedValue(as: DemoSettings.self)
        #expect(persisted?.general.depth == 7)
    }

    @Test("a burst of writes collapses into a single save")
    func debounceCollapsesBurst() async throws {
        guard #available(macOS 14.0, *) else { return }
        let storage = RecordingStorage()
        let store = SettingsStore(defaultValue: DemoSettings(), storage: storage, autoSaveDelay: autoSaveDelay)

        store.value.general.depth = 1
        store.value.general.depth = 2
        store.value.general.depth = 3
        store.value.title = "renamed"

        #expect(await waitUntil { storage.saveCount >= 1 }, "the burst was never persisted")
        await waitPastAutoSave()
        #expect(storage.saveCount == 1, "the burst produced more than one write")
        let persisted = try storage.decodedValue(as: DemoSettings.self)
        #expect(persisted?.general.depth == 3)
        #expect(persisted?.title == "renamed")
    }

    @Test("loading stored settings does not write them straight back")
    func loadDoesNotEcho() async throws {
        guard #available(macOS 14.0, *) else { return }
        let storedSettings = DemoSettings(
            general: DemoSettings.General(depth: 11, isEnabled: false),
            title: "stored"
        )
        let storage = RecordingStorage(initialData: try JSONEncoder().encode(storedSettings))

        let store = SettingsStore(defaultValue: DemoSettings(), storage: storage, autoSaveDelay: autoSaveDelay)
        let outcome = await store.load()
        await waitPastAutoSave()

        if case .loaded = outcome {} else {
            Issue.record("expected .loaded, got \(outcome)")
        }
        #expect(store.value == storedSettings)
        #expect(storage.saveCount == 0)
    }

    @Test("an empty store keeps its default value")
    func emptyStorageKeepsDefaults() async {
        guard #available(macOS 14.0, *) else { return }
        let storage = RecordingStorage()
        let defaultSettings = DemoSettings()
        let store = SettingsStore(defaultValue: defaultSettings, storage: storage, autoSaveDelay: autoSaveDelay)

        let outcome = await store.load()

        if case .noStoredData = outcome {} else {
            Issue.record("expected .noStoredData, got \(outcome)")
        }
        #expect(store.value === defaultSettings)
    }

    @Test("undecodable data leaves the defaults in place and reports the failure")
    func corruptStorageReportsFailure() async {
        guard #available(macOS 14.0, *) else { return }
        let storage = RecordingStorage(initialData: Data("not json".utf8))
        let defaultSettings = DemoSettings()
        let store = SettingsStore(defaultValue: defaultSettings, storage: storage, autoSaveDelay: autoSaveDelay)

        let outcome = await store.load()

        if case .failed = outcome {} else {
            Issue.record("expected .failed, got \(outcome)")
        }
        #expect(store.value === defaultSettings)
    }

    @Test("an explicit save writes immediately and cancels deferred work")
    func explicitSaveSupersedesDebounce() async throws {
        guard #available(macOS 14.0, *) else { return }
        let storage = RecordingStorage()
        let store = SettingsStore(defaultValue: DemoSettings(), storage: storage, autoSaveDelay: autoSaveDelay)

        store.value.title = "quitting"
        try await store.save()

        #expect(storage.saveCount == 1)

        // Neither the debounced task nor Observation's deferred re-arm may
        // produce a second write after the explicit save.
        await waitPastAutoSave()
        #expect(storage.saveCount == 1)
    }

    @Test("a synchronous save persists before returning and cancels deferred work")
    func synchronousSaveWritesImmediately() async throws {
        guard #available(macOS 14.0, *) else { return }
        let storage = RecordingStorage()
        let store = SettingsStore(defaultValue: DemoSettings(), storage: storage, autoSaveDelay: autoSaveDelay)

        store.value.title = "quitting"
        // In this async test a plain `store.save()` would resolve to the
        // async overload; binding a synchronous function value forces the
        // one under test.
        let saveWithoutSuspending: () throws -> Void = store.save
        try saveWithoutSuspending()

        // The point of the synchronous path: the write has landed by the time
        // the call returns, with nothing left to await.
        #expect(storage.saveCount == 1)
        let persisted = try storage.decodedValue(as: DemoSettings.self)
        #expect(persisted?.title == "quitting")

        await waitPastAutoSave()
        #expect(storage.saveCount == 1, "the debounced task produced a second write")
    }

    @Test("mutating settings immediately after a load still saves")
    func writeAfterLoadResumesSaving() async throws {
        guard #available(macOS 14.0, *) else { return }
        let storage = RecordingStorage(initialData: try JSONEncoder().encode(DemoSettings()))
        let store = SettingsStore(defaultValue: DemoSettings(), storage: storage, autoSaveDelay: autoSaveDelay)

        await store.load()
        store.value.general.isEnabled = true

        #expect(await waitUntil { storage.saveCount == 1 }, "the post-load write was never persisted")
        let persisted = try storage.decodedValue(as: DemoSettings.self)
        #expect(persisted?.general.isEnabled == true)
    }
}

@Suite("FileSystemSettingsStorage")
struct FileSystemSettingsStorageTests {
    @Test("round-trips through a real file")
    func roundTrip() async throws {
        guard #available(macOS 14.0, *) else { return }
        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("UIFoundationSettingsTests-\(UUID().uuidString)")
            .appendingPathComponent("Settings.json")
        defer { try? FileManager.default.removeItem(at: fileURL.deletingLastPathComponent()) }

        // Typed as the existential so the calls go through the async
        // requirements — pinning that the synchronous implementations
        // witness them.
        let storage: any SettingsStorage = FileSystemSettingsStorage(fileURL: fileURL)
        let payload = Data(#"{"title":"hello"}"#.utf8)

        try await storage.save(payload)
        #expect(try await storage.load() == payload)
    }

    @Test("reports missing data rather than an empty payload")
    func missingFile() async {
        guard #available(macOS 14.0, *) else { return }
        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("UIFoundationSettingsTests-\(UUID().uuidString)")
            .appendingPathComponent("Settings.json")
        let storage: any SettingsStorage = FileSystemSettingsStorage(fileURL: fileURL)

        await #expect(throws: FileSystemSettingsStorage.LoadError.self) {
            _ = try await storage.load()
        }
    }

    @Test("round-trips synchronously through a real file")
    func synchronousRoundTrip() throws {
        guard #available(macOS 14.0, *) else { return }
        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("UIFoundationSettingsTests-\(UUID().uuidString)")
            .appendingPathComponent("Settings.json")
        defer { try? FileManager.default.removeItem(at: fileURL.deletingLastPathComponent()) }

        let storage = FileSystemSettingsStorage(fileURL: fileURL)
        let payload = Data(#"{"title":"hello"}"#.utf8)

        try storage.save(payload)
        #expect(try storage.load() == payload)
    }

    @Test("the synchronous load reports missing data too")
    func synchronousMissingFile() {
        guard #available(macOS 14.0, *) else { return }
        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("UIFoundationSettingsTests-\(UUID().uuidString)")
            .appendingPathComponent("Settings.json")
        let storage = FileSystemSettingsStorage(fileURL: fileURL)

        #expect(throws: FileSystemSettingsStorage.LoadError.self) {
            _ = try storage.load()
        }
    }

    @Test("creates the enclosing directory on first save")
    func createsDirectory() throws {
        guard #available(macOS 14.0, *) else { return }
        let directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("UIFoundationSettingsTests-\(UUID().uuidString)")
        let fileURL = directoryURL.appendingPathComponent("Nested/Settings.json")
        defer { try? FileManager.default.removeItem(at: directoryURL) }

        #expect(!FileManager.default.fileExists(atPath: fileURL.path))
        try FileSystemSettingsStorage(fileURL: fileURL).save(Data("{}".utf8))
        #expect(FileManager.default.fileExists(atPath: fileURL.path))
    }
}

#endif
