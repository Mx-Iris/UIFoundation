#if RunningApplication && os(macOS)

import AppKit

public struct RunningApplication: RunningItem {
    public let processIdentifier: pid_t
    public let name: String
    public let bundleIdentifier: String?
    public let bundleURL: URL?
    public let executableURL: URL?
    public let icon: NSImage?
    public let architecture: Architecture?
    public let launchDate: Date?
    public let isFinishedLaunching: Bool
    public let isHidden: Bool
    public let isActive: Bool
    public let isTerminated: Bool
    public let ownsMenuBar: Bool
    public let activationPolicy: NSApplication.ActivationPolicy
    public internal(set) var isSandboxed: Bool
    public internal(set) var isSandboxResolved: Bool
    public let platform: Platform?

    public init(from app: NSRunningApplication, resolveSandbox: Bool = true) {
        self.processIdentifier = app.processIdentifier
        self.name = app.localizedName ?? "Unknown"
        self.bundleIdentifier = app.bundleIdentifier
        self.bundleURL = app.bundleURL
        self.executableURL = app.executableURL
        self.icon = app.icon
        self.architecture = app.architecture
        self.launchDate = app.launchDate
        self.isFinishedLaunching = app.isFinishedLaunching
        self.isHidden = app.isHidden
        self.isActive = app.isActive
        self.isTerminated = app.isTerminated
        self.ownsMenuBar = app.ownsMenuBar
        self.activationPolicy = app.activationPolicy
        self.isSandboxed = resolveSandbox ? app.isSandboxed : false
        self.isSandboxResolved = resolveSandbox
        // No resolve flag to match `resolveSandbox`: reading the Mach-O header costs
        // about two orders of magnitude less than the code-signing query behind
        // `isSandboxed`, and the result is cached per executable path.
        self.platform = app.executableURL.flatMap { executableURL in
            MachOPlatform.cachedPlatform(
                atPath: executableURL.path,
                runningArchitecture: BSDProcess.machOArchitecture(for: app.processIdentifier)
            )
        }
    }

    // Hashable: identity by PID
    public func hash(into hasher: inout Hasher) {
        hasher.combine(processIdentifier)
    }

    public static func == (lhs: RunningApplication, rhs: RunningApplication) -> Bool {
        lhs.processIdentifier == rhs.processIdentifier
    }
}


#endif
