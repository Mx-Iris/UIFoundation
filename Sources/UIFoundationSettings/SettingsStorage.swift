#if Settings && os(macOS)

import Foundation

/// Where a ``SettingsStore`` reads and writes its encoded payload.
///
/// The store only ever hands over `Data`; encoding is the store's business.
/// Implement this to persist somewhere other than the file system (a shared
/// container, the keychain, a test double).
public protocol SettingsStorage: Sendable {
    func save(_ data: Data) async throws
    func load() async throws -> Data
}

/// Stores settings as a single JSON file under a per-application directory.
///
/// The default location is
/// `~/Library/Application Support/<applicationDirectoryName>/Settings.json`.
/// Writes are atomic, and the enclosing directory is created on first save.
public struct FileSystemSettingsStorage: SettingsStorage {
    public enum LoadError: Error {
        /// Nothing has been written yet. Not a failure — the store keeps its
        /// default value when it sees this.
        case noStoredData
    }

    private let fileURL: URL

    /// - Parameters:
    ///   - applicationDirectoryName: Folder to create inside the search path
    ///     directory. Pass a name that distinguishes debug builds if you do not
    ///     want them sharing the release build's settings.
    ///   - fileName: Name of the JSON file itself.
    ///   - searchPathDirectory: Defaults to Application Support.
    public init(
        applicationDirectoryName: String,
        fileName: String = "Settings.json",
        searchPathDirectory: FileManager.SearchPathDirectory = .applicationSupportDirectory
    ) {
        // Guaranteed non-empty on macOS for the directories this initializer is
        // meant to be used with.
        let baseDirectory = FileManager.default
            .urls(for: searchPathDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(applicationDirectoryName)
        self.fileURL = baseDirectory.appendingPathComponent(fileName)
    }

    /// Writes to an explicit location. Useful for tests, and for hosts that
    /// keep settings inside a group container.
    public init(fileURL: URL) {
        self.fileURL = fileURL
    }

    public func save(_ data: Data) async throws {
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try data.write(to: fileURL, options: [.atomic])
    }

    public func load() async throws -> Data {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            throw LoadError.noStoredData
        }
        return try Data(contentsOf: fileURL)
    }
}

#endif
