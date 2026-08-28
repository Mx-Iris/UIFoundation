#if RunningApplication && os(macOS)

import Darwin
import MachO
import Testing
@testable import UIFoundationRunningApplication

@Suite("MachOPlatform")
struct MachOPlatformTests {
    /// The architecture this machine runs natively. Tests that exercise the host fallback
    /// must be written against it rather than a hard-coded arm64, so they hold on Intel
    /// machines too.
    static let hostCPUType: cpu_type_t = {
        var value: cpu_type_t = 0
        var size = MemoryLayout<cpu_type_t>.size
        guard sysctlbyname("hw.cputype", &value, &size, nil, 0) == 0 else { return 0 }
        return value
    }()

    /// Two CPU types that are never the host on any machine this library runs on, used to
    /// isolate the fallback levels from each other.
    static let foreignCPUType = CPU_TYPE_POWERPC
    static let otherForeignCPUType = CPU_TYPE_I386

    static func parse(_ bytes: [UInt8], runningArchitecture: MachOArchitecture? = nil) -> Platform? {
        MachOPlatform.platform(in: ArrayByteSource(bytes), runningArchitecture: runningArchitecture)
    }

    // MARK: - Thin Binaries

    @Test("LC_BUILD_VERSION carries the platform", arguments: PlatformTests.knownPlatforms)
    func buildVersionCommandIsRead(rawValue: UInt32, platform: Platform) {
        let image = MachOFixture.thin(commands: [MachOFixture.buildVersion(platform: rawValue)])
        #expect(Self.parse(image) == platform)
    }

    @Test("A 32-bit Mach-O header is parsed at its own header size")
    func thirtyTwoBitHeaderIsParsed() {
        let image = MachOFixture.thin(
            magic: MH_MAGIC,
            commands: [MachOFixture.buildVersion(platform: 7)]
        )
        #expect(Self.parse(image) == .iOSSimulator)
    }

    @Test("Load commands before LC_BUILD_VERSION are skipped")
    func precedingCommandsAreSkipped() {
        let image = MachOFixture.thin(commands: [
            MachOFixture.filler(payloadByteCount: 16),
            MachOFixture.filler(payloadByteCount: 24),
            MachOFixture.buildVersion(platform: 7),
        ])
        #expect(Self.parse(image) == .iOSSimulator)
    }

    @Test("An image with no platform command resolves to nil")
    func imageWithoutPlatformCommand() {
        let image = MachOFixture.thin(commands: [MachOFixture.filler()])
        #expect(Self.parse(image) == nil)
    }

    @Test("Data that is not Mach-O at all resolves to nil")
    func nonMachOData() {
        #expect(Self.parse([UInt8](repeating: 0x7F, count: 512)) == nil)
        #expect(Self.parse([]) == nil)
        #expect(Self.parse([0x01, 0x02]) == nil)
    }

    // MARK: - Legacy version_min Commands

    @Test("Pre-LC_BUILD_VERSION binaries fall back to their version_min command", arguments: [
        (LC_VERSION_MIN_MACOSX, Platform.macOS),
        (LC_VERSION_MIN_IPHONEOS, .iOS),
        (LC_VERSION_MIN_TVOS, .tvOS),
        (LC_VERSION_MIN_WATCHOS, .watchOS),
    ])
    func legacyVersionMinimumCommand(command: Int32, platform: Platform) {
        let image = MachOFixture.thin(commands: [MachOFixture.versionMinimum(command: command)])
        #expect(Self.parse(image) == platform)
    }

    @Test("LC_BUILD_VERSION wins over a version_min command that precedes it")
    func buildVersionWinsOverLegacyCommand() {
        let image = MachOFixture.thin(commands: [
            MachOFixture.versionMinimum(command: LC_VERSION_MIN_IPHONEOS),
            MachOFixture.buildVersion(platform: 7),
        ])
        #expect(Self.parse(image) == .iOSSimulator)
    }

    // MARK: - Fat Slice Selection

    @Test("Level 1: the slice matching both CPU type and subtype wins")
    func exactArchitectureMatchWins() {
        let image = MachOFixture.fat(slices: [
            .init(cpuType: CPU_TYPE_ARM64, cpuSubtype: CPU_SUBTYPE_ARM64_ALL,
                  image: MachOFixture.thin(commands: [MachOFixture.buildVersion(platform: 1)])),
            .init(cpuType: CPU_TYPE_ARM64, cpuSubtype: CPU_SUBTYPE_ARM64E,
                  image: MachOFixture.thin(commands: [MachOFixture.buildVersion(platform: 7)])),
        ])
        let arm64e = MachOArchitecture(cpuType: CPU_TYPE_ARM64, cpuSubtype: CPU_SUBTYPE_ARM64E)
        #expect(Self.parse(image, runningArchitecture: arm64e) == .iOSSimulator)

        let arm64 = MachOArchitecture(cpuType: CPU_TYPE_ARM64, cpuSubtype: CPU_SUBTYPE_ARM64_ALL)
        #expect(Self.parse(image, runningArchitecture: arm64) == .macOS)
    }

