// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "UIFoundation",
    platforms: [.macOS(.v12), .iOS(.v15)],
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
        )
    ],
    dependencies: [
        .package(
            url: "https://github.com/Mx-Iris/FrameworkToolbox",
            branch: "main"
        ),
    ],
    targets: [
        .target(
            name: "UIFoundation",
            dependencies: [
                "UIFoundationToolbox",
            ]
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
            name: "UIFoundationAppleInternal",
            dependencies: [
                "UIFoundationAppleInternalObjC"
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
