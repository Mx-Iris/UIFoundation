// swift-tools-version: 5.9
import PackageDescription

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
//        .package(
//            url: "https://github.com/p-x9/AssociatedObject",
//            .upToNextMajor(from: "0.10.0")
//        )
    ],
    targets: [
        .target(
            name: "UIFoundationTypealias"
        ),

        .target(
            name: "UIFoundation",
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
//                .product(name: "AssociatedObject", package: "AssociatedObject"),
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
