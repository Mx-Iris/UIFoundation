#if RunningApplication && os(macOS)

import Darwin
import MachO

/// A CPU type / subtype pair, used to pick the right slice out of a fat binary.
struct MachOArchitecture: Hashable, Sendable {
    var cpuType: cpu_type_t
    var cpuSubtype: cpu_subtype_t

    init(cpuType: cpu_type_t, cpuSubtype: cpu_subtype_t) {
        self.cpuType = cpuType
        self.cpuSubtype = cpuSubtype
    }

    /// Subtypes carry capability bits in their top byte (`CPU_SUBTYPE_MASK`) that are not
    /// part of the identity being matched against a fat slice.
    var cpuSubtypeWithoutCapabilities: cpu_subtype_t { cpuSubtype & 0x00ff_ffff }
}

/// Supplies bytes to the Mach-O parser.
///
/// Abstracted away from the file system so the parsing logic — the part with real
/// failure modes, namely byte order, slice offsets and load command bounds — can be
/// exercised against in-memory fixtures.
protocol MachOByteSource {
    /// Read exactly `count` bytes starting at `offset`, or nil on a short read.
    func readBytes(count: Int, at offset: UInt64) -> [UInt8]?
}

/// Reads the platform a Mach-O binary was built for out of its `LC_BUILD_VERSION`
/// load command.
enum MachOPlatform {
    /// Upper bound on the load command region. Real binaries stay far below this; the
    /// cap exists so a malformed `sizeofcmds` cannot trigger a huge allocation.
    private static let maximumLoadCommandsSize = 1 << 20

    /// Upper bound on fat slice count. Real universal binaries carry a handful.
    private static let maximumSliceCount = 64

    /// Smallest load command that can exist: the `cmd` and `cmdsize` fields themselves.
    private static let minimumLoadCommandSize = 8

    // `<mach-o/loader.h>` reaches Swift with these constants typed Int32, while the
    // `cmd` field they are compared against is UInt32. Converted once, here.
    private static let buildVersionCommand = UInt32(bitPattern: LC_BUILD_VERSION)
    private static let versionMinimumMacOSCommand = UInt32(bitPattern: LC_VERSION_MIN_MACOSX)
    private static let versionMinimumIPhoneOSCommand = UInt32(bitPattern: LC_VERSION_MIN_IPHONEOS)
    private static let versionMinimumTVOSCommand = UInt32(bitPattern: LC_VERSION_MIN_TVOS)
    private static let versionMinimumWatchOSCommand = UInt32(bitPattern: LC_VERSION_MIN_WATCHOS)

    /// The architecture this machine runs natively, used as the second-level fallback
    /// when a process's own running architecture cannot be read.
    private static let hostCPUType: cpu_type_t = {
        var value: cpu_type_t = 0
        var size = MemoryLayout<cpu_type_t>.size
        guard sysctlbyname("hw.cputype", &value, &size, nil, 0) == 0 else { return 0 }
        return value
    }()

    /// Read the platform of the executable at `path`.
    ///
    /// - Parameters:
    ///   - path: filesystem path to a Mach-O executable, thin or universal.
    ///   - runningArchitecture: the architecture the process is actually executing as,
    ///     used to pick the matching slice of a universal binary. Pass nil when it cannot
    ///     be determined — the host architecture is used instead. This is not a rare
    ///     path: `PROC_PIDARCHINFO` is unreadable for a sizeable minority of processes,
    ///     and without the fallback those all fail to resolve.
    /// - Returns: the platform, or nil if the file cannot be opened, read, or parsed.
    static func platform(atPath path: String, runningArchitecture: MachOArchitecture?) -> Platform? {
        let descriptor = open(path, O_RDONLY)
        guard descriptor >= 0 else { return nil }
        defer { close(descriptor) }
        return platform(in: FileByteSource(descriptor: descriptor), runningArchitecture: runningArchitecture)
    }

    /// Platform keyed by executable path. The outer optional distinguishes "not looked up
    /// yet" from a cached "could not be determined".
    private static let cache = ThreadSafeCache<String, Platform?>()

