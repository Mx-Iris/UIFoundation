//
//  DemoCatalog.swift
//  UIFoundationExample-macOS
//
//  The registry of every demo shown by the example app.
//

import AppKit

/// The list of demos shown in the sidebar.
///
/// **To add a demo:** create an `NSViewController` under `Demos/` and append one
/// `Demo` to ``all``. The sidebar, grouping, and detail wiring pick it up
/// automatically.
enum DemoCatalog {
    static let all: [Demo] = [
        Demo(
            title: "Tabs Control",
            category: "Controls",
            summary: "Numbers.app-style tabs — switch Default / Chrome / Safari styles, add, close, drag to reorder, double-click to rename.",
            makeViewController: { TabsControlDemoViewController() }
        ),
        Demo(
            title: "Layer Background",
            category: "Rendering",
            summary: "LayerBackedView cards and an NSTableCellView composed with LayerBackgroundProviding.",
            makeViewController: { LayerBackgroundDemoViewController() }
        ),
        Demo(
            title: "Insets Label",
            category: "Text",
            summary: "InsetsTextFieldCell / RoundedBorderLabel rendering plus runtime drawing-path diagnostics.",
            makeViewController: { InsetsLabelDemoViewController() }
        ),
        Demo(
            title: "Text Finder",
            category: "Text",
            summary: "OutlineViewTextFinderClient driving an NSOutlineView — press ⌘F to open the find bar.",
            makeViewController: { TextFinderDemoViewController() }
        ),
        Demo(
            title: "Custom Tooltip",
            category: "AppKit Private",
            summary: "CustomToolTipManager playground — live color/slider editing, per-view override, plus an unmodified system control for visual comparison.",
            makeViewController: { CustomTooltipDemoViewController() }
        ),
    ]

    /// Demos grouped by category, preserving first-seen category order.
    static var grouped: [(category: String, demos: [Demo])] {
        var order: [String] = []
        var buckets: [String: [Demo]] = [:]
        for demo in all {
            if buckets[demo.category] == nil { order.append(demo.category) }
            buckets[demo.category, default: []].append(demo)
        }
        return order.map { (category: $0, demos: buckets[$0] ?? []) }
    }
}
