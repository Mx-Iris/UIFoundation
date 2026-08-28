#if RunningApplication && os(macOS)

import AppKit
import Darwin
import UniformTypeIdentifiers

public struct RunningProcess: RunningItem {
    public let processIdentifier: pid_t
    public let name: String
    public let executablePath: String?
    public let icon: NSImage?
    public let architecture: Architecture?
    public let isSandboxed: Bool
    public let platform: Platform?

    init(
        processIdentifier: pid_t,
        name: String,
        executablePath: String? = nil,
        icon: NSImage? = nil,
        architecture: Architecture? = nil,
        isSandboxed: Bool = false,
        platform: Platform? = nil
    ) {
        self.processIdentifier = processIdentifier
        self.name = name
        self.executablePath = executablePath
        self.icon = icon
        self.architecture = architecture
        self.isSandboxed = isSandboxed
        self.platform = platform
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(processIdentifier)
    }

    public static func == (lhs: RunningProcess, rhs: RunningProcess) -> Bool {
        lhs.processIdentifier == rhs.processIdentifier
    }
}

// MARK: - Process Enumerator

@available(macOS 11.0, *)
public enum RunningProcessEnumerator {
    // Icon cache keyed by UTType identifier — process icons are just a handful of
    // distinct types (unix executable, generic document, etc.)
    private static let iconCache = ThreadSafeCache<String, NSImage>()
    // Architecture cache keyed by executable path — lookup returns Architecture??
    // where outer nil = cache miss, inner nil = architecture undetectable
    private static let architectureCache = ThreadSafeCache<String, Architecture?>()
    // Sandbox status cache keyed by executable path
    private static let sandboxCache = ThreadSafeCache<String, Bool>()

    /// Build a single `RunningProcess` for the given PID. Returns nil if the process name cannot be determined.
    public static func makeProcess(for pid: pid_t) -> RunningProcess? {
        let executablePath = BSDProcess.executablePath(for: pid)

        // PROC_PIDARCHINFO answers two questions — what to call the architecture, and
        // which slice of a universal binary to read the platform out of — so it is
        // fetched at most once here and shared, and not at all when both caches hit.
        var resolvedRunningArchitecture: MachOArchitecture??
        func runningArchitecture() -> MachOArchitecture? {
            if let resolvedRunningArchitecture { return resolvedRunningArchitecture }
            let fetched = BSDProcess.machOArchitecture(for: pid)
            resolvedRunningArchitecture = fetched
            return fetched
        }

        let name: String
        if let procName = BSDProcess.name(for: pid) {
            name = procName
        } else if let executablePath {
            name = (executablePath as NSString).lastPathComponent
        } else {
            return nil
        }

        let icon: NSImage?
        if let executablePath {
            icon = loadCachedIcon(for: executablePath)
        } else {
            icon = nil
        }

        let architecture: Architecture?
        if let executablePath {
            let cached: Architecture?? = architectureCache[executablePath]
            if let cached {
                architecture = cached
            } else {
                let detected = runningArchitecture().map(BSDProcess.architecture(of:))
                architectureCache[executablePath] = detected
                architecture = detected
            }
        } else {
            architecture = runningArchitecture().map(BSDProcess.architecture(of:))
        }

        // Platform comes from the executable file itself, so a process with no readable
        // path has no platform to report.
        let platform: Platform?
        if let executablePath {
            platform = MachOPlatform.cachedPlatform(atPath: executablePath, runningArchitecture: runningArchitecture())
        } else {
            platform = nil
        }

        let isSandboxed: Bool
        if let executablePath {
            if let cached = sandboxCache[executablePath] {
                isSandboxed = cached
            } else {
                let detected = BSDProcess.isSandboxed(pid: pid)
                sandboxCache[executablePath] = detected
                isSandboxed = detected
            }
        } else {
            isSandboxed = BSDProcess.isSandboxed(pid: pid)
        }

        return RunningProcess(
            processIdentifier: pid,
            name: name,
            executablePath: executablePath,
            icon: icon,
            architecture: architecture,
            isSandboxed: isSandboxed,
            platform: platform
        )
    }

    /// Load and cache icon based on the file's UTType. Process executables almost always
    /// map to just two icon types (unix executable or generic document), so caching by
    /// UTType identifier avoids expensive per-file icon lookups entirely.
    static func loadCachedIcon(for path: String) -> NSImage {
        let ext = URL(fileURLWithPath: path).pathExtension
        let uttype: UTType = if ext.isEmpty {
            .unixExecutable
        } else {
            UTType(filenameExtension: ext) ?? .data
        }

        let cacheKey = uttype.identifier
        if let cached = iconCache[cacheKey] {
            return cached
        }
        let icon = NSWorkspace.shared.icon(for: uttype)
        iconCache[cacheKey] = icon
        return icon
    }

    /// List all running processes, excluding those that are NSRunningApplications.
    public static func listProcesses(excludingApplications: Bool = true) -> [RunningProcess] {
        let appPIDs: Set<pid_t>
        if excludingApplications {
            appPIDs = Set(NSWorkspace.shared.runningApplications.map(\.processIdentifier))
        } else {
            appPIDs = []
        }

        return BSDProcess.allPIDs()
            .filter { !appPIDs.contains($0) }
            .compactMap { makeProcess(for: $0) }
            .sorted { $0.processIdentifier < $1.processIdentifier }
    }
}

#endif