    /// Read the platform of the executable at `path`, caching by path.
    ///
    /// Many processes share one executable — 1708 processes on the development machine
    /// map to 1026 distinct paths — and an executable's platform cannot change while it
    /// is running, so the file is read at most once per path.
    ///
    /// - Parameter runningArchitecture: evaluated only on a cache miss, so processes
    ///   whose platform is already known cost no syscall.
    static func cachedPlatform(
        atPath path: String,
        runningArchitecture: @autoclosure () -> MachOArchitecture?
    ) -> Platform? {
        if let cached = cache[path] { return cached }
        let resolved = platform(atPath: path, runningArchitecture: runningArchitecture())
        cache[path] = resolved
        return resolved
    }

    /// Read the platform out of an arbitrary byte source.
    static func platform(in byteSource: some MachOByteSource, runningArchitecture: MachOArchitecture?) -> Platform? {
        guard let sliceOffset = sliceOffset(in: byteSource, runningArchitecture: runningArchitecture) else {
            return nil
        }
        return platformOfSlice(in: byteSource, at: sliceOffset)
    }

    // MARK: - Fat Binaries

    /// Locate the slice to inspect. Returns 0 for a thin binary, or nil if the file is
    /// not Mach-O at all.
    private static func sliceOffset(in byteSource: some MachOByteSource, runningArchitecture: MachOArchitecture?) -> UInt64? {
        guard let magicBytes = byteSource.readBytes(count: 4, at: 0),
              let magic = magicBytes.hostUInt32(at: 0) else { return nil }

        // Fat headers are always stored big-endian, so on a little-endian host the magic
        // reads back as FAT_CIGAM. Accept both spellings and byte-swap the fields.
        let isFat32 = magic == FAT_CIGAM || magic == FAT_MAGIC
        let isFat64 = magic == FAT_CIGAM_64 || magic == FAT_MAGIC_64
        guard isFat32 || isFat64 else {
            // Thin binary: must still be a Mach-O of the host's byte order.
            guard magic == MH_MAGIC_64 || magic == MH_MAGIC else { return nil }
            return 0
        }

        guard let countBytes = byteSource.readBytes(count: 4, at: 4),
              let declaredSliceCount = countBytes.bigEndianUInt32(at: 0) else { return nil }
        let sliceCount = min(Int(declaredSliceCount), maximumSliceCount)
        guard sliceCount > 0 else { return nil }

        let entrySize = isFat64 ? 32 : 20
        var exactMatch: UInt64?
        var cpuTypeMatch: UInt64?
        var hostMatch: UInt64?
        var firstSlice: UInt64?

        for sliceIndex in 0 ..< sliceCount {
            let entryOffset = UInt64(8 + sliceIndex * entrySize)
            guard let entry = byteSource.readBytes(count: entrySize, at: entryOffset),
                  let rawCPUType = entry.bigEndianUInt32(at: 0),
                  let rawCPUSubtype = entry.bigEndianUInt32(at: 4) else { break }

            let offset: UInt64? = isFat64
                ? entry.bigEndianUInt64(at: 8)
                : entry.bigEndianUInt32(at: 8).map(UInt64.init)
            guard let sliceOffset = offset else { break }

            if firstSlice == nil { firstSlice = sliceOffset }

            let cpuType = cpu_type_t(bitPattern: rawCPUType)
            let cpuSubtype = cpu_subtype_t(bitPattern: rawCPUSubtype)

            if let runningArchitecture, cpuType == runningArchitecture.cpuType {
                let sliceArchitecture = MachOArchitecture(cpuType: cpuType, cpuSubtype: cpuSubtype)
                if sliceArchitecture.cpuSubtypeWithoutCapabilities == runningArchitecture.cpuSubtypeWithoutCapabilities {
                    exactMatch = sliceOffset
                    break
                }
                if cpuTypeMatch == nil { cpuTypeMatch = sliceOffset }
            }

            if hostMatch == nil, hostCPUType != 0, cpuType == hostCPUType {
                hostMatch = sliceOffset
            }
        }

        // Four-level fallback. Levels 2 and 3 are what keep universal binaries resolvable
        // when the process's running architecture is unavailable; without them roughly a
        // quarter of all processes fail to resolve.
        return exactMatch ?? cpuTypeMatch ?? hostMatch ?? firstSlice
    }

