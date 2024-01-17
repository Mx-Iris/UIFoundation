// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.
import Foundation
import PackageDescription
extension Package.Dependency {
    static func package(localPath: String, remotePath: String, branch: String) -> Package.Dependency {
        if FileManager.default.fileExists(atPath: localPath) {
            return .package(path: localPath)
        } else {
            return .package(url: remotePath, branch: branch)
        }
    }
}

let package = Package(
    name: "UIFoundation",
    platforms: [.macOS(.v12), .iOS(.v15), .tvOS(.v15), .macCatalyst(.v15)],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "UIFoundation",
            targets: ["UIFoundation"]
        ),
        .library(
            name: "UIFoundationToolbox",
            targets: [ "UIFoundationToolbox"]
        )
    ],
    dependencies: [
        .package(
            localPath: "/Volumes/Repositories/Private/Personal/Library/Multi/FrameworkToolbox",
            remotePath: "https://github.com/Mx-Iris/FrameworkToolbox",
            branch: "main"
        )
    ],
    targets: [
        .target(
            name: "UIFoundation",
            dependencies: [
                "UIFoundationToolbox",
            ]
        ),
        
        .target(
            name: "UIFoundationInternal"
        ),

        .target(
            name: "UIFoundationToolbox",
            dependencies: [
                .product(name: "FrameworkToolbox", package: "FrameworkToolbox"),
            ]
        ),

        .target(
            name: "UIFoundationAppleInternal"
        ),

        .testTarget(
            name: "UIFoundationTests",
            dependencies: ["UIFoundation"]
        ),
    ]
)
