#if canImport(AppKit) && !targetEnvironment(macCatalyst)

import AppKit
import UniformTypeIdentifiers
import FrameworkToolbox

// MARK: - NSWorkspace Extension

@available(macOS 11.0, *)
extension FrameworkToolbox where Base == NSWorkspace {
    
    // MARK: - AppleDevice

    /// Represents known Apple device families for icon and SF Symbol lookup.
    ///
    /// Each case maps to a UTType identifier declared in CoreTypes.bundle and
    /// an SF Symbol name suitable for use with `NSImage(systemSymbolName:accessibilityDescription:)`.
    public enum AppleDevice: String, CaseIterable, Hashable, Sendable {
        // MARK: Mac

        case mac
        case macLaptop
        case macLaptopNotched
        case macBook
        case macBookAir
        case macBookPro
        case iMac
        case macMini
        case macStudio
        case macPro
        case macProRack
        case macProCylinder

        // MARK: iPhone

        case iPhone
        case iPhoneFaceID
        case iPhoneDynamicIsland

        // MARK: iPad

        case iPad
        case iPadModern

        // MARK: Apple Watch

        case appleWatch

        // MARK: Apple TV

        case appleTV

        // MARK: HomePod

        case homePod
        case homePodMini

        // MARK: Apple Vision Pro

        case appleVisionPro

        // MARK: iPod

        case iPodTouch

        // MARK: AirPods

        case airPods
        case airPodsPro
        case airPodsMax

        // MARK: Display

        case display

        /// The SF Symbol name for this device family.
        public var symbolName: String {
            switch self {
            case .mac:                  return "desktopcomputer"
            case .macLaptop:            return "macbook"
            case .macLaptopNotched:     return "macbook.gen2"
            case .macBook:              return "macbook"
            case .macBookAir:           return "macbook"
            case .macBookPro:           return "macbook"
            case .iMac:                 return "desktopcomputer"
            case .macMini:              return "macmini"
            case .macStudio:            return "macstudio"
            case .macPro:               return "macpro.gen3"
            case .macProRack:           return "macpro.gen3.server"
            case .macProCylinder:       return "macpro.gen2"
            case .iPhone:               return "iphone.gen1"
            case .iPhoneFaceID:         return "iphone.gen2"
            case .iPhoneDynamicIsland:  return "iphone.gen3"
            case .iPad:                 return "ipad.homebutton"
            case .iPadModern:           return "ipad"
            case .appleWatch:           return "applewatch"
            case .appleTV:              return "appletv"
            case .homePod:              return "homepod"
            case .homePodMini:          return "homepodmini"
            case .appleVisionPro:       return "visionpro"
            case .iPodTouch:            return "ipodtouch"
            case .airPods:              return "airpods"
            case .airPodsPro:           return "airpodspro"
            case .airPodsMax:           return "airpodsmax"
            case .display:              return "display"
            }
        }

        /// The UTType identifier for this device family.
        public var utTypeIdentifier: String {
            switch self {
            case .mac:                  return "com.apple.mac"
            case .macLaptop:            return "com.apple.mac.laptop"
            case .macLaptopNotched:     return "com.apple.mac.notched-laptop"
            case .macBook:              return "com.apple.macbook"
            case .macBookAir:           return "com.apple.macbookair"
            case .macBookPro:           return "com.apple.macbookpro"
            case .iMac:                 return "com.apple.imac"
            case .macMini:              return "com.apple.macmini"
            case .macStudio:            return "com.apple.macstudio"
            case .macPro:               return "com.apple.macpro-2019"
            case .macProRack:           return "com.apple.macpro-2019-rackmount"
            case .macProCylinder:       return "com.apple.macpro-cylinder"
            case .iPhone:               return "com.apple.iphone"
            case .iPhoneFaceID:         return "com.apple.homebuttonless-iphone"
            case .iPhoneDynamicIsland:  return "com.apple.dynamic-island-iphone"
            case .iPad:                 return "com.apple.ipad"
            case .iPadModern:           return "com.apple.homebuttonless-ipad"
            case .appleWatch:           return "com.apple.watch"
            case .appleTV:              return "com.apple.apple-tv"
            case .homePod:              return "com.apple.homepod"
            case .homePodMini:          return "com.apple.homepod-mini"
            case .appleVisionPro:       return "com.apple.visionpro"
            case .iPodTouch:            return "com.apple.ipod-touch"
            case .airPods:              return "com.apple.airpods"
            case .airPodsPro:           return "com.apple.airpods-pro"
            case .airPodsMax:           return "com.apple.airpods-max"
            case .display:              return "public.display"
            }
        }

        /// The UTType for this device family, if declared in the system.
        public var utType: UTType? {
            UTType(utTypeIdentifier)
        }

        /// The full-color device icon from CoreTypes.bundle.
        /// Falls back to an SF Symbol image if the UTType is not declared.
        public var icon: NSImage {
            if let type = utType {
                return NSWorkspace.shared.icon(for: type)
            }
            return NSImage(systemSymbolName: symbolName, accessibilityDescription: nil)
                ?? NSImage(named: NSImage.computerName)!
        }
    }

