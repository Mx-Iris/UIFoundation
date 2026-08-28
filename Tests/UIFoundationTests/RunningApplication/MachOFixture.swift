#if RunningApplication && os(macOS)

import Darwin
import MachO
@testable import UIFoundationRunningApplication

/// Serves a byte array to the Mach-O parser, standing in for a file on disk.
struct ArrayByteSource: MachOByteSource {
    let bytes: [UInt8]

    init(_ bytes: [UInt8]) {
        self.bytes = bytes
    }

    func readBytes(count: Int, at offset: UInt64) -> [UInt8]? {
        guard count > 0, offset <= UInt64(Int.max) else { return nil }
        let start = Int(offset)
        guard start >= 0, start + count <= bytes.count else { return nil }
        return Array(bytes[start ..< start + count])
    }
}

/// Builds Mach-O byte layouts by hand so the parser can be tested against known-good and
/// deliberately malformed input without needing real binaries on the test machine.
enum MachOFixture {
    // MARK: - Load Commands

    struct LoadCommand {
        var command: UInt32
        /// Bytes following the `cmd` and `cmdsize` fields.
        var payload: [UInt8]
        /// Overrides the `cmdsize` field to a value that disagrees with the real payload
        /// length, for testing bounds handling.
        var declaredSizeOverride: UInt32?

        var actualSize: Int { 8 + payload.count }
        var declaredSize: UInt32 { declaredSizeOverride ?? UInt32(actualSize) }

        var bytes: [UInt8] {
            hostBytes(command) + hostBytes(declaredSize) + payload
        }
    }

    /// `struct build_version_command`: cmd, cmdsize, platform, minos, sdk, ntools.
    static func buildVersion(platform: UInt32, declaredSizeOverride: UInt32? = nil) -> LoadCommand {
        LoadCommand(
            command: UInt32(bitPattern: LC_BUILD_VERSION),
            payload: hostBytes(platform) + hostBytes(UInt32(0)) + hostBytes(UInt32(0)) + hostBytes(UInt32(0)),
            declaredSizeOverride: declaredSizeOverride
        )
    }

    /// `struct version_min_command`: cmd, cmdsize, version, sdk. The platform is implied
    /// by which command it is.
    static func versionMinimum(command: Int32) -> LoadCommand {
        LoadCommand(
            command: UInt32(bitPattern: command),
            payload: hostBytes(UInt32(0)) + hostBytes(UInt32(0)),
            declaredSizeOverride: nil
        )
    }

    /// A load command the parser should skip over without interpreting.
    static func filler(payloadByteCount: Int = 8) -> LoadCommand {
        LoadCommand(
            command: UInt32(bitPattern: LC_UUID),
            payload: [UInt8](repeating: 0xAB, count: payloadByteCount),
            declaredSizeOverride: nil
        )
    }

    // MARK: - Thin Binaries

    /// Build a single-architecture Mach-O image.
    ///
    /// - Parameters:
    ///   - declaredCommandCount: overrides the header's `ncmds` field.
    ///   - declaredCommandsSize: overrides the header's `sizeofcmds` field.
    static func thin(
        magic: UInt32 = MH_MAGIC_64,
        cpuType: cpu_type_t = CPU_TYPE_ARM64,
        cpuSubtype: cpu_subtype_t = CPU_SUBTYPE_ARM64_ALL,
        commands: [LoadCommand],
        declaredCommandCount: UInt32? = nil,
        declaredCommandsSize: UInt32? = nil
    ) -> [UInt8] {
        let commandBytes = commands.flatMap(\.bytes)
        var image: [UInt8] = []
        image += hostBytes(magic)
        image += hostBytes(UInt32(bitPattern: cpuType))
        image += hostBytes(UInt32(bitPattern: cpuSubtype))
        image += hostBytes(UInt32(MH_EXECUTE))
        image += hostBytes(declaredCommandCount ?? UInt32(commands.count))
        image += hostBytes(declaredCommandsSize ?? UInt32(commandBytes.count))
        image += hostBytes(UInt32(0)) // flags
        if magic == MH_MAGIC_64 {
            image += hostBytes(UInt32(0)) // reserved
        }
        image += commandBytes
        return image
    }

    // MARK: - Fat Binaries

    struct Slice {
        var cpuType: cpu_type_t
        var cpuSubtype: cpu_subtype_t
        var image: [UInt8]
    }

    /// Build a universal binary wrapping the given slices. Fat headers are big-endian on
    /// every host, which is exactly what this fixture reproduces.
    static func fat(slices: [Slice], is64Bit: Bool = false) -> [UInt8] {
        let entrySize = is64Bit ? 32 : 20
        let headerSize = 8 + slices.count * entrySize
        // Page-align each slice, as the real tooling does.
        let alignment = 0x4000
        var sliceOffsets: [Int] = []
        var cursor = (headerSize + alignment - 1) / alignment * alignment
        for slice in slices {
            sliceOffsets.append(cursor)
            cursor += (slice.image.count + alignment - 1) / alignment * alignment
        }

        var header: [UInt8] = []
        header += bigEndianBytes(is64Bit ? FAT_MAGIC_64 : FAT_MAGIC)
        header += bigEndianBytes(UInt32(slices.count))
        for (slice, offset) in zip(slices, sliceOffsets) {
            header += bigEndianBytes(UInt32(bitPattern: slice.cpuType))
            header += bigEndianBytes(UInt32(bitPattern: slice.cpuSubtype))
            if is64Bit {
                header += bigEndianBytes(UInt64(offset))
                header += bigEndianBytes(UInt64(slice.image.count))
                header += bigEndianBytes(UInt32(14)) // align
                header += bigEndianBytes(UInt32(0)) // reserved
            } else {
                header += bigEndianBytes(UInt32(offset))
                header += bigEndianBytes(UInt32(slice.image.count))
                header += bigEndianBytes(UInt32(14)) // align
            }
        }

        var image = header
        for (slice, offset) in zip(slices, sliceOffsets) {
            image += [UInt8](repeating: 0, count: offset - image.count)
            image += slice.image
        }
        return image
    }

    // MARK: - Byte Helpers

    /// Little-endian on every Apple platform, matching how Mach-O headers are stored.
    static func hostBytes(_ value: UInt32) -> [UInt8] {
        withUnsafeBytes(of: value) { Array($0) }
    }

    static func bigEndianBytes(_ value: UInt32) -> [UInt8] {
        withUnsafeBytes(of: value.bigEndian) { Array($0) }
    }

    static func bigEndianBytes(_ value: UInt64) -> [UInt8] {
        withUnsafeBytes(of: value.bigEndian) { Array($0) }
    }
}

/// Free function so `LoadCommand.bytes` can reach it without qualification.
private func hostBytes(_ value: UInt32) -> [UInt8] {
    MachOFixture.hostBytes(value)
}

#endif
