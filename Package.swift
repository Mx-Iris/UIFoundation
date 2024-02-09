// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "UIFoundation",
    platforms: [.macOS(.v12), .iOS(.v15), .tvOS(.v15), .macCatalyst(.v15)],
    products: [
        .library(
            name: "UIFoundation",
            targets: [
                "UIFoundation"
            ]
        ),
        .library(
            name: "UIFoundationToolbox",
            targets: [ 
                "UIFoundationToolbox"
            ]
        )
    ],
    dependencies: [
        .package(
            url: "https://github.com/Mx-Iris/FrameworkToolbox",
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
                .product(name: "FrameworkToolboxMacro", package: "FrameworkToolbox"),
                .product(name: "FoundationToolbox", package: "FrameworkToolbox"),
            ]
        ),

        .target(
            name: "UIFoundationAppleInternal"
        ),

        .testTarget(
            name: "UIFoundationTests",
            dependencies: [
                "UIFoundation"
            ]
        ),
    ]
)