    // MARK: - Device Symbol Name Map

    /// Maps UTType identifiers to SF Symbol names for device family resolution,
    /// ordered from the most specific device family to the most general one.
    /// Derived from CoreTypes.bundle UTTypeIcons/UTTypeSymbolName declarations.
    ///
    /// The order is load-bearing. `UTType.supertypes` is an unordered set holding the
    /// entire ancestor closure, so an iPhone 15 Pro Max conforms to `com.apple.iphone`,
    /// `com.apple.homebuttonless-iphone` *and* `com.apple.dynamic-island-iphone` at the
    /// same time, and a notched MacBook Pro conforms to both `com.apple.mac.notched-laptop`
    /// and `com.apple.mac.notchless-laptop`. Looking those supertypes up in a dictionary
    /// returns whichever one the set happens to yield first, which silently produces a
    /// home-button iPhone symbol for a Dynamic Island phone. Walking a fixed order and
    /// taking the first match instead makes the result deterministic and correct.
    private static let _orderedDeviceSymbolNames: [(utTypeIdentifier: String, symbolName: String)] = [
        // iPhone — dynamic island ⊂ home-button-less ⊂ iPhone.
        ("com.apple.dynamic-island-iphone",     "iphone.gen3"),
        ("com.apple.iphone-x",                  "iphone.gen2"),
        ("com.apple.homebuttonless-iphone",     "iphone.gen2"),
        ("com.apple.iphone-8-plus",             "iphone.gen1"),
        ("com.apple.iphone-8",                  "iphone.gen1"),
        ("com.apple.iphone-4",                  "iphone.gen1"),
        ("com.apple.iphone",                    "iphone.gen1"),

        // iPad — home-button-less ⊂ iPad.
        ("com.apple.homebuttonless-ipad",       "ipad"),
        ("com.apple.ipad",                      "ipad.homebutton"),

        // Mac laptops — notched ⊂ notchless ⊂ laptop.
        ("com.apple.macbookair.notched",        "macbook.gen2"),
        ("com.apple.macbookpro-2021",           "macbook.gen2"),
        ("com.apple.mac.notched-laptop",        "macbook.gen2"),
        ("com.apple.mac.notchless-laptop",      "macbook.gen1"),
        ("com.apple.macbookpro",                "macbook"),
        ("com.apple.macbookair",                "macbook"),
        ("com.apple.macbook",                   "macbook"),
        ("com.apple.mac.laptop",                "macbook"),

        // Mac desktops.
        ("com.apple.macstudio",                 "macstudio"),
        ("com.apple.macmini-2020",              "macmini"),
        ("com.apple.macmini",                   "macmini"),
        ("com.apple.imac-2021",                 "desktopcomputer"),
        ("com.apple.imac",                      "desktopcomputer"),
        ("com.apple.macpro-2019-rackmount",     "macpro.gen3.server"),
        ("com.apple.mac.rackmount",             "macpro.gen3.server"),
        ("com.apple.macpro-cylinder",           "macpro.gen2"),
        ("com.apple.macpro-firewire",           "macpro.gen1"),
        ("com.apple.macpro-2019",               "macpro.gen3"),
        ("com.apple.mac.tower",                 "macpro.gen3"),
        ("com.apple.macpro",                    "macpro.gen3"),
        ("com.apple.mac",                       "desktopcomputer"),

        // Apple Watch
        ("com.apple.watch",                     "applewatch"),

        // Apple TV
        ("com.apple.apple-tv",                  "appletv"),

        // HomePod — mini ⊂ HomePod.
        ("com.apple.homepod-mini",              "homepodmini"),
        ("com.apple.homepod",                   "homepod"),

        // Apple Vision Pro
        ("com.apple.visionpro",                 "visionpro"),

        // iPod — touch and shuffle ⊂ iPod.
        ("com.apple.ipod-touch",                "ipodtouch"),
        ("com.apple.ipod-shuffle",              "ipodshuffle.gen4"),
        ("com.apple.legacy-ipod",               "ipod"),
        ("com.apple.ipod",                      "ipod"),

        // AirPods — Max, Pro and gen 3 ⊂ AirPods.
        ("com.apple.airpods-max",               "airpodsmax"),
        ("com.apple.airpods-pro",               "airpodspro"),
        ("com.apple.airpods-gen3",              "airpods.gen3"),
        ("com.apple.airpods",                   "airpods"),

        // Display
        ("com.apple.studio-display",            "display"),
        ("com.apple.pro-display-xdr",           "display"),
        ("com.apple.virtual-machine",           "display"),
        ("public.display",                      "display"),
    ]

    /// The tag class for Apple device model codes (e.g., "Mac15,14", "iPhone16,2").
    private static let _deviceModelCodeTagClass = UTTagClass(rawValue: "com.apple.device-model-code")

    /// Color icon of a generic display, used as fallback for unrecognized device models.
    /// Loaded directly from CoreTypes.bundle to bypass NSWorkspace's dynamic resolution.
    private static let _fallbackDeviceColorIcon = NSImage(contentsOfFile: "/System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/com.apple.led-cinema-display-27.icns") ?? NSImage(named: NSImage.computerName)!

