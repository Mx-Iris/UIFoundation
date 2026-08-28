#if RunningApplication && os(macOS)

/// The platform a binary was built for, as recorded in its Mach-O `LC_BUILD_VERSION`
/// load command.
///
/// This is distinct from ``Architecture``, which reports the architecture the kernel is
/// actually running the process as. The difference is exactly what makes simulator
/// processes identifiable: on Apple Silicon a process running inside an iOS Simulator
/// executes as native `arm64`, indistinguishable from a host process by architecture
/// alone, but its binary is built for ``Platform/iOSSimulator``.
///
/// Case names mirror the `PLATFORM_*` constants in `<mach-o/loader.h>`. Apple adds new
/// constants to that table most years, so values this version of the library does not
/// recognize are preserved as ``Platform/unknown(_:)`` rather than being flattened away.
public enum Platform: CustomStringConvertible, Hashable, Sendable {
    case macOS
    case iOS
    case tvOS
    case watchOS
    case bridgeOS
    case macCatalyst
    case iOSSimulator
    case tvOSSimulator
    case watchOSSimulator
    case driverKit
    case visionOS
    case visionOSSimulator
    case firmware
    /// `PLATFORM_SEPOS` — the Secure Enclave Processor operating system.
    case securityEnclaveOS
    case macOSExclaveCore
    case macOSExclaveKit
    case iOSExclaveCore
    case iOSExclaveKit
    case tvOSExclaveCore
    case tvOSExclaveKit
    case watchOSExclaveCore
    case watchOSExclaveKit
    case visionOSExclaveCore
    case visionOSExclaveKit
    /// A platform constant this version of the library does not know about, carrying the
    /// raw Mach-O value so that future platforms stay diagnosable instead of vanishing.
    case unknown(UInt32)

    /// Build a platform from a raw Mach-O `PLATFORM_*` constant. Unrecognized values are
    /// preserved as ``Platform/unknown(_:)``.
    public init(machOPlatformValue: UInt32) {
        switch machOPlatformValue {
        case 1: self = .macOS
        case 2: self = .iOS
        case 3: self = .tvOS
        case 4: self = .watchOS
        case 5: self = .bridgeOS
        case 6: self = .macCatalyst
        case 7: self = .iOSSimulator
        case 8: self = .tvOSSimulator
        case 9: self = .watchOSSimulator
        case 10: self = .driverKit
        case 11: self = .visionOS
        case 12: self = .visionOSSimulator
        case 13: self = .firmware
        case 14: self = .securityEnclaveOS
        case 15: self = .macOSExclaveCore
        case 16: self = .macOSExclaveKit
        case 17: self = .iOSExclaveCore
        case 18: self = .iOSExclaveKit
        case 19: self = .tvOSExclaveCore
        case 20: self = .tvOSExclaveKit
        case 21: self = .watchOSExclaveCore
        case 22: self = .watchOSExclaveKit
        case 23: self = .visionOSExclaveCore
        case 24: self = .visionOSExclaveKit
        default: self = .unknown(machOPlatformValue)
        }
    }

    /// Whether the binary was built to run against a simulator runtime rather than real
    /// hardware.
    ///
    /// Deliberately written without a `default` branch: adding a new simulator platform
    /// must fail to compile here rather than silently report `false`.
    public var isSimulator: Bool {
        switch self {
        case .iOSSimulator, .tvOSSimulator, .watchOSSimulator, .visionOSSimulator:
            true
        case .macOS, .iOS, .tvOS, .watchOS, .bridgeOS, .macCatalyst, .driverKit, .visionOS,
             .firmware, .securityEnclaveOS,
             .macOSExclaveCore, .macOSExclaveKit, .iOSExclaveCore, .iOSExclaveKit,
             .tvOSExclaveCore, .tvOSExclaveKit, .watchOSExclaveCore, .watchOSExclaveKit,
             .visionOSExclaveCore, .visionOSExclaveKit, .unknown:
            false
        }
    }

