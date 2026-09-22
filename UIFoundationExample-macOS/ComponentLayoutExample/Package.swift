// swift-tools-version: 6.2

import CompilerPluginSupport
import PackageDescription

// The component-layout chapters live in a package of their own rather than in
// the example app's own sources, for two concrete reasons:
//
//   1. They define top-level `Text`, `Image` and `Separator`. Inside the app
//      module those names would win over SwiftUI's at every call site --
//      `SettingsDemoViewController` alone has 40-odd bare `Text("…")` that mean
//      SwiftUI.Text. A separate module keeps the two sets from ever meeting.
//   2. `#CodeExample` is a macro, and a macro needs a target of its own. An app
//      target cannot host one.
let package = Package(
    name: "ComponentLayoutExample",
    // Deliberately the example app's own deployment target, not the macOS 14
    // that `@Observable` needs. Raising the floor here would make the app fail
    // to even `import` this module ("compiling for macOS 12.0, but module has a
    // minimum deployment target of macOS 14.0"). The same trick UIFoundation's
    // own `UIFoundationSettings` uses: keep the floor low, annotate the
    // declarations that need more.
    platforms: [.macOS(.v12)],
    products: [
        .library(name: "ComponentLayoutExample", targets: ["ComponentLayoutExample"]),
    ],
    dependencies: [
        .package(path: "../..", traits: ["AppKitPlus"]),
        .package(url: "https://github.com/AppKitSupportProgram/AppKitPlus-Release", from: "0.3.1"),
        .package(url: "https://github.com/swiftlang/swift-syntax.git", from: "602.0.0"),
        // Syntax highlighting for the code blocks. `tree-sitter-swift` ships its
        // generated parser and its `queries/highlights.scm` only on the
        // `with-generated-files` branch -- the tagged releases carry the grammar
        // source and expect you to run `tree-sitter generate` yourself, which a
        // SwiftPM consumer cannot do.
        .package(url: "https://github.com/tree-sitter/swift-tree-sitter", from: "0.25.0"),
        .package(url: "https://github.com/alex-pinkus/tree-sitter-swift", branch: "with-generated-files"),
    ],
    targets: [
        // Captures an expression's source text at compile time *and* evaluates
        // it, so a chapter's sample and the code shown under it can never drift
        // apart. That is the whole reason upstream wrote it.
        .macro(
            name: "ComponentLayoutExampleMacros",
            dependencies: [
                .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
                .product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
            ]
        ),
        .target(
            name: "ComponentLayoutExample",
            dependencies: [
                "ComponentLayoutExampleMacros",
                .product(name: "UIFoundationComponent", package: "UIFoundation"),
                .product(name: "AppKitPlus", package: "AppKitPlus-Release"),
                .product(name: "SwiftTreeSitter", package: "swift-tree-sitter"),
                .product(name: "TreeSitterSwift", package: "tree-sitter-swift"),
            ]
        ),
    ],
    // Matches the UIFoundation package. The chapters are ported from upstream
    // code written before Swift 6's isolation rules, and several of them --
    // `Separator.defaultSeparatorColor` among them -- keep mutable statics that
    // language mode 6 rejects outright.
    swiftLanguageModes: [.v5]
)