    @Test("Level 1: capability bits in the subtype are ignored when matching")
    func subtypeCapabilityBitsAreMasked() {
        // Both slices share a CPU type, so only the subtype can tell them apart and the
        // CPU-type-only fallback cannot quietly rescue a failed mask. The arm64 slice is
        // placed first so an unmasked comparison would land on it instead.
        let image = MachOFixture.fat(slices: [
            .init(cpuType: CPU_TYPE_ARM64, cpuSubtype: CPU_SUBTYPE_ARM64_ALL,
                  image: MachOFixture.thin(commands: [MachOFixture.buildVersion(platform: 1)])),
            .init(cpuType: CPU_TYPE_ARM64, cpuSubtype: CPU_SUBTYPE_ARM64E,
                  image: MachOFixture.thin(commands: [MachOFixture.buildVersion(platform: 7)])),
        ])
        // CPU_SUBTYPE_PTRAUTH_ABI and friends live in the top byte and are not part of
        // the identity being matched.
        let withCapabilityBits = MachOArchitecture(
            cpuType: CPU_TYPE_ARM64,
            cpuSubtype: CPU_SUBTYPE_ARM64E | cpu_subtype_t(bitPattern: 0x8000_0000)
        )
        #expect(Self.parse(image, runningArchitecture: withCapabilityBits) == .iOSSimulator)
    }

    @Test("Level 2: CPU type alone matches when no subtype does")
    func cpuTypeMatchIsUsedWhenSubtypeDiffers() {
        // A foreign CPU type keeps the host fallback from reaching this slice, so only
        // level 2 can explain a hit.
        let image = MachOFixture.fat(slices: [
            .init(cpuType: Self.foreignCPUType, cpuSubtype: 1,
                  image: MachOFixture.thin(commands: [MachOFixture.buildVersion(platform: 7)])),
        ])
        let mismatchedSubtype = MachOArchitecture(cpuType: Self.foreignCPUType, cpuSubtype: 99)
        #expect(Self.parse(image, runningArchitecture: mismatchedSubtype) == .iOSSimulator)
    }

    @Test("Level 3: the host slice is used when the running architecture is unknown")
    func hostArchitectureFallback() {
        let image = MachOFixture.fat(slices: [
            .init(cpuType: Self.foreignCPUType, cpuSubtype: 0,
                  image: MachOFixture.thin(commands: [MachOFixture.buildVersion(platform: 1)])),
            .init(cpuType: Self.hostCPUType, cpuSubtype: 0,
                  image: MachOFixture.thin(commands: [MachOFixture.buildVersion(platform: 7)])),
        ])
        // This is the path taken for the many processes whose PROC_PIDARCHINFO is
        // unreadable: without it, the foreign first slice would answer instead.
        #expect(Self.parse(image, runningArchitecture: nil) == .iOSSimulator)
    }

    @Test("Level 4: the first slice answers when nothing else matches")
    func firstSliceFallback() {
        let image = MachOFixture.fat(slices: [
            .init(cpuType: Self.foreignCPUType, cpuSubtype: 0,
                  image: MachOFixture.thin(commands: [MachOFixture.buildVersion(platform: 7)])),
            .init(cpuType: Self.otherForeignCPUType, cpuSubtype: 0,
                  image: MachOFixture.thin(commands: [MachOFixture.buildVersion(platform: 1)])),
        ])
        #expect(Self.parse(image, runningArchitecture: nil) == .iOSSimulator)
    }

    @Test("64-bit fat headers use 64-bit slice offsets")
    func sixtyFourBitFatHeader() {
        let image = MachOFixture.fat(
            slices: [
                .init(cpuType: Self.foreignCPUType, cpuSubtype: 0,
                      image: MachOFixture.thin(commands: [MachOFixture.buildVersion(platform: 1)])),
                .init(cpuType: Self.hostCPUType, cpuSubtype: 0,
                      image: MachOFixture.thin(commands: [MachOFixture.buildVersion(platform: 7)])),
            ],
            is64Bit: true
        )
        #expect(Self.parse(image, runningArchitecture: nil) == .iOSSimulator)
    }

    @Test("A fat header declaring no slices resolves to nil")
    func fatHeaderWithoutSlices() {
        var image = MachOFixture.bigEndianBytes(FAT_MAGIC)
        image += MachOFixture.bigEndianBytes(UInt32(0))
        #expect(Self.parse(image) == nil)
    }

    @Test("A fat header whose slice table is truncated resolves to nil")
    func fatHeaderWithTruncatedSliceTable() {
        var image = MachOFixture.bigEndianBytes(FAT_MAGIC)
        image += MachOFixture.bigEndianBytes(UInt32(4))
        image += [0x00, 0x00, 0x00, 0x01] // one partial entry, then nothing
        #expect(Self.parse(image) == nil)
    }