    /// Resolves the SF Symbol name for a UTType from the type itself and its supertype
    /// closure, preferring the most specific device family that matches.
    private static func _resolveSymbolName(for type: UTType) -> String? {
        var conformingIdentifiers = Set(type.supertypes.map(\.identifier))
        conformingIdentifiers.insert(type.identifier)
        return _orderedDeviceSymbolNames.first { conformingIdentifiers.contains($0.utTypeIdentifier) }?.symbolName
    }

    /// Resolves a hardware model identifier to its UTType, if the system declares one.
    ///
    /// Model identifiers the running OS does not know about — a simulator's host
    /// architecture (`arm64`, `x86_64`), a VM (`VirtualMac2,1`), or hardware newer than
    /// this macOS release — resolve to a *dynamic* UTType that carries no icon and no
    /// supertypes, so those are reported as a miss rather than passed along.
    private static func _resolveDeclaredType(forModelIdentifier modelIdentifier: String) -> UTType? {
        guard let type = UTType(tag: modelIdentifier, tagClass: _deviceModelCodeTagClass, conformingTo: nil),
              type.isDeclared else {
            return nil
        }
        return type
    }

    /// Returns the full-color device icon for the given hardware model identifier.
    ///
    /// Uses `UTType` resolution via `com.apple.device-model-code` tag class to find
    /// the device icon from CoreTypes.bundle, similar to the icon shown in About This Mac.
    /// Dynamic (undeclared) UTTypes have no dedicated icon and fall back to the
    /// system computer icon obtained via `GetIconRef('root')`.
    ///
    /// - Parameter modelIdentifier: The hardware model identifier (e.g., "Mac15,14", "iPhone16,2").
    /// - Returns: The device icon, or the current computer icon if the model is not recognized.
    public func deviceIcon(forModelIdentifier modelIdentifier: String) -> NSImage {
        // Dynamic (undeclared) types like "VirtualMac2,1" have no icon in CoreTypes.bundle.
        // Fall back to the generic display icon.
        declaredDeviceIcon(forModelIdentifier: modelIdentifier) ?? Self._fallbackDeviceColorIcon
    }

    /// Returns the full-color device icon for the given hardware model identifier, or
    /// `nil` when the model is not declared in CoreTypes.bundle.
    ///
    /// Unlike ``deviceIcon(forModelIdentifier:)``, which substitutes a generic display
    /// icon, this reports the miss so callers holding a more appropriate fallback of
    /// their own — an asset catalog image, an SF Symbol — can supply it instead.
    ///
    /// - Parameter modelIdentifier: The hardware model identifier (e.g., "Mac15,14", "iPhone16,2").
    /// - Returns: The device icon, or `nil` if the model is not recognized.
    public func declaredDeviceIcon(forModelIdentifier modelIdentifier: String) -> NSImage? {
        Self._resolveDeclaredType(forModelIdentifier: modelIdentifier).map { base.icon(for: $0) }
    }

    /// Returns the SF Symbol name for the given hardware model identifier.
    ///
    /// Resolves the model identifier to a UTType and walks the supertype chain
    /// to find a known SF Symbol name for the device family.
    ///
    /// - Parameter modelIdentifier: The hardware model identifier (e.g., "Mac15,14", "iPhone16,2").
    /// - Returns: The SF Symbol name, or `nil` if no symbol mapping is found.
    public func deviceSymbolName(forModelIdentifier modelIdentifier: String) -> String? {
        Self._resolveDeclaredType(forModelIdentifier: modelIdentifier).flatMap(Self._resolveSymbolName(for:))
    }

    public func deviceSymbolIcon(forModelIdentifier modelIdentifier: String) -> NSImage {
        declaredDeviceSymbolIcon(forModelIdentifier: modelIdentifier) ?? fallbackIcon
    }

    /// Returns the SF Symbol device image for the given hardware model identifier, or
    /// `nil` when the model resolves to no known device family.
    ///
    /// The symbol counterpart to ``declaredDeviceIcon(forModelIdentifier:)``: it reports
    /// the miss instead of substituting a generic desktop computer symbol.
    ///
    /// - Parameter modelIdentifier: The hardware model identifier (e.g., "Mac15,14", "iPhone16,2").
    /// - Returns: The SF Symbol image, or `nil` if the model is not recognized.
    public func declaredDeviceSymbolIcon(forModelIdentifier modelIdentifier: String) -> NSImage? {
        deviceSymbolName(forModelIdentifier: modelIdentifier)
            .flatMap { NSImage(systemSymbolName: $0, accessibilityDescription: nil) }
    }

    /// Returns the full-color device icon for a known Apple device family.
    public func deviceIcon(for device: AppleDevice) -> NSImage {
        device.icon
    }
    
    private var fallbackIcon: NSImage {
        NSImage(systemSymbolName: "desktopcomputer", accessibilityDescription: nil)
            ?? NSImage(named: NSImage.computerName)!
    }
}

#endif