    /// The raw Mach-O `PLATFORM_*` constant this case corresponds to.
    public var machOPlatformValue: UInt32 { facts.machOPlatformValue }

    /// Full display wording, e.g. `"iOS Simulator"`, `"Mac Catalyst"`, `"DriverKit"`.
    public var description: String { facts.description }

    /// The spelling of this case in source, used as a second search target so that a
    /// query without spaces (`"maccatalyst"`) still matches, and so that the expanded
    /// name of ``Platform/securityEnclaveOS`` is searchable.
    var caseName: String { facts.caseName }

    /// Sort rank for the Platform column. Simulator platforms rank first so a single
    /// click on the column header lifts every simulator process to the top of the table.
    var sortOrder: Int { facts.sortOrder }

    /// Every static fact about a platform, produced by one exhaustive switch so that
    /// adding a case fails to compile until all of its facts are supplied.
    private var facts: (machOPlatformValue: UInt32, description: String, caseName: String, sortOrder: Int) {
        switch self {
        // Simulator platforms sort first — see `sortOrder`.
        case .iOSSimulator: (7, "iOS Simulator", "iOSSimulator", 0)
        case .tvOSSimulator: (8, "tvOS Simulator", "tvOSSimulator", 1)
        case .watchOSSimulator: (9, "watchOS Simulator", "watchOSSimulator", 2)
        case .visionOSSimulator: (12, "visionOS Simulator", "visionOSSimulator", 3)
        // Then everything that runs on real hardware, in Mach-O constant order.
        case .macOS: (1, "macOS", "macOS", 10)
        case .iOS: (2, "iOS", "iOS", 11)
        case .tvOS: (3, "tvOS", "tvOS", 12)
        case .watchOS: (4, "watchOS", "watchOS", 13)
        case .bridgeOS: (5, "bridgeOS", "bridgeOS", 14)
        case .macCatalyst: (6, "Mac Catalyst", "macCatalyst", 15)
        case .driverKit: (10, "DriverKit", "driverKit", 16)
        case .visionOS: (11, "visionOS", "visionOS", 17)
        case .firmware: (13, "Firmware", "firmware", 18)
        case .securityEnclaveOS: (14, "sepOS", "securityEnclaveOS", 19)
        case .macOSExclaveCore: (15, "macOS ExclaveCore", "macOSExclaveCore", 20)
        case .macOSExclaveKit: (16, "macOS ExclaveKit", "macOSExclaveKit", 21)
        case .iOSExclaveCore: (17, "iOS ExclaveCore", "iOSExclaveCore", 22)
        case .iOSExclaveKit: (18, "iOS ExclaveKit", "iOSExclaveKit", 23)
        case .tvOSExclaveCore: (19, "tvOS ExclaveCore", "tvOSExclaveCore", 24)
        case .tvOSExclaveKit: (20, "tvOS ExclaveKit", "tvOSExclaveKit", 25)
        case .watchOSExclaveCore: (21, "watchOS ExclaveCore", "watchOSExclaveCore", 26)
        case .watchOSExclaveKit: (22, "watchOS ExclaveKit", "watchOSExclaveKit", 27)
        case .visionOSExclaveCore: (23, "visionOS ExclaveCore", "visionOSExclaveCore", 28)
        case .visionOSExclaveKit: (24, "visionOS ExclaveKit", "visionOSExclaveKit", 29)
        // Unrecognized values sort last, keeping their raw constant visible.
        case .unknown(let rawPlatformValue):
            (rawPlatformValue, "Platform \(rawPlatformValue)", "unknown", 100)
        }
    }

    /// Whether this platform should be considered a match for a free-text search query.
    func matches(searchText: String) -> Bool {
        description.localizedCaseInsensitiveContains(searchText)
            || caseName.localizedCaseInsensitiveContains(searchText)
    }
}

#endif