    @Test("A slice offset pointing past the end of the file resolves to nil")
    func sliceOffsetBeyondEndOfFile() {
        var image = MachOFixture.bigEndianBytes(FAT_MAGIC)
        image += MachOFixture.bigEndianBytes(UInt32(1))
        image += MachOFixture.bigEndianBytes(UInt32(bitPattern: Self.hostCPUType))
        image += MachOFixture.bigEndianBytes(UInt32(0))
        image += MachOFixture.bigEndianBytes(UInt32(0x00FF_FFFF)) // offset far past EOF
        image += MachOFixture.bigEndianBytes(UInt32(1024))
        image += MachOFixture.bigEndianBytes(UInt32(14))
        #expect(Self.parse(image) == nil)
    }

    // MARK: - Malformed Load Commands

    @Test("A zero cmdsize terminates the walk instead of looping forever")
    func zeroCommandSizeDoesNotLoop() {
        let image = MachOFixture.thin(commands: [
            MachOFixture.buildVersion(platform: 7, declaredSizeOverride: 0),
        ])
        // The malformed command is rejected rather than read, so nothing resolves.
        #expect(Self.parse(image) == nil)
    }

    @Test("A cmdsize reaching past the load command region is rejected")
    func oversizedCommandSizeIsRejected() {
        let image = MachOFixture.thin(commands: [
            MachOFixture.buildVersion(platform: 7, declaredSizeOverride: 4096),
        ])
        #expect(Self.parse(image) == nil)
    }

    @Test("A cmdsize too small to hold its own fields is rejected")
    func undersizedCommandSizeIsRejected() {
        let image = MachOFixture.thin(commands: [
            MachOFixture.buildVersion(platform: 7, declaredSizeOverride: 4),
        ])
        #expect(Self.parse(image) == nil)
    }

    @Test("An LC_BUILD_VERSION too short to hold a platform field is rejected")
    func truncatedBuildVersionCommandIsRejected() {
        // Declared size covers cmd and cmdsize but stops before the platform field.
        let image = MachOFixture.thin(commands: [
            MachOFixture.LoadCommand(
                command: UInt32(bitPattern: LC_BUILD_VERSION),
                payload: [0x07, 0x00],
                declaredSizeOverride: 10
            ),
        ])
        #expect(Self.parse(image) == nil)
    }

    @Test("A truncated LC_BUILD_VERSION does not read into the command that follows it")
    func truncatedBuildVersionDoesNotReadPastItsOwnEnd() {
        // The declared size stops before the platform field, but another command follows,
        // so the bytes that field would occupy do exist — and would be misread as a
        // platform if the command's own length were not checked first.
        let image = MachOFixture.thin(commands: [
            MachOFixture.LoadCommand(
                command: UInt32(bitPattern: LC_BUILD_VERSION),
                payload: [0x07, 0x00],
                declaredSizeOverride: 10
            ),
            MachOFixture.filler(payloadByteCount: 16),
        ])
        #expect(Self.parse(image) == nil)
    }

    @Test("An ncmds larger than the region actually holds stops at the region end")
    func inflatedCommandCountStopsAtRegionEnd() {
        let image = MachOFixture.thin(
            commands: [MachOFixture.filler(payloadByteCount: 8)],
            declaredCommandCount: 5000
        )
        #expect(Self.parse(image) == nil)
    }

    @Test("An ncmds larger than the region does not prevent finding a real command")
    func inflatedCommandCountStillFindsPlatform() {
        let image = MachOFixture.thin(
            commands: [MachOFixture.buildVersion(platform: 7)],
            declaredCommandCount: 5000
        )
        #expect(Self.parse(image) == .iOSSimulator)
    }

    @Test("A sizeofcmds beyond the one-megabyte cap is rejected")
    func oversizedCommandRegionIsRejected() {
        let image = MachOFixture.thin(
            commands: [MachOFixture.buildVersion(platform: 7)],
            declaredCommandsSize: 1 << 21
        )
        #expect(Self.parse(image) == nil)
    }

    @Test("A sizeofcmds too small to hold a command is rejected")
    func undersizedCommandRegionIsRejected() {
        let image = MachOFixture.thin(
            commands: [MachOFixture.buildVersion(platform: 7)],
            declaredCommandsSize: 4
        )
        #expect(Self.parse(image) == nil)
    }

    @Test("A sizeofcmds larger than the file is rejected rather than over-read")
    func commandRegionLargerThanFileIsRejected() {
        let image = MachOFixture.thin(
            commands: [MachOFixture.buildVersion(platform: 7)],
            declaredCommandsSize: 8192
        )
        #expect(Self.parse(image) == nil)
    }
}

#endif
