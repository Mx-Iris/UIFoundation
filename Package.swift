// swift-tools-version: 6.2
import PackageDescription
import Foundation

extension Package.Dependency {
    enum LocalSearchPath {
        case package(path: String, isRelative: Bool, isEnabled: Bool)
    }

    static func package(local localSearchPaths: LocalSearchPath..., remote: Package.Dependency) -> Package.Dependency {
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

let package = Package(
    name: "UIFoundation",
    platforms: [
        // AppKit
        .macOS(.v10_15),
        // UIKit
        .iOS(.v13), .macCatalyst(.v13), .tvOS(.v13), .visionOS(.v1)
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

        .library(
            name: "UIFoundationAppleInternal",
            targets: ["UIFoundationAppleInternal"]
        ),

    ],
    dependencies: [
        .package(
            local: .package(
                path: "../FrameworkToolbox",
                isRelative: true,
                isEnabled: true
            ),
            remote: .package(
                url: "https://github.com/Mx-Iris/FrameworkToolbox",
                branch: "main"
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
