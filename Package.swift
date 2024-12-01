// swift-tools-version: 5.9
import PackageDescription

let appkitPlatforms: [Platform] = [.macOS]

let uikitPlatforms: [Platform] = [.iOS, .tvOS, .visionOS, .watchOS, .macCatalyst]


let package = Package(
    name: "UIFoundation",
    platforms: [.macOS(.v10_15), .iOS(.v12), .macCatalyst(.v13), .tvOS(.v13)],
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
        .library(
            name: "UIFoundationAppleInternalObjC",
            targets: ["UIFoundationAppleInternalObjC"]
        ),
    ],
    dependencies: [
        .package(
            url: "https://github.com/Mx-Iris/FrameworkToolbox",
            branch: "main"
        ),
        .package(
            url: "https://github.com/MxIris-Library-Forks/AssociatedObject",
            branch: "main"
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
            ]
        ),

        .target(
            name: "UIFoundationAppKit",
            dependencies: [
                "UIFoundationToolbox",
                "UIFoundationTypealias",
                "UIFoundationUtilities",
            ]
        ),
        .target(
            name: "UIFoundationUIKit",
            dependencies: [
                "UIFoundationToolbox",
                "UIFoundationTypealias",
                "UIFoundationUtilities",
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
                .product(name: "FrameworkToolboxMacro", package: "FrameworkToolbox"),
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
    ]
)
