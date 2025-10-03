// swift-tools-version: 6.2
import PackageDescription

let appkitPlatforms: [Platform] = [.macOS]

let uikitPlatforms: [Platform] = [.iOS, .tvOS, .visionOS, .watchOS, .macCatalyst]

let package = Package(
    name: "UIFoundation",
    platforms: [.macOS(.v10_15), .iOS(.v13), .macCatalyst(.v13), .tvOS(.v13)],
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

        .library(
            name: "UIFoundationAppleInternal",
            targets: ["UIFoundationAppleInternal"]
        ),

    ],
    dependencies: [
        .package(
            url: "https://github.com/Mx-Iris/FrameworkToolbox",
            branch: "main"
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
                "UIFoundationAppKit",
                "UIFoundationUIKit",
                "UIFoundationUtilities",
                "UIFoundationToolbox",
                "UIFoundationTypealias",
                "UIFoundationShared",
            ]
        ),

        .target(
            name: "UIFoundationAppKit",
            dependencies: [
                "UIFoundationToolbox",
                "UIFoundationTypealias",
                "UIFoundationUtilities",
                "UIFoundationShared",
            ],
            resources: [
                .process("Resources"),
            ]
        ),
        .target(
            name: "UIFoundationUIKit",
            dependencies: [
                "UIFoundationToolbox",
                "UIFoundationTypealias",
                "UIFoundationUtilities",
                "UIFoundationShared",
            ]
        ),
        .target(
            name: "UIFoundationShared",
            dependencies: [
                "UIFoundationToolbox",
                "UIFoundationTypealias",
            ]
        ),
        .target(
            name: "UIFoundationUtilities",
            dependencies: [
                "UIFoundationToolbox",
                "UIFoundationTypealias",
            ]
        ),
        .target(
            name: "UIFoundationToolbox",
            dependencies: [
                "UIFoundationTypealias",
                .product(name: "FrameworkToolbox", package: "FrameworkToolbox"),
                .product(name: "FoundationToolbox", package: "FrameworkToolbox"),
                .product(name: "AssociatedObject", package: "AssociatedObject"),
            ]
        ),

        .target(
            name: "UIFoundationAppleInternal",
            dependencies: [
                "UIFoundationAppleInternalObjC",
            ]
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
