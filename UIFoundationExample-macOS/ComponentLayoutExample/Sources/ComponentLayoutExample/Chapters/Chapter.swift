//
//  Chapter.swift
//  ComponentLayoutExample
//
//  The chapter registry.
//

import AppKit

/// One entry in the sidebar.
///
/// - Note: Holds a factory rather than a metatype. Upstream stores
///   `UIView.Type` and calls `viewType.init()`, which Swift only allows on a
///   `required init()` -- and `NSView`'s is not one. A closure sidesteps that
///   and matches how the example app's own `DemoCatalog` is written.
/// - Note: macOS 14 because most chapters drive themselves from an
///   `@Observable` view model, and `HomeView` does too. The example as a whole
///   is a macOS 14 feature; the package floor stays lower so the host app can
///   still import it -- see Package.swift.
@available(macOS 14.0, *)
public struct Chapter: Equatable {
    /// Shown in the sidebar.
    public let title: String

    /// Stable identity, used both for `Equatable` and as the render-node id so
    /// the engine swaps chapter views instead of reusing one across chapters.
    public let identifier: String

    let makeView: () -> ChapterView

    public init(title: String, identifier: String, makeView: @escaping () -> ChapterView) {
        self.title = title
        self.identifier = identifier
        self.makeView = makeView
    }

    public static func == (lhs: Chapter, rhs: Chapter) -> Bool {
        lhs.identifier == rhs.identifier
    }

    /// Every chapter, in sidebar order -- the same order upstream uses.
    public static let all: [Chapter] = [
        Chapter(title: "Getting Started", identifier: "getting-started") { GettingStartedView() },
        Chapter(title: "Simple Examples", identifier: "simple") { SimpleExamplesView() },
        Chapter(title: "VStack / HStack", identifier: "stack") { StackExamplesView() },
        Chapter(title: "ZStack", identifier: "zstack") { ZStackExamplesView() },
        Chapter(title: "Flow", identifier: "flow") { FlowExamplesView() },
        Chapter(title: "Waterfall", identifier: "waterfall") { WaterfallExamplesView() },
        Chapter(title: "Flex Modifiers", identifier: "flex") { FlexExamplesView() },
        Chapter(title: "Placement Modifiers", identifier: "placement") { PlacementExamplesView() },
        Chapter(title: "Sizing & Constraints", identifier: "sizing") { SizingAndConstraintExamplesView() },
        Chapter(title: "ConstraintReader", identifier: "constraint-reader") { ConstraintReaderExamplesView() },
        Chapter(title: "TappableView", identifier: "tappable-view") { TappableViewExamplesView() },
        Chapter(title: "ViewComponent", identifier: "view-component") { ViewComponentExamplesView() },
        Chapter(title: "Custom Components", identifier: "custom-component") { CustomComponentExamplesView() },
        Chapter(title: "Animation", identifier: "animation") { AnimationExamplesView() },
        Chapter(title: "View Hierarchy", identifier: "view-hierarchy") { ViewHierarchyExamplesView() },
        Chapter(title: "Environment", identifier: "environment") { EnvironmentExamplesView() },
        Chapter(title: "Performance Optimization", identifier: "performance") { PerformanceOptimizationExamplesView() },
        Chapter(title: "State Management", identifier: "state-management") { StateManagementExamplesView() },
    ]
}
