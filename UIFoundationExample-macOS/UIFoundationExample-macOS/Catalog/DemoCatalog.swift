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
            title: "Tab Bar",
            category: "Controls",
            summary: "The macOS 26 window tab bar — ⌘T / ⌘W, drag to reorder, double-click to rename, and overflow that folds into piles once the tabs stop fitting.",
            makeViewController: { TabBarDemoViewController() }
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
            title: "System HUD",
            category: "Controls",
            summary: "The volume-HUD-shaped floating panel — live glyph / title / geometry editing, plus the over-long-title and interrupted-fade cases.",
            makeViewController: { SystemHUDDemoViewController() }
        ),
        Demo(
            title: "Navigation",
            category: "Controls",
            summary: "NavigationController driving the App Store's push / pop — live duration, parallax, dimming and curve, plus the two-finger swipe back.",
            makeViewController: { NavigationDemoViewController() }
        ),
        Demo(
            title: "Settings Window",
            category: "Controls",
            summary: "A seven-page settings panel in its own window, with a page list driven by the settings themselves and counters showing what a change actually redraws.",
            minimumMacOS: OperatingSystemVersion(majorVersion: 14, minorVersion: 0, patchVersion: 0),
            makeViewController: {
                if #available(macOS 14.0, *) {
                    SettingsDemoViewController()
                } else {
                    Demo.unavailablePlaceholderViewController(requiring: "macOS 14")
                }
            }
        ),
        Demo(
            title: "Settings Scene Representation",
            category: "Controls",
            summary: "An AppKit-lifecycle app registering a native SwiftUI Settings scene with NSHostingSceneRepresentation and opening it through the representation environment.",
            minimumMacOS: OperatingSystemVersion(majorVersion: 26, minorVersion: 0, patchVersion: 0),
            makeViewController: {
                if #available(macOS 26.0, *) {
                    SettingsSceneRepresentationDemoViewController()
                } else {
                    Demo.unavailablePlaceholderViewController(requiring: "macOS 26")
                }
            }
        ),
        Demo(
            title: "Welcome Panel",
            category: "Controls",
            summary: "The Xcode-style welcome window in all three of its generations — it opens in a window of its own, which is also where the Xcode 26 replica gets compared against the real thing.",
            makeViewController: { WelcomePanelDemoViewController() }
        ),
        Demo(
            title: "Toolbar Navigation",
            category: "Controls",
            summary: "NSToolbar.Navigation driving a pretend documentation site in its own window — click to step, press and hold for the history menu.",
            makeViewController: { ToolbarNavigationDemoViewController() }
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