    // MARK: - Load Commands

    private static func platformOfSlice(in byteSource: some MachOByteSource, at sliceOffset: UInt64) -> Platform? {
        guard let headerBytes = byteSource.readBytes(count: 32, at: sliceOffset),
              let magic = headerBytes.hostUInt32(at: 0),
              let commandCount = headerBytes.hostUInt32(at: 16),
              let declaredCommandsSize = headerBytes.hostUInt32(at: 20) else { return nil }

        // Byte-swapped Mach-O (a big-endian binary on this little-endian host) is not
        // supported — no such executable runs on a platform this library targets.
        let headerSize: UInt64
        switch magic {
        case MH_MAGIC_64: headerSize = 32
        case MH_MAGIC: headerSize = 28
        default: return nil
        }

        let commandsSize = Int(declaredCommandsSize)
        guard commandsSize >= minimumLoadCommandSize, commandsSize <= maximumLoadCommandsSize else { return nil }
        guard let commands = byteSource.readBytes(count: commandsSize, at: sliceOffset + headerSize) else { return nil }

        var cursor = 0
        var legacyPlatform: Platform?

        for _ in 0 ..< commandCount {
            guard cursor + minimumLoadCommandSize <= commandsSize,
                  let command = commands.hostUInt32(at: cursor),
                  let commandSize = commands.hostUInt32(at: cursor + 4) else { break }

            let commandSizeInBytes = Int(commandSize)
            guard commandSizeInBytes >= minimumLoadCommandSize,
                  cursor + commandSizeInBytes <= commandsSize else { break }

            if command == buildVersionCommand {
                // struct build_version_command: cmd, cmdsize, platform, minos, sdk, ntools
                guard commandSizeInBytes >= 12, let rawPlatform = commands.hostUInt32(at: cursor + 8) else { break }
                return Platform(machOPlatformValue: rawPlatform)
            }

            // Binaries built before the iOS 12 era SDKs carry no LC_BUILD_VERSION, only a
            // version_min command whose type alone names the platform. Recorded as a
            // fallback rather than returned immediately, since a binary carrying both
            // should be described by LC_BUILD_VERSION.
            if legacyPlatform == nil {
                legacyPlatform = platformOfLegacyVersionMinimumCommand(command)
            }

            cursor += commandSizeInBytes
        }

        return legacyPlatform
    }

    private static func platformOfLegacyVersionMinimumCommand(_ command: UInt32) -> Platform? {
        switch command {
        case versionMinimumMacOSCommand: .macOS
        case versionMinimumIPhoneOSCommand: .iOS
        case versionMinimumTVOSCommand: .tvOS
        case versionMinimumWatchOSCommand: .watchOS
        default: nil
        }
    }
}

// MARK: - File Byte Source

private struct FileByteSource: MachOByteSource {
    let descriptor: Int32

    func readBytes(count: Int, at offset: UInt64) -> [UInt8]? {
        guard count > 0, offset <= UInt64(off_t.max) else { return nil }
        var buffer = [UInt8](repeating: 0, count: count)
        let bytesRead = buffer.withUnsafeMutableBytes { rawBuffer in
            pread(descriptor, rawBuffer.baseAddress, count, off_t(offset))
        }
        guard bytesRead == count else { return nil }
        return buffer
    }
}

// MARK: - Byte Reading

extension [UInt8] {
    /// Read a 32-bit value stored in the host's byte order.
    func hostUInt32(at offset: Int) -> UInt32? {
        guard offset >= 0, offset + 4 <= count else { return nil }
        return withUnsafeBytes { $0.loadUnaligned(fromByteOffset: offset, as: UInt32.self) }
    }

    /// Read a 32-bit value stored big-endian, as fat header fields always are.
    func bigEndianUInt32(at offset: Int) -> UInt32? {
        hostUInt32(at: offset)?.bigEndian
    }

    /// Read a 64-bit value stored big-endian, as 64-bit fat header fields always are.
    func bigEndianUInt64(at offset: Int) -> UInt64? {
        guard offset >= 0, offset + 8 <= count else { return nil }
        return withUnsafeBytes { $0.loadUnaligned(fromByteOffset: offset, as: UInt64.self) }.bigEndian
    }
}

#endif
