#if RunningApplication && os(macOS)

import Testing
@testable import UIFoundationRunningApplication

@Suite("Platform")
struct PlatformTests {
    /// Every case the library knows about, paired with its Mach-O constant. Written out
    /// rather than derived, so that a typo in the production mapping cannot be mirrored
    /// by the same typo in the test.
    static let knownPlatforms: [(rawValue: UInt32, platform: Platform)] = [
        (1, .macOS),
        (2, .iOS),
        (3, .tvOS),
        (4, .watchOS),
        (5, .bridgeOS),
        (6, .macCatalyst),
        (7, .iOSSimulator),
        (8, .tvOSSimulator),
        (9, .watchOSSimulator),
        (10, .driverKit),
        (11, .visionOS),
        (12, .visionOSSimulator),
        (13, .firmware),
        (14, .securityEnclaveOS),
        (15, .macOSExclaveCore),
        (16, .macOSExclaveKit),
        (17, .iOSExclaveCore),
        (18, .iOSExclaveKit),
        (19, .tvOSExclaveCore),
        (20, .tvOSExclaveKit),
        (21, .watchOSExclaveCore),
        (22, .watchOSExclaveKit),
        (23, .visionOSExclaveCore),
        (24, .visionOSExclaveKit),
    ]

    @Test("Mach-O constants map to platforms and back", arguments: knownPlatforms)
    func machOConstantRoundTrips(rawValue: UInt32, platform: Platform) {
        #expect(Platform(machOPlatformValue: rawValue) == platform)
        #expect(platform.machOPlatformValue == rawValue)
    }

    @Test("Unrecognized constants keep their raw value", arguments: [UInt32(0), 25, 99, .max])
    func unrecognizedConstantsArePreserved(rawValue: UInt32) {
        let platform = Platform(machOPlatformValue: rawValue)
        #expect(platform == .unknown(rawValue))
        #expect(platform.machOPlatformValue == rawValue)
        #expect(platform.description == "Platform \(rawValue)")
        #expect(!platform.isSimulator)
    }

    @Test("Exactly the four simulator platforms report isSimulator")
    func simulatorPlatformsAreIdentified() {
        let simulators = Self.knownPlatforms.filter(\.platform.isSimulator).map(\.platform)
        #expect(simulators == [.iOSSimulator, .tvOSSimulator, .watchOSSimulator, .visionOSSimulator])
    }

    @Test("Simulator platforms sort ahead of every other platform")
    func simulatorPlatformsSortFirst() {
        let simulatorRanks = Self.knownPlatforms.filter(\.platform.isSimulator).map(\.platform.sortOrder)
        let otherRanks = Self.knownPlatforms.filter { !$0.platform.isSimulator }.map(\.platform.sortOrder)
        let unknownRank = Platform.unknown(99).sortOrder

        #expect(simulatorRanks.max()! < otherRanks.min()!)
        #expect(otherRanks.max()! < unknownRank)
    }

    @Test("Sort ranks are unique so ordering is deterministic")
    func sortRanksAreUnique() {
        let ranks = Self.knownPlatforms.map(\.platform.sortOrder)
        #expect(Set(ranks).count == ranks.count)
    }

    @Test("Display wording is spelled out in full", arguments: [
        (Platform.macOS, "macOS"),
        (.iOSSimulator, "iOS Simulator"),
        (.tvOSSimulator, "tvOS Simulator"),
        (.watchOSSimulator, "watchOS Simulator"),
        (.visionOSSimulator, "visionOS Simulator"),
        (.macCatalyst, "Mac Catalyst"),
        (.driverKit, "DriverKit"),
        (.securityEnclaveOS, "sepOS"),
        (.macOSExclaveKit, "macOS ExclaveKit"),
    ])
    func displayWording(platform: Platform, expected: String) {
        #expect(platform.description == expected)
    }

    @Test("Each OS family gets its own badge colour, shared with its simulator")
    func badgeColoursGroupByFamily() {
        // The colour answers "which platform", so a simulator matches its family; the
        // label is what separates them.
        #expect(Platform.iOS.badgeColor == Platform.iOSSimulator.badgeColor)
        #expect(Platform.tvOS.badgeColor == Platform.tvOSSimulator.badgeColor)
        #expect(Platform.watchOS.badgeColor == Platform.watchOSSimulator.badgeColor)
        #expect(Platform.visionOS.badgeColor == Platform.visionOSSimulator.badgeColor)

        // The families that actually turn up in a process list must be distinguishable
        // from each other -- this is what "everything is grey" looked like before.
        let visible: [Platform] = [.iOSSimulator, .macCatalyst, .driverKit, .macOS]
        let colours = visible.map(\.badgeColor)
        #expect(Set(colours).count == visible.count, "\(colours)")
    }

    @Test("Search matches both the display wording and the case name", arguments: [
        (Platform.iOSSimulator, "sim"),
        (.iOSSimulator, "simulator"),
        (.iOSSimulator, "SIMULATOR"),
        (.iOSSimulator, "iOS Simulator"),
        (.iOSSimulator, "iOSSimulator"),
        (.tvOSSimulator, "tvos"),
        // No space: only the case name can match this.
        (.macCatalyst, "maccatalyst"),
        (.macCatalyst, "Mac Catalyst"),
        (.macCatalyst, "catalyst"),
        (.driverKit, "driver"),
        // Expanded name: only the case name carries "enclave".
        (.securityEnclaveOS, "enclave"),
        // Official spelling: only the display wording carries "sepOS".
        (.securityEnclaveOS, "sepos"),
    ])
    func searchMatches(platform: Platform, query: String) {
        #expect(platform.matches(searchText: query))
    }

    @Test("Search does not match unrelated queries", arguments: [
        (Platform.macOS, "simulator"),
        (.macOS, "iOS"),
        (.iOS, "simulator"),
        (.driverKit, "catalyst"),
    ])
    func searchRejectsUnrelatedQueries(platform: Platform, query: String) {
        #expect(!platform.matches(searchText: query))
    }
}

#endif
