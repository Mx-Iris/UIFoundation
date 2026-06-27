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
        // AppKit
        .macOS(.v10_15),
        // UIKit
        .iOS(.v13), .macCatalyst(.v13), .tvOS(.v13), .visionOS(.v1), .watchOS(.v6),
    ],
    products: [
        .library(
            name: "UIFoundation",
            targets: [
                "UIFoundation",
            ]
        ),

        .library(
            name: "UIFoundationToolbox",
            targets: [
                "UIFoundationToolbox",
            ]
        ),
    ],
    traits: [
        .trait(name: "AppleInternal"),
        .trait(name: "FilterUI"),
        .trait(name: "IDEIcons"),
        .trait(name: "NSAttributedStringBuilder"),
        .trait(name: "QuickActionBar"),
        .trait(name: "TabsControl"),
    ],
    dependencies: [
        .package(
            remote: .package(
                url: "https://github.com/Mx-Iris/FrameworkToolbox",
                from: "0.7.4"
            ),
        ),
        .package(
            url: "https://github.com/p-x9/AssociatedObject",
            from: "0.13.0"
        ),
    ],
    targets: [
        .target(
            name: "UIFoundationTypealias"
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
            ],
            resources: [
                .process("Resources"),
                .process("Filter/Resources/Colors.xcassets"),
                .process("Filter/Resources/Symbols.xcassets"),
                .process("Filter/Resources/MoreSymbols.xcassets"),
                .process("Filter/Resources/Localization"),
                .process("Filter/Resources/Documentation.docc"),
                .copy("TabsControl/Templates"),
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
            name: "UIFoundationCarbonInternal"
        ),
        
            .target(
            name: "UIFoundationAppleInternalObjC"
        ),

        .testTarget(
            name: "UIFoundationTests",
            dependencies: [
                "UIFoundation",
            ]
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
