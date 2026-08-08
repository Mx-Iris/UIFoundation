#if canImport(AppKit) && !targetEnvironment(macCatalyst)

import Testing
import AppKit
import UniformTypeIdentifiers
import UIFoundationToolbox

/// Regression coverage for resolving Apple hardware model identifiers ("iPhone16,2",
/// "Mac15,7") to device icons and SF Symbols.
///
/// These assertions read the system's CoreTypes.bundle declarations, so every model
/// identifier used here is old enough that the running macOS is guaranteed to declare it.
@Suite("Device icon resolution from hardware model identifiers")
struct DeviceIconResolutionTests {

    // MARK: SF Symbol resolution

    /// `UTType.supertypes` is an unordered set holding the entire ancestor closure, so a
    /// Dynamic Island iPhone conforms to `com.apple.iphone`,
    /// `com.apple.homebuttonless-iphone` *and* `com.apple.dynamic-island-iphone` at once.
    /// Resolving through an unordered dictionary lookup returned whichever ancestor the
    /// set yielded first, which handed a home-button symbol to phones that have no home
    /// button. Resolution must instead prefer the most specific device family.
    @Test(
        "The most specific device family wins over its ancestors",
        arguments: [
            // iPhone — dynamic island ⊂ home-button-less ⊂ iPhone.
            (modelIdentifier: "iPhone16,2", expectedSymbolName: "iphone.gen3"),   // iPhone 15 Pro Max
            (modelIdentifier: "iPhone14,7", expectedSymbolName: "iphone.gen2"),   // iPhone 14
            (modelIdentifier: "iPhone10,3", expectedSymbolName: "iphone.gen2"),   // iPhone X
            (modelIdentifier: "iPhone12,8", expectedSymbolName: "iphone.gen1"),   // iPhone SE (2nd gen)
            (modelIdentifier: "iPhone8,1", expectedSymbolName: "iphone.gen1"),    // iPhone 6s
            // iPad — home-button-less ⊂ iPad.
            (modelIdentifier: "iPad14,3", expectedSymbolName: "ipad"),            // iPad Pro 11-inch (4th gen)
            (modelIdentifier: "iPad8,1", expectedSymbolName: "ipad"),             // iPad Pro 11-inch (1st gen)
            (modelIdentifier: "iPad6,11", expectedSymbolName: "ipad.homebutton"), // iPad (5th gen)
            // Mac laptops — notched ⊂ notchless ⊂ laptop.
            (modelIdentifier: "Mac15,7", expectedSymbolName: "macbook.gen2"),          // MacBook Pro 16-inch, 2023
            (modelIdentifier: "MacBookPro18,1", expectedSymbolName: "macbook.gen2"),   // MacBook Pro 16-inch, 2021
            (modelIdentifier: "MacBookPro16,1", expectedSymbolName: "macbook.gen1"),   // MacBook Pro 16-inch, 2019
            (modelIdentifier: "MacBookAir10,1", expectedSymbolName: "macbook.gen1"),   // MacBook Air (M1, 2020)
            // Mac desktops.
            (modelIdentifier: "Macmini9,1", expectedSymbolName: "macmini"),            // Mac mini (M1, 2020)
            (modelIdentifier: "iMac21,1", expectedSymbolName: "desktopcomputer"),      // iMac (24-inch, M1, 2021)
            (modelIdentifier: "MacPro7,1", expectedSymbolName: "macpro.gen3"),         // Mac Pro (2019)
            // Other device families.
            (modelIdentifier: "Watch7,1", expectedSymbolName: "applewatch"),
            (modelIdentifier: "AppleTV11,1", expectedSymbolName: "appletv"),
            (modelIdentifier: "iPod9,1", expectedSymbolName: "ipodtouch"),
        ]
    )
    func symbolNameResolvesToMostSpecificFamily(modelIdentifier: String, expectedSymbolName: String) {
        #expect(
            NSWorkspace.shared.box.deviceSymbolName(forModelIdentifier: modelIdentifier) == expectedSymbolName,
            "\(modelIdentifier) should resolve to \(expectedSymbolName)"
        )
    }

    @Test("Every mapped SF Symbol name exists on this system")
    func mappedSymbolNamesExist() throws {
        let modelIdentifiers = [
            "iPhone16,2", "iPhone14,7", "iPhone8,1",
            "iPad14,3", "iPad6,11",
            "Mac15,7", "MacBookPro16,1", "Macmini9,1", "iMac21,1", "MacPro7,1",
            "Watch7,1", "AppleTV11,1", "iPod9,1",
        ]
        for modelIdentifier in modelIdentifiers {
            let symbolName = try #require(
                NSWorkspace.shared.box.deviceSymbolName(forModelIdentifier: modelIdentifier),
                "\(modelIdentifier) resolved to no symbol"
            )
            #expect(
                NSImage(systemSymbolName: symbolName, accessibilityDescription: nil) != nil,
                "SF Symbol \(symbolName) (from \(modelIdentifier)) does not exist"
            )
        }
    }

    // MARK: Undeclared model identifiers

    /// A simulator reports its host architecture through `hw.machine`, and a VM reports a
    /// model the host OS does not declare. Both resolve to a *dynamic* UTType that carries
    /// no icon and no supertypes, so they must be reported as a miss rather than silently
    /// producing a wrong icon.
    @Test(
        "Undeclared model identifiers resolve to nothing",
        arguments: ["arm64", "x86_64", "i386", "VirtualMac2,1", "NotAModel1,1", ""]
    )
    func undeclaredModelIdentifiersResolveToNothing(modelIdentifier: String) {
        #expect(NSWorkspace.shared.box.declaredDeviceIcon(forModelIdentifier: modelIdentifier) == nil)
        #expect(NSWorkspace.shared.box.declaredDeviceSymbolIcon(forModelIdentifier: modelIdentifier) == nil)
        #expect(NSWorkspace.shared.box.deviceSymbolName(forModelIdentifier: modelIdentifier) == nil)
    }

    /// The non-optional entry points keep their substitute-a-generic-icon behaviour, so
    /// callers that never want to deal with a miss stay source-compatible.
    @Test("Non-optional entry points still substitute a fallback icon")
    func nonOptionalEntryPointsFallBack() {
        _ = NSWorkspace.shared.box.deviceIcon(forModelIdentifier: "VirtualMac2,1")
        _ = NSWorkspace.shared.box.deviceSymbolIcon(forModelIdentifier: "VirtualMac2,1")
    }

    // MARK: Declared model identifiers

    @Test(
        "Declared model identifiers produce a full-colour icon",
        arguments: ["iPhone16,2", "iPad14,3", "Mac15,7", "Macmini9,1", "Watch7,1"]
    )
    func declaredModelIdentifiersProduceIcon(modelIdentifier: String) throws {
        let icon = try #require(
            NSWorkspace.shared.box.declaredDeviceIcon(forModelIdentifier: modelIdentifier),
            "\(modelIdentifier) should be declared by CoreTypes.bundle"
        )
        #expect(icon.size.width > 0 && icon.size.height > 0)
        #expect(icon.representations.isEmpty == false)
    }
}

#endif
