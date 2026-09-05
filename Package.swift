// swift-tools-version: 6.2
import PackageDescription
import Foundation

extension Package.Dependency {
    enum LocalSearchPath {
        case package(path: String, isRelative: Bool, isEnabled: Bool)
    }

    static func package(local localSearchPaths: LocalSearchPath..., remote: Package.Dependency) -> Package.Dependency {
        let currentFilePath = #filePath
        let isClonedDependency = currentFilePath.contains("/checkouts/") ||
            currentFilePath.contains("/SourcePackages/") ||
            currentFilePath.contains("/.build/")

        if isClonedDependency {
            return remote
        }
        for local in localSearchPaths {
            switch local {
            case .package(let path, let isRelative, let isEnabled):
                guard isEnabled else { continue }
                let url = if isRelative, let resolvedURL = URL(string: path, relativeTo: URL(fileURLWithPath: #filePath)) {
                    resolvedURL
                } else {
                    URL(fileURLWithPath: path)
                }

                if FileManager.default.fileExists(atPath: url.path) {
                    return .package(path: url.path)
                }
            }
        }
        return remote
    }
}

let appkitPlatforms: [Platform] = [.macOS]

let uikitPlatforms: [Platform] = [.iOS, .tvOS, .visionOS, .watchOS, .macCatalyst]

let swiftSettings: [SwiftSetting] = [
//    .internalImportsByDefault
]

let package = Package(
    name: "UIFoundation",
    defaultLocalization: "en",
    platforms: [
        // AppKit -- macOS 12 is AppKitPlus's own floor. A binary target's platform
        // requirement is checked on the package graph, so neither `@available` nor
        // `#if AppKitPlus` can keep this at 10.15 while the trait is available.
        // See Documentations/Evolutions/0017-appkitplus-layer-backed-view.md.
        .macOS(.v12),
        // UIKit
        .iOS(.v13), .macCatalyst(.v13), .tvOS(.v13), .visionOS(.v1), .watchOS(.v6),
    ],
    products: [
        .library(
            name: "UIFoundation",
            targets: [
                "UIFoundation",
            ],
        ),

        .library(
            name: "UIFoundationToolbox",
            targets: [
                "UIFoundationToolbox",
            ],
        ),

        .library(
            name: "UIFoundationSettings",
            targets: [
                "UIFoundationSettings",
            ],
        ),

        .library(
            name: "UIFoundationSettingsUI",
            targets: [
                "UIFoundationSettingsUI",
            ],
        ),

        .library(
            name: "UIFoundationRunningApplication",
            targets: [
                "UIFoundationRunningApplication",
            ],
        ),
    ],
    traits: [
        .trait(name: "AppKitPlus"),
        .trait(name: "AppleInternal"),
        .trait(name: "FilterUI"),
        .trait(name: "IDEIcons"),
        .trait(name: "Navigation"),
        .trait(name: "NSAttributedStringBuilder"),
        .trait(name: "QuickActionBar"),
        .trait(name: "RunningApplication"),
        .trait(name: "Settings"),
        .trait(name: "StatusItemController"),
        .trait(name: "SystemHUD"),
        .trait(name: "TabBar"),
        .trait(name: "WelcomePanel"),
    ],
    dependencies: [
        // 0.2.1 is a floor, not a pin. Two earlier releases are excluded for
        // reasons that both fail silently or confusingly:
        //   - through 0.1.6 an `NSView (Appearance)` category declared
        //     `backgroundColor`, which shadows `LayerBackgroundProviding`'s
        //     property of the same name in every downstream module -- the
        //     renderer simply stops receiving the value;
        //   - through 0.2.0 `NSCollectionViewItem` / `NSTableCellView` carried an
        //     extension property named `contentView`, which turns any subclass
        //     declaring its own (such as `XiblessCollectionViewItem`) into an
        //     illegal override. 0.2.1 renamed it `configurationContentView`.
        // Upstream is pre-1.0 and promises no API or ABI stability, so re-check
        // the name-collision surface across `NSView` / `NSViewController` /
        // `NSTableCellView` / `NSCollectionViewItem` when it moves.
        .package(
            url: "https://github.com/AppKitSupportProgram/AppKitPlus-Release",
            from: "0.2.1",
        ),
        .package(
            remote: .package(
                url: "https://github.com/Mx-Iris/FrameworkToolbox",
                from: "0.7.4",
            ),
        ),
        .package(
            url: "https://github.com/p-x9/AssociatedObject",
            from: "0.13.0",
        ),
    ],
    targets: [
        .target(
            name: "UIFoundationTypealias",
        ),

        .target(
            name: "UIFoundation",
            dependencies: [
                .target(name: "UIFoundationAppKit", condition: .when(platforms: appkitPlatforms)),
                .target(name: "UIFoundationUIKit", condition: .when(platforms: uikitPlatforms)),
                "UIFoundationUtilities",
                "UIFoundationToolbox",
                "UIFoundationTypealias",
                "UIFoundationShared",
                .target(name: "UIFoundationAppleInternal", condition: .when(traits: ["AppleInternal"])),
                .target(name: "UIFoundationAppleInternalObjC", condition: .when(traits: ["AppleInternal"])),
            ],
            swiftSettings: swiftSettings,
        ),

        .target(
            name: "UIFoundationAppKit",
            dependencies: [
                "UIFoundationToolbox",
                "UIFoundationTypealias",
                "UIFoundationUtilities",
                "UIFoundationShared",
                .product(name: "AssociatedObject", package: "AssociatedObject"),
                .product(name: "AppKitPlus", package: "AppKitPlus-Release", condition: .when(platforms: appkitPlatforms, traits: ["AppKitPlus"])),
            ],
            resources: [
                .process("Resources"),
                .process("Filter/Resources/Colors.xcassets"),
                .process("Filter/Resources/Symbols.xcassets"),
                .process("Filter/Resources/MoreSymbols.xcassets"),
                .process("Filter/Resources/Localization"),
                .process("Filter/Resources/Documentation.docc"),
            ],
            swiftSettings: swiftSettings,
        ),
        .target(
            name: "UIFoundationUIKit",
            dependencies: [
                "UIFoundationToolbox",
                "UIFoundationTypealias",
                "UIFoundationUtilities",
                "UIFoundationShared",
            ],
            swiftSettings: swiftSettings,
        ),
        .target(
            name: "UIFoundationShared",
            dependencies: [
                "UIFoundationToolbox",
                "UIFoundationTypealias",
            ],
            swiftSettings: swiftSettings,
        ),
        .target(
            name: "UIFoundationUtilities",
            dependencies: [
                "UIFoundationToolbox",
                "UIFoundationTypealias",
            ],
            swiftSettings: swiftSettings,
        ),
        .target(
            name: "UIFoundationToolbox",
            dependencies: [
                "UIFoundationTypealias",
                .product(name: "FrameworkToolbox", package: "FrameworkToolbox"),
                .product(name: "FoundationToolbox", package: "FrameworkToolbox"),
                .product(name: "AssociatedObject", package: "AssociatedObject"),
            ],
            swiftSettings: swiftSettings,
        ),

        .target(
            name: "UIFoundationAppleInternal",
            dependencies: [
                "UIFoundationAppleInternalObjC",
                "UIFoundationAppKit",
                "UIFoundationCarbonInternal",
                .product(name: "ObjCRuntimeToolbox", package: "FrameworkToolbox"),
            ],
            swiftSettings: swiftSettings,
        ),

        .target(
            name: "UIFoundationCarbonInternal",
        ),

        .target(
            name: "UIFoundationAppleInternalObjC",
        ),

        .target(
            name: "UIFoundationSettings",
            swiftSettings: swiftSettings,
        ),

        .target(
            name: "UIFoundationSettingsUI",
            dependencies: [
                "UIFoundationSettings",
                .target(name: "UIFoundationAppKit", condition: .when(platforms: appkitPlatforms)),
            ],
            // The module ships user-facing text of its own (the back / forward
            // buttons), so it needs a bundle to look strings up in. Without a
            // resource here `#bundle` does not resolve, and a plain literal
            // would silently search the app's catalog instead of this one.
            resources: [
                .process("Resources"),
            ],
            swiftSettings: swiftSettings,
        ),

        // Running applications and BSD processes: value-type models with architecture /
        // platform / sandbox detection, two observer actors, and a picker UI. Kept out of
        // the umbrella because its macOS 11 floor is higher than the package's 10.15 --
        // joining it would raise the floor for every consumer.
        .target(
            name: "UIFoundationRunningApplication",
            dependencies: [
                "UIFoundationAppKit",
                "UIFoundationToolbox",
                "UIFoundationUtilities",
                "UIFoundationShared",
            ],
            swiftSettings: swiftSettings + [.swiftLanguageMode(.v6)],
        ),

        .testTarget(
            name: "UIFoundationTests",
            dependencies: [
                "UIFoundation",
                "UIFoundationToolbox",
                "UIFoundationSettings",
                .target(name: "UIFoundationSettingsUI", condition: .when(platforms: appkitPlatforms)),
                .target(name: "UIFoundationRunningApplication", condition: .when(platforms: appkitPlatforms)),
                .product(name: "AppKitPlus", package: "AppKitPlus-Release", condition: .when(platforms: appkitPlatforms, traits: ["AppKitPlus"])),
            ],
        ),
    ],
    swiftLanguageModes: [.v5],
)

extension SwiftSetting {
    static let existentialAny: Self = .enableUpcomingFeature("ExistentialAny") // SE-0335, Swift 5.6,  SwiftPM 5.8+
    static let internalImportsByDefault: Self = .enableUpcomingFeature("InternalImportsByDefault") // SE-0409, Swift 6.0,  SwiftPM 6.0+
    static let memberImportVisibility: Self = .enableUpcomingFeature("MemberImportVisibility") // SE-0444, Swift 6.1,  SwiftPM 6.1+
    static let inferIsolatedConformances: Self = .enableUpcomingFeature("InferIsolatedConformances") // SE-0470, Swift 6.2,  SwiftPM 6.2+
    static let nonisolatedNonsendingByDefault: Self = .enableUpcomingFeature("NonisolatedNonsendingByDefault") // SE-0461, Swift 6.2,  SwiftPM 6.2+
    static let immutableWeakCaptures: Self = .enableUpcomingFeature("ImmutableWeakCaptures") // SE-0481, Swift 6.2,  SwiftPM 6.2+
}
